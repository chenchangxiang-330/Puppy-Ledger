import 'shapes.dart';
import 'package:flutter/material.dart';

import '../core/logic.dart';
import '../core/models.dart';
import 'motion.dart';
import 'swipe_entry.dart';
import 'widgets.dart';

/// A single card with lazily built rows, even on days with a long ledger.
class DailyDetails extends StatelessWidget {
  const DailyDetails({
    super.key,
    this.headerKey,
    required this.date,
    required this.today,
    required this.totals,
    required this.records,
    required this.categories,
    required this.filter,
    required this.onFilter,
    required this.onChooseDate,
    required this.onReceipt,
    required this.onMoveMonth,
    required this.openId,
    required this.onEdit,
    required this.onDelete,
    required this.onAdd,
    this.incomingId,
  });
  final GlobalKey? headerKey;
  final DateTime date, today;
  final Totals totals;
  final List<LedgerEntry> records;
  final Map<String, Category> categories;
  final EntryKind? filter;
  final ValueChanged<EntryKind?> onFilter;
  final VoidCallback onChooseDate, onAdd, onReceipt;
  final ValueChanged<int> onMoveMonth;
  final ValueNotifier<String?> openId;
  final ValueChanged<LedgerEntry> onEdit, onDelete;
  final String? incomingId;

  @override
  Widget build(BuildContext context) {
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final year = date.year == today.year ? '' : '${date.year}年';
    final label =
        '$year${date.month}月${date.day}日 ${weekdays[date.weekday - 1]}';
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            key: headerKey,
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: PeriodSwipe(
              key: const ValueKey('home-month-swipe'),
              onMove: onMoveMonth,
              child: Wrap(
                key: const ValueKey('daily-details-heading'),
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 3,
                    children: [
                      const Text(
                        '每日明细',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      TextButton.icon(
                        key: const ValueKey('generate-receipt'),
                        onPressed: onReceipt,
                        icon: const Icon(Icons.receipt_long_outlined, size: 16),
                        label: const Text(
                          '生成小票',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          foregroundColor: muted,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    key: const ValueKey('daily-date-button'),
                    onPressed: onChooseDate,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 32),
                      foregroundColor: ink,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withValues(alpha: .68),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedSuperellipseBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 16),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            label,
                            key: const ValueKey('daily-date-label'),
                          ),
                        ),
                        const SizedBox(width: 3),
                        const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        DecoratedSliver(
          decoration: ledgerSurface(
            20,
            Colors.white,
            side: const BorderSide(color: ink, width: 1.25),
            shadows: const [
              BoxShadow(color: Color(0xFFECE5D7), offset: Offset(0, 2)),
            ],
          ),
          sliver: LedgerSliverClip(
            shape: ledgerShape(
              20,
              side: const BorderSide(color: ink, width: 1.25),
            ),
            sliver: SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
              sliver: SliverMainAxisGroup(
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 4,
                                runSpacing: 2,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  _Total(
                                    kind: EntryKind.income,
                                    cents: totals.income,
                                  ),
                                  const ExcludeSemantics(
                                    child: Text(
                                      '·',
                                      style: TextStyle(color: muted),
                                    ),
                                  ),
                                  _Total(
                                    kind: EntryKind.expense,
                                    cents: totals.expense,
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              key: const ValueKey('entry-filter'),
                              tooltip: '筛选当天流水',
                              initialValue: filter?.name ?? 'all',
                              onSelected: (v) => onFilter(
                                v == 'all' ? null : EntryKind.values.byName(v),
                              ),
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'all',
                                  child: Text('全部'),
                                ),
                                for (final kind in EntryKind.values)
                                  PopupMenuItem(
                                    value: kind.name,
                                    child: Text(kind.label),
                                  ),
                              ],
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: 48,
                                  minWidth: 48,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      filter?.label ?? '全部',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: muted,
                                      ),
                                    ),
                                    const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 17,
                                      color: muted,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 1, color: line),
                      ],
                    ),
                  ),
                  if (records.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: Column(
                          children: [
                            Text(
                              filter == null
                                  ? '这一天的账本，还是空白的'
                                  : '这一天还没有${filter!.label}记录',
                              style: const TextStyle(color: muted),
                            ),
                            if (filter == null)
                              TextButton(
                                onPressed: onAdd,
                                child: const Text('记下今天的第一笔'),
                              ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverList.builder(
                      itemCount: records.length,
                      itemBuilder: (_, index) {
                        final record = records[index];
                        return Column(
                          key: ValueKey(record.id),
                          children: [
                            if (index > 0)
                              const Divider(height: 1, indent: 46, color: line),
                            EntryArrival(
                              animate: incomingId == record.id,
                              child: SwipeEntry(
                                id: record.id,
                                openId: openId,
                                onEdit: () => onEdit(record),
                                onDelete: () => onDelete(record),
                                child: _RecordTile(
                                  record: record,
                                  category:
                                      categories[record.categoryId]?.name ??
                                      '未知分类',
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.kind, required this.cents});
  final EntryKind kind;
  final int cents;
  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        TextSpan(text: '${kind.label} '),
        TextSpan(
          text: money(cents, symbol: '¥'),
          style: const TextStyle(color: ink, fontWeight: FontWeight.w700),
        ),
      ],
    ),
    key: ValueKey('daily-${kind.name}-total'),
    style: const TextStyle(color: muted, fontSize: 13),
  );
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record, required this.category});
  final LedgerEntry record;
  final String category;
  @override
  Widget build(BuildContext context) {
    final income = record.kind == EntryKind.income;
    final sign = income ? '+' : '−';
    final amount = Text(
      '$sign${money(record.cents, symbol: '¥')}',
      maxLines: 1,
      style: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: income ? const Color(0xFF4E6C49) : const Color(0xFF8C554C),
      ),
    );
    final iconColor = income
        ? const Color(0xFFE4EDDE)
        : switch (category) {
            '餐饮' => const Color(0xFFF9E4DB),
            '交通' => const Color(0xFFEDE8D7),
            _ => Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: .6),
          };
    final icon = switch (category) {
      '退款' => Icons.undo_rounded,
      '餐饮' => Icons.ramen_dining_outlined,
      '交通' => Icons.directions_bus_outlined,
      _ => categoryIcon(category),
    };
    final description = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              category,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            Text(
              minuteText(record.occurredMinute),
              style: const TextStyle(fontSize: 11, color: muted),
            ),
          ],
        ),
        const SizedBox(height: 2),
        DefaultTextStyle.merge(
          style: const TextStyle(fontSize: 12, color: muted),
          child: Row(
            children: [
              Text(record.kind.label),
              if (record.note.isNotEmpty) ...[
                const Text(' · '),
                Expanded(
                  child: Text(
                    record.note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
    return ColoredBox(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: LayoutBuilder(
          builder: (context, box) {
            final stackAmount =
                MediaQuery.textScalerOf(context).scale(16) > 24 ||
                box.maxWidth < 219;
            return Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: ledgerSurface(11, iconColor),
                  child: Icon(
                    icon,
                    size: 21,
                    color: income
                        ? const Color(0xFF4E6C49)
                        : const Color(0xFF755F49),
                  ),
                ),
                const SizedBox(width: 10),
                if (stackAmount)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        description,
                        const SizedBox(height: 3),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: amount,
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  Expanded(child: description),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: box.maxWidth * .47),
                    child: FittedBox(fit: BoxFit.scaleDown, child: amount),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
