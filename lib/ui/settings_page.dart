import 'shapes.dart';
import 'dart:io';

import 'package:flutter/material.dart';

import '../core/controller.dart';
import '../core/models.dart';
import 'widgets.dart';
import 'motion.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.controller});

  final LedgerController controller;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _busy = false;
  bool _themeSaving = false;

  LedgerController get controller => widget.controller;

  Future<void> _run(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await operation();
    } catch (error) {
      if (mounted) _showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editDetails() async {
    final previous = controller.settings;
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (context) => _LedgerDetailsDialog(
        initialName: previous.ledgerName,
        initialTagline: previous.tagline,
      ),
    );
    if (result == null || !mounted) return;
    await _run(() async {
      final current = controller.settings;
      await controller.updateSettings(
        LedgerSettings(
          ledgerName: result.$1,
          tagline: result.$2,
          themeKey: current.themeKey,
          imageFile: current.imageFile,
          goldenIncome: current.goldenIncome,
        ),
      );
      if (mounted) _showMessage(context, '已保存，账本更像你啦');
    });
  }

  Future<void> _setTheme(String key) async {
    if (_busy || _themeSaving) return;
    if (controller.settings.themeKey == key &&
        controller.settings.imageFile == null) {
      return;
    }
    // Theme selection is a small local write. Do not insert/remove the global
    // progress row or disable every control: that made the whole page jump.
    _themeSaving = true;
    try {
      await precacheImage(AssetImage(puppyArtworkAsset(key)), context);
      if (!mounted) return;
      // Choosing a pictured built-in theme selects its bundled expression.
      // The old custom image file is not deleted from the private directory.
      await controller.updateSettings(
        controller.settings.copyWith(themeKey: key, clearImage: true),
      );
    } catch (error) {
      if (mounted) _showError(context, error);
    } finally {
      _themeSaving = false;
    }
  }

  Future<void> _restore() async {
    await _run(() async {
      final backup = await controller.chooseBackup();
      if (backup == null || !mounted) return;
      final approved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('恢复这个账本？'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  backup.settings.ledgerName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  '${backup.entries.length} 笔账目 · '
                  '${backup.categories.length} 个分类',
                ),
                const SizedBox(height: 6),
                Text(backup.imageBytes == null ? '使用默认小狗图片' : '包含自定义首页图片'),
                const SizedBox(height: 18),
                const Text(
                  '将覆盖当前账本的全部账目、分类、设置和图片，无法撤销。'
                  '建议先导出当前账本备份。',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('先不恢复'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('确认覆盖并恢复'),
            ),
          ],
        ),
      );
      if (approved != true) return;
      await controller.restoreBackup(backup);
      if (mounted) _showMessage(context, '恢复好啦，账目和设置已更新');
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final settings = controller.settings;
        final theme = Theme.of(context);
        return SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PuppyPageHeading(
                  title: '我的小天地',
                  subtitle: '和小狗一起，把日子过成喜欢的样子',
                ),
                const SizedBox(height: 24),
                PuppyCard(
                  child: Column(
                    children: [
                      _ImagePreview(controller: controller),
                      const SizedBox(height: 12),
                      Text(
                        settings.ledgerName,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        settings.tagline,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _editDetails,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('修改名称与短文案'),
                      ),
                    ],
                  ),
                ),
                if (_busy) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(minHeight: 3),
                  const SizedBox(height: 8),
                  const Text('正在处理，请稍候…'),
                ],
                const SizedBox(height: 26),
                const SectionTitle('今天的小狗心情'),
                const SizedBox(height: 12),
                PuppyCard(
                  padding: const EdgeInsets.all(12),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = (constraints.maxWidth - 16) / 3;
                      return Wrap(
                        spacing: 8,
                        runSpacing: 12,
                        children: [
                          _ThemeChoice(
                            label: '蜜桃粉',
                            themeKey: 'peach',
                            width: width,
                            color: const Color(0xFFFFDCD4),
                            selected:
                                settings.themeKey == 'peach' &&
                                settings.imageFile == null,
                            onTap: _busy ? null : () => _setTheme('peach'),
                          ),
                          _ThemeChoice(
                            label: '奶油黄',
                            themeKey: 'lemon',
                            width: width,
                            color: const Color(0xFFFFE9A5),
                            selected:
                                settings.themeKey == 'lemon' &&
                                settings.imageFile == null,
                            onTap: _busy ? null : () => _setTheme('lemon'),
                          ),
                          _ThemeChoice(
                            label: '草地绿',
                            themeKey: 'sage',
                            width: width,
                            color: const Color(0xFFDCE7CF),
                            selected:
                                settings.themeKey == 'sage' &&
                                settings.imageFile == null,
                            onTap: _busy ? null : () => _setTheme('sage'),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '选一个主题，配色和小狗表情一起换',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
                const SizedBox(height: 26),
                const SectionTitle('账本管理'),
                const SizedBox(height: 12),
                PuppyCard(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      _ActionTile(
                        icon: Icons.swap_horiz_rounded,
                        title: '小狗分工',
                        subtitle:
                            '${settings.dogNameFor(EntryKind.income)}管收入 · ${settings.dogNameFor(EntryKind.expense)}管支出',
                        onTap: _busy
                            ? null
                            : () => Navigator.of(context).push<void>(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      DogRolesPage(controller: controller),
                                ),
                              ),
                      ),
                      const Divider(indent: 18, endIndent: 18),
                      _ActionTile(
                        icon: Icons.category_outlined,
                        title: '分类管理',
                        subtitle: '新增、改名或停用，旧账目会保留',
                        onTap: _busy
                            ? null
                            : () => Navigator.of(context).push<void>(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      _CategoriesPage(controller: controller),
                                ),
                              ),
                      ),
                      const Divider(indent: 18, endIndent: 18),
                      _ActionTile(
                        icon: Icons.ios_share_rounded,
                        title: '导出完整备份',
                        subtitle: '账目、分类、设置和图片一起带走',
                        onTap: _busy
                            ? null
                            : () => _run(() async {
                                await controller.exportBackup();
                                if (context.mounted) {
                                  _showMessage(context, '完整备份已导出');
                                }
                              }),
                      ),
                      const Divider(indent: 18, endIndent: 18),
                      _ActionTile(
                        icon: Icons.restore_rounded,
                        title: '从备份恢复',
                        subtitle: '选择备份文件，确认后覆盖当前账本',
                        onTap: _busy ? null : _restore,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 8),
                      const Text('小狗替你记，数据留在你手里', textAlign: TextAlign.center),
                      const SizedBox(height: 6),
                      Text(
                        '账目仅保存在本机，换机或卸载前请导出备份。\n'
                        '完整离线使用 · 版本 0.1.4+5 · 线条小狗风格',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.controller});

  final LedgerController controller;

  @override
  Widget build(BuildContext context) {
    final image = controller.settings.imageFile;
    if (image == null) return const DogArt(size: 172);
    return ClipRSuperellipse(
      borderRadius: BorderRadius.circular(24),
      child: Image.file(
        File('${controller.directory.path}/$image'),
        width: 160,
        height: 150,
        cacheWidth: 512,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const DogArt(size: 172),
      ),
    );
  }
}

class _ThemeChoice extends StatelessWidget {
  const _ThemeChoice({
    required this.label,
    required this.themeKey,
    required this.width,
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final String label, themeKey;
  final double width;
  final Color color;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: PressFeedback(
      enabled: onTap != null,
      child: InkWell(
        key: ValueKey('theme-$themeKey'),
        onTap: onTap,
        customBorder: ledgerShape(16),
        child: AnimatedContainer(
          duration: PuppyMotion.duration(context, PuppyMotion.theme),
          clipBehavior: Clip.antiAlias,
          width: width,
          padding: const EdgeInsets.fromLTRB(5, 8, 5, 10),
          decoration: ledgerSurface(
            16,
            color.withValues(alpha: selected ? .75 : .24),
            side: BorderSide(
              color: selected ? ink : line,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  size: 15,
                  color: selected ? ink : muted,
                ),
              ),
              DogArt(size: width - 14, themeKey: themeKey),
              const SizedBox(height: 7),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PressFeedback(
      enabled: onTap != null,
      child: ListTile(
        enabled: onTap != null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        leading: Icon(icon),
        title: Text(title),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(subtitle),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

class _LedgerDetailsDialog extends StatefulWidget {
  const _LedgerDetailsDialog({
    required this.initialName,
    required this.initialTagline,
  });

  final String initialName;
  final String initialTagline;

  @override
  State<_LedgerDetailsDialog> createState() => _LedgerDetailsDialogState();
}

class _LedgerDetailsDialogState extends State<_LedgerDetailsDialog> {
  late final TextEditingController _name;
  late final TextEditingController _tagline;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialName);
    _tagline = TextEditingController(text: widget.initialTagline);
  }

  @override
  void dispose() {
    _name.dispose();
    _tagline.dispose();
    super.dispose();
  }

  void _submit() {
    if (_name.text.trim().isEmpty || _tagline.text.trim().isEmpty) {
      setState(() => _error = '给账本一个名字，再写一句喜欢的话吧');
      return;
    }
    Navigator.pop(context, (_name.text.trim(), _tagline.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('给账本一点个性'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              maxLength: 20,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: '账本名称'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tagline,
              maxLength: 40,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(labelText: '首页短文案'),
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('保存')),
      ],
    );
  }
}

class _CategoriesPage extends StatefulWidget {
  const _CategoriesPage({required this.controller});

  final LedgerController controller;

  @override
  State<_CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<_CategoriesPage> {
  EntryKind kind = EntryKind.expense;
  bool _busy = false;

  Future<void> _save(Category category) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.controller.saveCategory(category);
    } catch (error) {
      if (mounted) _showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit([Category? category]) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _CategoryNameDialog(
        initialName: category?.name,
        otherNames: widget.controller.categories
            .where((item) => item.kind == kind && item.id != category?.id)
            .map((item) => item.name)
            .toList(),
      ),
    );
    if (name == null || !mounted) return;
    await _save(
      Category(
        id: category?.id ?? widget.controller.newId(),
        name: name,
        active: category?.active ?? true,
        kind: category?.kind ?? kind,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('分类管理')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.all(20),
            children: [
              SegmentedButton<EntryKind>(
                segments: const [
                  ButtonSegment(value: EntryKind.expense, label: Text('支出')),
                  ButtonSegment(value: EntryKind.income, label: Text('收入')),
                ],
                selected: {kind},
                onSelectionChanged: _busy
                    ? null
                    : (v) => setState(() => kind = v.first),
              ),
              const SizedBox(height: 16),
              const Text(
                '分类停用后，不再出现在新记账的选项里。\n'
                '原有账目与统计会保留，随时可以重新启用。',
              ),
              const SizedBox(height: 20),
              if (_busy) const LinearProgressIndicator(),
              ...widget.controller.categories
                  .where((c) => c.kind == kind)
                  .map(
                    (category) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: PuppyCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: _busy ? null : () => _edit(category),
                                borderRadius: BorderRadius.circular(10),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        category.name,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        category.active
                                            ? '正在使用 · 点此改名'
                                            : '已停用 · 点此改名',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Semantics(
                              label:
                                  '${category.name}分类${category.active ? '停用' : '启用'}',
                              child: Switch.adaptive(
                                value: category.active,
                                onChanged: _busy
                                    ? null
                                    : (value) => _save(
                                        Category(
                                          id: category.id,
                                          name: category.name,
                                          active: value,
                                          kind: category.kind,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _edit(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('新增分类'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryNameDialog extends StatefulWidget {
  const _CategoryNameDialog({this.initialName, required this.otherNames});

  final String? initialName;
  final List<String> otherNames;

  @override
  State<_CategoryNameDialog> createState() => _CategoryNameDialogState();
}

class _CategoryNameDialogState extends State<_CategoryNameDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      setState(() => _error = '分类名称不能为空');
      return;
    }
    if (widget.otherNames.any(
      (name) => name.toLowerCase() == value.toLowerCase(),
    )) {
      setState(() => _error = '已经有这个分类啦，换个名字吧');
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialName == null ? '新增分类' : '分类改名'),
      content: SingleChildScrollView(
        child: TextField(
          controller: _controller,
          autofocus: true,
          maxLength: 20,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: '分类名称',
            hintText: '例如：宠物、运动',
            errorText: _error,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('保存')),
      ],
    );
  }
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

void _showError(BuildContext context, Object error) {
  _showMessage(context, errorText(error));
}

class DogRolesPage extends StatefulWidget {
  const DogRolesPage({super.key, required this.controller});
  final LedgerController controller;
  @override
  State<DogRolesPage> createState() => _DogRolesPageState();
}

class _DogRolesPageState extends State<DogRolesPage> {
  bool saving = false;
  Future<void> swap() async {
    if (saving) return;
    setState(() => saving = true);
    try {
      final current = widget.controller.settings;
      await widget.controller.updateSettings(
        current.copyWith(goldenIncome: !current.goldenIncome),
      );
    } catch (error) {
      if (mounted) showFailure(context, error);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('小狗分工')),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              '两只小狗，一起照顾小账本',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text('选好分工后，每次记账都会有对应的小狗陪你。', style: TextStyle(color: muted)),
            const SizedBox(height: 24),
            for (final golden in [true, false]) ...[
              PuppyCard(
                child: Row(
                  children: [
                    PuppyAvatar(size: 72, golden: golden),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            golden ? '小鸡毛' : '小白',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            golden == widget.controller.settings.goldenIncome
                                ? '负责收入'
                                : '负责支出',
                            key: ValueKey(
                              'role-${golden ? 'golden' : 'white'}',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            PressFeedback(
              enabled: !saving,
              child: FilledButton.icon(
                key: const ValueKey('swap-dog-roles'),
                onPressed: saving ? null : swap,
                icon: const Icon(Icons.swap_horiz_rounded),
                label: const Text('交换分工'),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '自动保存 · 只交换小狗的职责\n已记录的收支、金额、分类和日期都保持原样。',
              style: TextStyle(fontSize: 12, color: muted, height: 1.6),
            ),
          ],
        ),
      ),
    ),
  );
}
