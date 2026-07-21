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
  final Map<int, int> checkinCounts; // taskId -> today's count
  final Map<int, List<TaskCheckin>> todayCheckins; // taskId -> today's checkin records
  final String? errorMessage;

  const TaskState({
    this.tasks = const [],
    this.isLoading = false,
    this.checkinCounts = const {},
    this.todayCheckins = const {},
    this.errorMessage,
  });

  int get todayCompletedCount =>
      tasks.where((t) => isTaskCompleted(t)).length;
  int get totalTaskCount => tasks.length;
  int get todayPoints {
    int total = 0;
    for (final entry in checkinCounts.entries) {
      TaskDefinition? task;
      for (final t in tasks) {
        if (t.id == entry.key) {
          task = t;
          break;
        }
      }
      if (task != null) {
        total += task.basePoints * entry.value;
      }
    }
    return total;
  }

  double get completionRate =>
      totalTaskCount > 0 ? todayCompletedCount / totalTaskCount : 0.0;

  /// 任务是否已完成（达到最低打卡次数）
  bool isTaskCompleted(TaskDefinition task) {
    final count = checkinCounts[task.id] ?? 0;
    return count >= task.minDailyCount;
  }

  /// 任务是否已达到今日最大打卡次数
  bool isTaskExceeded(TaskDefinition task) {
    final count = checkinCounts[task.id] ?? 0;
    return count >= task.maxDailyCount;
  }

  /// 还可打卡次数
  int getRemainingCheckins(TaskDefinition task) {
    final count = checkinCounts[task.id] ?? 0;
    return (task.maxDailyCount - count).clamp(0, task.maxDailyCount);
  }

  /// 获取今日打卡次数
  int getCheckinCount(int taskId) => checkinCounts[taskId] ?? 0;

  /// 获取今日打卡记录列表
  List<TaskCheckin> getTodayCheckins(int taskId) => todayCheckins[taskId] ?? [];

  TaskState copyWith({
    List<TaskDefinition>? tasks,
    bool? isLoading,
    Map<int, int>? checkinCounts,
    Map<int, List<TaskCheckin>>? todayCheckins,
    String? errorMessage,
  }) {
    return TaskState(
      tasks: tasks ?? this.tasks,
      isLoading: isLoading ?? this.isLoading,
      checkinCounts: checkinCounts ?? this.checkinCounts,
      todayCheckins: todayCheckins ?? this.todayCheckins,
      errorMessage: errorMessage,
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

  /// 格式化日期
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// 加载任务数据
  Future<void> load() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final tasks = await _taskDefinitionDao.getEnabled();

      // 加载今日打卡次数和记录
      final today = _formatDate(DateTime.now());
      final checkinCounts = <int, int>{};
      final todayCheckins = <int, List<TaskCheckin>>{};
      
      for (final task in tasks) {
        if (task.id != null) {
          final count = await _taskCheckinDao.getCountByTaskAndDate(task.id!, today);
          checkinCounts[task.id!] = count;
          final records = await _taskCheckinDao.getByTaskAndDate(task.id!, today);
          todayCheckins[task.id!] = records;
        }
      }

      state = state.copyWith(
        tasks: tasks,
        isLoading: false,
        checkinCounts: checkinCounts,
        todayCheckins: todayCheckins,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '加载任务失败: $e',
      );
    }
  }

  /// 刷新任务（供外部调用，如家长端添加/编辑/删除任务后）
  Future<void> refresh() async {
    await load();
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

  /// 执行打卡
  /// 返回打卡结果信息
  Future<CheckinResult> checkin(TaskDefinition task) async {
    if (task.id == null) {
      return CheckinResult(success: false, message: '任务无效');
    }

    // 检查是否已达上限
    final currentCount = state.checkinCounts[task.id] ?? 0;
    if (currentCount >= task.maxDailyCount) {
      return CheckinResult(
        success: false,
        message: '今日已达最大打卡次数 (${task.maxDailyCount}次)',
      );
    }

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

    // 重新加载状态以刷新UI
    await load();

    final newCount = currentCount + 1;
    final isCompleted = newCount >= task.minDailyCount;
    final remaining = task.maxDailyCount - newCount;

    return CheckinResult(
      success: true,
      message: isCompleted 
          ? (remaining > 0 ? '打卡成功！任务已完成，还可打卡$remaining次' : '打卡成功！任务已全部完成')
          : '打卡成功！还需打卡${task.minDailyCount - newCount}次完成任务',
      pointsEarned: task.basePoints,
      checkinTime: timeStr,
      remainingCheckins: remaining,
      isTaskCompleted: isCompleted,
    );
  }

  /// 获取历史打卡记录
  Future<List<TaskCheckin>> getCheckinHistory({
    int? taskId,
    int days = 7,
  }) async {
    final endDate = DateTime.now();
    final startDate = endDate.subtract(Duration(days: days - 1));
    final startStr = _formatDate(startDate);
    final endStr = _formatDate(endDate);

    if (taskId != null) {
      return _taskCheckinDao.getByTaskAndDateRange(taskId, startStr, endStr);
    }
    return _taskCheckinDao.getByDateRange(startStr, endStr);
  }

  /// 获取某天的打卡记录
  Future<List<TaskCheckin>> getCheckinsByDate(String date, {int? taskId}) async {
    final allCheckins = await _taskCheckinDao.getByDate(date);
    if (taskId != null) {
      return allCheckins.where((c) => c.taskId == taskId).toList();
    }
    return allCheckins;
  }

  /// 获取每日打卡汇总
  Future<List<DailyTaskCheckinSummary>> getDailySummaries({
    int days = 7,
    int? taskId,
  }) async {
    final endDate = DateTime.now();
    final startDate = endDate.subtract(Duration(days: days - 1));
    final startStr = _formatDate(startDate);
    final endStr = _formatDate(endDate);

    final tasks = await _taskDefinitionDao.getEnabled();
    final enabledTaskIds = tasks.where((t) => t.id != null).map((t) => t.id!).toList();
    final taskMinCounts = {for (var t in tasks) if (t.id != null) t.id!: t.minDailyCount};

    return _taskCheckinDao.getDailySummaries(
      startStr,
      endStr,
      enabledTaskIds,
      taskMinCounts,
      taskId: taskId,
    );
  }

  /// 获取某个任务的每日打卡统计
  Future<Map<String, int>> getTaskDailyCounts(int taskId, {int days = 7}) async {
    final endDate = DateTime.now();
    final startDate = endDate.subtract(Duration(days: days - 1));
    final startStr = _formatDate(startDate);
    final endStr = _formatDate(endDate);
    return _taskCheckinDao.getDailyCountsByTask(taskId, startStr, endStr);
  }

  /// 获取任务定义
  Future<TaskDefinition?> getTaskById(int taskId) async {
    return _taskDefinitionDao.getById(taskId);
  }
}

/// 打卡结果
class CheckinResult {
  final bool success;
  final String message;
  final int pointsEarned;
  final String checkinTime;
  final int remainingCheckins;
  final bool isTaskCompleted;

  CheckinResult({
    required this.success,
    required this.message,
    this.pointsEarned = 0,
    this.checkinTime = '',
    this.remainingCheckins = 0,
    this.isTaskCompleted = false,
  });
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
