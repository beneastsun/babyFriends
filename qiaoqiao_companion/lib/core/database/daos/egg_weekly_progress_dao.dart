import 'package:sqflite/sqflite.dart';
import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';
import 'package:qiaoqiao_companion/shared/models/egg_weekly_progress.dart';

class EggWeeklyProgressDao {
  final AppDatabase _db;

  EggWeeklyProgressDao(this._db);

  /// 插入或更新（按 week_start 唯一键）
  Future<void> upsert(EggWeeklyProgress progress) async {
    final database = await _db.database;
    await database.insert(
      DatabaseConstants.tableEggWeeklyProgress,
      progress.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 按 week_start 查询
  Future<EggWeeklyProgress?> getByWeekStart(String weekStart) async {
    final database = await _db.database;
    final maps = await database.query(
      DatabaseConstants.tableEggWeeklyProgress,
      where: 'week_start = ?',
      whereArgs: [weekStart],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return EggWeeklyProgress.fromMap(maps.first);
  }

  /// 更新风格
  Future<void> updateStyle(String weekStart, EggStyle style) async {
    final database = await _db.database;
    await database.update(
      DatabaseConstants.tableEggWeeklyProgress,
      {
        'egg_style': style.code,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'week_start = ?',
      whereArgs: [weekStart],
    );
  }

  /// 获取最近的周进度
  Future<EggWeeklyProgress?> getLatest() async {
    final database = await _db.database;
    final maps = await database.query(
      DatabaseConstants.tableEggWeeklyProgress,
      orderBy: 'week_start DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return EggWeeklyProgress.fromMap(maps.first);
  }
}
