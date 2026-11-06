import 'package:flutter/material.dart';

import '../core/controller.dart';
import '../core/logic.dart';
import '../core/models.dart';
import 'widgets.dart';
import 'motion.dart';

sealed class EntryOutcome {}

class SavedEntryOutcome extends EntryOutcome {
  SavedEntryOutcome(this.entry, this.isNew);
  final LedgerEntry entry;
  final bool isNew;
}

class DeletedEntryOutcome extends EntryOutcome {
  DeletedEntryOutcome(this.token);
  final DeletedEntryToken token;
}

class EntryPage extends StatefulWidget {
  const EntryPage({
    super.key,
    required this.controller,
    this.entry,
    this.initialDate,
    this.shortcutCategory,
  });
  final LedgerController controller;
  final LedgerEntry? entry;
  final DateTime? initialDate;
  final String? shortcutCategory;
  @override
  State<EntryPage> createState() => EntryPageState();
}

class EntryPageState extends State<EntryPage> {
  final formKey = GlobalKey<FormState>();
  late TextEditingController amount;
  late TextEditingController note;
  late final String initialAmount, initialNote;
  late EntryKind kind;
  late DateTime date;
  int? minute;
  String? categoryId;
  bool missingShortcut = false;
  bool busy = false;
  bool changed = false;
  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    amount = TextEditingController(
      text: entry == null
          ? ''
          : '${entry.cents ~/ 100}.${(entry.cents % 100).toString().padLeft(2, '0')}',
    );
    note = TextEditingController(text: entry?.note ?? '');
    kind = entry?.kind ?? EntryKind.expense;
    final local = widget.controller.now.toLocal();
    date = entry == null
        ? (widget.initialDate ?? local)
        : parseDateKey(entry.date);
    minute = entry == null
        ? local.hour * 60 + local.minute
        : entry.occurredMinute;
    categoryId = entry?.categoryId;
    if (entry == null && widget.shortcutCategory != null) {
      final shortcut = widget.controller.categories
          .where(
            (c) =>
                c.id == widget.shortcutCategory &&
                c.active &&
                c.kind == EntryKind.expense,
          )
          .firstOrNull;
      categoryId = shortcut?.id;
      missingShortcut = shortcut == null;
    }

    initialAmount = amount.text;
    initialNote = note.text;
    amount.addListener(markChanged);
    note.addListener(markChanged);
  }

  void markChanged() {
    if (!changed &&
        mounted &&
        (amount.text != initialAmount || note.text != initialNote)) {
      setState(() => changed = true);
    }
  }

  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy || !formKey.currentState!.validate()) return;
    if (categoryId == null) {
      showMessage(context, '选一个分类，再保存吧');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => busy = true);
    try {
      final saved = await widget.controller.saveEntry(
        id: widget.entry?.id,
        amount: amount.text,
        kind: kind,
        date: dateKey(date),
        occurredMinute: minute,
        categoryId: categoryId!,
        note: note.text,
      );
      if (!mounted) return;
      setState(() {
        busy = false;
        changed = false;
      });
      Navigator.of(context).pop(SavedEntryOutcome(saved, widget.entry == null));
    } catch (error) {
      if (mounted) {
        setState(() => busy = false);
        showFailure(context, error);
      }
    }
  }

  Future<void> remove() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除这笔记录？'),
        content: Text(
          '${money(widget.entry!.cents)} 的${widget.entry!.kind.label}将从账本和统计中移除。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('再想想'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => busy = true);
    try {
      final token = await widget.controller.deleteWithUndo(widget.entry!.id);
      if (!mounted) return;
      setState(() {
        busy = false;
        changed = false;
      });
      Navigator.pop(context, DeletedEntryOutcome(token));
    } catch (error) {
      if (mounted) {
        setState(() => busy = false);
        showFailure(context, error);
      }
    }
  }

  Future<bool> confirmLeave() async {
    if (busy) return false;
    if (!changed) return true;
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('还没有保存'),
            content: const Text('离开后，本次输入和修改不会保存。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('继续填写'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('放弃修改'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final categories = widget.controller.categories
        .where(
          (cat) =>
              cat.kind == kind &&
              (cat.active || cat.id == widget.entry?.categoryId),
        )
        .toList();
    return PopScope(
      canPop: !busy && !changed,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await confirmLeave() && mounted) {
          setState(() => changed = false);
          if (context.mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.entry == null ? '记一笔' : '这笔小日子'),
          actions: [
            if (widget.entry != null)
              IconButton(
                tooltip: '删除记录',
                onPressed: busy ? null : remove,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
          ],
        ),
        body: SafeArea(
          child: Form(
            key: formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                SegmentedButton<EntryKind>(
                  segments: const [
                    ButtonSegment(
                      value: EntryKind.expense,
                      label: Text('支出'),
                      icon: Icon(Icons.arrow_outward_rounded),
                    ),
                    ButtonSegment(
                      value: EntryKind.income,
                      label: Text('收入'),
                      icon: Icon(Icons.keyboard_return_rounded),
                    ),
                  ],
                  selected: {kind},
                  onSelectionChanged: busy
                      ? null
                      : (value) => setState(() {
                          kind = value.first;
                          categoryId = null;
                          changed = true;
                        }),
                ),
                const SizedBox(height: 14),
                ListenableBuilder(
                  listenable: widget.controller,
                  builder: (context, _) => ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight:
                          MediaQuery.textScalerOf(context).scale(14) * 2.6 + 16,
                    ),
                    child: Row(
                      children: [
                        PuppyAvatar(
                          key: const ValueKey('entry-role-avatar'),
                          size: 48,
                          golden: widget.controller.settings.goldenFor(kind),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${widget.controller.settings.dogNameFor(kind)}陪你记${kind.label}\n${kind == EntryKind.income ? '小小进账，也是生活的小幸福' : '每一笔，都有好好生活的痕迹'}',
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: amount,
                  enabled: !busy,
                  autofocus: widget.entry == null,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.done,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    labelText: kind == EntryKind.expense ? '支出金额' : '收入金额',
                    prefixText: '￥ ',
                    hintText: '0.00',
                    helperText: '输入正数，最多两位小数',
                    errorMaxLines: 2,
                  ),
                  validator: (value) {
                    try {
                      parseCents(value ?? '');
                      return null;
                    } catch (error) {
                      return errorText(error);
                    }
                  },
                ),
                const SectionTitle('选个分类'),
                if (missingShortcut && categoryId == null)
                  const Text(
                    '原快捷分类已停用或不存在，请选择一个可用分类。',
                    style: TextStyle(color: muted),
                  ),
                if (categories.isEmpty)
                  const Text('还没有启用的分类，请先在「我的」中添加或启用分类。')
                else
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final cat in categories)
                        PressFeedback(
                          enabled: !busy,
                          child: ChoiceChip(
                            key: ValueKey('category-${cat.id}'),
                            chipAnimationStyle: ChipAnimationStyle(
                              enableAnimation: AnimationStyle(
                                duration: PuppyMotion.duration(
                                  context,
                                  PuppyMotion.press,
                                ),
                              ),
                              selectAnimation: AnimationStyle(
                                duration: PuppyMotion.duration(
                                  context,
                                  PuppyMotion.press,
                                ),
                              ),
                            ),
                            side: BorderSide(
                              color: categoryId == cat.id ? ink : line,
                              width: categoryId == cat.id ? 1.6 : 1,
                            ),
                            selected: categoryId == cat.id,
                            label: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 7),
                              child: Text(
                                '${cat.name}${cat.active ? '' : '（已停用）'}',
                              ),
                            ),
                            avatar: Icon(categoryIcon(cat.name), size: 18),
                            onSelected: busy
                                ? null
                                : (_) => setState(() {
                                    categoryId = cat.id;
                                    changed = true;
                                  }),
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 24),
                PuppyCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        key: const ValueKey('entry-date'),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: const Icon(Icons.calendar_today_outlined),
                        title: Text(
                          kind == EntryKind.expense ? '消费日期' : '收入日期',
                        ),
                        subtitle: Text(dateKey(date)),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: busy
                            ? null
                            : () async {
                                FocusScope.of(context).unfocus();
                                final value = await showDatePicker(
                                  context: context,
                                  initialDate: clampUiDate(date),
                                  firstDate: DateTime(1900),
                                  lastDate: DateTime(2100, 12, 31),
                                  helpText: kind == EntryKind.expense
                                      ? '选择消费发生日期'
                                      : '选择实际到账日期',
                                );
                                if (value != null && mounted) {
                                  setState(() {
                                    date = value;
                                    changed = true;
                                  });
                                }
                              },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        key: const ValueKey('entry-time'),
                        leading: const Icon(Icons.schedule_rounded),
                        title: Text(
                          kind == EntryKind.expense ? '消费时间' : '到账时间',
                        ),
                        subtitle: Text(minuteText(minute)),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: busy
                            ? null
                            : () async {
                                FocusScope.of(context).unfocus();
                                final now = widget.controller.now.toLocal();
                                final t = await showTimePicker(
                                  context: context,
                                  initialTime: minute == null
                                      ? TimeOfDay.fromDateTime(now)
                                      : TimeOfDay(
                                          hour: minute! ~/ 60,
                                          minute: minute! % 60,
                                        ),
                                  helpText: kind == EntryKind.expense
                                      ? '选择消费时间'
                                      : '选择到账时间',
                                  initialEntryMode: TimePickerEntryMode.input,
                                  builder: (context, child) => MediaQuery(
                                    data: MediaQuery.of(
                                      context,
                                    ).copyWith(alwaysUse24HourFormat: true),
                                    child: child!,
                                  ),
                                );
                                if (t != null && mounted) {
                                  setState(() {
                                    minute = t.hour * 60 + t.minute;
                                    changed = true;
                                  });
                                }
                              },
                      ),
                    ],
                  ),
                ),
                if (kind == EntryKind.income)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(4, 10, 4, 0),
                    child: Text(
                      '收入按实际到账日期记录；退款计入收入，不再冲减支出。',
                      style: TextStyle(fontSize: 12, color: muted, height: 1.5),
                    ),
                  ),
                if (widget.entry?.legacyCategoryName != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      '旧版退款原分类：${widget.entry!.legacyCategoryName}\n原分类标识：${widget.entry!.legacyCategoryId}',
                      key: const ValueKey('legacy-refund-info'),
                      style: const TextStyle(fontSize: 12, color: muted),
                    ),
                  ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: note,
                  enabled: !busy,
                  maxLines: 3,
                  maxLength: 2000,
                  keyboardType: TextInputType.multiline,
                  decoration: const InputDecoration(
                    labelText: '备注（选填）',
                    hintText: '比如：下班后的小蛋糕',
                  ),
                ),
                const SizedBox(height: 14),
                PressFeedback(
                  enabled: !busy,
                  child: FilledButton.icon(
                    onPressed: busy ? null : save,
                    icon: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(
                      busy
                          ? '正在保存…'
                          : widget.entry == null
                          ? '记好啦，保存'
                          : '保存修改',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '保存到本机 · 离线也能安心记',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
