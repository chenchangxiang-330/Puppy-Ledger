import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puppy_ledger/ui/stats_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'full, short and empty category bars have rounded ends and no protruding marker',
    () async {
      for (final color in [const Color(0xffffdcd4), const Color(0xffdce7cf)]) {
        for (final fraction in [1.0, .25, 0.0]) {
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder)..translate(2, 4);
          CategoryBarPainter(
            fraction,
            color,
          ).paint(canvas, const Size(100, 10));
          final pic = recorder.endRecording();
          final image = await pic.toImage(104, 18);
          final rgba = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          int pixel(int x, int y) => rgba.getUint32((y * 104 + x) * 4);
          for (int x = 0; x < 104; x++) {
            expect(pixel(x, 2), 0);
            expect(pixel(x, 15), 0);
          }
          final fill =
              (color.r * 255).round() << 24 |
              (color.g * 255).round() << 16 |
              (color.b * 255).round() << 8 |
              255;
          if (fraction > 0) {
            expect(pixel(8, 9), fill);
            expect(pixel((100 * fraction).toInt() - 3, 9), fill);
          }
          if (fraction < 1) {
            expect(pixel((100 * fraction).toInt() + 9, 9), isNot(fill));
          }
          image.dispose();
          pic.dispose();
        }
      }
    },
  );
}
