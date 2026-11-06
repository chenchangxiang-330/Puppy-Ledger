import 'models.dart';
import 'logic.dart';

const defaultIncomeCategories = [
  Category(
    id: 'income-salary',
    name: '工资',
    active: true,
    kind: EntryKind.income,
  ),
  Category(
    id: 'income-refund',
    name: '退款',
    active: true,
    kind: EntryKind.income,
  ),
  Category(
    id: 'income-parttime',
    name: '兼职',
    active: true,
    kind: EntryKind.income,
  ),
];

class MigratedLedger {
  const MigratedLedger(this.entries, this.categories, this.settings);
  final List<LedgerEntry> entries;
  final List<Category> categories;
  final LedgerSettings settings;
}

/// Shared by SQLite schema-1 upgrade and portable version-1 backups.
/// Pure conversion: validate the entire candidate before any write. IDs and all
/// timestamps are preserved, including refunds' old category ID/name snapshot.
MigratedLedger migrateLegacyLedger({
  required List<Map<String, Object?>> entries,
  required List<Map<String, Object?>> categories,
  required Map<String, Object?> settings,
}) {
  final convertedCategories = categories
      .map((c) => Category.fromMap({...c, 'kind': 'expense'}))
      .toList();
  final oldCategories = {for (final c in convertedCategories) c.id: c};
  if (oldCategories.length != categories.length) {
    throw const FormatException('旧账本含重复分类标识');
  }
  String? refundCategoryId;
  final usedIds = oldCategories.keys.toSet();
  for (final category in defaultIncomeCategories) {
    var id = category.id;
    while (usedIds.contains(id)) {
      id = '_$id';
    }
    usedIds.add(id);
    convertedCategories.add(
      Category(
        id: id,
        name: category.name,
        active: true,
        kind: EntryKind.income,
      ),
    );
    if (category.id == 'income-refund') refundCategoryId = id;
  }
  final convertedEntries = entries.map((e) {
    if (e['kind'] != 'expense' && e['kind'] != 'refund') {
      throw const FormatException('旧账本类型无效');
    }
    final original = oldCategories[e['categoryId']];
    if (original == null) throw const FormatException('旧账目分类缺失');
    return LedgerEntry.fromMap({
      ...e,
      if (e['kind'] == 'refund') ...{
        'kind': 'income',
        'categoryId': refundCategoryId,
        'legacyCategoryId': original.id,
        'legacyCategoryName': original.name,
      },
    });
  }).toList();
  final convertedSettings = LedgerSettings.fromMap({
    ...settings,
    'goldenIncome': 1,
  });
  validateSnapshot(convertedEntries, convertedCategories, convertedSettings);
  return MigratedLedger(
    convertedEntries,
    convertedCategories,
    convertedSettings,
  );
}
