import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'motion.dart';
import 'receipt_paper.dart';
import 'shapes.dart';
import 'widgets.dart';

class ReceiptPage extends StatefulWidget {
  const ReceiptPage({super.key, required this.data});
  final ReceiptData data;
  @override
  State<ReceiptPage> createState() => _ReceiptPageState();
}

class _ReceiptPageState extends State<ReceiptPage>
    with SingleTickerProviderStateMixin {
  static const files = MethodChannel('puppy_ledger/files');
  late final feed = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1050),
  );
  bool started = false, busy = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    startFeed();
  }

  void startFeed() {
    if (PuppyMotion.reduced(context)) {
      started = true;
      feed.value = 1;
    } else if (!started) {
      started = true;
      feed.forward();
    }
  }

  @override
  void dispose() {
    feed.dispose();
    super.dispose();
  }

  Future<void> export(bool share) async {
    if (busy) return;
    setState(() => busy = true);
    ReceiptDrawing? drawing;
    List<ui.Image> dogs = [];
    final tint = Theme.of(context).colorScheme.primaryContainer;
    final data = widget.data;
    try {
      dogs = await receiptDogs();
      drawing = ReceiptDrawing.layout(
        data,
        360,
        TextScaler.noScaling,
        dogs,
        tint,
      );
      final dir = await files.invokeMethod<String>('receiptDirectory');
      if (dir == null) throw StateError('无法创建图片目录');
      final file = await writeReceiptPng(
        drawing,
        File(
          '$dir/receipt-${data.date}-${DateTime.now().microsecondsSinceEpoch}.png',
        ),
      );
      if (!mounted) return;
      final ok = await files.invokeMethod<bool>(
        share ? 'shareReceipt' : 'writeReceipt',
        {'path': file.path, 'name': '小狗账本-${data.date}.png'},
      );
      if (mounted && ok == true && !share) showMessage(context, '整张小票已保存');
    } catch (e) {
      if (mounted) showFailure(context, e);
    } finally {
      drawing?.picture.dispose();
      for (final d in dogs) {
        d.dispose();
      }
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tint = Theme.of(context).colorScheme.primaryContainer;
    return Scaffold(
      appBar: AppBar(title: const Text('每日收支小票')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
              child: Container(
                decoration: ledgerSurface(
                  19,
                  tint,
                  side: const BorderSide(color: ink, width: 1.3),
                ),
                padding: const EdgeInsets.fromLTRB(12, 7, 12, 5),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const PuppyAvatar(golden: false, size: 32),
                        const SizedBox(width: 8),
                        const Flexible(
                          child: Text(
                            '小狗打印机',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const PuppyAvatar(golden: true, size: 32),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(height: 5, decoration: ledgerSurface(3, ink)),
                  ],
                ),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) => SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(26, 0, 26, 14),
                  child: _Paper(
                    data: widget.data,
                    width: box.maxWidth - 52,
                    tint: tint,
                    feed: feed,
                    viewport: box.maxHeight,
                  ),
                ),
              ),
            ),
            if (busy) const LinearProgressIndicator(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                children: [
                  OutlinedButton.icon(
                    key: const ValueKey('save-receipt'),
                    onPressed: busy ? null : () => export(false),
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('保存长图'),
                  ),
                  FilledButton.icon(
                    key: const ValueKey('share-receipt'),
                    onPressed: busy ? null : () => export(true),
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('分享小票'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedClip extends CustomClipper<Rect> {
  const _FeedClip(this.t, this.viewport);
  final double viewport;
  final double t;
  @override
  Rect getClip(Size s) => Rect.fromLTWH(
    0,
    0,
    s.width,
    t == 1 ? s.height : s.height.clamp(0.0, viewport) * t,
  );
  @override
  bool shouldReclip(_FeedClip old) => t != old.t || viewport != old.viewport;
}

class _Paper extends StatefulWidget {
  const _Paper({
    required this.data,
    required this.width,
    required this.feed,
    required this.viewport,
    required this.tint,
  });
  final ReceiptData data;
  final double width;
  final Animation<double> feed;
  final double viewport;
  final Color tint;
  @override
  State<_Paper> createState() => _PaperState();
}

class _PaperState extends State<_Paper> {
  ReceiptDrawing? paper;
  TextScaler? previousScale;
  @override
  void didUpdateWidget(covariant _Paper old) {
    super.didUpdateWidget(old);
    if (old.width != widget.width ||
        old.tint != widget.tint ||
        old.data != widget.data) {
      paper?.picture.dispose();
      paper = null;
    }
  }

  @override
  void dispose() {
    paper?.picture.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context);
    if (previousScale != scale) {
      paper?.picture.dispose();
      paper = null;
      previousScale = scale;
    }
    paper ??= ReceiptDrawing.layout(
      widget.data,
      widget.width,
      scale,
      const [],
      widget.tint,
    );
    return AnimatedBuilder(
      animation: widget.feed,
      builder: (context, child) => ClipRect(
        clipper: _FeedClip(
          Curves.easeInOut.transform(widget.feed.value),
          widget.viewport,
        ),
        child: child,
      ),
      child: Stack(
        children: [
          CustomPaint(
            key: const ValueKey('printed-paper'),
            size: paper!.size,
            painter: _PaperPainter(paper!),
          ),
          Positioned(
            top: 16,
            left: widget.width / 2 - 35,
            child: const Row(
              children: [
                PuppyAvatar(size: 32, golden: true),
                SizedBox(width: 4),
                PuppyAvatar(size: 32, golden: false),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaperPainter extends CustomPainter {
  const _PaperPainter(this.paper);
  final ReceiptDrawing paper;
  @override
  void paint(Canvas canvas, Size size) => canvas.drawPicture(paper.picture);
  @override
  bool shouldRepaint(_PaperPainter old) => paper != old.paper;
  @override
  SemanticsBuilderCallback get semanticsBuilder =>
      (_) => [
        for (final row in paper.labels)
          CustomPainterSemantics(
            rect: row.$1,
            properties: SemanticsProperties(
              label: row.$2,
              textDirection: TextDirection.ltr,
            ),
          ),
      ];
}
