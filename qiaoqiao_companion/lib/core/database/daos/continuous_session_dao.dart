import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/shared/models/models.dart';

/// 连续使用会话数据访问对象
class ContinuousSessionDao {
  final AppDatabase _database;

  ContinuousSessionDao(this._database);

  /// 获取指定日期的活跃会话
  Future<ContinuousSession?> getActiveSession(String date) async {
    final db = await _database.database;
    final maps = await db.query(
      'continuous_usage_sessions',
      where: 'session_date = ? AND is_active = ?',
      whereArgs: [date, 1],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return ContinuousSession.fromMap(maps.first);
  }

  /// 获取当前正在休息的会话
  Future<ContinuousSession?> getRestingSession(String date) async {
    final db = await _database.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final maps = await db.query(
      'continuous_usage_sessions',
      where: 'session_date = ? AND rest_end_time > ?',
      whereArgs: [date, now],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return ContinuousSession.fromMap(maps.first);
  }

  /// 插入新会话
  Future<int> insert(ContinuousSession session) async {
    final db = await _database.database;
    return await db.insert('continuous_usage_sessions', session.toMap());
  }

  /// 更新会话
  Future<void> update(ContinuousSession session) async {
    final db = await _database.database;
    await db.update(
      'continuous_usage_sessions',
      session.toMap(),
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }

  /// 停用会话
  Future<void> deactivate(int id) async {
    final db = await _database.database;
    await db.update(
      'continuous_usage_sessions',
      {'is_active': 0, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 清除指定日期之前的旧会话
  Future<void> cleanupOldSessions(String beforeDate) async {
    final db = await _database.database;
    await db.delete(
      'continuous_usage_sessions',
      where: 'session_date < ?',
      whereArgs: [beforeDate],
    );
  }

  /// 删除所有会话
  Future<void> deleteAll() async {
    final db = await _database.database;
    await db.delete('continuous_usage_sessions');
  }
}
