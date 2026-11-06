import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:puppy_ledger/core/logic.dart';
import 'package:puppy_ledger/core/models.dart';
import 'package:puppy_ledger/core/store.dart';

LedgerEntry entry({
  String id = 'test-entry',
  String date = '2026-11-03',
  String? categoryId,
  int cents = 1234,
  EntryKind kind = EntryKind.expense,
  String note = '',
}) => LedgerEntry(
  id: id,
  date: date,
  categoryId:
      categoryId ?? (kind == EntryKind.income ? 'income-refund' : 'default-1'),
  cents: cents,
  kind: kind,
  note: note,
  createdAt: '2026-11-03T10:00:00.000Z',
  updatedAt: '2026-11-03T10:00:00.000Z',
);

void main() {
  group('Integer money', () {
    test('0.10 + 0.20 is exactly 0.30', () {
      final sum = parseCents('0.10') + parseCents('0.20');
      expect(sum, 30);
      expect(money(sum), '￥0.30');
      expect(parseCents('12.34'), 1234);
      expect(parseCents('12.3'), 1230);
      expect(parseCents('12'), 1200);
      expect(money(-101), '-￥1.01');
      expect(parseCents('9999999999.99'), maxEntryCents);
    });

    test('Invalid values are rejected without rounding', () {
      for (final value in [
        '',
        ' ',
        '0',
        '0.00',
        '-1',
        '1.234',
        'NaN',
        '.1',
        '1.',
        '1e3',
        '1,000',
        '+1',
        '10000000000',
        '999999999999999999999999',
      ]) {
        expect(() => parseCents(value), throwsFormatException, reason: value);
      }
    });
  });

  group('Business dates and calendar periods', () {
    test('Strict date parses and preserves the local calendar date', () {
      expect(dateKey(parseDateKey('2024-02-29')), '2024-02-29');
      expect(dateKey(DateTime(2026, 11, 3, 23, 59)), '2026-11-03');
      for (final value in [
        '2026-02-29',
        '2026-13-01',
        '2026-1-01',
        '2026-04-31',
        '2026-11-03T00:00:00Z',
        '0000-01-01',
      ]) {
        expect(() => parseDateKey(value), throwsFormatException);
      }
    });

    test('Weeks are Monday–Sunday, including the year boundary', () {
      final sunday = periodRange(DateTime(2027, 1, 3), Period.week);
      expect(sunday.start, '2026-12-28');
      expect(sunday.end, '2027-01-03');
      final monday = periodRange(DateTime(2027, 1, 4), Period.week);
      expect(monday.start, '2027-01-04');
      expect(monday.end, '2027-01-10');
    });

    test('Natural month includes leap day; month navigation clamps day', () {
      final february = periodRange(DateTime(2024, 2, 20), Period.month);
      expect(february.start, '2024-02-01');
      expect(february.end, '2024-02-29');
      expect(
        dateKey(movePeriod(DateTime(2026, 1, 31), Period.month, 1)),
        '2026-02-28',
      );
      expect(
        dateKey(movePeriod(DateTime(2026, 12, 31), Period.month, 1)),
        '2027-01-31',
      );
      expect(
        dateKey(movePeriod(DateTime(2027, 1, 1), Period.day, -1)),
        '2026-12-31',
      );
    });

    test('Cross-month refunds affect the refund date and can be negative', () {
      final entries = [
        entry(id: 'purchase', date: '2026-10-31', cents: 10000),
        entry(
          id: 'refund',
          date: '2026-11-01',
          cents: 10000,
          kind: EntryKind.income,
        ),
        entry(id: 'small', date: '2026-11-02', cents: 30),
      ];
      final october = inRange(
        entries,
        periodRange(DateTime(2026, 10), Period.month),
      );
      final novemberRange = periodRange(DateTime(2026, 11), Period.month);
      final november = inRange(entries, novemberRange);
      expect(summarize(october).balance, -10000);
      expect(summarize(november).expense, 30);
      expect(summarize(november).income, 10000);
      expect(summarize(november).balance, 9970);
      expect(
        dailyAmounts(entries, novemberRange, EntryKind.income)['2026-11-01'],
        10000,
      );
      expect(
        dailyAmounts(entries, novemberRange, EntryKind.income)['2026-11-30'],
        0,
      );
      expect(dailyAmounts(entries, novemberRange, EntryKind.income).length, 30);
      expect(categoryTotals(november, EntryKind.expense)['default-1'], 30);
      expect(
        categoryTotals(november, EntryKind.income)['income-refund'],
        10000,
      );
    });
  });

  group('SQLite isolated database', () {
    late Directory temp;
    late String databasePath;
    late LedgerStore store;

    setUp(() async {
      sqfliteFfiInit();
      temp = await Directory.systemTemp.createTemp('puppy-ledger-test-');
      databasePath = p.join(temp.path, 'test.sqlite');
      store = await LedgerStore.open(
        databasePath: databasePath,
        factory: databaseFactoryFfi,
      );
    });

    tearDown(() async {
      await store.close();
      await temp.delete(recursive: true);
    });

    test(
      'First launch is empty with seven expense and three income categories',
      () async {
        expect(await store.entries(), isEmpty);
        expect((await store.categories()).length, 10);
        expect((await store.settings()).ledgerName, '小狗账本');
      },
    );

    test(
      'Create, historical edit, refund and delete update real totals',
      () async {
        await store.saveEntry(entry(id: 'a', cents: 10, date: '2026-10-31'));
        await store.saveEntry(entry(id: 'b', cents: 20, date: '2026-10-31'));
        final october = periodRange(DateTime(2026, 10), Period.month);
        expect(summarize(inRange(await store.entries(), october)).balance, -30);
        await store.saveEntry(entry(id: 'a', cents: 100, date: '2026-11-01'));
        expect((await store.entries()).length, 2);
        expect(summarize(inRange(await store.entries(), october)).balance, -20);
        await store.saveEntry(
          entry(
            id: 'refund',
            cents: 200,
            date: '2026-11-02',
            kind: EntryKind.income,
          ),
        );
        final november = periodRange(DateTime(2026, 11), Period.month);
        expect(
          summarize(inRange(await store.entries(), november)).balance,
          100,
        );
        await store.deleteEntry('a');
        expect(
          summarize(inRange(await store.entries(), november)).balance,
          200,
        );
        expect(
          (await store.entries()).map((row) => row.id),
          unorderedEquals(['b', 'refund']),
        );
      },
    );

    test('Restart preserves entries, categories and settings', () async {
      await store.saveEntry(entry());
      await store.saveCategory(
        const Category(id: 'custom', name: '宠物', active: false),
      );
      await store.saveSettings(
        const LedgerSettings(
          ledgerName: '我的可爱账本',
          tagline: '每天认真生活',
          themeKey: 'sage',
          imageFile: 'puppy_test.png',
        ),
      );
      await store.close();
      store = await LedgerStore.open(
        databasePath: databasePath,
        factory: databaseFactoryFfi,
      );
      expect((await store.entries()).single.toMap(), entry().toMap());
      expect((await store.categories()).last.name, '宠物');
      expect((await store.categories()).last.active, isFalse);
      expect((await store.settings()).imageFile, 'puppy_test.png');
      expect((await store.settings()).themeKey, 'sage');
    });

    test(
      'Deactivation preserves references; invalid and duplicate categories rejected',
      () async {
        await store.saveEntry(entry());
        await store.saveCategory(
          const Category(id: 'default-1', name: '吃饭', active: false),
        );
        expect((await store.entries()).single.categoryId, 'default-1');
        await store.saveEntry(entry(note: '停用后仍可编辑原记录'));
        await expectLater(
          store.saveEntry(entry(id: 'new')),
          throwsFormatException,
        );
        await expectLater(
          store.saveEntry(entry(categoryId: 'missing')),
          throwsFormatException,
        );
        await expectLater(
          store.saveCategory(
            const Category(id: 'duplicate', name: '吃饭', active: true),
          ),
          throwsFormatException,
        );
        await expectLater(
          store.saveCategory(
            const Category(id: 'blank', name: '  ', active: true),
          ),
          throwsFormatException,
        );
      },
    );

    test(
      'Snapshot pre-validation leaves the original ledger untouched',
      () async {
        await store.saveEntry(entry());
        await expectLater(
          store.replaceAll(
            entries: [entry(categoryId: 'missing')],
            categories: await store.categories(),
            settings: const LedgerSettings(ledgerName: '不应保存'),
          ),
          throwsFormatException,
        );
        expect((await store.entries()).single.id, 'test-entry');
        expect((await store.settings()).ledgerName, '小狗账本');
      },
    );

    test(
      'SQLite failure after deletes rolls back the entire restore',
      () async {
        await store.saveEntry(entry());
        final inspector = await databaseFactoryFfi.openDatabase(
          databasePath,
          options: OpenDatabaseOptions(singleInstance: false),
        );
        await inspector.execute('''
        CREATE TRIGGER reject_test_restore BEFORE INSERT ON entries
        WHEN NEW.note = 'force-error'
        BEGIN SELECT RAISE(ABORT, 'injected write failure'); END
      ''');
        await inspector.close();
        await expectLater(
          store.replaceAll(
            entries: [
              entry(id: 'new', categoryId: 'replacement', note: 'force-error'),
            ],
            categories: [
              const Category(id: 'replacement', name: '新分类', active: true),
            ],
            settings: const LedgerSettings(ledgerName: '不应保存'),
          ),
          throwsA(isA<DatabaseException>()),
        );
        expect((await store.entries()).single.toMap(), entry().toMap());
        expect((await store.categories()).length, 10);
        expect((await store.settings()).ledgerName, '小狗账本');
      },
    );

    test(
      'Valid full restore replaces all data and settings atomically',
      () async {
        await store.saveEntry(entry());
        await store.replaceAll(
          entries: [
            entry(
              id: 'restored',
              categoryId: 'new-category',
              kind: EntryKind.income,
              cents: 99,
            ),
          ],
          categories: [
            const Category(
              id: 'new-category',
              name: '新分类',
              active: false,
              kind: EntryKind.income,
            ),
          ],
          settings: const LedgerSettings(ledgerName: '恢复账本', themeKey: 'lemon'),
        );
        expect((await store.entries()).single.id, 'restored');
        expect(summarize(await store.entries()).balance, 99);
        expect((await store.categories()).single.active, isFalse);
        expect((await store.settings()).ledgerName, '恢复账本');
      },
    );
  });
}
