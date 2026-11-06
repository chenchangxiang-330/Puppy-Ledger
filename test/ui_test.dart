import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:puppy_ledger/core/controller.dart';
import 'package:puppy_ledger/core/store.dart';
import 'package:puppy_ledger/ui/app.dart';
import 'package:puppy_ledger/ui/widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temporary;
  late LedgerStore store;
  late LedgerController controller;
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('puppy_ui_test_');
    store = await LedgerStore.open(
      databasePath: '${temporary.path}/test.sqlite',
      factory: databaseFactoryFfi,
    );
    controller = LedgerController(store: store, directory: temporary);
    await controller.refresh();
  });
  tearDown(() async {
    controller.dispose();
    await store.close();
    await temporary.delete(recursive: true);
  });

  testWidgets(
    'empty ledger, invalid amount, actual form save and refreshed total',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(PuppyLedgerApp(controller: controller));
      await tester.pumpAndSettle();
      expect(find.text('账本'), findsOneWidget);
      expect(find.text('统计'), findsOneWidget);
      expect(find.text('我的'), findsOneWidget);
      expect(controller.entries, isEmpty);
      await tester.tap(find.text('记一笔'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '0.001');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, '餐饮'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('记好啦，保存'),
        140,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('记好啦，保存'));
      await tester.pumpAndSettle();
      expect(controller.entries, isEmpty);
      expect(find.text('0.001'), findsOneWidget);
      await tester.ensureVisible(find.byType(TextFormField).first);
      await tester.enterText(find.byType(TextFormField).first, '0.10');
      await tester.scrollUntilVisible(
        find.text('记好啦，保存'),
        140,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .last,
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('记好啦，保存'));
        for (var i = 0; i < 100 && controller.entries.isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pumpAndSettle();
      expect(controller.entries.single.cents, 10);
      expect(find.text('本月结余'), findsOneWidget);
      expect(find.textContaining('0.10'), findsWidgets);
      await tester.tap(find.text('统计'));
      await tester.pumpAndSettle();
      expect(find.text('本周期结余'), findsOneWidget);
      expect(find.textContaining('0.10'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('360px large type tabs and keyboard form remain scrollable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(PuppyLedgerApp(controller: controller));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('统计'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('记一笔'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('记好啦，保存'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    final saveRect = tester.getRect(find.text('记好啦，保存'));
    expect(saveRect.bottom, lessThan(520));
    expect(tester.takeException(), isNull);
    tester.view.viewInsets = const FakeViewPadding();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byType(TextFormField).first,
      -180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(find.byType(TextFormField).first, '12.34');
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('还没有保存'), findsOneWidget);
    await tester.tap(find.text('继续填写'));
    await tester.pumpAndSettle();
    expect(find.text('12.34'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'pictured theme selection updates artwork and survives database reopen',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.runAsync(() async {
        await File(
          'assets/illustrations/puppy_pair.png',
        ).copy('${temporary.path}/custom.img');
        await controller.updateSettings(
          controller.settings.copyWith(imageFile: 'custom.img'),
        );
      });
      await tester.pumpWidget(PuppyLedgerApp(controller: controller));
      await tester.pumpAndSettle();
      Future<void> choose(String key) async {
        await tester.tap(find.text('我的'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(ValueKey('theme-$key')));
        await tester.runAsync(() async {
          await tester.tap(find.byKey(ValueKey('theme-$key')));
          for (
            var i = 0;
            i < 100 &&
                (controller.settings.themeKey != key ||
                    controller.settings.imageFile != null);
            i++
          ) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
        });
        await tester.pumpAndSettle();
        expect(controller.settings.themeKey, key);
        expect(controller.settings.imageFile, isNull);
        final saved = await tester.runAsync(() => store.settings());
        expect(saved!.themeKey, key);
        await tester.tap(find.text('账本'));
        await tester.pumpAndSettle();
        final displayed = tester.widget<Image>(
          find.descendant(
            of: find.byType(LedgerDog),
            matching: find.byType(Image),
          ),
        );
        expect(
          (displayed.image as AssetImage).assetName,
          puppyArtworkAsset(key),
        );
        expect(tester.takeException(), isNull);
      }

      await choose('peach');
      await choose('sage');
      await choose('lemon');
      await choose('sage');
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        controller.dispose();
        await store.close();
        store = await LedgerStore.open(
          databasePath: '${temporary.path}/test.sqlite',
          factory: databaseFactoryFfi,
        );
        controller = LedgerController(store: store, directory: temporary);
        await controller.refresh();
      });
      await tester.pumpWidget(PuppyLedgerApp(controller: controller));
      await tester.pumpAndSettle();
      expect(controller.settings.themeKey, 'sage');
      final image = tester.widget<Image>(
        find.descendant(
          of: find.byType(LedgerDog),
          matching: find.byType(Image),
        ),
      );
      expect(
        (image.image as AssetImage).assetName,
        'assets/illustrations/puppy_sage.png',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
