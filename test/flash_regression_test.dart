import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:puppy_ledger/core/controller.dart';
import 'package:puppy_ledger/core/logic.dart';
import 'package:puppy_ledger/core/models.dart';
import 'package:puppy_ledger/core/store.dart';
import 'package:puppy_ledger/ui/app.dart';
import 'package:puppy_ledger/ui/motion.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory dir;
  late LedgerStore store;
  late LedgerController controller;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('puppy_flash_');
    store = await LedgerStore.open(
      databasePath: '${dir.path}/db',
      factory: databaseFactoryFfi,
    );
    controller = LedgerController(store: store, directory: dir);
    await controller.refresh();
    for (var i = 0; i < 8; i++) {
      await controller.saveEntry(
        amount: '10',
        kind: EntryKind.expense,
        date: dateKey(DateTime.now()),
        categoryId: 'default-1',
        note: '第 $i 笔测试账目',
      );
    }
  });
  tearDown(() async {
    controller.dispose();
    await store.close();
    await dir.delete(recursive: true);
  });
  Future<GlobalKey> launch(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: PuppyLedgerApp(controller: controller),
      ),
    );
    await tester.runAsync(() async {
      for (final name in [
        'puppy_pair.png',
        'puppy_peach.png',
        'puppy_sage.png',
      ]) {
        await precacheImage(
          AssetImage('assets/illustrations/$name'),
          key.currentContext!,
        );
      }
    });
    await tester.pumpAndSettle();
    return key;
  }

  Future<Uint8List> pixels(WidgetTester tester, GlobalKey key) async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    return (await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return bytes!.buffer.asUint8List();
    }))!;
  }

  testWidgets(
    'dog taps change only the companion region, never the whole screen',
    (tester) async {
      final key = await launch(tester);
      for (final theme in ['lemon', 'peach', 'sage']) {
        await tester.runAsync(
          () => controller.updateSettings(
            controller.settings.copyWith(themeKey: theme),
          ),
        );
        await tester.pumpAndSettle();
        final area = tester.getRect(find.byType(PuppyCompanion)).inflate(16);
        final before = await pixels(tester, key);
        await tester.tap(find.byKey(const ValueKey('home-puppy')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));
        final after = await pixels(tester, key);
        var outsideChanges = 0;
        var insideChanges = 0;
        for (var y = 0; y < 844; y++) {
          for (var x = 0; x < 390; x++) {
            final offset = (y * 390 + x) * 4;
            if (List.generate(
              4,
              (c) => before[offset + c] == after[offset + c],
            ).every((same) => same)) {
              continue;
            }
            if (area.contains(Offset(x.toDouble(), y.toDouble()))) {
              insideChanges++;
            } else {
              outsideChanges++;
            }
          }
        }
        expect(insideChanges, greaterThan(0));
        expect(
          outsideChanges,
          0,
          reason: 'No pixel outside the local dog/caption may flash',
        );
        await tester.tap(find.text('统计'));
        await tester.pump(const Duration(milliseconds: 40));
        await tester.tap(find.text('账本'));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('startup-welcome')), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.runAsync(
          () async => Future<void>.delayed(const Duration(milliseconds: 710)),
        );
      }
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'theme selection keeps layout stable with no progress-row flash or white frame',
    (tester) async {
      final key = await launch(tester);
      await tester.tap(find.text('我的'));
      await tester.pumpAndSettle();
      final shell = tester.element(find.byType(LedgerShell));
      final themeCard = find.byKey(const ValueKey('theme-peach'));
      await tester.ensureVisible(themeCard);
      await tester.pumpAndSettle();
      final top = tester.getTopLeft(themeCard);
      for (final theme in ['peach', 'sage', 'lemon', 'peach']) {
        await tester.runAsync(() async {
          await tester.tap(find.byKey(ValueKey('theme-$theme')));
          for (
            var i = 0;
            i < 100 && controller.settings.themeKey != theme;
            i++
          ) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
        });
        expect(controller.settings.themeKey, theme);
        for (var frame = 0; frame < 8; frame++) {
          await tester.pump(const Duration(milliseconds: 40));
          expect(find.text('正在处理，请稍候…'), findsNothing);
          expect(find.byType(LinearProgressIndicator), findsNothing);
          expect(tester.getTopLeft(themeCard), top);
          expect(
            identical(tester.element(find.byType(LedgerShell)), shell),
            isTrue,
          );
          expect(find.byKey(const ValueKey('startup-welcome')), findsNothing);
          final rgba = await pixels(tester, key);
          final p = (80 * 390 + 2) * 4;
          expect(rgba[p + 1], inInclusiveRange(248, 252));
          expect(rgba[p + 2], inInclusiveRange(243, 245));
          expect(rgba[p + 3], 255);
        }
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'floating entry button leaves the rest of its row scrollable and photo controls are absent',
    (tester) async {
      await launch(tester);
      final fab = tester.getRect(find.byKey(const ValueKey('add-entry-fab')));
      final home = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byType(HomePage),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      final before = home.position.pixels;
      await tester.dragFrom(Offset(30, fab.center.dy), const Offset(0, -180));
      await tester.pumpAndSettle();
      expect(home.position.pixels, greaterThan(before));
      await tester.tap(find.text('我的'));
      await tester.pumpAndSettle();
      expect(find.text('从相册换一张'), findsNothing);
      expect(find.text('恢复默认小狗'), findsNothing);
      expect(find.text('图片保存在本机，重新打开也在'), findsNothing);
      expect(find.byKey(const ValueKey('theme-lemon')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
