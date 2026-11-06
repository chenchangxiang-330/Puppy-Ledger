import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puppy_ledger/ui/widgets.dart';
import 'package:puppy_ledger/ui/shapes.dart';

void main() {
  testWidgets(
    'card material clips pressed ink at its continuous contour in all three colors',
    (t) async {
      final boundary = GlobalKey();
      for (final color in [
        butter,
        const Color(0xffffdcd4),
        const Color(0xffdce7cf),
      ]) {
        await t.pumpWidget(
          MaterialApp(
            home: Center(
              child: RepaintBoundary(
                key: boundary,
                child: SizedBox(
                  width: 180,
                  height: 88,
                  child: PuppyCard(
                    padding: EdgeInsets.zero,
                    color: color,
                    child: InkWell(
                      onTap: () {},
                      highlightColor: Colors.red,
                      splashColor: Colors.red,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        final mat = t.widget<Material>(
          find
              .descendant(
                of: find.byType(PuppyCard),
                matching: find.byType(Material),
              )
              .first,
        );
        expect(mat.shape, isA<RoundedSuperellipseBorder>());
        expect(mat.clipBehavior, Clip.antiAlias);
        Future<ByteData> pixels() async {
          return (await t.runAsync(() async {
            final img =
                await (boundary.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await img.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            );
            img.dispose();
            return bytes!;
          }))!;
        }

        final before = await pixels();
        final g = await t.startGesture(t.getCenter(find.byType(InkWell)));
        await t.pump(const Duration(milliseconds: 130));
        await t.pump(const Duration(milliseconds: 180));
        final after = await pixels();
        expect(
          after.getUint32((2 * 180 + 2) * 4),
          before.getUint32((2 * 180 + 2) * 4),
        );
        expect(
          after.getUint32((44 * 180 + 85) * 4),
          isNot(before.getUint32((44 * 180 + 85) * 4)),
        );
        await g.up();
        await t.pumpAndSettle();
      }
      expect(
        const LedgerInputBorder().copyWith(
          borderSide: const BorderSide(width: 2),
        ),
        isA<LedgerInputBorder>(),
      );
      await t.pumpWidget(const SizedBox());
    },
  );
}
