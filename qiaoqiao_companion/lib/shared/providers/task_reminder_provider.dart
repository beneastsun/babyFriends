import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/database/daos/daos.dart';
import 'package:qiaoqiao_companion/shared/models/task_definition.dart';
import 'package:qiaoqiao_companion/core/services/notification_service.dart';

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
    final now = DateTime.now();
    final notificationService = NotificationService();

    for (final task in tasks) {
      if (task.reminderTime == null || task.id == null) continue;

      final today = _formatDate(now);
      final checkins = await _checkCheckinCount(task.id!, today);
      if (checkins >= task.minDailyCount) continue; // 已完成，不提醒

      // 解析提醒时间
      final timeParts = task.reminderTime!.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      var scheduledTime = DateTime(now.year, now.month, now.day, hour, minute);

      // 如果时间已过，按 repeatInterval 延迟到下一个有效时间
      if (scheduledTime.isBefore(now) && task.reminderRepeatInterval > 0) {
        while (scheduledTime.isBefore(now)) {
          scheduledTime = scheduledTime.add(Duration(minutes: task.reminderRepeatInterval));
        }
      } else if (scheduledTime.isBefore(now)) {
        continue; // 时间已过且不重复，跳过
      }

      // 通过 NotificationService 调度实际通知
      await notificationService.scheduleTaskReminder(
        taskId: task.id!,
        taskName: task.name,
        emoji: task.emoji,
        scheduledTime: scheduledTime,
        repeatIntervalMinutes: task.reminderRepeatInterval,
      );
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
    await NotificationService().cancelReminder(taskId);
    final pending = state.pendingReminders.where((t) => t.id != taskId).toList();
    state = state.copyWith(pendingReminders: pending);
  }
}

final taskReminderProvider =
    StateNotifierProvider<TaskReminderNotifier, TaskReminderState>((ref) {
  final db = AppDatabase.instance;
  return TaskReminderNotifier(TaskDefinitionDao(db), db);
});
