import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';

class TaskPenalty {
  final int? id;
  final int taskId;
  final String penaltyDate;
  final int penaltyMinutes;
  final String reason;
  final bool applied;
  final DateTime createdAt;

  TaskPenalty({
    this.id,
    required this.taskId,
    required this.penaltyDate,
    required this.penaltyMinutes,
    required this.reason,
    this.applied = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory TaskPenalty.fromMap(Map<String, dynamic> map) {
    return TaskPenalty(
      id: map['id'] as int?,
      taskId: map['task_id'] as int,
      penaltyDate: map['penalty_date'] as String,
      penaltyMinutes: map['penalty_minutes'] as int,
      reason: map['reason'] as String,
      applied: (map['applied'] as int? ?? 0) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'task_id': taskId,
      'penalty_date': penaltyDate,
      'penalty_minutes': penaltyMinutes,
      'reason': reason,
      'applied': applied ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }
}

class TaskPenaltyDao {
  final AppDatabase _db;

  TaskPenaltyDao(this._db);

  Future<int> insert(TaskPenalty penalty) async {
    final database = await _db.database;
    return await database.insert(
      DatabaseConstants.tableTaskPenalties,
      penalty.toMap(),
    );
  }

  Future<List<TaskPenalty>> getByDate(String date) async {
    final database = await _db.database;
    final maps = await database.query(
      DatabaseConstants.tableTaskPenalties,
      where: 'penalty_date = ?',
      whereArgs: [date],
      orderBy: 'created_at ASC',
    );
    return maps.map(TaskPenalty.fromMap).toList();
  }

  Future<bool> exists(int taskId, String date) async {
    final database = await _db.database;
    final result = await database.query(
      DatabaseConstants.tableTaskPenalties,
      where: 'task_id = ? AND penalty_date = ?',
      whereArgs: [taskId, date],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<int> markAsApplied(int id) async {
    final database = await _db.database;
    return await database.update(
      DatabaseConstants.tableTaskPenalties,
      {'applied': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
