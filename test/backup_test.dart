import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:puppy_ledger/core/backup.dart';
import 'package:puppy_ledger/core/models.dart';
import 'package:puppy_ledger/core/store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Local fixture: a generated valid 1×1 PNG, never user data or a remote asset.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4f+fEfwAJJAOjQ+82DQAAAABJRU5ErkJggg==',
);
const _timestamp = '2026-11-03T12:00:00.000Z';
const _categories = [
  Category(id: 'food', name: '餐饮', active: true),
  Category(id: 'old', name: '已停用分类', active: false, kind: EntryKind.income),
];
const _settings = LedgerSettings(
  ledgerName: '小狗的旅行账本',
  tagline: '慢慢花，也慢慢记录',
  themeKey: 'sage',
  imageFile: 'previous_phone_dog.png',
);
const _entries = [
  LedgerEntry(
    id: 'expense',
    date: '2026-10-31',
    categoryId: 'food',
    note: '晚餐',
    createdAt: _timestamp,
    updatedAt: _timestamp,
    cents: 1234,
    kind: EntryKind.expense,
  ),
  LedgerEntry(
    id: 'refund',
    date: '2026-11-01',
    categoryId: 'old',
    note: '跨月退款',
    createdAt: _timestamp,
    updatedAt: _timestamp,
    cents: 2000,
    kind: EntryKind.income,
  ),
];

BackupData _candidate({Uint8List? image}) => BackupData(
  entries: _entries,
  categories: _categories,
  settings: _settings,
  imageBytes: image ?? _png,
);

Map<String, dynamic> _manifest() => {
  'format': 'puppy_ledger',
  'version': 2,
  'exportedAt': _timestamp,
  'entries': _entries.map((e) => e.toMap()).toList(),
  'categories': _categories.map((e) => e.toMap()).toList(),
  'settings': {..._settings.toMap(), 'imageFile': 'home.img'},
};

Uint8List _zip(
  Map<String, dynamic> manifest, {
  bool includeImage = true,
  Uint8List? image,
  String? extraName,
}) {
  final json = utf8.encode(jsonEncode(manifest));
  final archive = Archive()
    ..addFile(
      (ArchiveFile('backup.json', json.length, json)
        ..compression = CompressionType.none),
    );
  if (includeImage) {
    final bytes = image ?? _png;
    archive.addFile(
      (ArchiveFile('home.img', bytes.length, bytes)
        ..compression = CompressionType.none),
    );
  }
  if (extraName != null) {
    archive.addFile(
      (ArchiveFile(extraName, 1, [0])..compression = CompressionType.none),
    );
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory directory;
  late LedgerStore store;
  late String databasePath;
  late List<Map<String, Object?>> originalEntries;
  late List<Map<String, Object?>> originalCategories;
  late Map<String, Object?> originalSettings;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('puppy-backup-test-');
    databasePath = p.join(directory.path, 'test.sqlite');
    store = await LedgerStore.open(
      databasePath: databasePath,
      factory: databaseFactoryFfi,
    );
    await File(p.join(directory.path, 'original.png')).writeAsBytes(_png);
    await store.saveSettings(
      const LedgerSettings(
        ledgerName: '不可丢失的原账本',
        tagline: '原有设置',
        themeKey: 'lemon',
        imageFile: 'original.png',
      ),
    );
    await store.saveEntry(
      const LedgerEntry(
        id: 'existing',
        date: '2025-01-01',
        categoryId: 'default-1',
        note: '必须保留',
        createdAt: _timestamp,
        updatedAt: _timestamp,
        cents: 99,
        kind: EntryKind.expense,
      ),
    );
    originalEntries = (await store.entries()).map((e) => e.toMap()).toList();
    originalCategories = (await store.categories())
        .map((e) => e.toMap())
        .toList();
    originalSettings = (await store.settings()).toMap();
  });

  tearDown(() async {
    await store.close();
    await directory.delete(recursive: true);
  });

  Future<void> expectOriginalUnchanged() async {
    expect(
      (await store.entries()).map((e) => e.toMap()).toList(),
      originalEntries,
    );
    expect(
      (await store.categories()).map((e) => e.toMap()).toList(),
      originalCategories,
    );
    expect((await store.settings()).toMap(), originalSettings);
    expect(
      await File(p.join(directory.path, 'original.png')).readAsBytes(),
      _png,
    );
  }

  test(
    'portable ZIP round trip restores full ledger and exact picture after reopen',
    () async {
      final encoded = BackupCodec.encode(_candidate());
      final archive = ZipDecoder().decodeBytes(encoded);
      expect(archive.map((e) => e.name), ['backup.json', 'home.img']);
      final manifest =
          jsonDecode(utf8.decode(archive.findFile('backup.json')!.content))
              as Map<String, dynamic>;
      expect(manifest['version'], 3);
      expect((manifest['settings'] as Map)['imageFile'], 'home.img');
      expect(
        utf8.decode(archive.findFile('backup.json')!.content),
        isNot(contains('previous_phone_dog.png')),
      );
      final decoded = BackupCodec.decode(encoded);
      expect(decoded.imageBytes, _png);
      await BackupService(store, directory).restore(decoded);
      await store.close();
      store = await LedgerStore.open(
        databasePath: databasePath,
        factory: databaseFactoryFfi,
      );
      expect(
        (await store.entries()).map((e) => e.toMap()),
        unorderedEquals(_entries.map((e) => e.toMap())),
      );
      expect(
        (await store.categories()).map((c) => c.toMap()).toList(),
        _categories.map((c) => c.toMap()).toList(),
      );
      final restoredSettings = await store.settings();
      expect(restoredSettings.ledgerName, _settings.ledgerName);
      expect(restoredSettings.tagline, _settings.tagline);
      expect(restoredSettings.themeKey, _settings.themeKey);
      expect(restoredSettings.imageFile, isNot('previous_phone_dog.png'));
      expect(p.isAbsolute(restoredSettings.imageFile!), isFalse);
      expect(
        await File(
          p.join(directory.path, restoredSettings.imageFile!),
        ).readAsBytes(),
        _png,
      );
    },
  );

  test(
    'default-image backup restores without requiring an old phone file',
    () async {
      final data = BackupData(
        entries: const [],
        categories: _categories,
        settings: const LedgerSettings(ledgerName: '空账本'),
      );
      final decoded = BackupCodec.decode(BackupCodec.encode(data));
      expect(decoded.imageBytes, isNull);
      await BackupService(store, directory).restore(decoded);
      expect(await store.entries(), isEmpty);
      expect((await store.settings()).imageFile, isNull);
      expect((await store.settings()).ledgerName, '空账本');
    },
  );

  test('corrupt ZIP leaves every original row and image untouched', () async {
    expect(
      () => BackupCodec.decode(Uint8List.fromList([80, 75, 3, 4, 0, 1])),
      throwsFormatException,
    );
    await expectOriginalUnchanged();
  });

  final malformed = <String, void Function(Map<String, dynamic>)>{
    'missing required entries': (m) => m.remove('entries'),
    'unsupported version': (m) => m['version'] = 99,
    'bad date': (m) => (m['entries'] as List)[0]['date'] = '2026-02-30',
    'negative cents': (m) => (m['entries'] as List)[0]['cents'] = -1234,
    'floating amount': (m) => (m['entries'] as List)[0]['cents'] = 12.34,
    'unknown category': (m) =>
        (m['entries'] as List)[0]['categoryId'] = 'missing',
    'duplicate IDs': (m) => (m['entries'] as List)[1]['id'] = 'expense',
    'unknown kind': (m) => (m['entries'] as List)[0]['kind'] = 'unknown',
    'missing ledger name': (m) => (m['settings'] as Map).remove('ledgerName'),
    'absolute image path': (m) =>
        (m['settings'] as Map)['imageFile'] = '/old/home.png',
    'unexpected image reference': (m) =>
        (m['settings'] as Map)['imageFile'] = 'other.png',
  };
  for (final invalid in malformed.entries) {
    test('rejects ${invalid.key} before touching current ledger', () async {
      final manifest = _manifest();
      invalid.value(manifest);
      expect(() => BackupCodec.decode(_zip(manifest)), throwsFormatException);
      await expectOriginalUnchanged();
    });
  }

  test(
    'missing image and archive traversal entry are rejected without extraction',
    () async {
      expect(
        () => BackupCodec.decode(_zip(_manifest(), includeImage: false)),
        throwsFormatException,
      );
      expect(
        () =>
            BackupCodec.decode(_zip(_manifest(), extraName: '../outside.png')),
        throwsFormatException,
      );
      await expectOriginalUnchanged();
    },
  );

  test(
    'invalid image fails preparation while original data and image survive',
    () async {
      final bad = Uint8List.fromList(utf8.encode('not an image'));
      final decoded = BackupCodec.decode(_zip(_manifest(), image: bad));
      await expectLater(
        BackupService(store, directory).restore(decoded),
        throwsFormatException,
      );
      await expectOriginalUnchanged();
      expect(
        directory.listSync().whereType<File>().where(
          (f) => p.basename(f.path).startsWith('dog_restore_'),
        ),
        isEmpty,
      );
    },
  );

  test('CRC damage is detected even when JSON still parses', () async {
    final bytes = _zip(_manifest());
    final data = ByteData.sublistView(bytes);
    final jsonStart = 30 + data.getUint16(26, Endian.little);
    final text = utf8.decode(
      bytes.sublist(jsonStart, jsonStart + data.getUint32(22, Endian.little)),
    );
    final index = text.indexOf('2026-11-03');
    bytes[jsonStart + index + 3] = '5'.codeUnitAt(0);
    expect(() => BackupCodec.decode(bytes), throwsFormatException);
    await expectOriginalUnchanged();
  });

  test(
    'compressed archive and forged huge size are rejected before decoding',
    () async {
      final json = utf8.encode(jsonEncode(_manifest()));
      final compressed = Uint8List.fromList(
        ZipEncoder().encode(
          Archive()..addFile(ArchiveFile('backup.json', json.length, json)),
        ),
      );
      expect(() => BackupCodec.decode(compressed), throwsFormatException);
      final bytes = _zip(_manifest());
      final data = ByteData.sublistView(bytes);
      final central = data.getUint32(bytes.length - 6, Endian.little);
      data.setUint32(central + 20, 0x7fffffff, Endian.little);
      data.setUint32(central + 24, 0x7fffffff, Endian.little);
      expect(() => BackupCodec.decode(bytes), throwsFormatException);
      await expectOriginalUnchanged();
    },
  );

  test(
    'duplicate ZIP member names are rejected before library deduplication',
    () async {
      final output = OutputMemoryStream();
      final encoder = ZipEncoder()..startEncode(output);
      encoder.add(
        ArchiveFile('home.img', _png.length, _png)
          ..compression = CompressionType.none,
      );
      encoder.add(
        ArchiveFile('home.img', _png.length, _png)
          ..compression = CompressionType.none,
      );
      encoder.endEncode();
      expect(
        () => BackupCodec.decode(Uint8List.fromList(output.getBytes())),
        throwsFormatException,
      );
      await expectOriginalUnchanged();
    },
  );

  test('direct restore also refuses missing referenced image', () async {
    await expectLater(
      BackupService(store, directory).restore(
        const BackupData(
          entries: _entries,
          categories: _categories,
          settings: _settings,
        ),
      ),
      throwsFormatException,
    );
    await expectOriginalUnchanged();
  });

  test(
    'database failure rolls back deletes and removes staged picture',
    () async {
      // Same factory/path returns the same isolated DB. A trigger fails after
      // replacement starts, proving rollback rather than only pre-validation.
      final db = await databaseFactoryFfi.openDatabase(databasePath);
      await db.execute(
        "CREATE TRIGGER reject_restore BEFORE INSERT ON entries "
        "WHEN NEW.id = 'expense' BEGIN SELECT RAISE(ABORT, 'simulated disk write failure'); END",
      );
      await expectLater(
        BackupService(store, directory).restore(_candidate()),
        throwsA(isA<DatabaseException>()),
      );
      await expectOriginalUnchanged();
      expect(
        directory.listSync().whereType<File>().where(
          (f) => p.basename(f.path).startsWith('dog_restore_'),
        ),
        isEmpty,
      );
    },
  );
}
