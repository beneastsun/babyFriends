import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/shared/models/models.dart';

/// 时间段数据访问对象
class TimePeriodDao {
  final AppDatabase _database;

  TimePeriodDao(this._database);

  /// 获取所有时间段
  Future<List<TimePeriod>> getAll() async {
    final db = await _database.database;
    final maps = await db.query('time_periods', orderBy: 'time_start');
    return maps.map(TimePeriod.fromMap).toList();
  }

  /// 获取所有启用的时间段
  Future<List<TimePeriod>> getEnabled() async {
    final db = await _database.database;
    final maps = await db.query(
      'time_periods',
      where: 'enabled = ?',
      whereArgs: [1],
      orderBy: 'time_start',
    );
    return maps.map(TimePeriod.fromMap).toList();
  }

  /// 获取指定模式的时间段
  Future<List<TimePeriod>> getByMode(TimePeriodMode mode) async {
    final db = await _database.database;
    final maps = await db.query(
      'time_periods',
      where: 'mode = ? AND enabled = ?',
      whereArgs: [mode.code, 1],
      orderBy: 'time_start',
    );
    return maps.map(TimePeriod.fromMap).toList();
  }

  /// 根据 ID 获取
  Future<TimePeriod?> getById(int id) async {
    final db = await _database.database;
    final maps = await db.query(
      'time_periods',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return TimePeriod.fromMap(maps.first);
  }

  /// 插入
  Future<int> insert(TimePeriod period) async {
    final db = await _database.database;
    return await db.insert('time_periods', period.toMap());
  }

  /// 更新
  Future<void> update(TimePeriod period) async {
    final db = await _database.database;
    await db.update(
      'time_periods',
      period.toMap(),
      where: 'id = ?',
      whereArgs: [period.id],
    );
  }

  /// 删除
  Future<void> delete(int id) async {
    final db = await _database.database;
    await db.delete(
      'time_periods',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 清空所有
  Future<void> deleteAll() async {
    final db = await _database.database;
    await db.delete('time_periods');
  }

  /// 获取当前模式（从第一个启用的时间段获取）
  Future<TimePeriodMode?> getCurrentMode() async {
    final db = await _database.database;
    final maps = await db.query(
      'time_periods',
      where: 'enabled = ?',
      whereArgs: [1],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return TimePeriodMode.fromCode(maps.first['mode'] as String? ?? 'blocked');
  }

  /// 更新所有时间段的模式
  Future<void> updateAllMode(TimePeriodMode mode) async {
    final db = await _database.database;
    await db.update(
      'time_periods',
      {'mode': mode.code},
    );
  }
}
