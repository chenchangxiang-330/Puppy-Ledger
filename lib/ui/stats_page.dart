import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/controller.dart';
import '../core/logic.dart';
import '../core/models.dart';
import 'widgets.dart';
import 'motion.dart';
import 'daily_flow_chart.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({
    super.key,
    required this.controller,
    required this.anchor,
    required this.onAnchorChanged,
  });
  final DateTime anchor;
  final ValueChanged<DateTime> onAnchorChanged;
  final LedgerController controller;
  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  Period period = Period.month;
  EntryKind categoryKind = EntryKind.expense;
  DateTime get anchor => widget.anchor;
  void setAnchor(DateTime value) {
    widget.onAnchorChanged(clampUiDate(value));
  }

  void move(int step) => setAnchor(movePeriod(anchor, period, step));
  Future<void> selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: clampUiDate(anchor),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100, 12, 31),
      helpText: period == Period.month ? '选择要查看的历史月份内任一天' : '选择要查看的日期',
    );
    if (date != null && mounted) {
      setAnchor(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final range = reportRange(
      anchor,
      period,
      widget.controller.now,
      widget.controller.entries,
    );
    final records = inRange(widget.controller.entries, range);
    final totals = summarize(records);
    final categories = {
      for (final c in widget.controller.categories) c.id: c.name,
    };
    final categoryValues = categoryTotals(
      records,
      categoryKind,
    ).entries.toList()..sort((a, b) => b.value.abs().compareTo(a.value.abs()));
    final maxCategory = categoryValues.fold<int>(
      1,
      (value, item) => math.max(value, item.value.abs()),
    );
    String rangeLabel;
    if (period == Period.month) {
      rangeLabel = '${anchor.year}年 ${anchor.month}月';
    } else if (period == Period.day) {
      rangeLabel = '${anchor.year}年${anchor.month}月${anchor.day}日';
    } else {
      rangeLabel = '${range.start} — ${range.end}';
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 110),
      children: [
        const PuppyPageHeading(
          title: '收支小报告',
          subtitle: '小狗陪你，把日子慢慢理清',
          golden: true,
        ),
        const SizedBox(height: 24),
        SegmentedButton<Period>(
          segments: const [
            ButtonSegment(value: Period.day, label: Text('日')),
            ButtonSegment(value: Period.week, label: Text('周')),
            ButtonSegment(value: Period.month, label: Text('月')),
          ],
          selected: {period},
          onSelectionChanged: (value) => setState(() {
            period = value.first;
          }),
        ),
        const SizedBox(height: 16),
        PeriodSwipe(
          key: const ValueKey('stats-period-swipe'),
          onMove: move,
          child: Row(
            children: [
              PressFeedback(
                child: IconButton(
                  tooltip: '上一周期',
                  onPressed: () => move(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: selectDate,
                  child: Text(
                    rangeLabel,
                    key: const ValueKey('stats-period-label'),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              PressFeedback(
                child: IconButton(
                  tooltip: '下一周期',
                  onPressed: () => move(1),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ),
            ],
          ),
        ),
        Center(
          child: TextButton(
            onPressed: () => setAnchor(widget.controller.now),
            child: Text(
              period == Period.week
                  ? '回到本周 · 周一至周日'
                  : period == Period.month
                  ? '回到本月'
                  : '回到今天',
            ),
          ),
        ),
        const SizedBox(height: 10),
        PuppyCard(
          color: Theme.of(
            context,
          ).colorScheme.primaryContainer.withValues(alpha: .48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Expanded(
                    child: Text('本周期结余', style: TextStyle(fontSize: 13)),
                  ),
                  PuppyFace(size: 32, golden: true),
                ],
              ),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  money(totals.balance),
                  key: const ValueKey('stats-balance'),
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Divider(height: 1),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) => Wrap(
                  spacing: 24,
                  runSpacing: 16,
                  children: [
                    _SmallTotal(label: '支出总额', amount: money(totals.expense)),
                    _SmallTotal(label: '收入总额', amount: money(totals.income)),
                  ],
                ),
              ),
              if (totals.balance < 0)
                const Padding(
                  padding: EdgeInsets.only(top: 14),
                  child: Text(
                    '本周期支出多于收入，结余为负数。',
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
        DailyFlowChart(
          entries: records,
          categories: categories,
          range: range,
          period: period,
          anchor: anchor,
          themeKey: widget.controller.settings.themeKey,
        ),
        if (records.isNotEmpty) ...[
          const SectionTitle('分类汇总'),
          SegmentedButton<EntryKind>(
            key: const ValueKey('stats-category-kind'),
            segments: const [
              ButtonSegment(value: EntryKind.expense, label: Text('支出去向')),
              ButtonSegment(value: EntryKind.income, label: Text('收入构成')),
            ],
            selected: {categoryKind},
            onSelectionChanged: (v) => setState(() => categoryKind = v.first),
          ),
          const SizedBox(height: 16),
          PuppyCard(
            key: const ValueKey('category-breakdown-card'),
            child: Column(
              children: [
                if (categoryValues.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('本周期暂无${categoryKind.label}'),
                  ),
                for (final item in categoryValues)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 19),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              categoryIcon(categories[item.key] ?? '其他'),
                              size: 17,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(categories[item.key] ?? '未知分类'),
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                money(item.value),
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 11),
                        SizedBox(
                          height: 9,
                          width: double.infinity,
                          child: CustomPaint(
                            painter: CategoryBarPainter(
                              item.value / maxCategory,
                              Theme.of(context).colorScheme.primaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const Text(
                  '按当前所选周期汇总，收入与支出分别统计',
                  style: TextStyle(color: muted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _SmallTotal extends StatelessWidget {
  const _SmallTotal({required this.label, required this.amount});
  final String label, amount;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: muted, fontSize: 12)),
      const SizedBox(height: 6),
      Text(
        amount,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
    ],
  );
}

class CategoryBarPainter extends CustomPainter {
  CategoryBarPainter(this.fraction, this.accent);
  final double fraction;
  final Color accent;
  @override
  void paint(Canvas canvas, Size size) {
    const mid = 0.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)),
      Paint()..color = cream,
    );
    if (fraction != 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            fraction < 0 ? mid + mid * fraction : mid,
            0,
            size.width * fraction,
            size.height,
          ),
          const Radius.circular(8),
        ),
        Paint()..color = fraction < 0 ? const Color(0xFF9FB394) : accent,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CategoryBarPainter old) =>
      fraction != old.fraction || accent != old.accent;
}
