import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';
import 'package:qiaoqiao_companion/core/database/daos/task_checkin_dao.dart';
import 'package:qiaoqiao_companion/shared/models/task_definition.dart';
import 'package:qiaoqiao_companion/shared/providers/task_provider.dart';
import 'package:qiaoqiao_companion/shared/providers/egg_provider.dart';
import 'package:qiaoqiao_companion/shared/providers/task_reminder_provider.dart';
import 'package:qiaoqiao_companion/shared/widgets/egg_character.dart';
import 'package:qiaoqiao_companion/shared/widgets/egg_upgrade_overlay.dart';
import 'package:qiaoqiao_companion/shared/widgets/coupon_exchange_dialog.dart';
import 'package:qiaoqiao_companion/features/tasks/presentation/widgets/task_checkin_dialog.dart';

class TaskPage extends ConsumerStatefulWidget {
  const TaskPage({super.key});

  @override
  ConsumerState<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends ConsumerState<TaskPage> {
  @override
  void initState() {
    super.initState();
    // 页面加载时刷新任务数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(taskProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final taskState = ref.watch(taskProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('今日任务'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: '打卡历史',
            onPressed: () => context.push('/tasks/history'),
          ),
        ],
      ),
      body: _buildBody(context, ref, taskState, theme),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => CouponExchangeDialog.show(context),
        icon: const Icon(Icons.card_giftcard_rounded),
        label: const Text('兑换加时券'),
        elevation: 2,
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, TaskState taskState, ThemeData theme) {
    if (taskState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (taskState.tasks.isEmpty) {
      return _buildEmptyState(context, theme);
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(taskProvider.notifier).load(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 顶部蛋仔形象和进度卡片
          _buildHeaderCard(context, ref, taskState, theme),
          const SizedBox(height: 16),

          // 惩罚提醒横幅
          ..._buildPenaltyBanner(taskState, theme),

          // 分类任务列表
          ...TaskCategory.values.map((category) {
            final tasks = taskState.tasks.where((t) => t.category == category).toList();
            if (tasks.isEmpty) return const SizedBox.shrink();

            return _buildCategorySection(context, ref, category, tasks, taskState, theme);
          }),

          const SizedBox(height: 80), // 为FAB留空间
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.emoji_nature_rounded,
                size: 56,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '还没有任务哦',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              '请让爸爸妈妈在家长模式中添加任务吧',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, WidgetRef ref, TaskState taskState, ThemeData theme) {
    final eggState = ref.watch(eggProvider);
    final completedCount = taskState.todayCompletedCount;
    final totalCount = taskState.totalTaskCount;
    final points = taskState.todayPoints;
    final rate = taskState.completionRate;
    final isAllDone = rate >= 1.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer.withOpacity(0.5),
            theme.colorScheme.secondaryContainer.withOpacity(0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          // 左侧：小号蛋仔形象
          EggCharacter(
            style: eggState.eggStyle,
            stage: eggState.stage,
            size: 64,
          ),
          const SizedBox(width: 14),
          // 右侧：进度+积分+进度条
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 第一行：进度数字 + 积分
                Row(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$completedCount',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                            height: 1.0,
                          ),
                        ),
                        Text(
                          '/$totalCount',
                          style: TextStyle(
                            fontSize: 16,
                            color: theme.colorScheme.outline,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '已完成',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.outline,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // 积分胶囊
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.stars_rounded, color: Colors.amber, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '$points',
                            style: const TextStyle(
                              color: Colors.amber,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // 进度条
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: rate,
                    minHeight: 8,
                    backgroundColor: Colors.white.withOpacity(0.5),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isAllDone ? Colors.green : theme.colorScheme.primary,
                    ),
                  ),
                ),
                // 全部完成时的庆祝提示
                if (isAllDone) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.celebration_rounded, color: Colors.green, size: 14),
                      const SizedBox(width: 4),
                      const Text(
                        '太棒了！今日任务全部完成！',
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPenaltyBanner(TaskState taskState, ThemeData theme) {
    final incompleteTasks = taskState.tasks.where((t) =>
      !taskState.isTaskCompleted(t) && t.penaltyMinutes > 0
    ).toList();

    if (incompleteTasks.isEmpty) return [];

    final totalPenalty = incompleteTasks.fold<int>(0, (sum, t) => sum + t.penaltyMinutes);

    return [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '还有 ${incompleteTasks.length} 个任务未完成，不完成明天将减少 $totalPenalty 分钟使用时长',
                style: const TextStyle(color: Colors.orange, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
    ];
  }

  Widget _buildCategorySection(
    BuildContext context,
    WidgetRef ref,
    TaskCategory category,
    List<TaskDefinition> tasks,
    TaskState taskState,
    ThemeData theme,
  ) {
    final categoryColor = _getCategoryColor(category);
    final completedInCategory = tasks.where((t) => taskState.isTaskCompleted(t)).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 分类标题
        Padding(
          padding: const EdgeInsets.only(bottom: 10, top: 8),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: categoryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                category.label,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: categoryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$completedInCategory/${tasks.length}',
                  style: TextStyle(
                    fontSize: 12,
                    color: categoryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        // 任务卡片
        ...tasks.map((task) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _TaskCard(
            task: task,
            checkinCount: taskState.getCheckinCount(task.id!),
            todayCheckins: taskState.getTodayCheckins(task.id!),
            isCompleted: taskState.isTaskCompleted(task),
            canCheckin: !taskState.isTaskExceeded(task),
            remainingCount: taskState.getRemainingCheckins(task),
            categoryColor: categoryColor,
            onCheckin: () => _handleCheckin(context, ref, task),
          ),
        )),
      ],
    );
  }

  Future<void> _handleCheckin(BuildContext context, WidgetRef ref, TaskDefinition task) async {
    final taskState = ref.read(taskProvider);
    final currentCount = taskState.getCheckinCount(task.id!);

    // 显示打卡确认弹窗
    final confirmed = await TaskCheckinDialog.show(
      context,
      task: task,
      currentCount: currentCount,
    );

    if (confirmed != true || !context.mounted) return;

    // 家长确认模式的处理
    if (task.checkinMode == CheckinMode.parentConfirm) {
      // 可以在这里添加家长密码验证逻辑
    }

    final oldStage = ref.read(eggProvider).stage;
    final result = await ref.read(taskProvider.notifier).checkin(task);

    if (!context.mounted) return;

    if (result.success) {
      // 取消该任务的当日提醒
      if (task.id != null) {
        await ref.read(taskReminderProvider.notifier).cancelReminderForTask(task.id!);
      }

      // 显示成功提示
      CheckinSuccessSnackBar.show(
        context,
        message: result.message,
        points: result.pointsEarned,
      );

      // 检查蛋仔升级
      await ref.read(eggProvider.notifier).refreshWeeklyProgress();
      final newStage = ref.read(eggProvider).stage;
      if (newStage > oldStage && context.mounted) {
        final eggState = ref.read(eggProvider);
        EggUpgradeOverlay.show(context, style: eggState.eggStyle, newStage: newStage);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Color _getCategoryColor(TaskCategory category) {
    return switch (category) {
      TaskCategory.health => Colors.green,
      TaskCategory.study => Colors.blue,
      TaskCategory.chore => Colors.orange,
      TaskCategory.discipline => Colors.purple,
    };
  }
}

class _TaskCard extends StatelessWidget {
  final TaskDefinition task;
  final int checkinCount;
  final List<TaskCheckin> todayCheckins;
  final bool isCompleted;
  final bool canCheckin;
  final int remainingCount;
  final Color categoryColor;
  final VoidCallback onCheckin;

  const _TaskCard({
    required this.task,
    required this.checkinCount,
    required this.todayCheckins,
    required this.isCompleted,
    required this.canCheckin,
    required this.remainingCount,
    required this.categoryColor,
    required this.onCheckin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = task.maxDailyCount > 0 ? checkinCount / task.maxDailyCount : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: isCompleted ? categoryColor.withOpacity(0.05) : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted ? categoryColor.withOpacity(0.2) : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canCheckin ? onCheckin : null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    // 任务图标
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? categoryColor.withOpacity(0.15)
                            : categoryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Text(task.emoji, style: const TextStyle(fontSize: 28)),
                          ),
                          if (isCompleted)
                            Positioned(
                              right: 4,
                              bottom: 4,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: categoryColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 1.5),
                                ),
                                child: const Icon(Icons.check_rounded, size: 10, color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  task.name,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    decoration: isCompleted && !canCheckin ? TextDecoration.lineThrough : null,
                                    color: isCompleted && !canCheckin ? theme.colorScheme.outline : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // 进度条
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress.clamp(0.0, 1.0),
                              minHeight: 6,
                              backgroundColor: theme.colorScheme.surfaceVariant,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isCompleted ? categoryColor : categoryColor.withOpacity(0.7),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          // 信息行
                          Wrap(
                            spacing: 10,
                            children: [
                              _buildInfoTag(
                                icon: Icons.repeat_rounded,
                                label: '$checkinCount/${task.maxDailyCount}次',
                                color: isCompleted ? categoryColor : theme.colorScheme.outline,
                              ),
                              _buildInfoTag(
                                icon: Icons.stars_rounded,
                                label: '+${task.basePoints}分',
                                color: Colors.amber,
                              ),
                              if (task.checkinMode == CheckinMode.parentConfirm && !isCompleted)
                                _buildInfoTag(
                                  icon: Icons.verified_user_rounded,
                                  label: '家长确认',
                                  color: Colors.purple,
                                ),
                              if (task.penaltyMinutes > 0 && !isCompleted)
                                _buildInfoTag(
                                  icon: Icons.warning_amber_rounded,
                                  label: '未完成扣${task.penaltyMinutes}分',
                                  color: Colors.red,
                                ),
                              if (canCheckin && isCompleted)
                                _buildInfoTag(
                                  icon: Icons.add_circle_outline_rounded,
                                  label: '还可打$remainingCount次',
                                  color: Colors.green,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // 打卡按钮
                    if (canCheckin)
                      SizedBox(
                        width: 64,
                        height: 64,
                        child: FilledButton(
                          onPressed: onCheckin,
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: EdgeInsets.zero,
                            backgroundColor: isCompleted ? Colors.green : categoryColor,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_rounded, size: 22),
                              const SizedBox(height: 2),
                              Text(
                                isCompleted ? '再打' : '打卡',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (isCompleted)
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 24),
                            const SizedBox(height: 2),
                            Text(
                              '已完成',
                              style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                // 今日打卡时间记录
                if (todayCheckins.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.access_time_rounded, size: 14, color: theme.colorScheme.outline),
                        const SizedBox(width: 6),
                        Text(
                          '今日打卡: ',
                          style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
                        ),
                        Expanded(
                          child: Text(
                            todayCheckins.map((c) => c.checkinTime.substring(0, 5)).join('  '),
                            style: TextStyle(fontSize: 11, color: categoryColor, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTag({required IconData icon, required String label, required Color color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 2),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: color),
        ),
      ],
    );
  }
}
