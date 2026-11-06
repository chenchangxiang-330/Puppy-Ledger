// Render real Flutter screens with isolated demonstration data.
// CJK_FONT=/path/to/NotoSansCJK-Regular.ttc PREVIEW_DIR=/absolute/path flutter test tool/preview_test.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:puppy_ledger/core/controller.dart';
import 'package:puppy_ledger/core/store.dart';
import 'package:puppy_ledger/core/models.dart';
import 'package:puppy_ledger/core/logic.dart';
import 'package:puppy_ledger/ui/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temporary;
  late LedgerStore store;
  late LedgerController controller;
  setUp(() async {
    final fontPath = Platform.environment['CJK_FONT'];
    if (fontPath != null) {
      final bytes = await File(fontPath).readAsBytes();
      for (final name in ['Roboto', 'NotoSansSC', 'Ahem']) {
        await (FontLoader(
          name,
        )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      }
    }
    final materialFont = File(
      '${Platform.environment['TASK_ROOT']}/tooling/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    await (FontLoader('MaterialIcons')..addFont(
          Future.value(ByteData.sublistView(await materialFont.readAsBytes())),
        ))
        .load();
    sqfliteFfiInit();
    temporary = await Directory.systemTemp.createTemp('linepuppy_preview_');
    store = await LedgerStore.open(
      databasePath: '${temporary.path}/preview.sqlite',
      factory: databaseFactoryFfi,
    );
    controller = LedgerController(store: store, directory: temporary);
    await controller.refresh();
    Future<void> add(
      String amount,
      String category,
      String note,
      DateTime date,
    ) => controller.saveEntry(
      amount: amount,
      kind: EntryKind.expense,
      date: dateKey(date),
      categoryId: controller.categories
          .firstWhere((c) => c.name == category)
          .id,
      note: note,
    );
    final now = DateTime.now();
    await add('18.00', '餐饮', '一杯拿铁，开启好心情', now);
    await add('6.00', '交通', '去见喜欢的人', now);
    await add('32.50', '生活用品', '把小日子收拾得软乎乎', now);
    await add('28.00', '餐饮', '和你一起吃晚饭', now.subtract(const Duration(days: 1)));
    await add('45.00', '学习', '想读很久的一本书', now.subtract(const Duration(days: 2)));
  });
  tearDown(() async {
    controller.dispose();
    await store.close();
    await temporary.delete(recursive: true);
  });
  testWidgets('render four screens with isolated sample entries', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 912);
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
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/illustrations/puppy_pair.png'),
        key.currentContext!,
      ),
    );
    await tester.pumpAndSettle();
    final out = Directory(
      Platform.environment['PREVIEW_DIR'] ?? 'build/previews',
    );
    await tester.runAsync(() => out.create(recursive: true));
    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = (await tester.runAsync(
        () => boundary.toImage(pixelRatio: 2),
      ))!;
      final bytes = await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.png),
      );
      await tester.runAsync(
        () => File(
          '${out.path}/$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List()),
      );
      image.dispose();
    }

    if (Platform.environment['PREVIEW_THEMES'] == 'true') {
      for (final themeKey in ['lemon', 'peach', 'sage']) {
        await tester.runAsync(
          () => controller.updateSettings(
            controller.settings.copyWith(themeKey: themeKey, clearImage: true),
          ),
        );
        await tester.pumpAndSettle();
        final asset = themeKey == 'peach'
            ? 'puppy_peach.png'
            : themeKey == 'sage'
            ? 'puppy_sage.png'
            : 'puppy_pair.png';
        await tester.runAsync(
          () => precacheImage(
            AssetImage('assets/illustrations/$asset'),
            key.currentContext!,
          ),
        );
        await tester.pumpAndSettle();
        final homeScroll = tester.state<ScrollableState>(
          find
              .descendant(
                of: find.byType(HomePage),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        homeScroll.position.jumpTo(0);
        await tester.pumpAndSettle();
        await capture('$themeKey-home');
      }
      await tester.tap(find.text('我的'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('今天的小狗心情'));
      await capture('theme-picker');
      await tester.pumpWidget(const SizedBox());
      return;
    }
    await capture('01-home');
    await tester.tap(find.text('统计'));
    await capture('02-stats');
    await tester.tap(find.text('我的'));
    await capture('03-settings');
    await tester.tap(find.text('记一笔'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '28.00');
    await tester.tap(find.widgetWithText(ChoiceChip, '餐饮'));
    tester.testTextInput.hide();
    FocusManager.instance.primaryFocus?.unfocus();
    await capture('04-entry');
    await tester.pumpWidget(const SizedBox());
  });
}
