import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/shared/models/models.dart';

/// 被监控应用数据访问对象
class MonitoredAppDao {
  final AppDatabase _database;

  MonitoredAppDao(this._database);

  /// 获取所有被监控的 app
  Future<List<MonitoredApp>> getAll() async {
    final db = await _database.database;
    final maps = await db.query('monitored_apps', orderBy: 'app_name');
    return maps.map(MonitoredApp.fromMap).toList();
  }

  /// 获取所有启用的被监控 app
  Future<List<MonitoredApp>> getEnabled() async {
    final db = await _database.database;
    final maps = await db.query(
      'monitored_apps',
      where: 'enabled = ?',
      whereArgs: [1],
      orderBy: 'app_name',
    );
    return maps.map(MonitoredApp.fromMap).toList();
  }

  /// 根据 package name 获取
  Future<MonitoredApp?> getByPackageName(String packageName) async {
    final db = await _database.database;
    final maps = await db.query(
      'monitored_apps',
      where: 'package_name = ?',
      whereArgs: [packageName],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return MonitoredApp.fromMap(maps.first);
  }

  /// 检查 package name 是否被监控
  Future<bool> isMonitored(String packageName) async {
    final db = await _database.database;
    final maps = await db.query(
      'monitored_apps',
      where: 'package_name = ? AND enabled = ?',
      whereArgs: [packageName, 1],
      limit: 1,
    );
    return maps.isNotEmpty;
  }

  /// 插入
  Future<void> insert(MonitoredApp app) async {
    final db = await _database.database;
    await db.insert('monitored_apps', app.toMap());
  }

  /// 批量插入
  Future<void> insertAll(List<MonitoredApp> apps) async {
    final db = await _database.database;
    final batch = db.batch();
    for (final app in apps) {
      batch.insert('monitored_apps', app.toMap());
    }
    await batch.commit(noResult: true);
  }

  /// 更新
  Future<void> update(MonitoredApp app) async {
    final db = await _database.database;
    await db.update(
      'monitored_apps',
      app.toMap(),
      where: 'package_name = ?',
      whereArgs: [app.packageName],
    );
  }

  /// 删除
  Future<void> delete(String packageName) async {
    final db = await _database.database;
    await db.delete(
      'monitored_apps',
      where: 'package_name = ?',
      whereArgs: [packageName],
    );
  }

  /// 清空所有
  Future<void> deleteAll() async {
    final db = await _database.database;
    await db.delete('monitored_apps');
  }
}
