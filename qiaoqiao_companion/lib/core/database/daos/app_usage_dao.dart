import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';
import 'package:qiaoqiao_companion/shared/models/models.dart';

/// 应用使用记录 DAO
class AppUsageDao {
  final AppDatabase _database;

  AppUsageDao(this._database);

  Future<int> insert(AppUsageRecord record) async {
    final db = await _database.database;
    return await db.insert(
      DatabaseConstants.tableAppUsageRecords,
      record.toMap(),
    );
  }

  Future<List<AppUsageRecord>> getByDate(String date) async {
    final db = await _database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseConstants.tableAppUsageRecords,
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'start_time DESC',
    );
    return maps.map((map) => AppUsageRecord.fromMap(map)).toList();
  }

  Future<List<AppUsageRecord>> getByDateRange(
    String startDate,
    String endDate,
  ) async {
    final db = await _database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseConstants.tableAppUsageRecords,
      where: 'date >= ? AND date <= ?',
      whereArgs: [startDate, endDate],
      orderBy: 'date DESC, start_time DESC',
    );
    return maps.map((map) => AppUsageRecord.fromMap(map)).toList();
  }

  Future<List<AppUsageRecord>> getByPackageAndDate(
    String packageName,
    String date,
  ) async {
    final db = await _database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseConstants.tableAppUsageRecords,
      where: 'package_name = ? AND date = ?',
      whereArgs: [packageName, date],
      orderBy: 'start_time DESC',
    );
    return maps.map((map) => AppUsageRecord.fromMap(map)).toList();
  }

  Future<int> getTotalDurationByCategoryAndDate(
    AppCategory category,
    String date,
  ) async {
    final db = await _database.database;
    final result = await db.rawQuery(
      'SELECT SUM(duration) as total FROM ${DatabaseConstants.tableAppUsageRecords} '
      'WHERE category = ? AND date = ?',
      [category.code, date],
    );
    return (result.first['total'] as int?) ?? 0;
  }

  Future<int> getTotalDurationByDate(String date) async {
    final db = await _database.database;
    final result = await db.rawQuery(
      'SELECT SUM(duration) as total FROM ${DatabaseConstants.tableAppUsageRecords} '
      'WHERE date = ?',
      [date],
    );
    return (result.first['total'] as int?) ?? 0;
  }

  Future<int> update(AppUsageRecord record) async {
    final db = await _database.database;
    return await db.update(
      DatabaseConstants.tableAppUsageRecords,
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _database.database;
    return await db.delete(
      DatabaseConstants.tableAppUsageRecords,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteByDate(String date) async {
    final db = await _database.database;
    return await db.delete(
      DatabaseConstants.tableAppUsageRecords,
      where: 'date = ?',
      whereArgs: [date],
    );
  }

  /// 获取指定日期的应用使用汇总（按包名聚合）
  Future<List<Map<String, dynamic>>> getAggregatedByDate(String date) async {
    final db = await _database.database;
    return await db.rawQuery('''
      SELECT
        package_name,
        app_name,
        category,
        SUM(duration) as total_duration
      FROM ${DatabaseConstants.tableAppUsageRecords}
      WHERE date = ?
      GROUP BY package_name
      ORDER BY total_duration DESC
    ''', [date]);
  }

  /// 获取指定日期限定包名列表的总使用时长（秒）
  Future<int> getTotalDurationByPackageNamesAndDate(
    Set<String> packageNames,
    String date,
  ) async {
    if (packageNames.isEmpty) {
      return 0;
    }
    final db = await _database.database;
    final placeholders = List.filled(packageNames.length, '?').join(',');
    final result = await db.rawQuery(
      'SELECT SUM(duration) as total FROM ${DatabaseConstants.tableAppUsageRecords} '
      'WHERE date = ? AND package_name IN ($placeholders)',
      [date, ...packageNames.toList()],
    );
    return (result.first['total'] as int?) ?? 0;
  }

  /// 获取指定日期限定包名列表的分类使用时长（秒）
  Future<int> getTotalDurationByPackageNamesAndCategoryAndDate(
    Set<String> packageNames,
    AppCategory category,
    String date,
  ) async {
    if (packageNames.isEmpty) {
      return 0;
    }
    final db = await _database.database;
    final placeholders = List.filled(packageNames.length, '?').join(',');
    final result = await db.rawQuery(
      'SELECT SUM(duration) as total FROM ${DatabaseConstants.tableAppUsageRecords} '
      'WHERE date = ? AND category = ? AND package_name IN ($placeholders)',
      [date, category.code, ...packageNames.toList()],
    );
    return (result.first['total'] as int?) ?? 0;
  }
}
