import 'package:sqflite/sqflite.dart';

import 'logic.dart';
import 'models.dart';
import 'migration.dart';

/// One SQLite transaction stores both ledger data and its settings.
/// Pictures are staged by the controller before settings reference their name.
class LedgerStore {
  LedgerStore._(this._database);
  final Database _database;
  static const schemaVersion = 3;

  static Future<LedgerStore> open({
    required String databasePath,
    DatabaseFactory? factory,
  }) async {
    final database = await (factory ?? databaseFactory).openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await _createTables(db);
          const names = ['餐饮', '交通', '购物', '学习', '娱乐', '生活用品', '其他'];
          for (var i = 0; i < names.length; i++) {
            await db.insert(
              'categories',
              Category(
                id: 'default-${i + 1}',
                name: names[i],
                active: true,
              ).toMap(),
            );
          }
          for (final category in defaultIncomeCategories) {
            await db.insert('categories', category.toMap());
          }
          await db.insert('settings', {
            'singleton': 1,
            ...const LedgerSettings().toMap(),
          });
        },
        // sqflite runs this callback and PRAGMA user_version in one transaction.
        // On any failure both the schema and all old rows are rolled back.
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion == 2 && newVersion == 3) {
            await db.execute('ALTER TABLE entries ADD COLUMN $_timeColumn');
            return;
          }
          if (oldVersion != 1 || newVersion != 3) {
            throw StateError('不支持从 $oldVersion 升级至 $newVersion');
          }
          final data = migrateLegacyLedger(
            entries: await db.query('entries'),
            categories: await db.query('categories', orderBy: 'rowid'),
            settings: (await db.query(
              'settings',
              where: 'singleton = 1',
            )).single,
          );
          await db.execute('DROP TABLE entries');
          await db.execute('DROP TABLE categories');
          await db.execute('DROP TABLE settings');
          await _createTables(db);
          for (final c in data.categories) {
            await db.insert('categories', c.toMap());
          }
          for (final e in data.entries) {
            await db.insert('entries', e.toMap());
          }
          await db.insert('settings', {
            'singleton': 1,
            ...data.settings.toMap(),
          });
        },
        onDowngrade: (db, oldVersion, newVersion) async {
          throw StateError('账本来自较新版本，请升级 App 后打开');
        },
      ),
    );
    return LedgerStore._(database);
  }

  static const _timeColumn =
      'occurredMinute INTEGER CHECK(occurredMinute IS NULL OR (typeof(occurredMinute) = \'integer\' AND occurredMinute BETWEEN 0 AND 1439))';

  static Future<void> _createTables(Database db) async {
    await db.execute("""
      CREATE TABLE categories (
        id TEXT PRIMARY KEY NOT NULL,
        name TEXT NOT NULL COLLATE NOCASE,
        active INTEGER NOT NULL CHECK(active IN (0,1)),
        kind TEXT NOT NULL CHECK(kind IN ('expense','income')),
        UNIQUE(kind, name), UNIQUE(id, kind)
      )
    """);
    await db.execute("""
      CREATE TABLE entries (
        id TEXT PRIMARY KEY NOT NULL, date TEXT NOT NULL,
        categoryId TEXT NOT NULL, note TEXT NOT NULL,
        createdAt TEXT NOT NULL, updatedAt TEXT NOT NULL,
        cents INTEGER NOT NULL CHECK(typeof(cents) = 'integer' AND cents > 0 AND cents <= 999999999999),
        kind TEXT NOT NULL CHECK(kind IN ('expense','income')),
        legacyCategoryId TEXT, legacyCategoryName TEXT, $_timeColumn,
        CHECK ((legacyCategoryId IS NULL) = (legacyCategoryName IS NULL)),
        FOREIGN KEY(categoryId, kind) REFERENCES categories(id, kind) ON DELETE RESTRICT
      )
    """);
    await db.execute('CREATE INDEX entries_date ON entries(date)');
    await db.execute("""
      CREATE TABLE settings (
        singleton INTEGER PRIMARY KEY CHECK(singleton = 1),
        ledgerName TEXT NOT NULL, tagline TEXT NOT NULL, themeKey TEXT NOT NULL,
        imageFile TEXT,
        goldenIncome INTEGER NOT NULL CHECK(goldenIncome IN (0,1))
      )
    """);
  }

  Future<List<LedgerEntry>> entries() async => (await _database.query(
    'entries',
    orderBy: 'date DESC, occurredMinute DESC, createdAt DESC, id',
  )).map(LedgerEntry.fromMap).toList(growable: false);

  Future<List<Category>> categories() async => (await _database.query(
    'categories',
    orderBy: 'rowid',
  )).map(Category.fromMap).toList(growable: false);

  Future<LedgerSettings> settings() async {
    final rows = await _database.query('settings', where: 'singleton = 1');
    if (rows.length != 1) throw StateError('账本设置读取失败');
    return LedgerSettings.fromMap(rows.single);
  }

  Future<void> saveEntry(LedgerEntry entry) async {
    validateEntry(entry);
    await _database.transaction((txn) async {
      final categories = await txn.query(
        'categories',
        where: 'id = ?',
        whereArgs: [entry.categoryId],
      );
      if (categories.isEmpty) throw const FormatException('所选分类不存在');
      if (categories.single['kind'] != entry.kind.name) {
        throw const FormatException('分类与收支类型不一致');
      }
      final prior = await txn.query(
        'entries',
        where: 'id = ?',
        whereArgs: [entry.id],
      );
      if (categories.single['active'] != 1 &&
          (prior.isEmpty || prior.single['categoryId'] != entry.categoryId)) {
        throw const FormatException('所选分类已停用，请选择其他分类');
      }
      if (prior.isEmpty) {
        await txn.insert('entries', entry.toMap());
      } else {
        // Keep the original creation time when editing an existing stable ID.
        final map = entry.toMap()
          ..['createdAt'] = prior.single['createdAt']
          ..['legacyCategoryId'] = prior.single['legacyCategoryId']
          ..['legacyCategoryName'] = prior.single['legacyCategoryName'];
        await txn.update(
          'entries',
          map,
          where: 'id = ?',
          whereArgs: [entry.id],
        );
      }
    });
  }

  Future<void> deleteEntry(String id) async {
    await _database.delete('entries', where: 'id = ?', whereArgs: [id]);
  }

  /// Undo is an exact restore, including historical inactive categories.
  /// INSERT (not replace) prevents accidentally overwriting a newer row.
  Future<void> restoreDeletedEntries(List<LedgerEntry> entries) async {
    for (final entry in entries) {
      validateEntry(entry);
    }
    await _database.transaction((txn) async {
      for (final entry in entries) {
        final category = await txn.query(
          'categories',
          where: 'id = ?',
          whereArgs: [entry.categoryId],
        );
        if (category.isEmpty) throw StateError('原分类已不存在，暂时无法撤销');
        await txn.insert(
          'entries',
          entry.toMap(),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }
    });
  }

  Future<void> saveCategory(Category category) async {
    validateCategory(category);
    await _database.transaction((txn) async {
      final rows = await txn.query('categories');
      for (final row in rows) {
        if (row['id'] == category.id && row['kind'] != category.kind.name) {
          throw const FormatException('分类不能更改收支类型');
        }
        if (row['id'] != category.id &&
            row['kind'] == category.kind.name &&
            normalizedCategoryName(row['name']! as String) ==
                normalizedCategoryName(category.name)) {
          throw const FormatException('已经有同名分类了');
        }
      }
      final exists = rows.any((row) => row['id'] == category.id);
      if (exists) {
        await txn.update(
          'categories',
          category.toMap(),
          where: 'id = ?',
          whereArgs: [category.id],
        );
      } else {
        await txn.insert('categories', category.toMap());
      }
    });
  }

  Future<void> saveSettings(LedgerSettings settings) async {
    validateSettings(settings);
    final changed = await _database.update(
      'settings',
      settings.toMap(),
      where: 'singleton = 1',
    );
    if (changed != 1) throw StateError('账本设置保存失败');
  }

  Future<void> replaceAll({
    required List<LedgerEntry> entries,
    required List<Category> categories,
    required LedgerSettings settings,
  }) async {
    validateSnapshot(entries, categories, settings);
    await _database.transaction((txn) async {
      await txn.delete('entries');
      await txn.delete('categories');
      for (final category in categories) {
        await txn.insert('categories', category.toMap());
      }
      for (final entry in entries) {
        await txn.insert('entries', entry.toMap());
      }
      final changed = await txn.update(
        'settings',
        settings.toMap(),
        where: 'singleton = 1',
      );
      if (changed != 1) throw StateError('账本设置恢复失败');
    });
  }

  Future<void> close() => _database.close();
}
