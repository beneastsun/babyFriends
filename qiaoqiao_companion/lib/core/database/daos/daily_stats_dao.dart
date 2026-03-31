import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';
import 'package:qiaoqiao_companion/shared/models/models.dart';

/// 每日统计 DAO
class DailyStatsDao {
  final AppDatabase _database;

  DailyStatsDao(this._database);

  Future<int> insert(DailyStats stats) async {
    final db = await _database.database;
    return await db.insert(
      DatabaseConstants.tableDailyStats,
      stats.toMap(),
    );
  }

  Future<DailyStats?> getByDate(String date) async {
    final db = await _database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseConstants.tableDailyStats,
      where: 'date = ?',
      whereArgs: [date],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return DailyStats.fromMap(maps.first);
  }

  Future<List<DailyStats>> getByDateRange(
    String startDate,
    String endDate,
  ) async {
    final db = await _database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseConstants.tableDailyStats,
      where: 'date >= ? AND date <= ?',
      whereArgs: [startDate, endDate],
      orderBy: 'date ASC',
    );
    return maps.map((map) => DailyStats.fromMap(map)).toList();
  }

  /// 获取或创建当日统计
  Future<DailyStats> getOrCreate(String date) async {
    final existing = await getByDate(date);
    if (existing != null) return existing;

    final newStats = DailyStats.empty(date);
    await insert(newStats);
    return newStats;
  }

  Future<int> update(DailyStats stats) async {
    final db = await _database.database;
    return await db.update(
      DatabaseConstants.tableDailyStats,
      stats.toMap(),
      where: 'date = ?',
      whereArgs: [stats.date],
    );
  }

  /// 更新使用时长（增量）
  Future<void> updateDurations(
    String date, {
    int? totalDelta,
    int? gameDelta,
    int? videoDelta,
    int? studyDelta,
  }) async {
    final stats = await getOrCreate(date);
    final updated = stats.copyWith(
      totalDurationSeconds:
          totalDelta != null ? stats.totalDurationSeconds + totalDelta : null,
      gameDurationSeconds:
          gameDelta != null ? stats.gameDurationSeconds + gameDelta : null,
      videoDurationSeconds:
          videoDelta != null ? stats.videoDurationSeconds + videoDelta : null,
      studyDurationSeconds:
          studyDelta != null ? stats.studyDurationSeconds + studyDelta : null,
    );
    await update(updated);
  }

  /// 设置使用时长（直接设置值，用于从系统同步数据）
  Future<void> setDurations({
    required String date,
    required int totalSeconds,
    required int gameSeconds,
    required int videoSeconds,
    required int studySeconds,
  }) async {
    final stats = await getOrCreate(date);
    final updated = stats.copyWith(
      totalDurationSeconds: totalSeconds,
      gameDurationSeconds: gameSeconds,
      videoDurationSeconds: videoSeconds,
      studyDurationSeconds: studySeconds,
    );
    await update(updated);
  }

  /// 更新获得积分
  Future<void> updatePointsEarned(String date, int delta) async {
    final stats = await getOrCreate(date);
    final updated = stats.copyWith(
      pointsEarned: stats.pointsEarned + delta,
    );
    await update(updated);
  }

  /// 设置规则遵守状态
  Future<void> setRulesFollowed(String date, bool followed) async {
    final stats = await getOrCreate(date);
    final updated = stats.copyWith(rulesFollowed: followed);
    await update(updated);
  }

  /// 获取最近 N 天的统计
  Future<List<DailyStats>> getRecentDays(int days) async {
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days - 1));
    return getByDateRange(
      DailyStats.formatDate(startDate),
      DailyStats.formatDate(now),
    );
  }

  /// 获取本周统计
  Future<List<DailyStats>> getThisWeek() async {
    final now = DateTime.now();
    final weekday = now.weekday;
    final monday = now.subtract(Duration(days: weekday - 1));
    return getByDateRange(
      DailyStats.formatDate(monday),
      DailyStats.formatDate(now),
    );
  }

  Future<int> deleteAll() async {
    final db = await _database.database;
    return await db.delete(DatabaseConstants.tableDailyStats);
  }
}
