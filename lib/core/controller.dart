import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import 'backup.dart';
import 'logic.dart';
import 'models.dart';
import 'store.dart';

class LedgerController extends ChangeNotifier {
  LedgerController({
    required this.store,
    required this.directory,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;
  final DateTime Function() _clock;
  DateTime get now => _clock();
  int _ledgerGeneration = 0;
  final LedgerStore store;
  final Directory directory;
  List<LedgerEntry> entries = [];
  List<Category> categories = [];
  LedgerSettings settings = const LedgerSettings();
  bool _busy = false;
  static const _files = MethodChannel('puppy_ledger/files');
  final _random = Random.secure();

  String newId() =>
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
      '-${List.generate(12, (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';

  Future<void> refresh() async {
    final newEntries = await store.entries();
    final newCategories = await store.categories();
    final newSettings = await store.settings();
    entries = newEntries;
    categories = newCategories;
    settings = newSettings;
    notifyListeners();
  }

  Future<T> _exclusive<T>(Future<T> Function() action) async {
    if (_busy) throw StateError('正在处理，请稍候再试');
    _busy = true;
    try {
      return await action();
    } finally {
      _busy = false;
    }
  }

  Future<LedgerEntry> saveEntry({
    String? id,
    required String amount,
    required EntryKind kind,
    required String date,
    int? occurredMinute,
    required String categoryId,
    required String note,
  }) => _exclusive(() async {
    final cents = parseCents(amount);
    parseDateKey(date);
    final local = _clock().toLocal();
    final now = local.toUtc().toIso8601String();
    final existing = id == null
        ? null
        : entries.where((e) => e.id == id).firstOrNull;
    if (id != null && existing == null) throw StateError('这笔记录已不存在，请返回刷新');
    final category = categories.where((c) => c.id == categoryId).firstOrNull;
    if (category == null ||
        category.kind != kind ||
        (!category.active && existing?.categoryId != categoryId)) {
      throw StateError('请选择一个可用分类');
    }
    final saved = LedgerEntry(
      id: id ?? newId(),
      date: date,
      occurredMinute:
          occurredMinute ??
          (existing == null
              ? local.hour * 60 + local.minute
              : existing.occurredMinute),
      categoryId: categoryId,
      note: note.trim(),
      cents: cents,
      kind: kind,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      legacyCategoryId: existing?.legacyCategoryId,
      legacyCategoryName: existing?.legacyCategoryName,
    );
    await store.saveEntry(saved);
    entries = [...entries.where((e) => e.id != saved.id), saved]
      ..sort(ledgerOrder);
    notifyListeners();
    return saved;
  });

  Future<void> deleteEntry(String id) => _exclusive(() async {
    await store.deleteEntry(id);
    entries = entries.where((e) => e.id != id).toList();
    notifyListeners();
  });

  Future<DeletedEntryToken> deleteWithUndo(String id) => _exclusive(() async {
    final entry = entries.where((e) => e.id == id).firstOrNull;
    if (entry == null) throw StateError('这笔记录已不存在');
    await store.deleteEntry(id);
    entries = entries.where((e) => e.id != id).toList();
    final token = DeletedEntryToken._(
      entry,
      _clock().add(const Duration(seconds: 5)),
      _ledgerGeneration,
    );
    notifyListeners();
    return token;
  });

  Future<void> undoDeletes(List<DeletedEntryToken> tokens) =>
      _exclusive(() async {
        final now = _clock();
        if (tokens.isEmpty ||
            tokens.any(
              (t) =>
                  t._used ||
                  t._generation != _ledgerGeneration ||
                  !now.isBefore(t.expiresAt),
            )) {
          throw StateError('撤销时间已过或账本已变更');
        }
        if (tokens.map((t) => t.entry.id).toSet().length != tokens.length) {
          throw StateError('重复的撤销请求');
        }
        await store.restoreDeletedEntries(tokens.map((t) => t.entry).toList());
        for (final token in tokens) {
          token._used = true;
        }
        entries = [...entries, ...tokens.map((t) => t.entry)]
          ..sort(ledgerOrder);
        notifyListeners();
      });

  Future<void> saveCategory(Category category) => _exclusive(() async {
    await store.saveCategory(category);
    if (categories.any((c) => c.id == category.id)) {
      categories = categories
          .map((c) => c.id == category.id ? category : c)
          .toList();
    } else {
      categories = [...categories, category];
    }
    notifyListeners();
  });

  Future<void> updateSettings(LedgerSettings value) => _exclusive(() async {
    await store.saveSettings(value);
    settings = value;
    notifyListeners();
  });

  Future<void> chooseImage() => _exclusive(() async {
    final bytes = await _files.invokeMethod<Uint8List>('pickImage');
    if (bytes == null) return;
    await validateImage(bytes);
    final name = 'dog_${newId()}.img';
    final file = File(p.join(directory.path, name));
    try {
      await file.writeAsBytes(bytes, flush: true);
      final saved = LedgerSettings(
        ledgerName: settings.ledgerName,
        tagline: settings.tagline,
        themeKey: settings.themeKey,
        imageFile: name,
        goldenIncome: settings.goldenIncome,
      );
      await store.saveSettings(saved);
      settings = saved;
    } catch (_) {
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
      rethrow;
    }
    notifyListeners();
  });

  Future<void> resetImage() => updateSettings(
    LedgerSettings(
      ledgerName: settings.ledgerName,
      tagline: settings.tagline,
      themeKey: settings.themeKey,
      goldenIncome: settings.goldenIncome,
    ),
  );

  Future<void> exportBackup() => _exclusive(() async {
    final currentEntries = await store.entries();
    final currentCategories = await store.categories();
    final currentSettings = await store.settings();
    Uint8List? image;
    if (currentSettings.imageFile != null) {
      image = await File(
        p.join(directory.path, currentSettings.imageFile!),
      ).readAsBytes();
    }
    final bytes = BackupCodec.encode(
      BackupData(
        entries: currentEntries,
        categories: currentCategories,
        settings: currentSettings,
        imageBytes: image,
      ),
    );
    final saved = await _files.invokeMethod<bool>('writeBackup', {
      'bytes': bytes,
      'name': 'puppy_ledger_${dateKey(DateTime.now())}.zip',
    });
    if (saved != true) throw const FileActionCancelled();
  });

  Future<BackupData?> chooseBackup() => _exclusive(() async {
    final bytes = await _files.invokeMethod<Uint8List>('readBackup');
    if (bytes == null) return null;
    final data = BackupCodec.decode(bytes);
    if (data.imageBytes != null) await validateImage(data.imageBytes!);
    return data;
  });

  Future<void> restoreBackup(BackupData data) => _exclusive(() async {
    settings = await BackupService(store, directory).restore(data);
    _ledgerGeneration++;
    entries = [...data.entries]..sort(ledgerOrder);
    categories = List.of(data.categories);
    notifyListeners();
  });
}

class FileActionCancelled implements Exception {
  const FileActionCancelled();
  @override
  String toString() => '已取消保存，备份文件未导出';
}

/// Short-lived undo receipt. Original immutable row, including both timestamps.
class DeletedEntryToken {
  DeletedEntryToken._(this.entry, this.expiresAt, this._generation);
  final LedgerEntry entry;
  final DateTime expiresAt;
  final int _generation;
  bool _used = false;
}
