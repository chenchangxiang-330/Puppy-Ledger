/// Amounts are whole fen; dates are business dates independent of time zones.
enum EntryKind { expense, income }

extension EntryKindLabel on EntryKind {
  String get label => this == EntryKind.income ? '收入' : '支出';
  String get successMessage =>
      this == EntryKind.income ? '又攒下一点小幸福！' : '这笔花销记好啦！';
}

class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.date,
    required this.categoryId,
    required this.note,
    required this.createdAt,
    required this.updatedAt,
    required this.cents,
    required this.kind,
    this.occurredMinute,
    this.legacyCategoryId,
    this.legacyCategoryName,
  });

  final String id;
  final String date;
  // Local wall-clock time, independent of creation time; null is unknown.
  final int? occurredMinute;
  final String categoryId;
  final String note;
  final String createdAt;
  final String updatedAt;
  final int cents;
  final EntryKind kind;
  final String? legacyCategoryId, legacyCategoryName;

  Map<String, Object?> toMap() => {
    'id': id,
    'date': date,
    'occurredMinute': occurredMinute,
    'categoryId': categoryId,
    'note': note,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'cents': cents,
    'kind': kind.name,
    'legacyCategoryId': legacyCategoryId,
    'legacyCategoryName': legacyCategoryName,
  };

  factory LedgerEntry.fromMap(Map<String, Object?> map) {
    final kind = _string(map, 'kind');
    if (kind != 'expense' && kind != 'income') {
      throw const FormatException('账目类型无效');
    }
    final cents = map['cents'];
    if (cents is! int) throw const FormatException('金额必须以整数分保存');
    final minute = map['occurredMinute'];
    if (minute != null && (minute is! int || minute < 0 || minute >= 1440)) {
      throw const FormatException('发生时间必须是有效的小时与分钟');
    }
    return LedgerEntry(
      occurredMinute: minute as int?,
      id: _string(map, 'id'),
      date: _string(map, 'date'),
      categoryId: _string(map, 'categoryId'),
      note: _string(map, 'note'),
      createdAt: _string(map, 'createdAt'),
      updatedAt: _string(map, 'updatedAt'),
      cents: cents,
      kind: EntryKind.values.byName(kind),
      legacyCategoryId: _optionalString(map, 'legacyCategoryId'),
      legacyCategoryName: _optionalString(map, 'legacyCategoryName'),
    );
  }

  LedgerEntry copyWith({
    String? id,
    String? date,
    int? occurredMinute,
    String? categoryId,
    String? note,
    String? createdAt,
    String? updatedAt,
    int? cents,
    EntryKind? kind,
  }) => LedgerEntry(
    id: id ?? this.id,
    date: date ?? this.date,
    occurredMinute: occurredMinute ?? this.occurredMinute,
    categoryId: categoryId ?? this.categoryId,
    note: note ?? this.note,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    cents: cents ?? this.cents,
    kind: kind ?? this.kind,
    legacyCategoryId: legacyCategoryId,
    legacyCategoryName: legacyCategoryName,
  );
}

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.active,
    this.kind = EntryKind.expense,
  });
  final String id;
  final String name;
  final bool active;
  final EntryKind kind;

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'active': active ? 1 : 0,
    'kind': kind.name,
  };

  factory Category.fromMap(Map<String, Object?> map) {
    final active = map['active'];
    if (active is! bool && !(active is int && (active == 0 || active == 1))) {
      throw const FormatException('分类状态无效');
    }
    return Category(
      id: _string(map, 'id'),
      name: _string(map, 'name'),
      active: active == 1 || active == true,
      kind: EntryKind.values.byName(_string(map, 'kind')),
    );
  }

  Category copyWith({String? name, bool? active}) => Category(
    id: id,
    name: name ?? this.name,
    active: active ?? this.active,
    kind: kind,
  );
}

class LedgerSettings {
  const LedgerSettings({
    this.ledgerName = '小狗账本',
    this.tagline = '把日子过成喜欢的样子',
    this.themeKey = 'lemon',
    this.imageFile,
    this.goldenIncome = true,
  });

  final String ledgerName;
  final String tagline;
  final String themeKey;
  final String? imageFile;
  final bool goldenIncome;
  bool goldenFor(EntryKind kind) =>
      kind == EntryKind.income ? goldenIncome : !goldenIncome;
  String dogNameFor(EntryKind kind) => goldenFor(kind) ? '小鸡毛' : '小白';

  Map<String, Object?> toMap() => {
    'ledgerName': ledgerName,
    'tagline': tagline,
    'themeKey': themeKey,
    'imageFile': imageFile,
    'goldenIncome': goldenIncome ? 1 : 0,
  };

  factory LedgerSettings.fromMap(Map<String, Object?> map) {
    final image = map['imageFile'];
    final role = map['goldenIncome'] ?? 1;
    if (role != true && role != false && role != 0 && role != 1) {
      throw const FormatException('小狗分工设置无效');
    }
    if (image != null && image is! String) {
      throw const FormatException('首页图片引用无效');
    }
    return LedgerSettings(
      ledgerName: _string(map, 'ledgerName'),
      tagline: _string(map, 'tagline'),
      themeKey: _string(map, 'themeKey'),
      imageFile: image as String?,
      goldenIncome: role == 1 || role == true,
    );
  }

  LedgerSettings copyWith({
    String? ledgerName,
    String? tagline,
    String? themeKey,
    String? imageFile,
    bool clearImage = false,
    bool? goldenIncome,
  }) => LedgerSettings(
    ledgerName: ledgerName ?? this.ledgerName,
    tagline: tagline ?? this.tagline,
    themeKey: themeKey ?? this.themeKey,
    imageFile: clearImage ? null : (imageFile ?? this.imageFile),
    goldenIncome: goldenIncome ?? this.goldenIncome,
  );
}

String _string(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! String) throw FormatException('字段 $key 缺失或格式不正确');
  return value;
}

String? _optionalString(Map<String, Object?> map, String key) {
  if (map[key] == null) return null;
  return _string(map, key);
}
