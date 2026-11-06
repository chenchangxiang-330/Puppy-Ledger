import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:puppy_ledger/core/controller.dart';
import 'package:puppy_ledger/core/store.dart';
import 'package:puppy_ledger/ui/app.dart';
import 'package:puppy_ledger/ui/receipt_page.dart';
import 'package:puppy_ledger/ui/receipt_paper.dart';
import '../test/support/daily_sample.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);
  late Directory dir;
  late LedgerStore store;
  late LedgerController c;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('receipt_');
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
  test(
    'streamed tall PNG includes bottom scanlines, final long note and summary; empty receipt also renders',
    () async {
      final original = c.entries.firstWhere((e) => e.id == 'lunch');
      c.entries = [
        for (int i = 0; i < 140; i++)
          original.copyWith(
            id: 'row-$i',
            note: i == 139 ? '最后一笔 ${'长备注 ' * 60}' : '完整备注' * 8,
          ),
      ];
      for (final date in [exampleDate, DateTime(2026, 10, 5)]) {
        final data = ReceiptData(c, date);
        final drawing = ReceiptDrawing.layout(
          data,
          310,
          TextScaler.noScaling,
          [],
          Colors.yellow,
        );
        final f = await writeReceiptPng(
          drawing,
          File('${dir.path}/${date.day}.png'),
        );
        final bytes = await f.readAsBytes();
        final b = ByteData.sublistView(bytes);
        final h = b.getUint32(20), w = b.getUint32(16);
        expect(h, (drawing.size.height * 2).ceil());
        final z = BytesBuilder();
        for (int i = 8; i < bytes.length;) {
          final n = b.getUint32(i);
          if (ascii.decode(bytes.sublist(i + 4, i + 8)) == 'IDAT') {
            z.add(bytes.sublist(i + 8, i + 8 + n));
          }
          i += n + 12;
        }
        final raw = zlib.decode(z.takeBytes());
        expect(raw.length, h * (w * 4 + 1));
        if (data.entries.isNotEmpty) {
          expect(h, greaterThan(16384));
          expect(drawing.labels.any((row) => row.$2.contains('最后一笔')), true);
          expect(drawing.labels.last.$2, contains('3920.00'));
          final footer = raw.sublist(
            (drawing.footerTop * 2).ceil() * (w * 4 + 1),
          );
          expect(footer.where((v) => v < 90).length, greaterThan(200));
        } else {
          expect(data.totals.balance, 0);
        }
        drawing.picture.dispose();
      }
    },
  );
  testWidgets(
    'expense-filtered home opens full receipt, reduced motion and save/share use real full export',
    (t) async {
      t.view.physicalSize = const Size(320, 700);
      t.view.devicePixelRatio = 1;
      t.platformDispatcher.textScaleFactorTestValue = 2;
      t.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final messenger = t.binding.defaultBinaryMessenger;
      final actions = <String>[];
      const files = MethodChannel('puppy_ledger/files');
      messenger.setMockMethodCallHandler(files, (call) async {
        if (call.method == 'receiptDirectory') return dir.path;
        final f = File(call.arguments['path'] as String);
        expect(await f.length(), greaterThan(500));
        actions.add(call.method);
        return true;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(files, null));
      await t.pumpWidget(PuppyLedgerApp(controller: c));
      await t.pumpAndSettle();
      final filter = find.byKey(const ValueKey('entry-filter'));
      await t.scrollUntilVisible(
        filter,
        160,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      await t.ensureVisible(filter);
      await t.pumpAndSettle();
      await t.tap(filter);
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(PopupMenuItem<String>, '支出'));
      await t.pumpAndSettle();
      final open = find.byKey(const ValueKey('generate-receipt'));
      await t.ensureVisible(open);
      await t.pumpAndSettle();
      await t.tap(open);
      await t.pumpAndSettle();
      final d = t.widget<ReceiptPage>(find.byType(ReceiptPage)).data;
      expect(d.entries.map((e) => e.id), ['refund', 'metro', 'lunch']);
      expect(
        [d.totals.income, d.totals.expense, d.totals.balance],
        [10000, 3400, 6600],
      );
      await t.runAsync(() async {
        for (int n = 0; n < 50; n++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          if (t
                  .widget<OutlinedButton>(
                    find.byKey(const ValueKey('save-receipt')),
                  )
                  .onPressed !=
              null) {
            break;
          }
          await t.pump();
        }
      });
      await t.pumpAndSettle();
      for (final key in ['save-receipt', 'share-receipt']) {
        await t.pump(const Duration(seconds: 3));
        await t.pumpAndSettle();
        await t.runAsync(() async {
          await t.tap(find.byKey(ValueKey(key)));
          for (
            int n = 0;
            n < 150 && actions.length < (key == 'save-receipt' ? 1 : 2);
            n++
          ) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
        });
        await t.pumpAndSettle();
      }
      expect(actions, ['writeReceipt', 'shareReceipt']);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
}
