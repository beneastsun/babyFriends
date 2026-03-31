import 'package:sqflite/sqflite.dart';
import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';
import 'package:qiaoqiao_companion/shared/models/achievement.dart';

/// 成就 DAO
class AchievementDao {
  final AppDatabase _database;

  AchievementDao(this._database);

  Future<int> insert(UserAchievement achievement) async {
    final db = await _database.database;
    return await db.insert(
      'user_achievements',
      achievement.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<UserAchievement>> getAll() async {
    final db = await _database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'user_achievements',
      orderBy: 'unlocked_at DESC',
    );
    return maps.map((map) => UserAchievement.fromMap(map)).toList();
  }

  Future<UserAchievement?> getById(String achievementId) async {
    final db = await _database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'user_achievements',
      where: 'achievement_id = ?',
      whereArgs: [achievementId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return UserAchievement.fromMap(maps.first);
  }

  Future<int> update(UserAchievement achievement) async {
    final db = await _database.database;
    return await db.update(
      'user_achievements',
      achievement.toMap(),
      where: 'achievement_id = ?',
      whereArgs: [achievement.achievementId],
    );
  }

  Future<int> updateProgress(String achievementId, int progress, bool isUnlocked) async {
    final db = await _database.database;
    return await db.update(
      'user_achievements',
      {
        'progress': progress,
        'is_unlocked': isUnlocked ? 1 : 0,
        'unlocked_at': isUnlocked ? DateTime.now().millisecondsSinceEpoch : null,
      },
      where: 'achievement_id = ?',
      whereArgs: [achievementId],
    );
  }

  Future<List<UserAchievement>> getUnlocked() async {
    final db = await _database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'user_achievements',
      where: 'is_unlocked = ?',
      whereArgs: [1],
      orderBy: 'unlocked_at DESC',
    );
    return maps.map((map) => UserAchievement.fromMap(map)).toList();
  }

  Future<int> countUnlocked() async {
    final db = await _database.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM user_achievements WHERE is_unlocked = 1',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> deleteAll() async {
    final db = await _database.database;
    return await db.delete('user_achievements');
  }
}
