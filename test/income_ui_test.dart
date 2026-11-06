import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:puppy_ledger/core/controller.dart';
import 'package:puppy_ledger/core/logic.dart';
import 'package:puppy_ledger/core/models.dart';
import 'package:puppy_ledger/core/store.dart';
import 'package:puppy_ledger/ui/app.dart';
import 'package:puppy_ledger/ui/settings_page.dart';
import 'package:puppy_ledger/ui/widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);
  late Directory dir;
  late LedgerStore store;
  late LedgerController c;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('puppy_income_ui_');
    store = await LedgerStore.open(
      databasePath: '${dir.path}/db',
      factory: databaseFactoryFfi,
    );
    c = LedgerController(store: store, directory: dir);
    await c.refresh();
  });
  tearDown(() async {
    c.dispose();
    await store.close();
    await dir.delete(recursive: true);
  });
  Future<void> launch(
    WidgetTester t, {
    Size size = const Size(390, 1000),
    double scale = 1,
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpWidget(PuppyLedgerApp(controller: c));
    await t.pumpAndSettle();
  }

  Future<void> waitFor(WidgetTester t, bool Function() done) async {
    await t.runAsync(() async {
      for (var i = 0; i < 100 && !done(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    expect(done(), isTrue);
    await t.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester t, String text) async {
    if (find.text(text).evaluate().isEmpty) {
      await t.scrollUntilVisible(
        find.text(text),
        160,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .last,
      );
    }
    await t.ensureVisible(find.text(text));
    await t.tap(find.text(text));
    await t.pumpAndSettle();
  }

  String displayedPortrait(WidgetTester t, Finder avatar) {
    final image = t.widget<Image>(
      find.descendant(of: avatar, matching: find.byType(Image)),
    );
    final provider = (image.image as ResizeImage).imageProvider as AssetImage;
    return provider.assetName;
  }

  void top(WidgetTester t) => t
      .state<ScrollableState>(
        find
            .descendant(
              of: find.byType(HomePage),
              matching: find.byType(Scrollable),
            )
            .first,
      )
      .position
      .jumpTo(0);

  testWidgets(
    'type switches keep fields and reset category; save updates monthly totals with assigned dog',
    (t) async {
      await launch(t);
      await tapText(t, '记一笔');
      await t.enterText(find.byType(TextFormField).first, '100.00');
      await t.enterText(find.byType(TextFormField).last, '收入测试备注');
      await t.ensureVisible(find.byKey(const ValueKey('category-default-1')));
      await t.tap(find.byKey(const ValueKey('category-default-1')));
      await tapText(t, '收入');
      expect(find.byKey(const ValueKey('category-default-1')), findsNothing);
      expect(find.text('100.00'), findsOneWidget);
      expect(find.text('收入测试备注'), findsOneWidget);
      expect(find.textContaining('冲减所选分类'), findsNothing);
      expect(
        find
            .byType(ChoiceChip)
            .evaluate()
            .every((e) => !(e.widget as ChoiceChip).selected),
        isTrue,
      );
      expect(
        t
            .widget<PuppyAvatar>(
              find.byKey(const ValueKey('entry-role-avatar')),
            )
            .golden,
        isTrue,
      );
      await t.tap(find.byKey(const ValueKey('category-income-refund')));
      await t.scrollUntilVisible(
        find.text('记好啦，保存'),
        160,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .last,
      );
      await t.ensureVisible(find.text('记好啦，保存'));
      await t.pumpAndSettle();
      await t.tap(find.text('记好啦，保存'));
      await waitFor(t, () => c.entries.isNotEmpty);
      expect(c.entries.single.kind, EntryKind.income);
      expect(find.text('又攒下一点小幸福！'), findsOneWidget);
      expect(
        t
            .widget<PuppyAvatar>(
              find.byKey(const ValueKey('success-role-avatar')),
            )
            .golden,
        isTrue,
      );
      expect(
        t.widget<Text>(find.byKey(const ValueKey('home-month-income'))).data,
        '￥100.00',
      );
      expect(
        t.widget<Text>(find.byKey(const ValueKey('home-month-total'))).data,
        '￥100.00',
      );
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'daily filter never changes monthly 100 income, 100 expense, zero balance; stats match',
    (t) async {
      await t.runAsync(() async {
        for (final kind in EntryKind.values) {
          await c.saveEntry(
            amount: '100',
            kind: kind,
            date: dateKey(DateTime.now()),
            categoryId: kind == EntryKind.income
                ? 'income-refund'
                : 'default-1',
            note: '${kind.label}这一天',
          );
        }
      });
      await launch(t);
      expect(
        t.widget<Text>(find.byKey(const ValueKey('home-month-total'))).data,
        '￥0.00',
      );
      final filter = find.byKey(const ValueKey('entry-filter'));
      await t.ensureVisible(filter);
      await t.tap(filter);
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(PopupMenuItem<String>, '收入'));
      await t.pumpAndSettle();
      final expense = c.entries.firstWhere((e) => e.kind == EntryKind.expense);
      final income = c.entries.firstWhere((e) => e.kind == EntryKind.income);
      expect(find.byKey(ValueKey('swipe-${expense.id}')), findsNothing);
      expect(find.byKey(ValueKey('swipe-${income.id}')), findsOneWidget);
      expect(find.text('+¥100.00'), findsOneWidget);
      top(t);
      await t.pumpAndSettle();
      expect(
        t.widget<Text>(find.byKey(const ValueKey('home-month-total'))).data,
        '￥0.00',
      );
      expect(
        t.widget<Text>(find.byKey(const ValueKey('home-month-expense'))).data,
        '￥100.00',
      );
      await tapText(t, '统计');
      expect(
        t.widget<Text>(find.byKey(const ValueKey('stats-balance'))).data,
        '￥0.00',
      );
      final toggle = find.byKey(const ValueKey('stats-category-kind'));
      await t.scrollUntilVisible(
        toggle,
        200,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .last,
      );
      await t.tap(find.descendant(of: toggle, matching: find.text('收入构成')));
      await t.pumpAndSettle();
      expect(t.widget<SegmentedButton<EntryKind>>(toggle).selected, {
        EntryKind.income,
      });
      await t.scrollUntilVisible(
        find.text('退款'),
        100,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .last,
      );
      expect(find.text('退款'), findsOneWidget);
      expect(find.text('餐饮'), findsNothing);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'exchange roles immediately updates forms and success for all themes, preserving rows',
    (t) async {
      await launch(t);
      await tapText(t, '我的');
      await tapText(t, '小狗分工');
      expect(find.byType(DogRolesPage), findsOneWidget);
      final portraits = find.descendant(
        of: find.byType(DogRolesPage),
        matching: find.byType(PuppyAvatar),
      );
      expect(
        displayedPortrait(t, portraits.at(0)),
        'assets/avatars/golden_coin.jpg',
      );
      expect(
        displayedPortrait(t, portraits.at(1)),
        'assets/avatars/white_coin.jpg',
      );
      final oldRolePosition = t.getTopLeft(
        find.byKey(const ValueKey('role-golden')),
      );
      final rows = c.entries.map((e) => e.toMap()).toList();
      await t.tap(find.byKey(const ValueKey('swap-dog-roles')));
      await waitFor(t, () => !c.settings.goldenIncome);
      expect(
        t.getTopLeft(find.byKey(const ValueKey('role-golden'))),
        oldRolePosition,
      );
      expect(
        t.widget<Text>(find.byKey(const ValueKey('role-golden'))).data,
        '负责支出',
      );
      expect(c.entries.map((e) => e.toMap()).toList(), rows);
      expect((await t.runAsync(() => store.settings()))!.goldenIncome, isFalse);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      await tapText(t, '账本');
      for (final theme in ['lemon', 'peach', 'sage']) {
        await t.runAsync(
          () => c.updateSettings(c.settings.copyWith(themeKey: theme)),
        );
        await t.pumpAndSettle();
        expect(
          displayedPortrait(
            t,
            find.byKey(const ValueKey('home-income-avatar')),
          ),
          'assets/avatars/white_coin.jpg',
        );
        expect(
          displayedPortrait(
            t,
            find.byKey(const ValueKey('home-expense-avatar')),
          ),
          'assets/avatars/golden_coin.jpg',
        );
        await tapText(t, '记一笔');
        await tapText(t, '收入');
        expect(
          displayedPortrait(t, find.byKey(const ValueKey('entry-role-avatar'))),
          'assets/avatars/white_coin.jpg',
        );
        await t.enterText(find.byType(TextFormField).first, '20');
        await t.tap(find.byKey(const ValueKey('category-income-salary')));
        await t.scrollUntilVisible(
          find.text('记好啦，保存'),
          160,
          scrollable: find
              .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
              )
              .last,
        );
        final count = c.entries.length;
        await t.ensureVisible(find.text('记好啦，保存'));
        await t.pumpAndSettle();
        await t.tap(find.text('记好啦，保存'));
        await waitFor(t, () => c.entries.length == count + 1);
        expect(find.text('又攒下一点小幸福！'), findsOneWidget);
        expect(
          displayedPortrait(
            t,
            find.byKey(const ValueKey('success-role-avatar')),
          ),
          'assets/avatars/white_coin.jpg',
        );
        await t.pump(const Duration(seconds: 2));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      }
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    '320px 2x type: income, roles, category manager and statistics remain usable',
    (t) async {
      t.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await launch(t, size: const Size(320, 640), scale: 2);
      await tapText(t, '我的');
      await tapText(t, '小狗分工');
      await tapText(t, '交换分工');
      await waitFor(t, () => !c.settings.goldenIncome);
      expect(t.takeException(), isNull);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      await tapText(t, '分类管理');
      await tapText(t, '收入');
      expect(find.text('工资'), findsOneWidget);
      expect(find.text('餐饮'), findsNothing);
      expect(t.takeException(), isNull);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      await tapText(t, '记一笔');
      await tapText(t, '收入');
      await t.enterText(find.byType(TextFormField).first, '9999999999.99');
      await t.ensureVisible(
        find.byKey(const ValueKey('category-income-parttime')),
      );
      await t.tap(find.byKey(const ValueKey('category-income-parttime')));
      await t.scrollUntilVisible(
        find.text('记好啦，保存'),
        160,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .last,
      );
      await t.ensureVisible(find.text('记好啦，保存'));
      await t.pumpAndSettle();
      await t.tap(find.text('记好啦，保存'));
      await waitFor(t, () => c.entries.isNotEmpty);
      expect(t.takeException(), isNull);
      await tapText(t, '统计');
      expect(t.takeException(), isNull);
      await t.scrollUntilVisible(
        find.byKey(const ValueKey('stats-category-kind')),
        150,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .last,
      );
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
}
