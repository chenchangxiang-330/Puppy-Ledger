import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:puppy_ledger/core/backup.dart';
import 'package:puppy_ledger/core/controller.dart';
import 'package:puppy_ledger/core/logic.dart';
import 'package:puppy_ledger/core/models.dart';
import 'package:puppy_ledger/core/store.dart';
import 'package:puppy_ledger/ui/app.dart';
import 'support/daily_sample.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);
  late Directory dir;
  late LedgerStore store;
  late LedgerController c;
  Future<void> open() async {
    store = await LedgerStore.open(
      databasePath: '${dir.path}/ledger.db',
      factory: databaseFactoryFfi,
    );
    c = LedgerController(
      store: store,
      directory: dir,
      clock: () => DateTime(2026, 11, 6, 20, 23),
    );
    await c.refresh();
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('actual_minutes');
    await open();
    await seedDailyExample(store);
    await c.refresh();
  });
  tearDown(() async {
    c.dispose();
    await store.close();
    await dir.delete(recursive: true);
  });
  test(
    'schema 2, old ZIP, midnight, editing, undo, restart and v3 ZIP',
    () async {
      c.dispose();
      await store.close();
      final old = await databaseFactoryFfi.openDatabase(
        '${dir.path}/ledger.db',
      );
      await old.execute('ALTER TABLE entries DROP COLUMN occurredMinute');
      await old.setVersion(2);
      await old.close();
      await open();
      expect(c.entries.every((e) => e.occurredMinute == null), true);
      final sample = c.entries.firstWhere((e) => e.id == 'lunch');
      final json = utf8.encode(
        jsonEncode({
          'format': 'puppy_ledger',
          'version': 2,
          'exportedAt': sample.createdAt,
          'settings': c.settings.toMap(),
          'categories': c.categories.map((c) => c.toMap()).toList(),
          'entries': [sample.toMap()..remove('occurredMinute')],
        }),
      );
      final archive = Archive()
        ..addFile(
          ArchiveFile('backup.json', json.length, json)
            ..compression = CompressionType.none,
        );
      final v2 = BackupCodec.decode(
        Uint8List.fromList(ZipEncoder().encode(archive)),
      );
      await c.restoreBackup(v2);
      expect(c.entries.single.occurredMinute, isNull);
      final midnight = await c.saveEntry(
        amount: '1',
        kind: EntryKind.expense,
        date: sample.date,
        categoryId: sample.categoryId,
        note: '午夜',
        occurredMinute: 0,
      );
      expect(midnight.occurredMinute, 0);
      expect(
        hourlyAmounts(c.entries, sample.date, EntryKind.expense)['00'],
        100,
      );
      final lunch = await c.saveEntry(
        id: sample.id,
        amount: '28',
        kind: EntryKind.expense,
        date: sample.date,
        categoryId: sample.categoryId,
        note: sample.note,
        occurredMinute: 755,
      );
      final token = await c.deleteWithUndo(lunch.id);
      await c.undoDeletes([token]);
      expect(c.entries.first.toMap(), lunch.toMap());
      c.dispose();
      await store.close();
      await open();
      expect(c.entries.map((e) => e.occurredMinute), [755, 0]);
      final backup = BackupCodec.decode(
        BackupCodec.encode(
          BackupData(
            entries: c.entries,
            categories: c.categories,
            settings: c.settings,
          ),
        ),
      );
      await c.restoreBackup(backup);
      expect(c.entries.map((e) => e.occurredMinute), [755, 0]);
    },
  );
  Finder k(String s) => find.byKey(ValueKey(s));
  Future<void> tap(WidgetTester t, Finder f) async {
    if (f.evaluate().isEmpty) {
      await t.scrollUntilVisible(
        f,
        160,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
    }
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  Future<void> launch(WidgetTester t) async {
    t.view.physicalSize = const Size(390, 940);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(PuppyLedgerApp(controller: c));
    await t.pumpAndSettle();
  }

  testWidgets(
    'selected day opens entry with local time; hourly drill-down aggregates separate kinds',
    (t) async {
      await launch(t);
      t
          .widget<HomePage>(find.byType(HomePage))
          .onDateChanged(DateTime(2026, 11, 4));
      await t.pumpAndSettle();
      await tap(t, find.text('记一笔'));
      expect(find.text('2026-11-04'), findsOneWidget);
      expect(find.text('20:23'), findsOneWidget);
      await tap(t, k('entry-time'));
      expect(find.byType(TimePickerDialog), findsOneWidget);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      if (find.text('放弃修改').evaluate().isNotEmpty) {
        await t.tap(find.text('放弃修改'));
        await t.pumpAndSettle();
      }
      t.widget<HomePage>(find.byType(HomePage)).onDateChanged(exampleDate);
      await t.pumpAndSettle();
      await tap(t, find.text('统计'));
      await tap(t, find.text('日'));
      await tap(t, k('flow-day-12'));
      expect(t.widget<Text>(k('flow-picked-amount')).data, '¥34.00');
      expect(k('flow-day-00'), findsOneWidget);
      expect(k('flow-day-23'), findsOneWidget);
      expect(find.text('食堂午餐'), findsOneWidget);
      expect(find.text('地铁回家'), findsOneWidget);
      await tap(t, k('flow-income'));
      await tap(t, k('flow-day-19'));
      expect(t.widget<Text>(k('flow-picked-amount')).data, '¥100.00');
      expect(find.text('耳机退款'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
}
