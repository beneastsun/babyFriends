import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/database/daos/daos.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';
import 'package:qiaoqiao_companion/shared/models/models.dart';
import 'package:qiaoqiao_companion/shared/models/task_definition.dart';
import 'package:qiaoqiao_companion/core/database/daos/task_checkin_dao.dart';
import 'package:qiaoqiao_companion/core/database/daos/task_penalty_dao.dart';

/// 任务状态
class TaskState {
  final List<TaskDefinition> tasks;
  final bool isLoading;
  final Map<int, int> checkinCounts; // taskId -> count

  const TaskState({
    this.tasks = const [],
    this.isLoading = false,
    this.checkinCounts = const {},
  });

  int get todayCompletedCount =>
      tasks.where((t) => isTaskCompleted(t)).length;
  int get totalTaskCount => tasks.length;
  int get todayPoints => 0; // TODO: calculate from checkins
  double get completionRate =>
      totalTaskCount > 0 ? todayCompletedCount / totalTaskCount : 0.0;

  bool isTaskCompleted(TaskDefinition task) {
    final count = checkinCounts[task.id] ?? 0;
    return count >= task.minDailyCount;
  }

  bool isTaskExceeded(TaskDefinition task) {
    final count = checkinCounts[task.id] ?? 0;
    return count >= task.maxDailyCount;
  }

  int getCheckinCount(int taskId) => checkinCounts[taskId] ?? 0;

  TaskState copyWith({
    List<TaskDefinition>? tasks,
    bool? isLoading,
    Map<int, int>? checkinCounts,
  }) {
    return TaskState(
      tasks: tasks ?? this.tasks,
      isLoading: isLoading ?? this.isLoading,
      checkinCounts: checkinCounts ?? this.checkinCounts,
    );
  }
}

/// 任务状态 Notifier
class TaskNotifier extends StateNotifier<TaskState> {
  final TaskDefinitionDao _taskDefinitionDao;
  final TaskCheckinDao _taskCheckinDao;
  final TaskPenaltyDao _taskPenaltyDao;
  final DailyLimitAdjustmentDao _limitAdjustmentDao;
  final PointsDao? _pointsDao;

  TaskNotifier(
    this._taskDefinitionDao,
    this._taskCheckinDao,
    this._taskPenaltyDao,
    this._limitAdjustmentDao, [
    this._pointsDao,
  ]) : super(const TaskState());

  /// 加载任务数据
  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    final tasks = await _taskDefinitionDao.getEnabled();

    // 加载今日打卡次数
    final today = _formatDate(DateTime.now());
    final checkinCounts = <int, int>{};
    for (final task in tasks) {
      if (task.id != null) {
        final count = await _taskCheckinDao.getCountByTaskAndDate(task.id!, today);
        checkinCounts[task.id!] = count;
      }
    }

    state = state.copyWith(
      tasks: tasks,
      isLoading: false,
      checkinCounts: checkinCounts,
    );
  }

  /// 生成惩罚（app 启动时调用）
  Future<List<TaskPenalty>> generatePenalties() async {
    final yesterday = _formatDate(DateTime.now().subtract(const Duration(days: 1)));
    final today = _formatDate(DateTime.now());
    final tasks = await _taskDefinitionDao.getEnabled();
    final penalties = <TaskPenalty>[];

    for (final task in tasks) {
      if (task.id == null) continue;
      if (task.penaltyMinutes <= 0) continue;

      // 检查是否已有惩罚记录（幂等保护）
      final exists = await _taskPenaltyDao.exists(task.id!, today);
      if (exists) continue;

      // 检查昨天是否完成
      final yesterdayCheckins = await _taskCheckinDao.getByTaskAndDate(task.id!, yesterday);
      if (yesterdayCheckins.length < task.minDailyCount) {
        final penalty = TaskPenalty(
          taskId: task.id!,
          penaltyDate: today,
          penaltyMinutes: task.penaltyMinutes,
          reason: '昨日任务"${task.name}"未完成',
        );
        final penaltyId = await _taskPenaltyDao.insert(penalty);
        penalties.add(penalty);

        // v2 新增：同时写入日限额调整记录（负数 = 扣减）
        final adjustment = DailyLimitAdjustment(
          adjustDate: today,
          adjustmentMinutes: -task.penaltyMinutes,
          source: LimitAdjustmentSource.taskPenalty,
          sourceId: penaltyId,
        );
        await _limitAdjustmentDao.insert(adjustment);

        // 标记惩罚已应用
        await _taskPenaltyDao.markAsApplied(penaltyId);
      }
    }

    return penalties;
  }

  /// 打卡
  Future<void> checkin(TaskDefinition task) async {
    if (task.id == null) return;

    final today = _formatDate(DateTime.now());
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    final checkin = TaskCheckin(
      taskId: task.id!,
      checkinDate: today,
      checkinTime: timeStr,
      pointsEarned: task.basePoints,
    );

    await _taskCheckinDao.insert(checkin);

    // 添加积分
    if (task.basePoints > 0 && _pointsDao != null) {
      await _pointsDao.addPoints(
        task.basePoints,
        '完成任务: ${task.name}',
        category: task.pointsCategory,
      );
    }

    // 刷新状态
    await load();
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

/// 任务状态 Provider
final taskProvider = StateNotifierProvider<TaskNotifier, TaskState>((ref) {
  final db = AppDatabase.instance;
  return TaskNotifier(
    TaskDefinitionDao(db),
    TaskCheckinDao(db),
    TaskPenaltyDao(db),
    DailyLimitAdjustmentDao(db),
    PointsDao(db),
  );
});
