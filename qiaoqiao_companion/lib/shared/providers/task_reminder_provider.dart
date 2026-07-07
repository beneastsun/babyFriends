import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/database/daos/daos.dart';
import 'package:qiaoqiao_companion/shared/models/task_definition.dart';

class TaskReminderState {
  final List<TaskDefinition> pendingReminders;
  final bool isActive;

  const TaskReminderState({
    this.pendingReminders = const [],
    this.isActive = false,
  });

  TaskReminderState copyWith({
    List<TaskDefinition>? pendingReminders,
    bool? isActive,
  }) {
    return TaskReminderState(
      pendingReminders: pendingReminders ?? this.pendingReminders,
      isActive: isActive ?? this.isActive,
    );
  }
}

class TaskReminderNotifier extends StateNotifier<TaskReminderState> {
  final TaskDefinitionDao _taskDefinitionDao;
  final AppDatabase _db;

  TaskReminderNotifier(this._taskDefinitionDao, this._db)
      : super(const TaskReminderState());

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// 注册当日所有任务的提醒
  /// 返回注册的提醒数量
  Future<int> registerDailyReminders() async {
    final tasks = await _taskDefinitionDao.getEnabled();
    int count = 0;

    for (final task in tasks) {
      if (task.reminderTime == null) continue;

      // 检查今天是否已打卡完成
      final today = _formatDate(DateTime.now());
      if (task.id == null) continue;

      final checkins = await _checkCheckinCount(task.id!, today);
      if (checkins >= task.minDailyCount) continue; // 已完成，不提醒

      // 注册提醒（实际通知调度在 UI 层通过 flutter_local_notifications 执行）
      count++;
    }

    state = state.copyWith(pendingReminders: await getPendingReminders(), isActive: true);
    return count;
  }

  /// 获取待提醒的任务列表（有 reminderTime 且今天未完成）
  Future<List<TaskDefinition>> getPendingReminders() async {
    final tasks = await _taskDefinitionDao.getEnabled();
    final today = _formatDate(DateTime.now());
    final pending = <TaskDefinition>[];

    for (final task in tasks) {
      if (task.reminderTime == null || task.id == null) continue;
      final checkins = await _checkCheckinCount(task.id!, today);
      if (checkins < task.minDailyCount) {
        pending.add(task);
      }
    }

    return pending;
  }

  Future<int> _checkCheckinCount(int taskId, String date) async {
    final database = await _db.database;
    final result = await database.query(
      'task_checkins',
      where: 'task_id = ? AND checkin_date = ?',
      whereArgs: [taskId, date],
    );
    return result.length;
  }

  /// 取消某个任务的当日提醒（打卡完成后调用）
  Future<void> cancelReminderForTask(int taskId) async {
    final pending = state.pendingReminders.where((t) => t.id != taskId).toList();
    state = state.copyWith(pendingReminders: pending);
  }
}

final taskReminderProvider =
    StateNotifierProvider<TaskReminderNotifier, TaskReminderState>((ref) {
  final db = AppDatabase.instance;
  return TaskReminderNotifier(TaskDefinitionDao(db), db);
});
