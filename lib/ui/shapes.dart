import 'dart:ui' show ClipOp;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

RoundedSuperellipseBorder ledgerShape(
  double radius, {
  BorderSide side = BorderSide.none,
}) => RoundedSuperellipseBorder(
  borderRadius: BorderRadius.circular(radius),
  side: side,
);
ShapeDecoration ledgerSurface(
  double radius,
  Color color, {
  BorderSide side = BorderSide.none,
  List<BoxShadow>? shadows,
}) => ShapeDecoration(
  color: color,
  shape: ledgerShape(radius, side: side),
  shadows: shadows,
);

/// InputDecorator uses these paths for its fill and its outline. Reserve the
/// floating label's gap on the top edge, including during the focus animation.
class LedgerInputBorder extends InputBorder {
  const LedgerInputBorder({
    super.borderSide = const BorderSide(),
    this.radius = 17,
  });
  final double radius;
  @override
  bool get isOutline => true;
  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(borderSide.width);
  @override
  LedgerInputBorder copyWith({BorderSide? borderSide}) => LedgerInputBorder(
    radius: radius,
    borderSide: borderSide ?? this.borderSide,
  );
  @override
  LedgerInputBorder scale(double t) =>
      LedgerInputBorder(radius: radius * t, borderSide: borderSide.scale(t));
  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      ledgerShape(radius, side: borderSide).getOuterPath(rect);
  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      ledgerShape(radius, side: borderSide).getInnerPath(rect);
  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    double? gapStart,
    double gapExtent = 0,
    double gapPercentage = 0,
    TextDirection? textDirection,
  }) {
    canvas.save();
    if (gapStart != null && gapExtent > 0 && gapPercentage > 0) {
      final width = (gapExtent + 8) * gapPercentage;
      final x =
          rect.left +
          gapStart +
          (textDirection == TextDirection.rtl ? 4 - width : -4);
      canvas.clipRect(
        Rect.fromLTRB(
          x,
          rect.top - 1,
          x + width,
          rect.top + borderSide.width + 1,
        ),
        clipOp: ClipOp.difference,
      );
    }
    ledgerShape(
      radius,
      side: borderSide,
    ).paint(canvas, rect, textDirection: textDirection);
    canvas.restore();
  }

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) => a is LedgerInputBorder
      ? LedgerInputBorder(
          radius: a.radius + (radius - a.radius) * t,
          borderSide: BorderSide.lerp(a.borderSide, borderSide, t),
        )
      : super.lerpFrom(a, t);
  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) =>
      b is LedgerInputBorder ? b.lerpFrom(this, t) : super.lerpTo(b, t);
  @override
  bool operator ==(Object other) =>
      other is LedgerInputBorder &&
      radius == other.radius &&
      borderSide == other.borderSide;
  @override
  int get hashCode => Object.hash(radius, borderSide);
}

/// Clip lazy sliver rows against the same full scrolling contour used by
/// DecoratedSliver. Do not clip the shadow painted by the outer decoration.
class LedgerSliverClip extends SingleChildRenderObjectWidget {
  const LedgerSliverClip({
    super.key,
    required this.shape,
    required Widget sliver,
  }) : super(child: sliver);
  final ShapeBorder shape;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderLedgerClip(shape);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderProxySliver renderObject,
  ) {
    (renderObject as _RenderLedgerClip).shape = shape;
  }
}

class _RenderLedgerClip extends RenderProxySliver {
  _RenderLedgerClip(this._shape);
  ShapeBorder _shape;
  set shape(ShapeBorder next) {
    if (_shape != next) {
      _shape = next;
      markNeedsPaint();
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null || geometry?.visible != true) return;
    final bounds = getMaxPaintRect();
    context.pushClipPath(
      needsCompositing,
      offset,
      bounds,
      _shape.getInnerPath(bounds),
      (c, o) => c.paintChild(child!, o),
      clipBehavior: Clip.antiAlias,
    );
  }
}
