import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import 'models.dart';
import 'migration.dart';
import 'logic.dart';
import 'store.dart';
import 'zip_guard.dart';

class BackupData {
  const BackupData({
    required this.entries,
    required this.categories,
    required this.settings,
    this.imageBytes,
  });
  final List<LedgerEntry> entries;
  final List<Category> categories;
  final LedgerSettings settings;
  final Uint8List? imageBytes;
}

/// A portable ZIP. Only backup.json and optional home.img are permitted.
/// No file from an untrusted archive is ever extracted using its own path.
class BackupCodec {
  static const formatVersion = 3;
  static const maxBackupBytes = 64 * 1024 * 1024;
  static const maxImageBytes = 12 * 1024 * 1024;
  static const maxJsonBytes = 32 * 1024 * 1024;

  static Uint8List encode(BackupData data) {
    validateSnapshot(data.entries, data.categories, data.settings);
    final settings = data.settings.toMap();
    settings['imageFile'] = data.imageBytes == null ? null : 'home.img';
    final json = utf8.encode(
      jsonEncode({
        'format': 'puppy_ledger',
        'version': formatVersion,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'entries': data.entries.map((e) => e.toMap()).toList(),
        'categories': data.categories.map((c) => c.toMap()).toList(),
        'settings': settings,
      }),
    );
    if (json.length > maxJsonBytes) {
      throw const FormatException('账本过大，暂时无法导出');
    }
    final archive = Archive()
      ..addFile(
        (ArchiveFile('backup.json', json.length, json)
          ..compression = CompressionType.none),
      );
    final image = data.imageBytes;
    if (image != null) {
      if (image.length > maxImageBytes) {
        throw const FormatException('图片过大，请选择 12 MB 以内的图片');
      }
      archive.addFile(
        (ArchiveFile('home.img', image.length, image)
          ..compression = CompressionType.none),
      );
    }
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  static BackupData decode(Uint8List bytes) {
    try {
      if (bytes.isEmpty || bytes.length > maxBackupBytes) {
        throw const FormatException('备份为空或超过 64 MB');
      }
      final files = readStoredBackupFiles(
        bytes,
        limits: {'backup.json': maxJsonBytes, 'home.img': maxImageBytes},
        maxArchiveBytes: maxBackupBytes,
      );
      final jsonFile = files['backup.json'];
      if (jsonFile == null) throw const FormatException('缺少账本数据');
      final decoded = jsonDecode(utf8.decode(jsonFile));
      if (decoded is! Map<String, dynamic> ||
          decoded['format'] != 'puppy_ledger' ||
          ![1, 2, formatVersion].contains(decoded['version'])) {
        throw const FormatException('不是支持的小狗账本备份，或备份版本不兼容');
      }
      final exportedAt = decoded['exportedAt'];
      if (exportedAt is! String || DateTime.tryParse(exportedAt) == null) {
        throw const FormatException('备份导出时间无效');
      }
      if (decoded['entries'] is! List ||
          decoded['categories'] is! List ||
          decoded['settings'] is! Map<String, dynamic>) {
        throw const FormatException('备份必要字段缺失');
      }
      final rawEntries = (decoded['entries'] as List)
          .map((v) => Map<String, Object?>.from(v as Map))
          .toList();
      if (decoded['version'] != formatVersion) {
        for (final row in rawEntries) {
          row.remove('occurredMinute');
        }
      }
      final rawCategories = (decoded['categories'] as List)
          .map((v) => Map<String, Object?>.from(v as Map))
          .toList();
      final rawSettings = Map<String, Object?>.from(decoded['settings'] as Map);
      final legacy = decoded['version'] == 1
          ? migrateLegacyLedger(
              entries: rawEntries,
              categories: rawCategories,
              settings: rawSettings,
            )
          : null;
      final entries =
          legacy?.entries ?? rawEntries.map(LedgerEntry.fromMap).toList();
      final categories =
          legacy?.categories ?? rawCategories.map(Category.fromMap).toList();
      final settings = legacy?.settings ?? LedgerSettings.fromMap(rawSettings);
      validateSnapshot(entries, categories, settings);
      final imageFile = files['home.img'];
      if ((settings.imageFile != null && settings.imageFile != 'home.img') ||
          (settings.imageFile != null) != (imageFile != null)) {
        throw const FormatException('备份图片引用不完整');
      }
      final image = imageFile == null ? null : Uint8List.fromList(imageFile);
      if (image != null && image.isEmpty) throw const FormatException('备份图片为空');
      return BackupData(
        entries: entries,
        categories: categories,
        settings: settings,
        imageBytes: image,
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('备份已损坏或格式不正确，原账本未改动');
    }
  }
}

Future<void> validateImage(Uint8List bytes) async {
  if (bytes.isEmpty || bytes.length > BackupCodec.maxImageBytes) {
    throw const FormatException('请选择 12 MB 以内的图片');
  }
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  try {
    buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    if (descriptor.width <= 0 ||
        descriptor.height <= 0 ||
        descriptor.width * descriptor.height > 40000000) {
      throw const FormatException('图片尺寸过大，请选择 4000 万像素以内的图片');
    }
    final codec = await descriptor.instantiateCodec(targetWidth: 512);
    final frame = await codec.getNextFrame();
    frame.image.dispose();
    codec.dispose();
  } on FormatException {
    rethrow;
  } catch (_) {
    throw const FormatException('图片无法读取，请选择有效的照片或 PNG 图片');
  } finally {
    descriptor?.dispose();
    buffer?.dispose();
  }
}

/// Prepares every byte before the SQLite transaction. Old image remains until
/// commit; a failed DB transaction leaves old rows and old image reference intact.
class BackupService {
  BackupService(this.store, this.directory);
  final LedgerStore store;
  final Directory directory;

  Future<LedgerSettings> restore(BackupData data) async {
    validateSnapshot(data.entries, data.categories, data.settings);
    if ((data.settings.imageFile != null) != (data.imageBytes != null)) {
      throw const FormatException('备份图片引用不完整');
    }
    File? staged;
    try {
      if (data.imageBytes != null) {
        await validateImage(data.imageBytes!);
        staged = File(
          p.join(
            directory.path,
            'dog_restore_${DateTime.now().microsecondsSinceEpoch}.img',
          ),
        );
        await staged.writeAsBytes(data.imageBytes!, flush: true);
      }
      final settings = LedgerSettings(
        ledgerName: data.settings.ledgerName,
        tagline: data.settings.tagline,
        themeKey: data.settings.themeKey,
        goldenIncome: data.settings.goldenIncome,
        imageFile: staged == null ? null : p.basename(staged.path),
      );
      await store.replaceAll(
        entries: data.entries,
        categories: data.categories,
        settings: settings,
      );
      return settings;
    } catch (_) {
      if (staged != null && await staged.exists()) {
        try {
          await staged.delete();
        } catch (_) {
          /* preserve original error */
        }
      }
      rethrow;
    }
  }
}
