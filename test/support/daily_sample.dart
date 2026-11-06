import 'package:puppy_ledger/core/models.dart';
import 'package:puppy_ledger/core/store.dart';

final exampleDate = DateTime(2026, 11, 6);

/// Only for a disposable test/render database; these are never app defaults.
Future<void> seedDailyExample(LedgerStore store) async {
  Future<void> add(
    String id,
    String date,
    int cents,
    String category,
    String note,
    int hour, {
    EntryKind kind = EntryKind.expense,
    int? minute,
  }) async {
    final at = '${date}T${hour.toString().padLeft(2, '0')}:00:00Z';
    await store.saveEntry(
      LedgerEntry(
        id: id,
        date: date,
        cents: cents,
        categoryId: category,
        note: note,
        kind: kind,
        occurredMinute: minute,
        createdAt: at,
        updatedAt: at,
      ),
    );
  }

  await add('october', '2026-10-31', 900, 'default-1', '上月午餐', 12);
  for (final (day, cents) in [(1, 1800), (2, 4200), (4, 2400), (5, 5600)]) {
    await add('earlier-$day', '2026-11-0$day', cents, 'default-1', '午餐', 12);
  }
  await add(
    'metro',
    '2026-11-06',
    600,
    'default-2',
    '地铁回家',
    20,
    minute: 12 * 60 + 50,
  );
  await add(
    'lunch',
    '2026-11-06',
    2800,
    'default-1',
    '食堂午餐',
    20,
    minute: 12 * 60 + 35,
  );
  await add(
    'refund',
    '2026-11-06',
    10000,
    'income-refund',
    '耳机退款',
    15,
    kind: EntryKind.income,
    minute: 19 * 60 + 10,
  );
}
