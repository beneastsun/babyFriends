import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/database/daos/daily_limit_adjustment_dao.dart';
import 'package:qiaoqiao_companion/shared/models/daily_limit_adjustment.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';

void main() {
  late AppDatabase db;
  late DailyLimitAdjustmentDao dao;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    db = AppDatabase.instance;
    await db.database;
    dao = DailyLimitAdjustmentDao(db);
  });

  tearDownAll(() async {
    await db.close();
  });

  setUp(() async {
    final database = await db.database;
    await database.delete(DatabaseConstants.tableDailyLimitAdjustments);
  });

  test('insert and getByDate returns the record', () async {
    final adjustment = DailyLimitAdjustment(
      adjustDate: '2026-07-07',
      adjustmentMinutes: 15,
      source: LimitAdjustmentSource.coupon,
      sourceId: 1,
    );

    await dao.insert(adjustment);
    final result = await dao.getByDate('2026-07-07');

    expect(result.length, 1);
    expect(result.first.adjustmentMinutes, 15);
    expect(result.first.source, LimitAdjustmentSource.coupon);
  });

  test('getTotalMinutesByDate sums positive and negative correctly', () async {
    await dao.insert(DailyLimitAdjustment(
      adjustDate: '2026-07-08',
      adjustmentMinutes: 15,
      source: LimitAdjustmentSource.coupon,
    ));
    await dao.insert(DailyLimitAdjustment(
      adjustDate: '2026-07-08',
      adjustmentMinutes: -10,
      source: LimitAdjustmentSource.taskPenalty,
    ));

    final total = await dao.getTotalMinutesByDate('2026-07-08');

    expect(total, 5);
  });

  test('getTotalMinutesByDate returns 0 when no records', () async {
    final total = await dao.getTotalMinutesByDate('2026-07-09');

    expect(total, 0);
  });

  test('existsBySource returns true when matching record exists', () async {
    await dao.insert(DailyLimitAdjustment(
      adjustDate: '2026-07-07',
      adjustmentMinutes: -10,
      source: LimitAdjustmentSource.taskPenalty,
      sourceId: 5,
    ));

    final exists = await dao.existsBySource(
      '2026-07-07',
      LimitAdjustmentSource.taskPenalty,
      5,
    );

    expect(exists, true);
  });

  test('existsBySource returns false when no match', () async {
    final exists = await dao.existsBySource(
      '2026-07-07',
      LimitAdjustmentSource.coupon,
      999,
    );

    expect(exists, false);
  });
}
