import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';

class TaskCheckin {
  final int? id;
  final int taskId;
  final String checkinDate;
  final String checkinTime;
  final int pointsEarned;
  final bool confirmedByParent;
  final DateTime createdAt;

  TaskCheckin({
    this.id,
    required this.taskId,
    required this.checkinDate,
    required this.checkinTime,
    this.pointsEarned = 0,
    this.confirmedByParent = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory TaskCheckin.fromMap(Map<String, dynamic> map) {
    return TaskCheckin(
      id: map['id'] as int?,
      taskId: map['task_id'] as int,
      checkinDate: map['checkin_date'] as String,
      checkinTime: map['checkin_time'] as String,
      pointsEarned: map['points_earned'] as int? ?? 0,
      confirmedByParent: (map['confirmed_by_parent'] as int? ?? 0) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'task_id': taskId,
      'checkin_date': checkinDate,
      'checkin_time': checkinTime,
      'points_earned': pointsEarned,
      'confirmed_by_parent': confirmedByParent ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }
}

class TaskCheckinDao {
  final AppDatabase _db;

  TaskCheckinDao(this._db);

  Future<int> insert(TaskCheckin checkin) async {
    final database = await _db.database;
    return await database.insert(
      DatabaseConstants.tableTaskCheckins,
      checkin.toMap(),
    );
  }

  Future<List<TaskCheckin>> getByTaskAndDate(int taskId, String date) async {
    final database = await _db.database;
    final maps = await database.query(
      DatabaseConstants.tableTaskCheckins,
      where: 'task_id = ? AND checkin_date = ?',
      whereArgs: [taskId, date],
      orderBy: 'checkin_time ASC',
    );
    return maps.map(TaskCheckin.fromMap).toList();
  }

  Future<int> getCountByTaskAndDate(int taskId, String date) async {
    final database = await _db.database;
    final result = await database.rawQuery(
      'SELECT COUNT(*) as count FROM ${DatabaseConstants.tableTaskCheckins} WHERE task_id = ? AND checkin_date = ?',
      [taskId, date],
    );
    if (result.isNotEmpty) {
      return (result.first['count'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }
}
