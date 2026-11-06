import 'models.dart';

const maxEntryCents = 999999999999;

/// Parses decimal text using integer operations only; never rounds silently.
int parseCents(String text) {
  final value = text.trim();
  if (value.isEmpty) throw const FormatException('请输入金额');
  if (value.startsWith('-')) throw const FormatException('金额必须大于 0');
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(value)) {
    throw const FormatException('请输入有效金额，最多保留两位小数');
  }
  final parts = value.split('.');
  final whole = int.tryParse(parts[0]);
  if (whole == null || whole > maxEntryCents ~/ 100) {
    throw const FormatException('金额过大，请输入不超过 9,999,999,999.99 元');
  }
  final fraction = parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0;
  final cents = whole * 100 + fraction;
  if (cents <= 0) throw const FormatException('金额必须大于 0');
  if (cents > maxEntryCents) throw const FormatException('金额超过支持范围');
  return cents;
}

String money(int cents, {String symbol = '￥'}) {
  final amount = cents.abs();
  return '${cents < 0 ? '-' : ''}$symbol${amount ~/ 100}.${(amount % 100).toString().padLeft(2, '0')}';
}

String minuteText(int? minute) => minute == null
    ? '未记录时间'
    : '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';

int ledgerOrder(LedgerEntry a, LedgerEntry b) {
  var cmp = b.date.compareTo(a.date);
  if (cmp == 0) {
    cmp = (b.occurredMinute ?? -1).compareTo(a.occurredMinute ?? -1);
  }
  if (cmp == 0) cmp = b.createdAt.compareTo(a.createdAt);
  return cmp == 0 ? a.id.compareTo(b.id) : cmp;
}

Map<String, int> hourlyAmounts(
  Iterable<LedgerEntry> records,
  String date,
  EntryKind kind,
) {
  final hours = {for (var h = 0; h < 24; h++) h.toString().padLeft(2, '0'): 0};
  for (final entry in records) {
    if (entry.date != date ||
        entry.kind != kind ||
        entry.occurredMinute == null) {
      continue;
    }
    final hour = (entry.occurredMinute! ~/ 60).toString().padLeft(2, '0');
    hours[hour] = hours[hour]! + entry.cents;
  }
  return hours;
}

String dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

DateTime parseDateKey(String key) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(key)) {
    throw const FormatException('日期格式应为 YYYY-MM-DD');
  }
  final year = int.parse(key.substring(0, 4));
  final month = int.parse(key.substring(5, 7));
  final day = int.parse(key.substring(8, 10));
  if (year < 1 || year > 9999 || month < 1 || month > 12 || day < 1) {
    throw const FormatException('日期无效');
  }
  final result = DateTime(year, month, day);
  if (result.year != year || result.month != month || result.day != day) {
    throw const FormatException('日期无效');
  }
  return result;
}

enum Period { day, week, month }

class DateRange {
  const DateRange({required this.start, required this.end});
  final String start;
  final String end;
}

DateRange periodRange(DateTime anchor, Period period) {
  final day = DateTime(anchor.year, anchor.month, anchor.day);
  switch (period) {
    case Period.day:
      return DateRange(start: dateKey(day), end: dateKey(day));
    case Period.week:
      // Calendar constructors avoid DST-related 23/25-hour day drift.
      final monday = DateTime(day.year, day.month, day.day - day.weekday + 1);
      return DateRange(
        start: dateKey(monday),
        end: dateKey(DateTime(monday.year, monday.month, monday.day + 6)),
      );
    case Period.month:
      return DateRange(
        start: dateKey(DateTime(day.year, day.month)),
        end: dateKey(DateTime(day.year, day.month + 1, 0)),
      );
  }
}

DateTime movePeriod(DateTime anchor, Period period, int delta) {
  switch (period) {
    case Period.day:
      return DateTime(anchor.year, anchor.month, anchor.day + delta);
    case Period.week:
      return DateTime(anchor.year, anchor.month, anchor.day + 7 * delta);
    case Period.month:
      final nextMonth = DateTime(anchor.year, anchor.month + delta);
      final lastDay = DateTime(nextMonth.year, nextMonth.month + 1, 0).day;
      return DateTime(
        nextMonth.year,
        nextMonth.month,
        anchor.day > lastDay ? lastDay : anchor.day,
      );
  }
}

class Totals {
  const Totals({required this.expense, required this.income});
  final int expense, income;
  int get balance => income - expense;
}

Totals summarize(Iterable<LedgerEntry> entries) {
  var expense = 0, income = 0;
  for (final entry in entries) {
    if (entry.kind == EntryKind.expense) {
      expense += entry.cents;
    } else {
      income += entry.cents;
    }
  }
  return Totals(expense: expense, income: income);
}

List<LedgerEntry> inRange(Iterable<LedgerEntry> entries, DateRange range) =>
    entries
        .where(
          (entry) =>
              entry.date.compareTo(range.start) >= 0 &&
              entry.date.compareTo(range.end) <= 0,
        )
        .toList(growable: false);

/// Hide unelapsed, empty days at the end of the running period. Keep any
/// explicitly selected or already booked future day in that period visible.
DateRange reportRange(
  DateTime anchor,
  Period period,
  DateTime today,
  Iterable<LedgerEntry> entries,
) {
  final full = periodRange(anchor, period);
  final now = dateKey(today);
  if (now.compareTo(full.start) < 0 || now.compareTo(full.end) >= 0) {
    return full;
  }
  var end = dateKey(anchor).compareTo(now) > 0 ? dateKey(anchor) : now;
  for (final entry in entries) {
    if (entry.date.compareTo(end) > 0 && entry.date.compareTo(full.end) <= 0) {
      end = entry.date;
    }
  }
  return DateRange(start: full.start, end: end);
}

Map<String, int> dailyAmounts(
  Iterable<LedgerEntry> entries,
  DateRange range,
  EntryKind kind,
) {
  final result = <String, int>{};
  final end = parseDateKey(range.end);
  for (
    var day = parseDateKey(range.start);
    !day.isAfter(end);
    day = DateTime(day.year, day.month, day.day + 1)
  ) {
    result[dateKey(day)] = 0;
  }
  for (final entry in entries) {
    if (entry.kind == kind && result.containsKey(entry.date)) {
      result[entry.date] = result[entry.date]! + entry.cents;
    }
  }
  return result;
}

Map<String, int> categoryTotals(Iterable<LedgerEntry> entries, EntryKind kind) {
  final result = <String, int>{};
  for (final entry in entries.where((e) => e.kind == kind)) {
    result[entry.categoryId] = (result[entry.categoryId] ?? 0) + entry.cents;
  }
  return result;
}

void validateEntry(LedgerEntry entry) {
  _validateId(entry.id);
  _validateId(entry.categoryId);
  if ((entry.legacyCategoryId == null) != (entry.legacyCategoryName == null)) {
    throw const FormatException('旧分类历史信息不完整');
  }
  if (entry.legacyCategoryId != null) {
    _validateId(entry.legacyCategoryId!);
    if (entry.legacyCategoryName!.isEmpty ||
        entry.legacyCategoryName!.length > 20) {
      throw const FormatException('旧分类名称无效');
    }
  }
  parseDateKey(entry.date);
  if (entry.occurredMinute != null &&
      (entry.occurredMinute! < 0 || entry.occurredMinute! >= 1440)) {
    throw const FormatException('发生时间无效');
  }
  if (entry.cents < 1 || entry.cents > maxEntryCents) {
    throw const FormatException('账目金额必须是支持范围内的正整数分');
  }
  if (entry.note.length > 2000) throw const FormatException('备注不能超过 2000 字');
  if (DateTime.tryParse(entry.createdAt) == null ||
      DateTime.tryParse(entry.updatedAt) == null) {
    throw const FormatException('账目创建或更新时间无效');
  }
}

void validateCategory(Category category) {
  _validateId(category.id);
  if (category.name.trim().isEmpty || category.name.trim() != category.name) {
    throw const FormatException('分类名称不能为空或以空格开头、结尾');
  }
  if (category.name.length > 20) throw const FormatException('分类名称不能超过 20 字');
}

void validateSettings(LedgerSettings settings) {
  if (settings.ledgerName.trim().isEmpty || settings.ledgerName.length > 40) {
    throw const FormatException('账本名称应为 1 至 40 字');
  }
  if (settings.tagline.length > 100) {
    throw const FormatException('首页文案不能超过 100 字');
  }
  if (!RegExp(r'^[a-zA-Z0-9_-]{1,40}$').hasMatch(settings.themeKey)) {
    throw const FormatException('主题设置无效');
  }
  final file = settings.imageFile;
  if (file != null &&
      (!RegExp(r'^[a-zA-Z0-9_-]+\.[a-zA-Z0-9]{1,8}$').hasMatch(file) ||
          file.length > 200)) {
    throw const FormatException('首页图片引用必须为应用目录内的文件名');
  }
}

void _validateId(String id) {
  if (id.isEmpty || id.length > 200 || id.trim() != id) {
    throw const FormatException('记录标识无效');
  }
}

String normalizedCategoryName(String name) =>
    name.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

/// Validates a complete restore candidate before any database write begins.
void validateSnapshot(
  List<LedgerEntry> entries,
  List<Category> categories,
  LedgerSettings settings,
) {
  validateSettings(settings);
  if (categories.isEmpty) throw const FormatException('备份必须包含至少一个分类');
  final categoryIds = <String>{};
  final categoryKinds = <String, EntryKind>{};
  final categoryNames = <String>{};
  for (final category in categories) {
    validateCategory(category);
    categoryKinds[category.id] = category.kind;
    if (!categoryIds.add(category.id) ||
        !categoryNames.add(
          '${category.kind.name}:${normalizedCategoryName(category.name)}',
        )) {
      throw const FormatException('备份包含重复的分类');
    }
  }
  final entryIds = <String>{};
  for (final entry in entries) {
    validateEntry(entry);
    if (!entryIds.add(entry.id)) throw const FormatException('备份包含重复的账目');
    if (!categoryIds.contains(entry.categoryId)) {
      throw const FormatException('账目引用了不存在的分类');
    }
    if (categoryKinds[entry.categoryId] != entry.kind) {
      throw const FormatException('账目与分类的收支类型不一致');
    }
  }
}
