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

/// 每日任务打卡汇总
class DailyTaskCheckinSummary {
  final String date;
  final int totalTasks;
  final int completedTasks;
  final int totalCheckins;
  final int pointsEarned;

  DailyTaskCheckinSummary({
    required this.date,
    required this.totalTasks,
    required this.completedTasks,
    required this.totalCheckins,
    required this.pointsEarned,
  });

  double get completionRate => totalTasks > 0 ? completedTasks / totalTasks : 0.0;
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

  /// 获取某个日期范围内所有打卡记录
  Future<List<TaskCheckin>> getByDateRange(String startDate, String endDate) async {
    final database = await _db.database;
    final maps = await database.query(
      DatabaseConstants.tableTaskCheckins,
      where: 'checkin_date >= ? AND checkin_date <= ?',
      whereArgs: [startDate, endDate],
      orderBy: 'checkin_date DESC, checkin_time DESC',
    );
    return maps.map(TaskCheckin.fromMap).toList();
  }

  /// 获取某天所有打卡记录
  Future<List<TaskCheckin>> getByDate(String date) async {
    final database = await _db.database;
    final maps = await database.query(
      DatabaseConstants.tableTaskCheckins,
      where: 'checkin_date = ?',
      whereArgs: [date],
      orderBy: 'checkin_time ASC',
    );
    return maps.map(TaskCheckin.fromMap).toList();
  }

  /// 获取某个任务在日期范围内的所有打卡记录
  Future<List<TaskCheckin>> getByTaskAndDateRange(int taskId, String startDate, String endDate) async {
    final database = await _db.database;
    final maps = await database.query(
      DatabaseConstants.tableTaskCheckins,
      where: 'task_id = ? AND checkin_date >= ? AND checkin_date <= ?',
      whereArgs: [taskId, startDate, endDate],
      orderBy: 'checkin_date DESC, checkin_time DESC',
    );
    return maps.map(TaskCheckin.fromMap).toList();
  }

  /// 获取某个任务每天的打卡次数统计
  Future<Map<String, int>> getDailyCountsByTask(int taskId, String startDate, String endDate) async {
    final database = await _db.database;
    final result = await database.rawQuery(
      '''SELECT checkin_date, COUNT(*) as count 
         FROM ${DatabaseConstants.tableTaskCheckins} 
         WHERE task_id = ? AND checkin_date >= ? AND checkin_date <= ?
         GROUP BY checkin_date
         ORDER BY checkin_date ASC''',
      [taskId, startDate, endDate],
    );
    final Map<String, int> counts = {};
    for (final row in result) {
      counts[row['checkin_date'] as String] = (row['count'] as num?)?.toInt() ?? 0;
    }
    return counts;
  }

  /// 获取每日打卡汇总
  /// [taskId] 为null时统计所有任务，指定时只统计该任务
  Future<List<DailyTaskCheckinSummary>> getDailySummaries(
    String startDate,
    String endDate,
    List<int> enabledTaskIds,
    Map<int, int> taskMinCounts, {
    int? taskId,
  }) async {
    final database = await _db.database;

    // 如果指定了taskId，只统计该任务
    final effectiveTaskIds = taskId != null ? [taskId] : enabledTaskIds;
    final effectiveMinCounts = taskId != null
        ? {taskId: taskMinCounts[taskId] ?? 1}
        : taskMinCounts;
    
    // 先获取该日期范围内所有打卡记录的统计
    final String whereClause = taskId != null
        ? 'checkin_date >= ? AND checkin_date <= ? AND task_id = ?'
        : 'checkin_date >= ? AND checkin_date <= ?';
    final List<Object?> whereArgs = taskId != null
        ? [startDate, endDate, taskId]
        : [startDate, endDate];

    final result = await database.rawQuery(
      '''SELECT checkin_date, COUNT(*) as total_checkins, SUM(points_earned) as total_points
         FROM ${DatabaseConstants.tableTaskCheckins} 
         WHERE $whereClause
         GROUP BY checkin_date
         ORDER BY checkin_date ASC''',
      whereArgs,
    );

    // 获取每个任务每天的打卡次数
    final perTaskResult = await database.rawQuery(
      '''SELECT checkin_date, task_id, COUNT(*) as cnt
         FROM ${DatabaseConstants.tableTaskCheckins} 
         WHERE $whereClause
         GROUP BY checkin_date, task_id''',
      whereArgs,
    );

    // 整理数据
    final Map<String, Map<int, int>> perDateTaskCounts = {};
    for (final row in perTaskResult) {
      final date = row['checkin_date'] as String;
      final tid = row['task_id'] as int;
      final cnt = (row['cnt'] as num?)?.toInt() ?? 0;
      perDateTaskCounts.putIfAbsent(date, () => {})[tid] = cnt;
    }

    // 生成日期范围内的每一天
    final summaries = <DailyTaskCheckinSummary>[];
    final start = DateTime.parse(startDate);
    final end = DateTime.parse(endDate);
    
    for (DateTime date = start;
         !date.isAfter(end);
         date = date.add(const Duration(days: 1))) {
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      
      final taskCounts = perDateTaskCounts[dateStr] ?? {};
      int completedTasks = 0;
      for (final tid in effectiveTaskIds) {
        final count = taskCounts[tid] ?? 0;
        final minCount = effectiveMinCounts[tid] ?? 1;
        if (count >= minCount) {
          completedTasks++;
        }
      }

      // 查找当天的积分和打卡数
      final dayStats = result.firstWhere(
        (r) => r['checkin_date'] == dateStr,
        orElse: () => {'total_checkins': 0, 'total_points': 0},
      );

      summaries.add(DailyTaskCheckinSummary(
        date: dateStr,
        totalTasks: effectiveTaskIds.length,
        completedTasks: completedTasks,
        totalCheckins: (dayStats['total_checkins'] as num?)?.toInt() ?? 0,
        pointsEarned: (dayStats['total_points'] as num?)?.toInt() ?? 0,
      ));
    }

    return summaries;
  }

  /// 获取最近一次打卡时间
  Future<TaskCheckin?> getLatestByTask(int taskId) async {
    final database = await _db.database;
    final maps = await database.query(
      DatabaseConstants.tableTaskCheckins,
      where: 'task_id = ?',
      whereArgs: [taskId],
      orderBy: 'checkin_date DESC, checkin_time DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return TaskCheckin.fromMap(maps.first);
  }
}
