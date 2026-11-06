import 'shapes.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/logic.dart';
import '../core/models.dart';
import 'motion.dart';
import 'widgets.dart';

class DailyFlowChart extends StatefulWidget {
  const DailyFlowChart({
    super.key,
    required this.entries,
    required this.range,
    required this.period,
    required this.anchor,
    required this.themeKey,
    required this.categories,
  });
  final List<LedgerEntry> entries;
  final DateRange range;
  final Period period;
  final DateTime anchor;
  final String themeKey;
  final Map<String, String> categories;
  @override
  State<DailyFlowChart> createState() => _DailyFlowChartState();
}

class _DailyFlowChartState extends State<DailyFlowChart> {
  EntryKind kind = EntryKind.expense;
  String? picked;
  @override
  void didUpdateWidget(covariant DailyFlowChart old) {
    super.didUpdateWidget(old);
    if (old.anchor != widget.anchor || old.period != widget.period) {
      picked = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hourly = widget.period == Period.day;
    final date = dateKey(widget.anchor);
    final byKind = widget.entries.where((e) => e.kind == kind).toList();
    final values = hourly
        ? hourlyAmounts(byKind, date, kind)
        : dailyAmounts(byKind, widget.range, kind);
    final sum = byKind.fold(0, (total, e) => total + e.cents);
    final defaultHour =
        values.keys.where((k) => values[k]! > 0).firstOrNull ?? '00';
    final selected = picked != null && values.containsKey(picked)
        ? picked!
        : hourly
        ? defaultHour
        : date;
    final unknown = hourly
        ? byKind.where((e) => e.occurredMinute == null).toList()
        : <LedgerEntry>[];
    final inHour = hourly
        ? byKind
              .where(
                (e) =>
                    e.occurredMinute != null &&
                    e.occurredMinute! ~/ 60 == int.parse(selected),
              )
              .toList()
        : <LedgerEntry>[];
    final (strong, fill, pale) = switch (widget.themeKey) {
      'sage' => (
        const Color(0xFF4E704A),
        const Color(0xFFABC29F),
        const Color(0xFFE6EFDF),
      ),
      'peach' => (
        const Color(0xFF905D56),
        const Color(0xFFDFB6AC),
        const Color(0xFFFAE6DF),
      ),
      _ => (
        const Color(0xFF796337),
        const Color(0xFFDDC27E),
        const Color(0xFFFAEDC5),
      ),
    };
    final start = parseDateKey(widget.range.start),
        end = parseDateKey(widget.range.end);
    final crossYear = start.year != end.year;
    String stamp(DateTime d) =>
        '${crossYear ? '${d.year}年' : ''}${d.month}月${d.day}日';
    final dateText = start == end
        ? stamp(start)
        : '${stamp(start)} 至 ${start.year == end.year && start.month == end.month ? '${end.day}日' : stamp(end)}';
    final periodText = switch (widget.period) {
      Period.month => '本月累计',
      Period.week => '本周累计',
      Period.day => '当日',
    };
    return Column(
      key: const ValueKey('daily-flow-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: [
              const Text(
                '每日收支',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              DecoratedBox(
                decoration: ledgerSurface(
                  15,
                  pale.withValues(alpha: .55),
                  side: BorderSide(color: fill),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final option in EntryKind.values)
                        Semantics(
                          button: true,
                          selected: option == kind,
                          child: InkWell(
                            key: ValueKey('flow-${option.name}'),
                            customBorder: ledgerShape(12),
                            onTap: () => setState(() => kind = option),
                            child: AnimatedContainer(
                              duration: PuppyMotion.duration(
                                context,
                                PuppyMotion.press,
                              ),
                              constraints: const BoxConstraints(
                                minHeight: 40,
                                minWidth: 48,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              alignment: Alignment.center,
                              decoration: ledgerSurface(
                                12,
                                option == kind
                                    ? fill.withValues(alpha: .48)
                                    : Colors.transparent,
                              ),
                              child: Text(
                                option.label,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: option == kind ? strong : muted,
                                  fontWeight: option == kind
                                      ? FontWeight.w700
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        PuppyCard(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 8,
                runSpacing: 2,
                children: [
                  Text(
                    '$periodText${kind.label}',
                    style: const TextStyle(color: muted, fontSize: 13),
                  ),
                  Text(
                    dateText,
                    key: const ValueKey('flow-range'),
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    money(sum, symbol: '¥'),
                    key: const ValueKey('flow-total'),
                    style: const TextStyle(
                      fontSize: 29,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              if (widget.entries.isEmpty && !hourly)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      '这段时间还没有收支记录',
                      style: const TextStyle(fontSize: 13, color: muted),
                    ),
                  ),
                )
              else
                _DayPlot(
                  hourly: hourly,
                  values: values,
                  selected: selected,
                  kind: kind,
                  strong: strong,
                  fill: fill,
                  pale: pale,
                  onPick: (day) => setState(() => picked = day),
                ),
              if (hourly) ...[
                const Divider(),
                Text(
                  '$selected 时 · ${inHour.length} 笔',
                  key: const ValueKey('hour-detail-heading'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                for (final entry in inHour)
                  _HourLine(
                    entry: entry,
                    category: widget.categories[entry.categoryId] ?? '其他',
                  ),
                if (inHour.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      '此时段暂无记录',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  ),
                if (unknown.isNotEmpty)
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    key: const ValueKey('unknown-time'),
                    title: const Text('未记录时间'),
                    subtitle: Text(
                      '${unknown.length} 笔 · ${money(unknown.fold(0, (s, e) => s + e.cents), symbol: '¥')}',
                    ),
                    children: [
                      for (final entry in unknown)
                        _HourLine(
                          entry: entry,
                          category: widget.categories[entry.categoryId] ?? '其他',
                        ),
                    ],
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _HourLine extends StatelessWidget {
  const _HourLine({required this.entry, required this.category});
  final LedgerEntry entry;
  final String category;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 8,
          children: [
            Text('${minuteText(entry.occurredMinute)}  $category'),
            Text(
              '${entry.kind == EntryKind.expense ? '−' : '+'}${money(entry.cents, symbol: '¥')}',
            ),
          ],
        ),
        if (entry.note.isNotEmpty)
          Text(entry.note, style: const TextStyle(color: muted, fontSize: 12)),
      ],
    ),
  );
}

class _DayPlot extends StatefulWidget {
  const _DayPlot({
    required this.hourly,
    required this.values,
    required this.selected,
    required this.kind,
    required this.strong,
    required this.fill,
    required this.pale,
    required this.onPick,
  });
  final bool hourly;
  final Map<String, int> values;
  final String selected;
  final EntryKind kind;
  final Color strong, fill, pale;
  final ValueChanged<String> onPick;
  @override
  State<_DayPlot> createState() => _DayPlotState();
}

class _DayPlotState extends State<_DayPlot> {
  final scroll = ScrollController();
  (String, String, String, double, double)? lastView;
  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  void revealSelected(
    List<String> days,
    int selected,
    double slot,
    double width,
    double bubbleLeft,
    double bubbleWidth,
  ) {
    final view = (days.first, days.last, days[selected], width, bubbleWidth);
    if (view == lastView) return;
    lastView = view;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scroll.hasClients || view != lastView) return;
      final left = math.min(slot * selected, bubbleLeft);
      final right = math.max(slot * (selected + 1), bubbleLeft + bubbleWidth);
      final offset = scroll.offset;
      final target = left < offset
          ? left
          : right > offset + width
          ? right - width
          : offset;
      scroll.jumpTo(target.clamp(0, scroll.position.maxScrollExtent));
    });
  }

  @override
  Widget build(BuildContext context) {
    final days = widget.values.keys.toList();
    final selected = math.max(0, days.indexOf(widget.selected));
    final maxAmount = widget.values.values.reduce(math.max);
    final step = maxAmount == 0 ? 100 : _axisStep(maxAmount);
    final ticks = math.max(1, (maxAmount / step).ceil());
    final top = ticks * step;
    final scaler = MediaQuery.textScalerOf(context);
    final labelHeight = scaler.scale(12) * 1.5 + 10;
    final headroom = scaler.scale(12) * 1.55 + 15;
    const plotHeight = 112.0;
    final baseline = headroom + plotHeight;
    final totalHeight = baseline + labelHeight;
    final axisWidth = math.max(
      25.0,
      scaler.scale(10) * (_axisLabel(top).length * .65 + 1.1),
    );
    return SizedBox(
      height: totalHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: axisWidth,
            height: totalHeight,
            child: Stack(
              children: [
                for (var i = 0; i <= ticks; i++)
                  Positioned(
                    right: 4,
                    top:
                        baseline -
                        i / ticks * plotHeight -
                        scaler.scale(10) * .66,
                    child: Text(
                      _axisLabel(i * step),
                      style: const TextStyle(color: muted, fontSize: 10),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                final viewport = box.maxWidth;
                final slot = math.max(
                  math.max(42.0, scaler.scale(12) * 2.5 + 8),
                  viewport / days.length,
                );
                final width = slot * days.length;
                final barWidth = math.min(22.0, slot * .47);

                final amount = widget.values[days[selected]]!;
                final tooltip = money(amount, symbol: '¥');
                final style = DefaultTextStyle.of(context).style.copyWith(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                );
                final painter = TextPainter(
                  text: TextSpan(text: tooltip, style: style),
                  textDirection: TextDirection.ltr,
                  textScaler: scaler,
                )..layout();
                final bubbleWidth = math.min(viewport, painter.width + 16);
                painter.dispose();
                final center = (selected + .5) * slot;
                final bubbleLeft = (center - bubbleWidth / 2).clamp(
                  0.0,
                  width - bubbleWidth,
                );
                revealSelected(
                  days,
                  selected,
                  slot,
                  viewport,
                  bubbleLeft,
                  bubbleWidth,
                );
                return SingleChildScrollView(
                  key: const ValueKey('daily-chart-scroll'),
                  controller: scroll,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: width,
                    height: totalHeight,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _Grid(
                              headroom,
                              baseline,
                              ticks,
                              widget.fill,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            for (var i = 0; i < days.length; i++)
                              Builder(
                                builder: (_) {
                                  final day = days[i],
                                      value = widget.values[day]!;
                                  final active = i == selected;
                                  return Semantics(
                                    button: true,
                                    selected: active,
                                    label:
                                        '${widget.hourly ? '$day时' : day} ${widget.kind.label} ${money(value, symbol: '¥')}',
                                    child: GestureDetector(
                                      key: ValueKey('flow-day-$day'),
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => widget.onPick(day),
                                      child: ExcludeSemantics(
                                        child: SizedBox(
                                          width: slot,
                                          height: totalHeight,
                                          child: Stack(
                                            alignment: Alignment.topCenter,
                                            children: [
                                              if (value > 0)
                                                Positioned(
                                                  bottom: labelHeight,
                                                  child: Container(
                                                    key: ValueKey(
                                                      'flow-bar-$day',
                                                    ),
                                                    width: barWidth,
                                                    height:
                                                        plotHeight *
                                                        value /
                                                        top,
                                                    decoration: BoxDecoration(
                                                      color: active
                                                          ? widget.strong
                                                          : widget.fill,
                                                      borderRadius:
                                                          const BorderRadius.vertical(
                                                            top:
                                                                Radius.circular(
                                                                  4,
                                                                ),
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                              Positioned(
                                                top: baseline + 3,
                                                child: DecoratedBox(
                                                  decoration: ledgerSurface(
                                                    9,
                                                    active
                                                        ? widget.pale
                                                        : Colors.transparent,
                                                  ),
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 4,
                                                          vertical: 1,
                                                        ),
                                                    child: Text(
                                                      widget.hourly
                                                          ? '$day时'
                                                          : '${int.parse(day.substring(8))}日',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: active
                                                            ? widget.strong
                                                            : muted,
                                                        fontWeight: active
                                                            ? FontWeight.w700
                                                            : FontWeight.normal,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                        Positioned(
                          left: bubbleLeft,
                          width: bubbleWidth,
                          bottom: labelHeight + plotHeight * amount / top + 4,
                          child: IgnorePointer(
                            child: ExcludeSemantics(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  DecoratedBox(
                                    decoration: ledgerSurface(7, widget.strong),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 3,
                                      ),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          tooltip,
                                          key: const ValueKey(
                                            'flow-picked-amount',
                                          ),
                                          style: style,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    height: 4,
                                    child: CustomPaint(
                                      painter: _Tip(
                                        widget.strong,
                                        center - bubbleLeft,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Use integer cents for both bar height and totals. Round the axis to 1/2/5 steps.
int _axisStep(int maxAmount) {
  final raw = math.max(1.0, maxAmount / 3);
  final unit = math.pow(10, (math.log(raw) / math.ln10).floor()).toInt();
  return [
    unit,
    2 * unit,
    5 * unit,
    10 * unit,
  ].firstWhere((value) => value >= raw);
}

String _axisLabel(int cents) {
  if (cents >= 10000000000) {
    return '${cents / 10000000000 >= 10 ? (cents / 10000000000).round() : (cents / 10000000000).toStringAsFixed(1)}亿';
  }
  if (cents >= 1000000) {
    return '${cents / 1000000 >= 10 ? (cents / 1000000).round() : (cents / 1000000).toStringAsFixed(1)}万';
  }
  final whole = cents ~/ 100, frac = cents % 100;
  if (frac == 0) return '$whole';
  return '$whole.${frac.toString().padLeft(2, '0').replaceFirst(RegExp(r'0$'), '')}';
}

class _Grid extends CustomPainter {
  const _Grid(this.top, this.bottom, this.ticks, this.color);
  final double top, bottom;
  final int ticks;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: .42)
      ..strokeWidth = 1;
    for (var i = 1; i <= ticks; i++) {
      final y = bottom - (bottom - top) * i / ticks;
      for (double x = 0; x < size.width; x += 6) {
        canvas.drawLine(
          Offset(x, y),
          Offset(math.min(x + 2.5, size.width), y),
          paint,
        );
      }
    }
    canvas.drawLine(
      Offset(0, bottom),
      Offset(size.width, bottom),
      paint
        ..color = color
        ..strokeWidth = 1.15,
    );
  }

  @override
  bool shouldRepaint(_Grid old) =>
      old.top != top ||
      old.bottom != bottom ||
      old.ticks != ticks ||
      old.color != color;
}

class _Tip extends CustomPainter {
  const _Tip(this.color, this.x);
  final Color color;
  final double x;
  @override
  void paint(Canvas c, Size s) {
    final center = x.clamp(4.0, math.max(4.0, s.width - 4)).toDouble();
    c.drawPath(
      Path()
        ..moveTo(center - 4, 0)
        ..lineTo(center, s.height)
        ..lineTo(center + 4, 0)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_Tip old) => old.x != x || old.color != color;
}
