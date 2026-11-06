// Capture real Flutter widgets with isolated, reproducible sample entries.
// TASK_ROOT, CJK_FONT and PREVIEW_DIR point to the local SDK, font and exports.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:puppy_ledger/core/controller.dart';
import 'package:puppy_ledger/core/store.dart';
import 'package:puppy_ledger/ui/app.dart';
import 'package:puppy_ledger/ui/widgets.dart';
import '../test/support/daily_sample.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temporary;
  late LedgerStore store;
  late LedgerController controller;
  setUp(() async {
    final regular = await File(Platform.environment['CJK_FONT']!).readAsBytes();
    for (final name in ['Roboto', 'NotoSansSC', 'Ahem']) {
      await (FontLoader(
        name,
      )..addFont(Future.value(ByteData.sublistView(regular)))).load();
    }
    final icons = await File(
      '${Platform.environment['TASK_ROOT']}/tooling/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ).readAsBytes();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(Future.value(ByteData.sublistView(icons)))).load();
    sqfliteFfiInit();
    temporary = await Directory.systemTemp.createTemp('daily_screens_');
    store = await LedgerStore.open(
      databasePath: '${temporary.path}/example.db',
      factory: databaseFactoryFfi,
    );
    await seedDailyExample(store);
    controller = LedgerController(
      store: store,
      directory: temporary,
      clock: () => exampleDate,
    );
    await controller.refresh();
    await controller.updateSettings(
      controller.settings.copyWith(themeKey: 'peach'),
    );
  });
  tearDown(() async {
    controller.dispose();
    await store.close();
    await temporary.delete(recursive: true);
  });
  testWidgets(
    'capture the daily ledger and positive flow chart from the running Flutter UI',
    (t) async {
      const width = 414.0;
      t.view.physicalSize = const Size(width, 950);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final root = GlobalKey();
      await t.pumpWidget(
        RepaintBoundary(
          key: root,
          child: PuppyLedgerApp(controller: controller),
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
      Finder key(String name) => find.byKey(ValueKey(name));
      Future<void> show(Finder finder) async {
        if (finder.evaluate().isEmpty) {
          await t.scrollUntilVisible(
            finder,
            180,
            scrollable: find
                .byWidgetPredicate(
                  (w) =>
                      w is Scrollable && w.axisDirection == AxisDirection.down,
                )
                .first,
          );
        }
        await t.ensureVisible(finder);
        await t.pumpAndSettle();
      }

      Future<void> capture(String name, Rect rect) async {
        expect(t.takeException(), isNull);
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThan(t.view.physicalSize.height - 80));
        final boundary =
            root.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await t.runAsync(() async {
          const ratio = 2.5;
          final frame = await boundary.toImage(pixelRatio: ratio);
          final target = Rect.fromLTWH(
            0,
            0,
            rect.width * ratio,
            rect.height * ratio,
          );
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder);
          canvas.drawImageRect(
            frame,
            Rect.fromLTRB(
              rect.left * ratio,
              rect.top * ratio,
              rect.right * ratio,
              rect.bottom * ratio,
            ),
            target,
            Paint(),
          );
          final picture = recorder.endRecording();
          final section = await picture.toImage(
            target.width.ceil(),
            target.height.ceil(),
          );
          final bytes = await section.toByteData(
            format: ui.ImageByteFormat.png,
          );
          final out = Directory(
            Platform.environment['PREVIEW_DIR'] ?? 'build/daily-previews',
          );
          await out.create(recursive: true);
          await File(
            '${out.path}/$name.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          section.dispose();
          picture.dispose();
          frame.dispose();
        });
      }

      await show(key('swipe-metro'));
      final header = t.getRect(key('daily-details-heading')),
          last = t.getRect(key('swipe-metro'));
      await capture(
        'puppy-ledger-0.1.8-daily-details',
        Rect.fromLTRB(0, header.top - 12, width, last.bottom + 16),
      );
      await t.runAsync(
        () => controller.updateSettings(
          controller.settings.copyWith(themeKey: 'sage'),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('统计'));
      await t.pumpAndSettle();
      final section = key('daily-flow-section');
      await show(section);
      await t.tap(key('flow-day-2026-11-02'));
      await t.pumpAndSettle();
      await t.tap(key('flow-day-2026-11-06'));
      await t.pumpAndSettle();
      expect(t.widget<Text>(key('flow-picked-amount')).data, '¥34.00');
      final chart = t.getRect(section);
      await capture(
        'puppy-ledger-0.1.8-daily-flow',
        Rect.fromLTRB(0, chart.top + 6, width, chart.bottom + 12),
      );
      await t.pumpWidget(const SizedBox());
    },
  );
}
