import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:puppy_ledger/core/backup.dart';
import 'package:puppy_ledger/core/controller.dart';
import 'package:puppy_ledger/core/models.dart';
import 'package:puppy_ledger/core/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory dir;
  late LedgerStore store;
  late LedgerController controller;
  late DateTime now;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('puppy_undo_');
    store = await LedgerStore.open(
      databasePath: '${dir.path}/db',
      factory: databaseFactoryFfi,
    );
    now = DateTime(2026, 11, 5, 12);
    controller = LedgerController(
      store: store,
      directory: dir,
      clock: () => now,
    );
    await controller.refresh();
  });
  tearDown(() async {
    controller.dispose();
    await store.close();
    await dir.delete(recursive: true);
  });
  Future<LedgerEntry> add(String note) => controller.saveEntry(
    amount: '123.45',
    kind: EntryKind.income,
    date: '2024-02-29',
    categoryId: 'income-refund',
    note: note,
  );

  test(
    'undo restores every field, inactive category and SQLite persistence',
    () async {
      final original = await add('跨年退款 · 原备注');
      final token = await controller.deleteWithUndo(original.id);
      expect(await store.entries(), isEmpty);
      await controller.saveCategory(
        controller.categories
            .firstWhere((c) => c.id == 'income-refund')
            .copyWith(active: false),
      );
      now = now.add(const Duration(milliseconds: 4999));
      await controller.undoDeletes([token]);
      expect(controller.entries.single.toMap(), original.toMap());
      await store.close();
      store = await LedgerStore.open(
        databasePath: '${dir.path}/db',
        factory: databaseFactoryFfi,
      );
      expect((await store.entries()).single.toMap(), original.toMap());
      await expectLater(controller.undoDeletes([token]), throwsStateError);
    },
  );

  test('undo expires at five seconds and does not restore data', () async {
    final entry = await add('过期');
    final token = await controller.deleteWithUndo(entry.id);
    now = now.add(const Duration(seconds: 5));
    await expectLater(controller.undoDeletes([token]), throwsStateError);
    expect(await store.entries(), isEmpty);
    expect(controller.entries, isEmpty);
  });

  test(
    'rapid deletes can be undone together; duplicate receipts rejected',
    () async {
      final a = await add('第一笔');
      final b = await add('第二笔');
      final ta = await controller.deleteWithUndo(a.id);
      final tb = await controller.deleteWithUndo(b.id);
      await expectLater(controller.undoDeletes([ta, ta]), throwsStateError);
      await controller.undoDeletes([ta, tb]);
      expect(
        (await store.entries()).map((e) => e.toMap()),
        unorderedEquals([a.toMap(), b.toMap()]),
      );
    },
  );

  test('failed undo rolls back whole batch and remains retryable', () async {
    final a = await add('第一笔');
    final b = await add('第二笔');
    final ta = await controller.deleteWithUndo(a.id);
    final tb = await controller.deleteWithUndo(b.id);
    final db = await databaseFactoryFfi.openDatabase('${dir.path}/db');
    await db.execute(
      "CREATE TRIGGER reject_undo BEFORE INSERT ON entries WHEN NEW.id = '${b.id}' BEGIN SELECT RAISE(ABORT, 'injected write failure'); END",
    );
    await expectLater(
      controller.undoDeletes([ta, tb]),
      throwsA(isA<DatabaseException>()),
    );
    expect(await store.entries(), isEmpty);
    expect(controller.entries, isEmpty);
    await db.execute('DROP TRIGGER reject_undo');
    await controller.undoDeletes([ta, tb]);
    expect(controller.entries.length, 2);
  });

  test('failed delete preserves memory and persisted row', () async {
    final original = await add('保留我');
    final db = await databaseFactoryFfi.openDatabase('${dir.path}/db');
    await db.execute(
      "CREATE TRIGGER reject_delete BEFORE DELETE ON entries BEGIN SELECT RAISE(ABORT, 'injected write failure'); END",
    );
    await expectLater(
      controller.deleteWithUndo(original.id),
      throwsA(isA<DatabaseException>()),
    );
    expect(controller.entries.single.toMap(), original.toMap());
    expect((await store.entries()).single.toMap(), original.toMap());
  });

  test('restoring backup invalidates pending delete receipts', () async {
    final original = await add('旧账本');
    final token = await controller.deleteWithUndo(original.id);
    await controller.restoreBackup(
      BackupData(
        entries: [],
        categories: controller.categories,
        settings: controller.settings,
      ),
    );
    await expectLater(controller.undoDeletes([token]), throwsStateError);
    expect(await store.entries(), isEmpty);
  });
}
