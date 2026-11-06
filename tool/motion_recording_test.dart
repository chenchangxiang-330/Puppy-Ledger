// Actual Flutter frame capture driven by widget-test gestures, not Android
// screen recording. Sample data is confined to a temporary SQLite database.
// TASK_ROOT, CJK_FONT, MOTION_DIR select the local toolchain/font/output.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:puppy_ledger/core/controller.dart';
import 'package:puppy_ledger/core/logic.dart';
import 'package:puppy_ledger/core/models.dart';
import 'package:puppy_ledger/core/store.dart';
import 'package:puppy_ledger/ui/app.dart';
import 'package:puppy_ledger/ui/entry_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temporary;
  late LedgerStore store;
  late LedgerController controller;
  late DateTime recordingClock;
  setUp(() async {
    final bytes = await File(Platform.environment['CJK_FONT']!).readAsBytes();
    for (final name in ['Roboto', 'NotoSansSC', 'Ahem']) {
      await (FontLoader(
        name,
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
    final icons = await File(
      '${Platform.environment['TASK_ROOT']}/tooling/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ).readAsBytes();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(Future.value(ByteData.sublistView(icons)))).load();
    sqfliteFfiInit();
    temporary = await Directory.systemTemp.createTemp('puppy_motion_video_');
    store = await LedgerStore.open(
      databasePath: '${temporary.path}/demo.db',
      factory: databaseFactoryFfi,
    );
    recordingClock = DateTime.now();
    controller = LedgerController(
      store: store,
      directory: temporary,
      clock: () => recordingClock,
    );
    await controller.refresh();
    await controller.saveEntry(
      amount: '100.00',
      kind: EntryKind.expense,
      date: dateKey(DateTime.now()),
      categoryId: 'default-1',
      note: '和你一起吃晚饭',
    );
  });
  tearDown(() async {
    controller.dispose();
    await store.close();
    await temporary.delete(recursive: true);
  });
  testWidgets('record actual press, dog, save, swipe, undo and theme frames', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final boundaryKey = GlobalKey();
    final caption = ValueNotifier('小狗账本 0.1.6 · Flutter 自动化交互演示');
    final touch = ValueNotifier<Offset?>(null);
    final scene = RepaintBoundary(
      key: boundaryKey,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  PuppyLedgerApp(controller: controller),
                  ValueListenableBuilder<Offset?>(
                    valueListenable: touch,
                    builder: (_, point, _) => point == null
                        ? const SizedBox()
                        : Positioned(
                            left: point.dx - 11,
                            top: point.dy - 11,
                            child: IgnorePointer(
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: .65),
                                  border: Border.all(
                                    color: const Color(0xFFEB8279),
                                    width: 2,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
            Container(
              height: 60,
              color: const Color(0xFF302C27),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: ValueListenableBuilder<String>(
                valueListenable: caption,
                builder: (_, value, _) => Text(
                  value,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'NotoSansSC',
                    color: Colors.white,
                    fontSize: 12,
                    height: 1.5,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(scene);

    await tester.runAsync(() async {
      for (final name in [
        'puppy_pair.png',
        'puppy_peach.png',
        'puppy_sage.png',
      ]) {
        await precacheImage(
          AssetImage('assets/illustrations/$name'),
          boundaryKey.currentContext!,
        );
      }
    });
    await tester.pumpAndSettle();
    final out = Directory(Platform.environment['MOTION_DIR']!);
    await tester.runAsync(() => out.create(recursive: true));
    var index = 0;
    final chapters = <String>[];
    void label(String value) {
      caption.value = value;
      chapters.add('${(index / 20).toStringAsFixed(2)}s $value');
    }

    Future<void> frame() async {
      recordingClock = recordingClock.add(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '${out.path}/${(index++).toString().padLeft(5, '0')}.png',
        ).writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }

    Future<void> hold(int frames) async {
      for (var i = 0; i < frames; i++) {
        await frame();
      }
    }

    Future<void> tap(Finder finder) async {
      final point = tester.getCenter(finder);
      touch.value = point;
      final gesture = await tester.startGesture(point);
      await hold(3);
      await gesture.up();
      touch.value = null;
      await frame();
    }

    Future<void> drag(Finder finder, Offset delta) async {
      final start = tester.getCenter(finder);
      final gesture = await tester.startGesture(start);
      for (var i = 1; i <= 10; i++) {
        touch.value = start + delta * (i / 10);
        await gesture.moveTo(touch.value!);
        await frame();
      }
      await gesture.up();
      touch.value = null;
      await hold(5);
    }

    Future<void> waitData(bool Function() ready) async {
      await tester.runAsync(() async {
        for (var i = 0; i < 100 && !ready(); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      expect(ready(), isTrue);
    }

    Future<void> homeTop() async {
      final scroll = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byType(HomePage),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      scroll.position.jumpTo(0);
      await frame();
    }

    Future<void> reveal(Finder finder) async {
      if (finder.evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          finder,
          180,
          scrollable: find
              .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
              )
              .last,
        );
      }
      await tester.ensureVisible(finder);
      await hold(6);
    }

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(scene);
    label('开屏 · 保留原图双小狗');
    await hold(32);
    label('首页 · 本月结余与双小狗收支卡片');
    await hold(24);
    label('记收入 · 工资、退款、兼职独立分类');
    await tap(find.text('记一笔'));
    await hold(12);
    await tap(
      find.descendant(of: find.byType(EntryPage), matching: find.text('收入')),
    );
    await hold(8);
    await tester.enterText(find.byType(TextFormField).first, '100.00');
    await tap(find.byKey(const ValueKey('category-income-refund')));
    await tester.enterText(find.byType(TextFormField).last, '退款到账，算作收入');
    FocusManager.instance.primaryFocus?.unfocus();
    await hold(18);
    await reveal(find.text('记好啦，保存'));
    await tap(find.text('记好啦，保存'));
    await waitData(() => controller.entries.length == 2);
    label('实际保存 · 小鸡毛收入反馈，结余回到 0');
    await hold(36);
    final refund = controller.entries.firstWhere(
      (e) => e.kind == EntryKind.income,
    );
    final row = find.byKey(ValueKey('swipe-${refund.id}'));
    await reveal(row);
    label('收入也支持左滑编辑、删除和撤销');
    await drag(row, const Offset(-175, 0));
    await hold(12);
    await tap(find.byKey(ValueKey('delete-${refund.id}')));
    await waitData(() => controller.entries.length == 1);
    await hold(12);
    await tap(find.byKey(const ValueKey('undo-delete')));
    await waitData(() => controller.entries.length == 2);
    await hold(16);
    label('小狗分工 · 我的 → 账本管理');
    await tap(find.text('我的'));
    await hold(6);
    await reveal(find.text('小狗分工'));
    await tap(find.text('小狗分工'));
    await hold(20);
    label('交换职责 · 自动保存，历史账目保持原样');
    await tap(find.byKey(const ValueKey('swap-dog-roles')));
    await waitData(() => !controller.settings.goldenIncome);
    await hold(28);
    await tap(find.byType(BackButton));
    await hold(8);
    await tap(find.text('账本'));
    await homeTop();
    await hold(20);
    label('交换后 · 小白陪你记收入');
    await tap(find.text('记一笔'));
    await hold(12);
    await tap(
      find.descendant(of: find.byType(EntryPage), matching: find.text('收入')),
    );
    await hold(8);
    await tester.enterText(find.byType(TextFormField).first, '5000.00');
    await tap(find.byKey(const ValueKey('category-income-salary')));
    await tester.enterText(find.byType(TextFormField).last, '这个月的工资');
    FocusManager.instance.primaryFocus?.unfocus();
    await hold(16);
    await reveal(find.text('记好啦，保存'));
    await tap(find.text('记好啦，保存'));
    await waitData(() => controller.entries.length == 3);
    await hold(34);
    label('收支报告 · 同一周期的收入、支出与结余');
    await tap(find.text('统计'));
    await hold(28);
    await reveal(find.byKey(const ValueKey('stats-category-kind')));
    label('分类统计 · 收入退款不会冲减支出');
    await tap(find.text('收入构成'));
    await hold(18);
    await reveal(find.text('工资'));
    await hold(18);
    await reveal(find.text('支出去向'));
    await tap(find.text('支出去向'));
    await hold(18);
    for (final theme in ['peach', 'sage']) {
      label(theme == 'peach' ? '蜜桃粉 · 主题与分工相互独立' : '草地绿 · 保留原表情与轻量互动');
      await tap(find.text('我的'));
      await hold(6);
      await reveal(find.byKey(ValueKey('theme-$theme')));
      await tap(find.byKey(ValueKey('theme-$theme')));
      await waitData(() => controller.settings.themeKey == theme);
      await hold(10);
      await tap(find.text('账本'));
      await homeTop();
      await hold(8);
      await tap(find.byKey(const ValueKey('home-puppy')));
      await hold(32);
    }
    label('实际 Flutter 界面渲染 · 非安卓手机录屏');
    await hold(20);
    await tester.runAsync(
      () => File('${out.path}/chapters.txt').writeAsString(chapters.join('\n')),
    );
    await tester.pumpWidget(const SizedBox());
    caption.dispose();
    touch.dispose();
  }, timeout: const Timeout(Duration(minutes: 8)));
}
