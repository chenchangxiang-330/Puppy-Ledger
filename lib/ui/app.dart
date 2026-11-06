import 'shapes.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/controller.dart';
import '../core/logic.dart';
import '../core/models.dart';
import 'entry_page.dart';
import 'settings_page.dart';
import 'stats_page.dart';
import 'widgets.dart';
import 'motion.dart';
import 'daily_details.dart';
import 'receipt_page.dart';
import 'widget_links.dart';
import 'receipt_paper.dart';
import 'startup_welcome.dart';

class PuppyLedgerApp extends StatelessWidget {
  const PuppyLedgerApp({super.key, required this.controller});
  final LedgerController controller;
  static final Map<String, ThemeData> _themes = {};
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final accent = switch (controller.settings.themeKey) {
        'lemon' => butter,
        'sage' => const Color(0xFFDCE7CF),
        _ => const Color(0xFFFFDCD4),
      };
      final scheme =
          ColorScheme.fromSeed(
            seedColor: ink,
            brightness: Brightness.light,
          ).copyWith(
            primary: ink,
            onPrimary: Colors.white,
            primaryContainer: accent,
            onPrimaryContainer: ink,
            surface: cream,
            onSurface: ink,
            secondaryContainer: accent,
            onSecondaryContainer: ink,
            outline: line,
            onSurfaceVariant: muted,
          );
      final background = switch (controller.settings.themeKey) {
        'peach' => const Color(0xFFFFF8F5),
        'sage' => const Color(0xFFF8FBF3),
        _ => cream,
      };
      return MaterialApp(
        themeAnimationDuration: PuppyMotion.duration(
          context,
          PuppyMotion.theme,
        ),
        themeAnimationCurve: Curves.easeInOut,
        title: '小狗账本',
        debugShowCheckedModeBanner: false,
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: _themes.putIfAbsent(
          controller.settings.themeKey,
          () => ThemeData(
            useMaterial3: true,
            extensions: [PuppyArtworkTheme(controller.settings.themeKey)],
            colorScheme: scheme,
            scaffoldBackgroundColor: background,
            textTheme: ThemeData.light().textTheme.apply(
              bodyColor: ink,
              displayColor: ink,
            ),
            appBarTheme: AppBarTheme(
              backgroundColor: background,
              foregroundColor: ink,
              centerTitle: false,
              surfaceTintColor: Colors.transparent,
            ),
            dividerColor: line,
            dividerTheme: const DividerThemeData(color: line, thickness: 1),
            chipTheme: ChipThemeData(
              backgroundColor: Colors.white,
              selectedColor: accent,
              side: const BorderSide(color: ink, width: 1.1),
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              showCheckmark: false,
              labelStyle: const TextStyle(
                fontFamily: 'Roboto',
                color: ink,
                fontWeight: FontWeight.w600,
              ),
            ),
            segmentedButtonTheme: SegmentedButtonThemeData(
              style: ButtonStyle(
                side: const WidgetStatePropertyAll(
                  BorderSide(color: ink, width: 1.2),
                ),
                shape: WidgetStatePropertyAll(
                  RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                backgroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? accent
                      : Colors.white,
                ),
                foregroundColor: const WidgetStatePropertyAll(ink),
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
            navigationBarTheme: const NavigationBarThemeData(
              height: 72,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              labelTextStyle: WidgetStatePropertyAll(
                TextStyle(
                  color: ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            dialogTheme: DialogThemeData(
              shape: ledgerShape(26),
              clipBehavior: Clip.antiAlias,
            ),
            bottomSheetTheme: BottomSheetThemeData(
              shape: ledgerShape(24),
              clipBehavior: Clip.antiAlias,
            ),
            popupMenuTheme: PopupMenuThemeData(shape: ledgerShape(15)),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(shape: ledgerShape(12)),
            ),
            datePickerTheme: DatePickerThemeData(shape: ledgerShape(26)),
            timePickerTheme: TimePickerThemeData(
              shape: ledgerShape(26),
              hourMinuteShape: ledgerShape(12),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              border: const LedgerInputBorder(
                borderSide: BorderSide(color: line),
              ),
              focusedBorder: const LedgerInputBorder(
                borderSide: BorderSide(color: ink, width: 1.6),
              ),
              errorBorder: LedgerInputBorder(
                borderSide: BorderSide(color: scheme.error),
              ),
              focusedErrorBorder: LedgerInputBorder(
                borderSide: BorderSide(color: scheme.error, width: 1.6),
              ),
              enabledBorder: const LedgerInputBorder(
                borderSide: BorderSide(color: line),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 18,
              ),
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                minimumSize: const Size(48, 52),
                backgroundColor: accent,
                foregroundColor: ink,
                side: const BorderSide(color: ink, width: 1.3),
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(48, 48),
                side: const BorderSide(color: ink, width: 1.1),
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
            snackBarTheme: SnackBarThemeData(
              behavior: SnackBarBehavior.floating,
              backgroundColor: ink,
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        builder: (context, child) => StartupWelcome(child: child!),
        home: LedgerShell(controller: controller),
      );
    },
  );
}

class LedgerShell extends StatefulWidget {
  const LedgerShell({super.key, required this.controller});
  final LedgerController controller;
  @override
  State<LedgerShell> createState() => _LedgerShellState();
}

class _LedgerShellState extends State<LedgerShell> {
  int tab = 0, celebration = 0;
  late DateTime selected = widget.controller.now;
  String? incomingId;
  EntryKind celebrationKind = EntryKind.expense;
  bool routeOpen = false, undoBusy = false;
  Timer? arrivalTimer, undoTimer;
  final List<DeletedEntryToken> pending = [];
  void chooseDate(DateTime value) =>
      setState(() => selected = clampUiDate(value));
  late WidgetLinks widgetLinks;
  final _launches = <(String, String)>[];
  bool _routingWidget = false, _confirmingExit = false;
  final _entryKey = GlobalKey<EntryPageState>();
  int detailRequest = 0;
  @override
  void initState() {
    super.initState();
    attachLinks();
  }

  void attachLinks() {
    widgetLinks = WidgetLinks(widget.controller, (type, value) {
      if (type != 'day' && type != 'expense') return;
      _launches.clear();
      _launches.add((type, value));
      if (routeOpen) {
        leaveEntryForWidget();
      } else {
        routeWidget();
      }
    })..attach();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widgetLinks.drain();
    });
  }

  @override
  void didUpdateWidget(covariant LedgerShell old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      widgetLinks.dispose();
      attachLinks();
    }
  }

  Future<void> leaveEntryForWidget() async {
    if (_confirmingExit || !routeOpen || !mounted) return;
    final editor = _entryKey.currentState;
    if (editor == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) leaveEntryForWidget();
      });
      return;
    }
    if (editor.busy) {
      return; // openEntry delivers a queued launch after this commit.
    }
    final navigator = Navigator.of(context);
    _confirmingExit = true;
    try {
      if (await editor.confirmLeave()) {
        if (mounted && routeOpen) navigator.popUntil((r) => r.isFirst);
      } else {
        _launches.clear();
      }
    } finally {
      _confirmingExit = false;
    }
  }

  Future<void> routeWidget() async {
    if (_routingWidget || routeOpen || !mounted) return;
    final navigator = Navigator.of(context);
    _routingWidget = true;
    try {
      while (_launches.isNotEmpty && mounted && !routeOpen) {
        final (type, value) = _launches.removeAt(0);
        if (type != 'day' && type != 'expense') continue;
        navigator.popUntil((route) => route.isFirst);
        if (type == 'day') {
          try {
            final d = clampUiDate(parseDateKey(value));
            setState(() {
              tab = 0;
              selected = d;
              detailRequest++;
            });
          } on FormatException {
            continue;
          }
        } else {
          setState(() {
            tab = 0;
            selected = widget.controller.now;
          });
          await openEntry(null, value);
        }
      }
    } finally {
      _routingWidget = false;
    }
  }

  Future<void> openEntry([LedgerEntry? entry, String? shortcut]) async {
    if (routeOpen) return;
    setState(() => routeOpen = true);
    final outcome = await Navigator.of(context).push<EntryOutcome>(
      MaterialPageRoute(
        builder: (_) => EntryPage(
          key: _entryKey,
          controller: widget.controller,
          entry: entry,
          initialDate: selected,
          shortcutCategory: shortcut,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => routeOpen = false);
    if (outcome is SavedEntryOutcome) {
      arrivalTimer?.cancel();
      setState(() {
        selected = parseDateKey(outcome.entry.date);
        tab = 0;
        celebration++;
        celebrationKind = outcome.entry.kind;
        incomingId = outcome.isNew ? outcome.entry.id : null;
      });
      arrivalTimer = Timer(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => incomingId = null);
      });
    } else if (outcome is DeletedEntryOutcome) {
      setState(() {
        tab = 0;
        selected = parseDateKey(outcome.token.entry.date);
      });
      offerUndo(outcome.token);
    }
    if (_launches.isNotEmpty) routeWidget();
  }

  Future<void> removeEntry(LedgerEntry entry) async {
    try {
      final token = await widget.controller.deleteWithUndo(entry.id);
      if (mounted) offerUndo(token);
    } catch (error) {
      if (mounted) showFailure(context, error);
    }
  }

  void offerUndo(DeletedEntryToken token) {
    setState(() {
      pending.removeWhere((t) => !widget.controller.now.isBefore(t.expiresAt));
      pending.add(token);
    });
    scheduleUndoExpiry();
  }

  void scheduleUndoExpiry() {
    undoTimer?.cancel();
    if (pending.isEmpty) return;
    final first = pending
        .map((t) => t.expiresAt)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final remaining = first.difference(widget.controller.now);
    undoTimer = Timer(remaining.isNegative ? Duration.zero : remaining, () {
      if (!mounted) return;
      setState(
        () => pending.removeWhere(
          (t) => !widget.controller.now.isBefore(t.expiresAt),
        ),
      );
      scheduleUndoExpiry();
    });
  }

  Future<void> undo() async {
    if (undoBusy) return;
    final tokens = pending
        .where((t) => widget.controller.now.isBefore(t.expiresAt))
        .toList();
    if (tokens.isEmpty) {
      setState(pending.clear);
      return;
    }
    setState(() => undoBusy = true);
    try {
      await widget.controller.undoDeletes(tokens);
      if (!mounted) return;
      setState(() {
        pending.removeWhere(tokens.contains);
        selected = parseDateKey(tokens.last.entry.date);
        tab = 0;
      });
      showMessage(context, '已撤销，账目恢复啦');
    } catch (error) {
      if (mounted) showFailure(context, error);
    } finally {
      if (mounted) {
        setState(() => undoBusy = false);
        scheduleUndoExpiry();
      }
    }
  }

  @override
  void dispose() {
    widgetLinks.dispose();
    arrivalTimer?.cancel();
    undoTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: IndexedStack(
        index: tab,
        children: [
          TickerMode(
            enabled: tab == 0 && !routeOpen,
            child: HomePage(
              controller: widget.controller,
              onAdd: openEntry,
              onEdit: openEntry,
              onDelete: removeEntry,
              selected: selected,
              onDateChanged: chooseDate,
              active: tab == 0 && !routeOpen,
              detailRequest: detailRequest,
              celebration: celebration,
              celebrationKind: celebrationKind,
              incomingId: incomingId,
            ),
          ),
          TickerMode(
            enabled: tab == 1 && !routeOpen,
            child: StatsPage(
              controller: widget.controller,
              anchor: selected,
              onAnchorChanged: chooseDate,
            ),
          ),
          TickerMode(
            enabled: tab == 2 && !routeOpen,
            child: SettingsPage(controller: widget.controller),
          ),
        ],
      ),
    ),
    floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    floatingActionButton: tab == 1
        ? null
        : PressFeedback(
            child: FloatingActionButton.extended(
              key: const ValueKey('add-entry-fab'),
              onPressed: openEntry,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              foregroundColor: ink,
              elevation: 2,
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(22),
                side: const BorderSide(color: ink, width: 1.5),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                '记一笔',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
    bottomNavigationBar: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (pending.isNotEmpty)
          Material(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: SafeArea(
              top: false,
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '已删除 ${pending.length} 笔',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    PressFeedback(
                      enabled: !undoBusy,
                      child: TextButton(
                        key: const ValueKey('undo-delete'),
                        onPressed: undoBusy ? null : undo,
                        child: Text(undoBusy ? '恢复中…' : '撤销'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        NavigationBar(
          backgroundColor: Colors.white,
          indicatorColor: Theme.of(context).colorScheme.primaryContainer,
          selectedIndex: tab,
          onDestinationSelected: (value) => setState(() => tab = value),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book_rounded),
              label: '账本',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart_rounded),
              label: '统计',
            ),
            NavigationDestination(
              icon: PuppyFace(size: 28),
              selectedIcon: PuppyFace(size: 28, golden: true),
              label: '我的',
            ),
          ],
        ),
      ],
    ),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.controller,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.selected,
    required this.onDateChanged,
    required this.active,
    required this.celebration,
    this.celebrationKind = EntryKind.expense,
    this.detailRequest = 0,
    this.incomingId,
  });
  final LedgerController controller;
  final VoidCallback onAdd;
  final ValueChanged<LedgerEntry> onEdit, onDelete;
  final DateTime selected;
  final ValueChanged<DateTime> onDateChanged;
  final bool active;
  final int celebration;
  final EntryKind celebrationKind;
  final int detailRequest;
  final String? incomingId;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _detailAnchor = GlobalKey();
  EntryKind? filter;
  final scroll = ScrollController();
  final ValueNotifier<String?> openId = ValueNotifier(null);
  DateTime get selected => widget.selected;
  @override
  void didUpdateWidget(covariant HomePage old) {
    super.didUpdateWidget(old);
    if (widget.detailRequest != old.detailRequest) {
      filter = null;
      openId.value = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final anchor = _detailAnchor.currentContext;
        if (mounted && anchor != null) Scrollable.ensureVisible(anchor);
      });
    }
    if (widget.celebration != old.celebration) {
      filter = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && scroll.hasClients) scroll.jumpTo(0);
      });
    }
    if (!widget.active || dateKey(selected) != dateKey(old.selected)) {
      openId.value = null;
    }
  }

  @override
  void dispose() {
    openId.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> chooseDate() async {
    openId.value = null;
    final value = await showDialog<DateTime>(
      context: context,
      builder: (dialog) => AlertDialog(
        scrollable: true,
        contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
        insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        content: SizedBox(
          width: 320,
          child: CalendarDatePicker(
            initialDate: clampUiDate(selected),
            currentDate: widget.controller.now,
            firstDate: DateTime(1900),
            lastDate: DateTime(2100, 12, 31),
            onDateChanged: (date) => Navigator.pop(dialog, date),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialog, clampUiDate(widget.controller.now)),
            child: const Text('回到今天'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('取消'),
          ),
        ],
      ),
    );
    if (value != null && mounted) widget.onDateChanged(value);
  }

  void moveMonth(int step) => widget.onDateChanged(
    clampUiDate(movePeriod(selected, Period.month, step)),
  );
  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final allRecords = inRange(c.entries, periodRange(selected, Period.day));
    final records = allRecords
        .where((e) => filter == null || e.kind == filter)
        .toList();
    final day = summarize(allRecords);
    final month = summarize(
      inRange(c.entries, periodRange(selected, Period.month)),
    );
    final categories = {for (final item in c.categories) item.id: item};
    final now = c.now;
    return CustomScrollView(
      key: const PageStorageKey('home-ledger-list'),
      controller: scroll,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          sliver: SliverList.list(
            children: [
              PuppyPageHeading(
                title: c.settings.ledgerName,
                subtitle: c.settings.tagline,
              ),
              const SizedBox(height: 22),
              PuppyCard(
                color: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: .65),
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selected.year == now.year && selected.month == now.month
                          ? '本月结余'
                          : '${selected.year}年${selected.month}月结余',
                      key: const ValueKey('home-month-heading'),
                      style: const TextStyle(fontSize: 14, color: muted),
                    ),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        money(month.balance),
                        key: const ValueKey('home-month-total'),
                        style: const TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    LayoutBuilder(
                      builder: (context, box) {
                        final dogSize = box.maxWidth < 300 ? 116.0 : 138.0;
                        return PuppyCompanion(
                          themeKey: c.settings.themeKey,
                          active: widget.active,
                          celebration: widget.celebration,
                          successMessage: widget.celebrationKind.successMessage,
                          successDog: SizedBox(
                            width: dogSize,
                            height: dogSize * .84,
                            child: Center(
                              child: PuppyAvatar(
                                key: const ValueKey('success-role-avatar'),
                                size: 76,
                                golden: c.settings.goldenFor(
                                  widget.celebrationKind,
                                ),
                              ),
                            ),
                          ),
                          leading: const Text(
                            '一起攒下小幸福\n结余 = 收入 − 支出',
                            style: TextStyle(
                              fontSize: 12,
                              color: muted,
                              height: 1.7,
                            ),
                          ),
                          dog: LedgerDog(controller: c, size: dogSize),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _RoleTotal(
                        kind: EntryKind.income,
                        cents: month.income,
                        settings: c.settings,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _RoleTotal(
                        kind: EntryKind.expense,
                        cents: month.expense,
                        settings: c.settings,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 112),
          sliver: DailyDetails(
            headerKey: _detailAnchor,
            date: selected,
            today: now,
            totals: day,
            records: records,
            categories: categories,
            filter: filter,
            onFilter: (value) => setState(() {
              filter = value;
              openId.value = null;
            }),
            onChooseDate: chooseDate,
            onReceipt: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ReceiptPage(data: ReceiptData(c, selected)),
              ),
            ),
            onMoveMonth: moveMonth,
            openId: openId,
            incomingId: widget.incomingId,
            onEdit: widget.onEdit,
            onDelete: widget.onDelete,
            onAdd: widget.onAdd,
          ),
        ),
      ],
    );
  }
}

class _RoleTotal extends StatelessWidget {
  const _RoleTotal({
    required this.kind,
    required this.cents,
    required this.settings,
  });
  final EntryKind kind;
  final int cents;
  final LedgerSettings settings;
  @override
  Widget build(BuildContext context) => PuppyCard(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                kind.label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 4),
            PuppyAvatar(
              key: ValueKey('home-${kind.name}-avatar'),
              size: 36,
              golden: settings.goldenFor(kind),
            ),
          ],
        ),
        const SizedBox(height: 10),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            money(cents),
            key: ValueKey('home-month-${kind.name}'),
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              color: kind == EntryKind.income ? const Color(0xFF57704C) : ink,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${settings.dogNameFor(kind)}陪你记',
          style: const TextStyle(fontSize: 11, color: muted),
        ),
      ],
    ),
  );
}
