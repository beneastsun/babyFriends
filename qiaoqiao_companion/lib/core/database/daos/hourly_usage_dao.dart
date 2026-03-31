import 'package:sqflite/sqflite.dart';
import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';
import 'package:qiaoqiao_companion/shared/models/models.dart';

/// 小时级使用统计 DAO
class HourlyUsageDao {
  final AppDatabase _database;

  HourlyUsageDao(this._database);

  /// 插入或替换记录
  Future<void> upsert(HourlyUsageStats stats) async {
    final db = await _database.database;
    await db.insert(
      DatabaseConstants.tableHourlyUsageStats,
      stats.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 批量插入或替换
  Future<void> upsertBatch(List<HourlyUsageStats> statsList) async {
    final db = await _database.database;
    final batch = db.batch();
    for (final stats in statsList) {
      batch.insert(
        DatabaseConstants.tableHourlyUsageStats,
        stats.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// 获取指定日期的所有小时级统计
  Future<List<HourlyUsageStats>> getByDate(String date) async {
    final db = await _database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseConstants.tableHourlyUsageStats,
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'hour ASC, duration_seconds DESC',
    );
    return maps.map((map) => HourlyUsageStats.fromMap(map)).toList();
  }

  /// 获取指定日期范围的小时级统计
  Future<List<HourlyUsageStats>> getByDateRange(
    String startDate,
    String endDate,
  ) async {
    final db = await _database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseConstants.tableHourlyUsageStats,
      where: 'date >= ? AND date <= ?',
      whereArgs: [startDate, endDate],
      orderBy: 'date ASC, hour ASC',
    );
    return maps.map((map) => HourlyUsageStats.fromMap(map)).toList();
  }

  /// 获取指定日期的每小时总时长（按小时聚合所有应用）
  Future<Map<int, int>> getHourlyTotalsByDate(String date) async {
    final db = await _database.database;
    final result = await db.rawQuery('''
      SELECT hour, SUM(duration_seconds) as total
      FROM ${DatabaseConstants.tableHourlyUsageStats}
      WHERE date = ?
      GROUP BY hour
    ''', [date]);

    return Map.fromEntries(
      result.map((row) => MapEntry(
        row['hour'] as int,
        row['total'] as int? ?? 0,
      )),
    );
  }

  /// 获取指定日期的完整时间线数据
  Future<HourlyTimeline> getTimelineByDate(String date) async {
    final records = await getByDate(date);
    final hourlyTotals = await getHourlyTotalsByDate(date);

    return HourlyTimeline(
      date: date,
      hourlyTotals: hourlyTotals,
      allRecords: records,
    );
  }

  /// 删除指定日期的数据
  Future<int> deleteByDate(String date) async {
    final db = await _database.database;
    return await db.delete(
      DatabaseConstants.tableHourlyUsageStats,
      where: 'date = ?',
      whereArgs: [date],
    );
  }

  /// 删除旧数据（保留最近N天）
  Future<int> deleteOldData({int keepDays = 30}) async {
    final db = await _database.database;
    final cutoffDate = DateTime.now().subtract(Duration(days: keepDays));
    final cutoffStr = DailyStats.formatDate(cutoffDate);

    return await db.delete(
      DatabaseConstants.tableHourlyUsageStats,
      where: 'date < ?',
      whereArgs: [cutoffStr],
    );
  }

  /// 获取指定日期和小时的统计
  Future<List<HourlyUsageStats>> getByDateAndHour(
    String date,
    int hour,
  ) async {
    final db = await _database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseConstants.tableHourlyUsageStats,
      where: 'date = ? AND hour = ?',
      whereArgs: [date, hour],
      orderBy: 'duration_seconds DESC',
    );
    return maps.map((map) => HourlyUsageStats.fromMap(map)).toList();
  }
}
