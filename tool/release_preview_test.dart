// These captures render the running app with isolated SQLite data.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:puppy_ledger/core/controller.dart';
import 'package:puppy_ledger/core/models.dart';
import 'package:puppy_ledger/core/store.dart';
import 'package:puppy_ledger/ui/app.dart';
import 'package:puppy_ledger/ui/receipt_paper.dart';
import 'package:puppy_ledger/ui/widgets.dart';
import '../test/support/daily_sample.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  late LedgerStore store;
  late LedgerController c;
  late GlobalKey root;
  setUpAll(() async {
    sqfliteFfiInit();
    final b = ByteData.sublistView(
      await File(Platform.environment['CJK_FONT']!).readAsBytes(),
    );
    for (final name in ['Roboto', 'NotoSansSC', 'Ahem']) {
      await (FontLoader(name)..addFont(Future.value(b))).load();
    }
    final icons = ByteData.sublistView(
      await File(
        '${Platform.environment['TASK_ROOT']}/tooling/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      ).readAsBytes(),
    );
    await (FontLoader('MaterialIcons')..addFont(Future.value(icons))).load();
  });
  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('ledger_screens_');
    store = await LedgerStore.open(
      databasePath: '${tmp.path}/db',
      factory: databaseFactoryFfi,
    );
    await seedDailyExample(store);
    c = LedgerController(
      store: store,
      directory: tmp,
      clock: () => DateTime(2026, 11, 6, 20, 5),
    );
    await c.refresh();
    await c.updateSettings(c.settings.copyWith(themeKey: 'peach'));
    root = GlobalKey();
  });
  tearDown(() async {
    c.dispose();
    await store.close();
    await tmp.delete(recursive: true);
  });
  Finder key(String k) => find.byKey(ValueKey(k));
  Future<void> launch(WidgetTester t) async {
    t.view.physicalSize = const Size(414, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      RepaintBoundary(
        key: root,
        child: PuppyLedgerApp(controller: c),
      ),
    );
    await t.pumpAndSettle();
    await t.runAsync(
      () => Future.wait([
        for (final theme in ['lemon', 'peach', 'sage'])
          precacheImage(
            AssetImage(puppyArtworkAsset(theme)),
            root.currentContext!,
          ),
        for (final dog in [
          PuppyAvatar.goldenPortrait,
          PuppyAvatar.whitePortrait,
        ])
          precacheImage(dog, root.currentContext!),
      ]),
    );
    await t.pumpAndSettle();
  }

  Future<void> show(WidgetTester t, Finder f, {double step = 180}) async {
    if (f.evaluate().isEmpty) {
      await t.scrollUntilVisible(
        f,
        step,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .last,
      );
    }
    await t.ensureVisible(f);
    await t.pumpAndSettle();
  }

  Future<void> tap(WidgetTester t, Finder f, {double step = 180}) async {
    await show(t, f, step: step);
    await t.tap(f);
    await t.pumpAndSettle();
  }

  Future<void> shot(WidgetTester t, String name, {Rect? rect}) async {
    expect(t.takeException(), isNull);
    final size = t.view.physicalSize;
    final crop = (rect ?? (Offset.zero & size)).intersect(Offset.zero & size);
    await t.runAsync(() async {
      const r = 2.0;
      final boundary =
          root.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final frame = await boundary.toImage(pixelRatio: r);
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      final target = Rect.fromLTWH(0, 0, crop.width * r, crop.height * r);
      canvas.drawImageRect(
        frame,
        Rect.fromLTRB(
          crop.left * r,
          crop.top * r,
          crop.right * r,
          crop.bottom * r,
        ),
        target,
        Paint(),
      );
      final pic = rec.endRecording(),
          image = await pic.toImage(target.width.ceil(), target.height.ceil());
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = Directory(Platform.environment['PREVIEW_DIR']!);
      await dir.create(recursive: true);
      await File(
        '${dir.path}/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      frame.dispose();
      pic.dispose();
      image.dispose();
    });
  }

  testWidgets('category bars actual expense and income', (t) async {
    await t.runAsync(
      () => c.saveEntry(
        amount: '50',
        kind: EntryKind.income,
        date: '2026-11-03',
        categoryId: 'income-salary',
        note: '工资',
        occurredMinute: 540,
      ),
    );
    await launch(t);
    await tap(t, find.text('统计'));
    final panel = key('category-breakdown-card'),
        toggle = key('stats-category-kind');
    for (final kind in ['expense', 'income']) {
      await show(t, toggle);
      await tap(
        t,
        find.descendant(
          of: toggle,
          matching: find.text(kind == 'expense' ? '支出去向' : '收入构成'),
        ),
      );
      await show(t, panel);
      final a = t.getRect(toggle), b = t.getRect(panel);
      await shot(
        t,
        '02-category-$kind',
        rect: Rect.fromLTRB(0, a.top - 14, 414, b.bottom + 12),
      );
    }
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('actual minute form and daily hour detail', (t) async {
    await launch(t);
    await tap(t, key('swipe-lunch'));
    await show(t, key('entry-time'));
    await shot(t, '01-occurrence-form');
    await t.pumpWidget(const SizedBox());
    await launch(t);
    await tap(t, find.text('统计'));
    await tap(t, find.text('日'));
    await show(t, key('daily-flow-section'));
    for (final mode in ['expense', 'income']) {
      await tap(t, key('flow-$mode'));
      await tap(t, key('flow-day-${mode == 'expense' ? '12' : '19'}'));
      final rect = t.getRect(key('daily-flow-section'));
      await shot(
        t,
        '01-hour-$mode',
        rect: Rect.fromLTRB(0, rect.top + 6, 414, rect.bottom + 8),
      );
    }
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('continuous surfaces across themes and date dialog', (t) async {
    await launch(t);
    for (final theme in ['lemon', 'peach', 'sage']) {
      await t.runAsync(
        () => c.updateSettings(c.settings.copyWith(themeKey: theme)),
      );
      await t.pumpAndSettle();
      await show(t, key('swipe-lunch'));
      await shot(t, '03-home-$theme');
    }
    await tap(t, key('daily-date-button'));
    await shot(t, '03-calendar');
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('receipt preview and full exported paper use all three rows', (
    t,
  ) async {
    await launch(t);
    await tap(t, key('entry-filter'));
    await t.tap(find.widgetWithText(PopupMenuItem<String>, '支出'));
    await t.pumpAndSettle();
    await show(t, key('generate-receipt'));
    await t.tap(key('generate-receipt'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 460));
    await shot(t, '04-printing-in-progress');
    await t.pumpAndSettle();
    await t.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await t.pumpAndSettle();
    await t.pump(const Duration(milliseconds: 1200));
    await t.pumpAndSettle();
    expect(key('printed-paper'), findsOneWidget);
    await shot(t, '04-receipt-printer');
    await t.runAsync(() async {
      final dogs = await receiptDogs();
      final draw = ReceiptDrawing.layout(
        ReceiptData(c, exampleDate),
        360,
        TextScaler.noScaling,
        dogs,
        const Color(0xffffdcd4),
      );
      await writeReceiptPng(
        draw,
        File('${Platform.environment['PREVIEW_DIR']}/04-exported-receipt.png'),
      );
      draw.picture.dispose();
      for (final dog in dogs) {
        dog.dispose();
      }
    });
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
    'legacy unknown time is separate from midnight; long export reaches the footer',
    (t) async {
      await t.runAsync(
        () => c.saveEntry(
          amount: '1.25',
          kind: EntryKind.expense,
          date: '2026-11-05',
          categoryId: 'default-2',
          note: '午夜车票',
          occurredMinute: 0,
        ),
      );
      await launch(t);
      t
          .widget<HomePage>(find.byType(HomePage))
          .onDateChanged(DateTime(2026, 11, 5));
      await t.pumpAndSettle();
      await tap(t, find.text('统计'));
      await tap(t, find.text('日'));
      await show(t, key('daily-flow-section'));
      await tap(t, key('flow-day-00'));
      await tap(t, key('unknown-time'));
      expect(find.text('¥1.25'), findsOneWidget);
      expect(find.textContaining('¥56.00'), findsWidgets);
      await shot(t, '01-midnight-and-unknown');
      await t.pumpWidget(const SizedBox());
      await t.runAsync(() async {
        for (int i = 0; i < 130; i++) {
          await c.saveEntry(
            amount: '1.25',
            kind: EntryKind.expense,
            date: '2026-09-01',
            categoryId: 'default-1',
            note: i == 129 ? '最后一笔 · 长图验收' : ('午餐票据，完整记录这一天。' * 5),
            occurredMinute: 850 - i,
          );
        }
        final dogs = await receiptDogs();
        final paper = ReceiptDrawing.layout(
          ReceiptData(c, DateTime(2026, 9, 1)),
          340,
          TextScaler.noScaling,
          dogs,
          const Color(0xffdce7cf),
        );
        final file = File(
          '${Platform.environment['PREVIEW_DIR']}/04-long-receipt.png',
        );
        await writeReceiptPng(paper, file);
        expect(paper.size.height * 2, greaterThan(16384));
        paper.picture.dispose();
        for (final dog in dogs) {
          dog.dispose();
        }
      });
    },
  );
}
