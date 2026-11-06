import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:puppy_ledger/core/controller.dart';
import 'package:puppy_ledger/core/store.dart';
import 'package:puppy_ledger/core/models.dart';
import 'package:puppy_ledger/core/backup.dart';
import 'package:puppy_ledger/ui/app.dart';
import 'package:puppy_ledger/ui/entry_page.dart';
import 'package:puppy_ledger/ui/widget_links.dart';
import 'support/daily_sample.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);
  late Directory dir;
  late LedgerStore store;
  late LedgerController c;
  final queue = <Map<String, String>>[];
  int refreshes = 0;
  setUp(() async {
    queue.clear();
    refreshes = 0;
    dir = await Directory.systemTemp.createTemp('links');
    store = await LedgerStore.open(
      databasePath: '${dir.path}/db',
      factory: databaseFactoryFfi,
    );
    await seedDailyExample(store);
    c = LedgerController(
      store: store,
      directory: dir,
      clock: () => exampleDate,
    );
    await c.refresh();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(WidgetLinks.channel, (call) async {
          if (call.method == 'dataChanged') {
            refreshes++;
            return null;
          }
          return queue.isEmpty ? null : queue.removeAt(0);
        });
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(WidgetLinks.channel, null);
    c.dispose();
    await store.close();
    await dir.delete(recursive: true);
  });
  Future<void> launch(WidgetTester t) async {
    t.view.physicalSize = const Size(390, 940);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(PuppyLedgerApp(controller: c));
    await t.pumpAndSettle();
  }

  testWidgets(
    'cold shortcut selects actual enabled expense category; stale shortcut allows choosing again',
    (t) async {
      queue.add({'type': 'expense', 'value': 'default-1'});
      await launch(t);
      expect(find.byType(EntryPage), findsOneWidget);
      expect(
        t
            .widget<ChoiceChip>(
              find.byKey(const ValueKey('category-default-1')),
            )
            .selected,
        true,
      );
      await t.pumpWidget(const SizedBox());
      await t.runAsync(
        () => c.saveCategory(
          c.categories
              .firstWhere((x) => x.id == 'default-1')
              .copyWith(active: false),
        ),
      );
      queue.add({'type': 'expense', 'value': 'default-1'});
      await launch(t);
      expect(find.textContaining('原快捷分类已停用'), findsOneWidget);
      expect(find.byKey(const ValueKey('category-default-1')), findsNothing);
      await t.tap(find.byKey(const ValueKey('category-default-2')));
      await t.pumpAndSettle();
      expect(
        t
            .widget<ChoiceChip>(
              find.byKey(const ValueKey('category-default-2')),
            )
            .selected,
        true,
      );
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'calendar intent anchors day/month and mutations request widget refresh after commit',
    (t) async {
      queue.add({'type': 'day', 'value': '2026-10-31'});
      await launch(t);
      expect(find.text('10月31日 周六'), findsOneWidget);
      expect(find.text('上月午餐'), findsOneWidget);
      expect(
        t.widget<Text>(find.byKey(const ValueKey('home-month-total'))).data,
        '-￥9.00',
      );
      await t.runAsync(() async {
        var before = refreshes;
        final e = await c.saveEntry(
          amount: '9',
          kind: EntryKind.expense,
          date: '2026-10-31',
          categoryId: 'default-1',
          note: 'widget',
        );
        expect(refreshes, greaterThan(before));
        before = refreshes;
        await c.saveEntry(
          id: e.id,
          amount: '12',
          kind: e.kind,
          date: e.date,
          categoryId: e.categoryId,
          note: e.note,
        );
        expect(refreshes, greaterThan(before));
        before = refreshes;
        final token = await c.deleteWithUndo(e.id);
        expect(refreshes, greaterThan(before));
        before = refreshes;
        await c.undoDeletes([token]);
        expect(refreshes, greaterThan(before));
        final b = BackupData(
          entries: c.entries,
          categories: c.categories,
          settings: c.settings,
        );
        before = refreshes;
        await c.restoreBackup(b);
        expect(refreshes, greaterThan(before));
      });
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'warm calendar opens immediately from a clean form and asks before dropping a draft',
    (t) async {
      Future<void> deliver(String date) async {
        queue.add({'type': 'day', 'value': date});
        await t.binding.defaultBinaryMessenger.handlePlatformMessage(
          WidgetLinks.channel.name,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('intentAvailable'),
          ),
          (_) {},
        );
        await t.pumpAndSettle();
      }

      queue.add({'type': 'expense', 'value': 'default-1'});
      await launch(t);
      await deliver('2026-10-31');
      expect(find.byType(EntryPage), findsNothing);
      expect(find.text('10月31日 周六'), findsOneWidget);
      await t.tap(find.text('记一笔'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextFormField).first, '9.00');
      await deliver('2026-11-06');
      expect(find.text('还没有保存'), findsOneWidget);
      await t.tap(find.text('继续填写'));
      await t.pumpAndSettle();
      expect(find.text('9.00'), findsOneWidget);
      await deliver('2026-11-06');
      await t.tap(find.text('放弃修改'));
      await t.pumpAndSettle();
      expect(find.text('11月6日 周五'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    },
  );
}
