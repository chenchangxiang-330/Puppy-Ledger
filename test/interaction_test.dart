import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:puppy_ledger/core/controller.dart';
import 'package:puppy_ledger/core/logic.dart';
import 'package:puppy_ledger/core/models.dart';
import 'package:puppy_ledger/core/store.dart';
import 'package:puppy_ledger/ui/app.dart';
import 'package:puppy_ledger/ui/entry_page.dart';
import 'package:puppy_ledger/ui/motion.dart';
import 'package:puppy_ledger/ui/swipe_entry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory dir;
  late LedgerStore store;
  late LedgerController controller;
  late DateTime Function() clock;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('puppy_interactions_');
    store = await LedgerStore.open(
      databasePath: '${dir.path}/db',
      factory: databaseFactoryFfi,
    );
    clock = DateTime.now;
    controller = LedgerController(
      store: store,
      directory: dir,
      clock: () => clock(),
    );
    await controller.refresh();
  });
  tearDown(() async {
    controller.dispose();
    await store.close();
    await dir.delete(recursive: true);
  });
  Future<void> launch(
    WidgetTester tester, {
    Size size = const Size(390, 1000),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(PuppyLedgerApp(controller: controller));
    await tester.pumpAndSettle();
  }

  Future<LedgerEntry?> seed(
    WidgetTester tester,
    String note, {
    DateTime? date,
  }) => tester.runAsync(
    () => controller.saveEntry(
      amount: '12.34',
      kind: EntryKind.expense,
      date: dateKey(date ?? DateTime.now()),
      categoryId: 'default-1',
      note: note,
    ),
  );
  Future<void> waitFor(WidgetTester tester, bool Function() done) async {
    await tester.runAsync(() async {
      for (var i = 0; i < 100 && !done(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    expect(done(), isTrue);
  }

  Future<void> swipe(WidgetTester tester, String id) async {
    final row = find.byKey(ValueKey('swipe-$id'));
    if (row.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        row,
        180,
        scrollable: find
            .descendant(
              of: find.byType(HomePage),
              matching: find.byType(Scrollable),
            )
            .first,
      );
    }
    await tester.ensureVisible(row);
    await tester.drag(row, const Offset(-200, 0));
    await tester.pumpAndSettle();
  }

  testWidgets('three dog interactions, rapid taps, bubble expiry and page exit', (
    tester,
  ) async {
    await launch(tester);
    for (final pair in {
      'lemon': '今天也要好好记账呀',
      'peach': '贴贴，快乐记一笔',
      'sage': '又是元气满满的一天',
    }.entries) {
      // A fresh page resets the interaction throttle, as on a real app restart.
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(
        () => controller.updateSettings(
          controller.settings.copyWith(themeKey: pair.key),
        ),
      );
      await tester.pumpWidget(PuppyLedgerApp(controller: controller));
      await tester.pumpAndSettle();
      for (var i = 0; i < 8; i++) {
        await tester.tap(find.byKey(const ValueKey('home-puppy')));
        await tester.pump(const Duration(milliseconds: 30));
      }
      expect(find.text(pair.value), findsOneWidget);
      expect(find.byKey(const ValueKey('puppy-bubble')), findsOneWidget);
      if (pair.key == 'peach') {
        expect(find.byIcon(Icons.favorite_rounded), findsNWidgets(3));
      }
      if (pair.key == 'sage') {
        expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
      }
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pumpAndSettle();
      expect(find.text(pair.value), findsNothing);
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'swipe opens only one row, vertical scrolling does not open actions, delete undo restores exact row',
    (tester) async {
      final first = (await seed(tester, '第一笔'))!;
      final second = (await seed(tester, '第二笔'))!;
      await launch(tester);
      await swipe(tester, first.id);
      final open = tester
          .widget<SwipeEntry>(find.byType(SwipeEntry).first)
          .openId;
      expect(open.value, first.id);
      await swipe(tester, second.id);
      expect(open.value, second.id);
      await tester.tap(find.byKey(ValueKey('delete-${second.id}')));
      await waitFor(tester, () => controller.entries.length == 1);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('undo-delete')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('undo-delete')));
      await waitFor(tester, () => controller.entries.length == 2);
      await tester.pumpAndSettle();
      expect(
        controller.entries.firstWhere((e) => e.id == second.id).toMap(),
        second.toMap(),
      );
      final persisted = await tester.runAsync(() => store.entries());
      expect(
        persisted!.firstWhere((e) => e.id == second.id).toMap(),
        second.toMap(),
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.ensureVisible(find.byKey(ValueKey('swipe-${first.id}')));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(ValueKey('swipe-${first.id}')),
        const Offset(0, -120),
      );
      await tester.pumpAndSettle();
      expect(open.value, isNull);
      expect(find.byType(EntryPage), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'undo entrance disappears after five seconds without resurrecting data',
    (tester) async {
      var now = DateTime.now();
      clock = () => now;
      final original = (await seed(tester, '到期删除'))!;
      await launch(tester);
      await swipe(tester, original.id);
      await tester.tap(find.byKey(ValueKey('delete-${original.id}')));
      await waitFor(tester, () => controller.entries.isEmpty);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('undo-delete')), findsOneWidget);
      now = now.add(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('undo-delete')), findsNothing);
      expect(await tester.runAsync(() => store.entries()), isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'swipe edit returns same id, updates actual totals and celebrates after save',
    (tester) async {
      final original = (await seed(tester, '修改前'))!;
      await launch(tester);
      await swipe(tester, original.id);
      await tester.tap(find.byKey(ValueKey('edit-${original.id}')));
      await tester.pumpAndSettle();
      expect(find.byType(EntryPage), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, '25.50');
      await tester.ensureVisible(find.text('保存修改'));
      await tester.tap(find.text('保存修改'));
      await waitFor(tester, () => controller.entries.single.cents == 2550);
      await tester.pumpAndSettle();
      expect(controller.entries.single.id, original.id);
      expect(controller.entries.single.createdAt, original.createdAt);
      expect(find.text('这笔花销记好啦！'), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('daily-expense-total')))
            .textSpan!
            .toPlainText(),
        '支出 ¥25.50',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('month gesture is local and synchronizes home and statistics', (
    tester,
  ) async {
    final now = DateTime.now();
    final next = movePeriod(now, Period.month, 1);
    await seed(tester, '下月记录', date: next);
    await launch(tester);
    final header = find.byKey(const ValueKey('home-month-swipe'));
    await tester.ensureVisible(header);
    await tester.drag(header, const Offset(-110, 0));
    await tester.pumpAndSettle();
    expect(find.text('下月记录'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('daily-date-label'))).data,
      contains('${next.month}月${next.day}日'),
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('home-month-total'))).data,
      '-￥12.34',
    );
    await tester.tap(find.text('统计'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('stats-period-label')))
          .data,
      '${next.year}年 ${next.month}月',
    );
    await tester.drag(
      find.byKey(const ValueKey('stats-period-swipe')),
      const Offset(110, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('账本'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('daily-date-label'))).data,
      contains('${now.month}月${now.day}日'),
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('home-month-total'))).data,
      '￥0.00',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'actual write failure preserves form, no celebration, retry saves once and selects saved day',
    (tester) async {
      await launch(tester);
      await tester.ensureVisible(
        find.byKey(const ValueKey('home-month-swipe')),
      );
      await tester.drag(
        find.byKey(const ValueKey('home-month-swipe')),
        const Offset(-100, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('记一笔'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '8.88');
      await tester.tap(find.widgetWithText(ChoiceChip, '餐饮'));
      await tester.enterText(find.byType(TextFormField).last, '不能丢失的备注');
      await tester.runAsync(() async {
        final db = await databaseFactoryFfi.openDatabase('${dir.path}/db');
        await db.execute(
          "CREATE TRIGGER fail_save BEFORE INSERT ON entries BEGIN SELECT RAISE(ABORT, 'injected write failure'); END",
        );
      });
      await tester.ensureVisible(find.text('记好啦，保存'));
      await tester.runAsync(() async {
        await tester.tap(find.text('记好啦，保存'));
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();
      expect(controller.entries, isEmpty);
      expect(find.byType(EntryPage), findsOneWidget);
      expect(find.text('8.88'), findsOneWidget);
      expect(find.text('不能丢失的备注'), findsOneWidget);
      expect(find.text('这笔花销记好啦！'), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
      await tester.runAsync(() async {
        final db = await databaseFactoryFfi.openDatabase('${dir.path}/db');
        await db.execute('DROP TRIGGER fail_save');
      });
      ScaffoldMessenger.of(
        tester.element(find.byType(EntryPage)),
      ).clearSnackBars();
      await tester.tap(find.text('记好啦，保存'));
      await tester.tap(find.text('记好啦，保存'));
      await waitFor(tester, () => controller.entries.isNotEmpty);
      await tester.pumpAndSettle();
      expect(controller.entries.length, 1);
      expect(find.text('不能丢失的备注'), findsOneWidget);
      expect(find.text('这笔花销记好啦！'), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('daily-expense-total')))
            .textSpan!
            .toPlainText(),
        '支出 ¥8.88',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    '320px 2x text, reduced motion and app lifecycle do not overflow or leave active effects',
    (tester) async {
      await tester.runAsync(
        () => controller.updateSettings(
          controller.settings.copyWith(themeKey: 'peach'),
        ),
      );
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await launch(tester, size: const Size(320, 720), scale: 2);
      await tester.tap(find.byKey(const ValueKey('home-puppy')));
      await tester.pump();
      expect(find.text('贴贴，快乐记一笔'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_rounded), findsNothing);
      expect(tester.takeException(), isNull);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const ValueKey('puppy-bubble')), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.tap(find.text('统计'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('我的'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'press feedback keeps a full hit area and returns after pointer cancel',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PressFeedback(
                child: FilledButton(
                  onPressed: () => taps++,
                  child: const Text('点我'),
                ),
              ),
            ),
          ),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('点我')),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        .96,
      );
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
      await tester.tap(find.text('点我'));
      expect(taps, 1);
    },
  );
}
