import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:puppy_ledger/core/backup.dart';
import 'package:puppy_ledger/core/controller.dart';
import 'package:puppy_ledger/core/logic.dart';
import 'package:puppy_ledger/core/models.dart';
import 'package:puppy_ledger/core/store.dart';

const created = '2024-02-29T13:45:01.123Z';
const updated = '2026-10-31T10:02:03.456Z';
final oldCategories = [
  {'id': 'old-food', 'name': '旧餐饮', 'active': 0},
  // A legacy ID may collide with our new defaults: never overwrite it.
  {'id': 'income-refund', 'name': '我的旧分类', 'active': 1},
];
final oldEntries = [
  for (final kind in ['expense', 'refund'])
    {
      'id': 'stable-$kind',
      'date': '2026-10-31',
      'categoryId': 'old-food',
      'note': '不改原始备注 $kind',
      'createdAt': created,
      'updatedAt': updated,
      'cents': 10000,
      'kind': kind,
    },
];
final oldSettings = {
  'ledgerName': '旧账本',
  'tagline': '原来的话',
  'themeKey': 'peach',
  'imageFile': null,
};

Uint8List legacyZip() {
  final json = utf8.encode(
    jsonEncode({
      'format': 'puppy_ledger',
      'version': 1,
      'exportedAt': updated,
      'entries': oldEntries,
      'categories': oldCategories,
      'settings': oldSettings,
    }),
  );
  return Uint8List.fromList(
    ZipEncoder().encode(
      Archive()..addFile(
        ArchiveFile('backup.json', json.length, json)
          ..compression = CompressionType.none,
      ),
    ),
  );
}

Future<void> createV1(String path, {bool blockIndex = false}) async {
  final db = await databaseFactoryFfi.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE categories(id TEXT PRIMARY KEY NOT NULL, name TEXT NOT NULL COLLATE NOCASE UNIQUE, active INTEGER NOT NULL CHECK(active IN (0,1)))',
        );
        await db.execute(
          "CREATE TABLE entries(id TEXT PRIMARY KEY NOT NULL, date TEXT NOT NULL, categoryId TEXT NOT NULL REFERENCES categories(id), note TEXT NOT NULL, createdAt TEXT NOT NULL, updatedAt TEXT NOT NULL, cents INTEGER NOT NULL CHECK(cents > 0), kind TEXT NOT NULL CHECK(kind IN ('expense','refund')))",
        );
        await db.execute(
          'CREATE TABLE settings(singleton INTEGER PRIMARY KEY CHECK(singleton=1), ledgerName TEXT NOT NULL, tagline TEXT NOT NULL, themeKey TEXT NOT NULL, imageFile TEXT)',
        );
        if (blockIndex) {
          await db.execute('CREATE TABLE unrelated(value TEXT)');
          await db.execute('CREATE INDEX entries_date ON unrelated(value)');
        } else {
          await db.execute('CREATE INDEX entries_date ON entries(date)');
        }
        for (final row in oldCategories) {
          await db.insert('categories', row);
        }
        for (final row in oldEntries) {
          await db.insert('entries', row);
        }
        await db.insert('settings', {'singleton': 1, ...oldSettings});
      },
    ),
  );
  await db.close();
}

void assertConverted(List<LedgerEntry> entries, List<Category> categories) {
  expect(entries.length, 2);
  for (final old in oldEntries) {
    final e = entries.firstWhere((e) => e.id == old['id']);
    for (final key in [
      'id',
      'date',
      'cents',
      'note',
      'createdAt',
      'updatedAt',
    ]) {
      expect(e.toMap()[key], old[key], reason: key);
    }
    if (old['kind'] == 'refund') {
      expect(e.kind, EntryKind.income);
      expect(e.legacyCategoryId, 'old-food');
      expect(e.legacyCategoryName, '旧餐饮');
      final c = categories.firstWhere((c) => c.id == e.categoryId);
      expect(c.kind, EntryKind.income);
      expect(c.name, '退款');
      expect(c.id, isNot('income-refund'));
    } else {
      expect(e.kind, EntryKind.expense);
      expect(e.categoryId, 'old-food');
    }
  }
  final t = summarize(entries);
  expect(t.income, 10000);
  expect(t.expense, 10000);
  expect(t.balance, 0);
  expect(categoryTotals(entries, EntryKind.expense)['old-food'], 10000);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);
  late Directory dir;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('puppy_v2_');
  });
  tearDown(() async {
    await dir.delete(recursive: true);
  });

  test(
    'real schema-1 upgrade preserves fields, migrates once, and keeps 100/100/0 totals',
    () async {
      final path = '${dir.path}/old.db';
      await createV1(path);
      var store = await LedgerStore.open(
        databasePath: path,
        factory: databaseFactoryFfi,
      );
      assertConverted(await store.entries(), await store.categories());
      expect((await store.settings()).themeKey, 'peach');
      final rows = (await store.entries()).map((e) => e.toMap()).toList();
      final cats = (await store.categories()).map((e) => e.toMap()).toList();
      await store.close();
      store = await LedgerStore.open(
        databasePath: path,
        factory: databaseFactoryFfi,
      );
      expect((await store.entries()).map((e) => e.toMap()).toList(), rows);
      expect((await store.categories()).map((e) => e.toMap()).toList(), cats);
      await store.close();
    },
  );

  test(
    'failure after old tables are dropped rolls back schema, rows and user_version; retry works',
    () async {
      final path = '${dir.path}/failure.db';
      await createV1(path, blockIndex: true);
      await expectLater(
        LedgerStore.open(databasePath: path, factory: databaseFactoryFfi),
        throwsA(isA<DatabaseException>()),
      );
      final db = await databaseFactoryFfi.openDatabase(path);
      expect(await db.getVersion(), 1);
      expect(await db.query('entries'), oldEntries);
      expect(await db.query('categories'), oldCategories);
      expect(
        (await db.rawQuery(
          'PRAGMA table_info(entries)',
        )).any((c) => c['name'] == 'legacyCategoryId'),
        isFalse,
      );
      await db.execute('DROP INDEX entries_date');
      await db.close();
      final store = await LedgerStore.open(
        databasePath: path,
        factory: databaseFactoryFfi,
      );
      assertConverted(await store.entries(), await store.categories());
      await store.close();
    },
  );

  test(
    'v1 ZIP conversion equals database upgrade; repeat restore and v2 roundtrip keep history and roles',
    () async {
      final path = '${dir.path}/backup.db';
      await createV1(path);
      final store = await LedgerStore.open(
        databasePath: path,
        factory: databaseFactoryFfi,
      );
      final c = LedgerController(store: store, directory: dir);
      await c.refresh();
      final upgraded = c.entries.map((e) => e.toMap()).toList();
      final converted = BackupCodec.decode(legacyZip());
      for (var i = 0; i < 2; i++) {
        await c.restoreBackup(converted);
        expect(c.entries.map((e) => e.toMap()).toList(), upgraded);
      }
      await c.updateSettings(c.settings.copyWith(goldenIncome: false));
      final decoded = BackupCodec.decode(
        BackupCodec.encode(
          BackupData(
            entries: c.entries,
            categories: c.categories,
            settings: c.settings,
          ),
        ),
      );
      await c.restoreBackup(decoded);
      expect(c.settings.goldenIncome, isFalse);
      assertConverted(c.entries, c.categories);
      final refund = c.entries.firstWhere((e) => e.kind == EntryKind.income);
      await c.saveEntry(
        id: refund.id,
        amount: '101',
        kind: refund.kind,
        date: refund.date,
        categoryId: refund.categoryId,
        note: '编辑后的备注',
      );
      final edited = c.entries.firstWhere((e) => e.id == refund.id);
      expect(edited.legacyCategoryId, refund.legacyCategoryId);
      expect(edited.legacyCategoryName, refund.legacyCategoryName);
      final token = await c.deleteWithUndo(edited.id);
      await c.undoDeletes([token]);
      expect(
        c.entries.firstWhere((e) => e.id == refund.id).toMap(),
        edited.toMap(),
      );
      c.dispose();
      await store.close();
    },
  );

  test(
    'all three income categories support edit/delete/undo; types cannot mix, disabled categories remain editable',
    () async {
      final store = await LedgerStore.open(
        databasePath: '${dir.path}/new.db',
        factory: databaseFactoryFfi,
      );
      final c = LedgerController(store: store, directory: dir);
      await c.refresh();
      for (final category
          in c.categories.where((c) => c.kind == EntryKind.income).toList()) {
        final entry = await c.saveEntry(
          amount: '12.34',
          kind: EntryKind.income,
          date: '2026-11-06',
          categoryId: category.id,
          note: category.name,
        );
        await c.saveCategory(
          category.copyWith(active: false, name: '${category.name}收入'),
        );
        final edited = await c.saveEntry(
          id: entry.id,
          amount: '25',
          kind: entry.kind,
          date: '2026-10-31',
          categoryId: entry.categoryId,
          note: '历史编辑',
        );
        final token = await c.deleteWithUndo(edited.id);
        await c.undoDeletes([token]);
        expect(
          c.entries.firstWhere((e) => e.id == edited.id).toMap(),
          edited.toMap(),
        );
        await expectLater(
          c.saveEntry(
            amount: '1',
            kind: EntryKind.income,
            date: entry.date,
            categoryId: category.id,
            note: '',
          ),
          throwsStateError,
        );
      }
      await expectLater(
        c.saveEntry(
          amount: '1',
          kind: EntryKind.income,
          date: '2026-11-06',
          categoryId: 'default-1',
          note: '',
        ),
        throwsStateError,
      );
      await expectLater(
        store.saveEntry(c.entries.first.copyWith(categoryId: 'default-1')),
        throwsFormatException,
      );
      await c.saveCategory(
        const Category(
          id: 'same-name',
          name: '餐饮',
          active: true,
          kind: EntryKind.income,
        ),
      );
      await expectLater(
        c.saveCategory(
          const Category(
            id: 'same-name-2',
            name: '餐饮',
            active: true,
            kind: EntryKind.income,
          ),
        ),
        throwsFormatException,
      );
      final before = c.entries.map((e) => e.toMap()).toList();
      await c.updateSettings(c.settings.copyWith(goldenIncome: false));
      await c.updateSettings(c.settings.copyWith(themeKey: 'sage'));
      expect(c.entries.map((e) => e.toMap()).toList(), before);
      c.dispose();
      await store.close();
      final reopened = await LedgerStore.open(
        databasePath: '${dir.path}/new.db',
        factory: databaseFactoryFfi,
      );
      expect((await reopened.settings()).goldenIncome, isFalse);
      expect((await reopened.settings()).themeKey, 'sage');
      expect(
        (await reopened.entries()).map((e) => e.toMap()),
        unorderedEquals(before),
      );
      await reopened.close();
    },
  );
}
