import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';
import 'package:qiaoqiao_companion/shared/models/daily_limit_adjustment.dart';

class DailyLimitAdjustmentDao {
  final AppDatabase _db;

  DailyLimitAdjustmentDao(this._db);

  Future<int> insert(DailyLimitAdjustment adjustment) async {
    final database = await _db.database;
    return await database.insert(
      DatabaseConstants.tableDailyLimitAdjustments,
      adjustment.toMap(),
    );
  }

  Future<List<DailyLimitAdjustment>> getByDate(String date) async {
    final database = await _db.database;
    final maps = await database.query(
      DatabaseConstants.tableDailyLimitAdjustments,
      where: 'adjust_date = ?',
      whereArgs: [date],
      orderBy: 'created_at ASC',
    );
    return maps.map(DailyLimitAdjustment.fromMap).toList();
  }

  Future<int> getTotalMinutesByDate(String date) async {
    final database = await _db.database;
    final result = await database.rawQuery(
      'SELECT COALESCE(SUM(adjustment_minutes), 0) as total FROM ${DatabaseConstants.tableDailyLimitAdjustments} WHERE adjust_date = ?',
      [date],
    );
    if (result.isNotEmpty) {
      return (result.first['total'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }

  Future<bool> existsBySource(
    String date,
    LimitAdjustmentSource source,
    int sourceId,
  ) async {
    final database = await _db.database;
    final result = await database.query(
      DatabaseConstants.tableDailyLimitAdjustments,
      where: 'adjust_date = ? AND source = ? AND source_id = ?',
      whereArgs: [date, source.code, sourceId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<void> deleteByDate(String date) async {
    final database = await _db.database;
    await database.delete(
      DatabaseConstants.tableDailyLimitAdjustments,
      where: 'adjust_date = ?',
      whereArgs: [date],
    );
  }
}
