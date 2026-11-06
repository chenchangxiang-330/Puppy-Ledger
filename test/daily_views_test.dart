import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
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
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('daily_views_');
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
  });
  tearDown(() async {
    c.dispose();
    await store.close();
    await dir.delete(recursive: true);
  });
  Finder key(String k) => find.byKey(ValueKey(k));
  Future<void> launch(WidgetTester t, {bool small = false}) async {
    t.view.physicalSize = small ? const Size(320, 640) : const Size(390, 940);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = small ? 2 : 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpWidget(PuppyLedgerApp(controller: c));
    await t.pumpAndSettle();
  }

  Future<void> show(WidgetTester t, Finder target) async {
    if (target.evaluate().isEmpty) {
      await t.scrollUntilVisible(
        target,
        180,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
    }
    await t.ensureVisible(target);
    await t.pumpAndSettle();
  }

  Future<void> tap(WidgetTester t, Finder f) async {
    await show(t, f);
    await t.tap(f);
    await t.pumpAndSettle();
  }

  String value(WidgetTester t, String k) {
    final w = t.widget<Text>(key(k));
    return w.data ?? w.textSpan!.toPlainText();
  }

  testWidgets(
    'same day: 100 income / 34 expense; filters leave day and month totals intact',
    (t) async {
      await launch(t);
      await show(t, key('entry-filter'));
      expect(value(t, 'daily-date-label'), '11月6日 周五');
      expect(value(t, 'daily-income-total'), '收入 ¥100.00');
      expect(value(t, 'daily-expense-total'), '支出 ¥34.00');
      expect(find.text('+¥100.00'), findsOneWidget);
      expect(find.text('−¥28.00'), findsOneWidget);
      expect(find.text('−¥6.00'), findsOneWidget);
      await tap(t, key('entry-filter'));
      await t.tap(find.widgetWithText(PopupMenuItem<String>, '收入'));
      await t.pumpAndSettle();
      expect(key('swipe-lunch'), findsNothing);
      expect(key('swipe-refund'), findsOneWidget);
      expect(value(t, 'daily-expense-total'), '支出 ¥34.00');
      expect(value(t, 'home-month-total'), '-￥74.00');
      await tap(t, key('entry-filter'));
      await t.tap(find.widgetWithText(PopupMenuItem<String>, '支出'));
      await t.pumpAndSettle();
      expect(key('swipe-refund'), findsNothing);
      expect(key('swipe-metro'), findsOneWidget);
      expect(value(t, 'daily-income-total'), '收入 ¥100.00');
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets('calendar opens on demand, crosses month and returns to today', (
    t,
  ) async {
    await launch(t);
    expect(find.byType(CalendarDatePicker), findsNothing);
    await tap(t, key('daily-date-button'));
    final cal = find.byType(CalendarDatePicker);
    final loc = MaterialLocalizations.of(t.element(cal));
    await t.tap(find.byTooltip(loc.previousMonthTooltip));
    await t.pumpAndSettle();
    await t.tap(find.descendant(of: cal, matching: find.text('31')).last);
    await t.pumpAndSettle();
    expect(value(t, 'daily-date-label'), '10月31日 周六');
    expect(value(t, 'home-month-total'), '-￥9.00');
    expect(find.text('上月午餐'), findsOneWidget);
    await tap(t, key('daily-date-button'));
    await t.tap(find.text('回到今天'));
    await t.pumpAndSettle();
    expect(value(t, 'daily-date-label'), '11月6日 周五');
    expect(value(t, 'home-month-total'), '-￥74.00');
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
    'daily bars share the bottom baseline and accumulate the selected kind only',
    (t) async {
      await launch(t);
      await tap(t, find.text('统计'));
      await show(t, key('daily-flow-section'));
      expect(value(t, 'flow-range'), '11月1日 至 6日');
      expect(value(t, 'flow-total'), '¥174.00');
      expect(value(t, 'flow-picked-amount'), '¥34.00');
      expect(key('flow-day-2026-11-03'), findsOneWidget);
      expect(key('flow-bar-2026-11-03'), findsNothing);
      final a = t.getRect(key('flow-bar-2026-11-05')),
          b = t.getRect(key('flow-bar-2026-11-06'));
      expect(a.bottom, closeTo(b.bottom, .01));
      expect(a.height / b.height, closeTo(56 / 34, .01));
      await tap(t, key('flow-day-2026-11-03'));
      expect(value(t, 'flow-picked-amount'), '¥0.00');
      await tap(t, key('flow-day-2026-11-06'));
      await tap(t, key('flow-income'));
      expect(value(t, 'flow-total'), '¥100.00');
      expect(value(t, 'flow-picked-amount'), '¥100.00');
      expect(key('flow-bar-2026-11-05'), findsNothing);
      expect(
        t.getRect(key('flow-bar-2026-11-06')).bottom,
        closeTo(b.bottom, .1),
      );
      t
          .state<ScrollableState>(
            find
                .byWidgetPredicate(
                  (w) =>
                      w is Scrollable && w.axisDirection == AxisDirection.down,
                )
                .first,
          )
          .position
          .jumpTo(0);
      await t.pumpAndSettle();
      await tap(t, find.byTooltip('上一周期'));
      await tap(t, find.byTooltip('上一周期'));
      await show(t, key('daily-flow-section'));
      expect(value(t, 'flow-total'), '¥0.00');
      expect(find.text('这段时间还没有收支记录'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    '320px at double text size: date, filter, long amounts and chart stay usable',
    (t) async {
      await t.runAsync(
        () => c.saveEntry(
          amount: '9999999999.99',
          kind: EntryKind.expense,
          date: dateKey(exampleDate),
          categoryId: 'default-1',
          note: '大额账目',
        ),
      );
      await launch(t, small: true);
      await show(t, key('daily-date-button'));
      expect(
        t
            .getRect(find.text('每日明细'))
            .overlaps(t.getRect(key('daily-date-button'))),
        isFalse,
      );
      await tap(t, key('daily-date-button'));
      await t.tap(find.text('回到今天'));
      await t.pumpAndSettle();
      await show(t, key('entry-filter'));
      expect(
        t
            .getRect(key('daily-expense-total'))
            .overlaps(t.getRect(key('entry-filter'))),
        isFalse,
      );
      await tap(t, key('entry-filter'));
      await t.tap(find.widgetWithText(PopupMenuItem<String>, '全部'));
      await t.pumpAndSettle();
      await show(t, find.text('−¥9999999999.99'));
      await tap(t, find.text('统计'));
      await show(t, key('flow-income'));
      await tap(t, key('flow-income'));
      await show(t, key('flow-picked-amount'));
      expect(value(t, 'flow-picked-amount'), '¥100.00');
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'three themes share the data; a long month scrolls to the last day including empty income slots',
    (t) async {
      await launch(t);
      final buttonColors = <Color?>{}, barColors = <Color?>{};
      for (final theme in ['lemon', 'peach', 'sage']) {
        await t.runAsync(
          () => c.updateSettings(c.settings.copyWith(themeKey: theme)),
        );
        await t.pumpAndSettle();
        await show(t, key('daily-date-button'));
        buttonColors.add(
          t
              .widget<TextButton>(key('daily-date-button'))
              .style!
              .backgroundColor!
              .resolve({}),
        );
        expect(value(t, 'daily-income-total'), '收入 ¥100.00');
        await tap(t, find.text('统计'));
        await show(t, key('daily-flow-section'));
        expect(value(t, 'flow-total'), '¥174.00');
        barColors.add(
          (t.widget<Container>(key('flow-bar-2026-11-06')).decoration
                  as BoxDecoration)
              .color,
        );
        if (theme != 'sage') await tap(t, find.text('账本'));
      }
      expect(buttonColors.length, 3);
      expect(barColors.length, 3);
      t
          .state<ScrollableState>(
            find
                .byWidgetPredicate(
                  (w) =>
                      w is Scrollable && w.axisDirection == AxisDirection.down,
                )
                .first,
          )
          .position
          .jumpTo(0);
      await t.pumpAndSettle();
      await tap(t, find.byTooltip('上一周期'));
      await show(t, key('daily-flow-section'));
      expect(value(t, 'flow-range'), '10月1日 至 31日');
      await tap(t, key('flow-day-2026-10-31'));
      expect(value(t, 'flow-picked-amount'), '¥9.00');
      await tap(t, key('flow-income'));
      expect(value(t, 'flow-total'), '¥0.00');
      expect(value(t, 'flow-picked-amount'), '¥0.00');
      expect(key('flow-bar-2026-10-31'), findsNothing);
      expect(key('flow-day-2026-10-31'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  test(
    'current range preserves booked future dates, and historical months retain all empty slots',
    () {
      final future = c.entries.first.copyWith(date: '2026-11-21');
      final current = reportRange(exampleDate, Period.month, exampleDate, [
        ...c.entries,
        future,
      ]);
      expect(current.end, '2026-11-21');
      final past = reportRange(
        DateTime(2026, 10, 6),
        Period.month,
        exampleDate,
        c.entries,
      );
      expect(past.end, '2026-10-31');
      expect(dailyAmounts(c.entries, past, EntryKind.expense).length, 31);
    },
  );
}
