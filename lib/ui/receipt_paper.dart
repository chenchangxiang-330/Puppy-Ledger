import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:archive/archive.dart' show getCrc32;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/controller.dart';
import '../core/models.dart';
import '../core/logic.dart';
import 'widgets.dart';

class ReceiptData {
  ReceiptData(LedgerController c, DateTime selected)
    : date = dateKey(selected),
      name = c.settings.ledgerName,
      entries = List.unmodifiable(
        c.entries.where((e) => e.date == dateKey(selected)).toList()
          ..sort(ledgerOrder),
      ),
      categories = Map.unmodifiable({
        for (final cat in c.categories) cat.id: cat.name,
      });
  final String date, name;
  final List<LedgerEntry> entries;
  final Map<String, String> categories;
  Totals get totals => summarize(entries);
}

Future<List<ui.Image>> receiptDogs() async {
  Future<ui.Image> load(String path) async {
    final bytes = await rootBundle.load('assets/avatars/${path}_coin.jpg');
    final codec = await ui.instantiateImageCodec(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      targetWidth: 112,
    );
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  }

  return Future.wait([load('golden'), load('white')]);
}

/// The scrollable preview and exported PNG use the same typesetting commands.
class ReceiptDrawing {
  ReceiptDrawing._(this.picture, this.size, this.labels, this.footerTop);
  final ui.Picture picture;
  final Size size;
  final List<(Rect, String)> labels;
  final double footerTop;
  static ReceiptDrawing layout(
    ReceiptData data,
    double width,
    TextScaler scale,
    List<ui.Image> dogs,
    Color tint,
  ) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const inset = 18.0;
    final usable = width - 2 * inset;
    var y = 16.0;
    final labels = <(Rect, String)>[];
    TextPainter text(
      String content,
      double fs,
      Color color, {
      bool bold = false,
      double? max,
      TextAlign align = TextAlign.left,
    }) => TextPainter(
      text: TextSpan(
        text: content,
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: fs,
          height: 1.35,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          color: color,
        ),
      ),
      textAlign: align,
      textScaler: scale,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: max ?? usable);
    void line(
      String s,
      double fs,
      Color color, {
      bool bold = false,
      bool centered = false,
    }) {
      final p = text(s, fs, color, bold: bold);
      p.paint(canvas, Offset(centered ? (width - p.width) / 2 : inset, y));
      y += p.height;
      p.dispose();
    }

    void dash() {
      y += 8;
      final paint = Paint()
        ..color = lineColor
        ..strokeWidth = .8;
      for (double x = inset; x < width - inset; x += 6) {
        canvas.drawLine(
          Offset(x, y),
          Offset(math.min(x + 3, width - inset), y),
          paint,
        );
      }
      y += 9;
    }

    void pair(
      String label,
      String value, {
      bool bold = false,
      Color valueColor = ink,
      double fs = 14,
    }) {
      final v = text(value, fs, valueColor, bold: true);
      final space = usable - v.width - 8;
      if (space < scale.scale(13) * 3.8) {
        line(label, fs, ink, bold: bold);
        v.paint(canvas, Offset(width - inset - v.width, y));
        y += v.height;
      } else {
        final l = text(label, fs, ink, bold: bold, max: space);
        l.paint(canvas, Offset(inset, y));
        v.paint(canvas, Offset(width - inset - v.width, y));
        y += math.max(l.height, v.height);
        l.dispose();
      }
      v.dispose();
    }

    for (var i = 0; i < dogs.length; i++) {
      final dog = dogs[i];
      final rect = Rect.fromLTWH(width / 2 - 35 + i * 36, y, 32, 32);
      canvas.save();
      canvas.clipPath(Path()..addOval(rect));
      final side = math.min(dog.width, dog.height).toDouble();
      canvas.drawImageRect(
        dog,
        Rect.fromCenter(
          center: Offset(dog.width / 2, dog.height / 2),
          width: side,
          height: side,
        ),
        rect,
        Paint()..filterQuality = FilterQuality.medium,
      );
      canvas.restore();
    }
    y += 38;
    line(data.name, 20, ink, bold: true, centered: true);
    line('每日收支小票', 13, muted, centered: true);
    y += 5;
    line(data.date, 14, ink, centered: true);
    dash();
    labels.add((
      Rect.fromLTRB(inset, 0, width - inset, y),
      '${data.name} 每日收支小票 ${data.date}',
    ));
    if (data.entries.isEmpty) {
      line('当天还没有账目', 14, muted, centered: true);
      y += 8;
    }
    for (final entry in data.entries) {
      final top = y;
      final category = data.categories[entry.categoryId] ?? '其他';
      final time = minuteText(entry.occurredMinute);
      final amount =
          '${entry.kind == EntryKind.income ? '+' : '−'}${money(entry.cents, symbol: '¥')}';
      pair(
        '$time  $category',
        amount,
        bold: true,
        valueColor: entry.kind == EntryKind.income
            ? const Color(0xff4e704a)
            : const Color(0xff8c554c),
      );
      y += 2;
      line(
        entry.note.isEmpty
            ? entry.kind.label
            : '${entry.kind.label} · ${entry.note}',
        12,
        muted,
      );
      y += 8;
      labels.add((
        Rect.fromLTRB(inset, top, width - inset, y),
        '$time $category ${entry.kind.label} ${entry.note} $amount',
      ));
    }
    dash();
    final footer = y;
    final total = data.totals;
    pair('当日收入', money(total.income, symbol: '¥'));
    y += 4;
    pair('当日支出', money(total.expense, symbol: '¥'));
    y += 6;
    final start = y;
    pair('当日结余', money(total.balance, symbol: '¥'), bold: true, fs: 17);
    canvas.drawLine(
      Offset(inset, start - 3),
      Offset(width - inset, start - 3),
      Paint()
        ..color = tint
        ..strokeWidth = 2,
    );
    y += 18;
    labels.add((
      Rect.fromLTRB(inset, footer, width - inset, y),
      '当日收入 ${money(total.income)} 当日支出 ${money(total.expense)} 当日结余 ${money(total.balance)}',
    ));
    final height = (y + 5).ceilToDouble();
    final inkPicture = recorder.endRecording();
    final paper = ui.PictureRecorder();
    final c = Canvas(paper);
    c.drawRect(
      Rect.fromLTWH(0, 0, width, height),
      Paint()..color = tint.withValues(alpha: 1),
    );
    final edge = Path()
      ..moveTo(0, 0)
      ..lineTo(width, 0)
      ..lineTo(width, height - 4);
    for (double x = width; x > 0; x -= 10) {
      edge.lineTo(math.max(0, x - 5), height);
      edge.lineTo(math.max(0, x - 10), height - 4);
    }
    edge.close();
    c.drawPath(edge, Paint()..color = Colors.white);
    c.drawPicture(inkPicture);
    final picture = paper.endRecording();
    inkPicture.dispose();
    return ReceiptDrawing._(picture, Size(width, height), labels, footer);
  }

  static const lineColor = Color(0xffb4aa98);
}

/// Encode strips sequentially; a tall receipt never requires a height-sized GPU texture.
Future<File> writeReceiptPng(
  ReceiptDrawing paper,
  File target, {
  double ratio = 2,
}) async {
  final w = (paper.size.width * ratio).ceil(),
      h = (paper.size.height * ratio).ceil();
  final part = File('${target.path}.part');
  await part.parent.create(recursive: true);
  final sink = part.openWrite();
  void chunk(String type, List<int> bytes) {
    final tag = ascii.encode(type);
    final size = ByteData(4)..setUint32(0, bytes.length);
    final crc = ByteData(4)..setUint32(0, getCrc32(bytes, getCrc32(tag)));
    sink.add(size.buffer.asUint8List());
    sink.add(tag);
    sink.add(bytes);
    sink.add(crc.buffer.asUint8List());
  }

  try {
    sink.add([137, 80, 78, 71, 13, 10, 26, 10]);
    final header = ByteData(13)
      ..setUint32(0, w)
      ..setUint32(4, h)
      ..setUint8(8, 8)
      ..setUint8(9, 6);
    chunk('IHDR', header.buffer.asUint8List());
    final compressor = ZLibEncoder().startChunkedConversion(
      _Chunks((bytes) => chunk('IDAT', bytes)),
    );
    for (int y = 0; y < h; y += 512) {
      final n = math.min(512, h - y);
      final r = ui.PictureRecorder();
      final canvas = Canvas(r)
        ..translate(0, -y.toDouble())
        ..scale(ratio);
      canvas.drawPicture(paper.picture);
      final drawing = r.endRecording();
      final tile = await drawing.toImage(w, n);
      final raw = (await tile.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
      final stride = w * 4;
      final lines = Uint8List((stride + 1) * n);
      for (int i = 0; i < n; i++) {
        lines.setRange(
          i * (stride + 1) + 1,
          (i + 1) * (stride + 1),
          raw,
          i * stride,
        );
      }
      compressor.add(lines);
      tile.dispose();
      drawing.dispose();
      await sink.flush();
    }
    compressor.close();
    chunk('IEND', []);
    await sink.close();
    return await part.rename(target.path);
  } catch (_) {
    await sink.close();
    if (await part.exists()) await part.delete();
    rethrow;
  }
}

class _Chunks implements Sink<List<int>> {
  _Chunks(this.consume);
  final void Function(List<int>) consume;
  @override
  void add(List<int> data) {
    if (data.isNotEmpty) consume(data);
  }

  @override
  void close() {}
}
