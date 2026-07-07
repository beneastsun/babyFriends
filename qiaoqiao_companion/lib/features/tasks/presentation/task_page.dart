import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';
import 'package:qiaoqiao_companion/shared/models/task_definition.dart';
import 'package:qiaoqiao_companion/shared/providers/task_provider.dart';
import 'package:qiaoqiao_companion/shared/providers/egg_provider.dart';
import 'package:qiaoqiao_companion/shared/widgets/egg_character.dart';
import 'package:qiaoqiao_companion/shared/widgets/egg_upgrade_overlay.dart';
import 'package:qiaoqiao_companion/shared/widgets/coupon_exchange_dialog.dart';

class TaskPage extends ConsumerWidget {
  const TaskPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskState = ref.watch(taskProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('今日任务')),
      body: _buildBody(context, ref, taskState, theme),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => CouponExchangeDialog.show(context),
        icon: const Icon(Icons.card_giftcard),
        label: const Text('兑换加时券'),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, TaskState taskState, ThemeData theme) {
    if (taskState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (taskState.tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_nature_rounded, size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text('还没有任务哦', style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.outline)),
            const SizedBox(height: 8),
            Text('请让爸爸妈妈添加任务吧', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
          ],
        ),
      );
    }

    final List<Widget> banners = [];

    // 当天提醒（有未完成任务且有惩罚时）
    final incompleteTasks = taskState.tasks.where((t) =>
      !taskState.isTaskCompleted(t) && t.penaltyMinutes > 0
    ).toList();
    if (incompleteTasks.isNotEmpty) {
      final totalPenalty = incompleteTasks.fold<int>(0, (sum, t) => sum + t.penaltyMinutes);
      banners.add(Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        color: theme.colorScheme.tertiaryContainer,
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: theme.colorScheme.tertiary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '今天有 ${incompleteTasks.length} 个任务还没完成哦，如果不完成，明天会减少 $totalPenalty 分钟使用时长',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onTertiaryContainer),
              ),
            ),
          ],
        ),
      ));
    }

    return Column(
      children: [
        // 蛋仔形象区域
        Consumer(builder: (context, ref, _) {
          final eggState = ref.watch(eggProvider);
          return Center(
            child: EggCharacter(
              style: eggState.eggStyle,
              stage: eggState.stage,
              size: 100,
            ),
          );
        }),
        const SizedBox(height: 8),
        ...banners,
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: TaskCategory.values.map((category) {
              final tasks = taskState.tasks.where((t) => t.category == category).toList();
              if (tasks.isEmpty) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, top: 16),
                    child: Text(category.label, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
                  ),
                  ...tasks.map((task) => _TaskCard(
                    task: task,
                    checkinCount: taskState.getCheckinCount(task.id!),
                    isCompleted: taskState.isTaskCompleted(task),
                    canCheckin: !taskState.isTaskExceeded(task),
                    onCheckin: () => _handleCheckin(context, ref, task),
                  )),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Future<void> _handleCheckin(BuildContext context, WidgetRef ref, TaskDefinition task) async {
    if (task.checkinMode == CheckinMode.parentConfirm) {
      // 简化处理：直接调用 checkin
      // 实际应用中需要家长密码确认
    }
    final oldStage = ref.read(eggProvider).stage;
    await ref.read(taskProvider.notifier).checkin(task);
    await ref.read(eggProvider.notifier).refreshWeeklyProgress();
    final newStage = ref.read(eggProvider).stage;
    if (newStage > oldStage && context.mounted) {
      final eggState = ref.read(eggProvider);
      EggUpgradeOverlay.show(context, style: eggState.eggStyle, newStage: newStage);
    }
  }
}

class _TaskCard extends StatelessWidget {
  final TaskDefinition task;
  final int checkinCount;
  final bool isCompleted;
  final bool canCheckin;
  final VoidCallback onCheckin;

  const _TaskCard({
    required this.task,
    required this.checkinCount,
    required this.isCompleted,
    required this.canCheckin,
    required this.onCheckin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Text(task.emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                      color: isCompleted ? theme.colorScheme.outline : null,
                    ),
                  ),
                  Text(
                    '$checkinCount/${task.maxDailyCount} 次',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isCompleted ? theme.colorScheme.outline : theme.colorScheme.primary,
                    ),
                  ),
                  if (task.checkinMode == CheckinMode.parentConfirm && !isCompleted && canCheckin)
                    Text('需家长确认', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.tertiary, fontSize: 11)),
                  if (task.penaltyMinutes > 0 && !isCompleted && canCheckin)
                    Text('⚠️ 未完成扣 ${task.penaltyMinutes} 分钟', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.tertiary, fontSize: 11)),
                ],
              ),
            ),
            if (canCheckin && !isCompleted)
              FilledButton.tonal(onPressed: onCheckin, child: Text(task.checkinMode == CheckinMode.parentConfirm ? '待确认' : '打卡'))
            else if (isCompleted)
              Icon(Icons.check_circle, color: theme.colorScheme.primary)
            else
              Icon(Icons.lock_outline, color: theme.colorScheme.outline),
          ],
        ),
      ),
    );
  }
}
