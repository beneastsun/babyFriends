import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qiaoqiao_companion/core/theme/app_theme.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';
import 'package:qiaoqiao_companion/core/services/avatar_service.dart';
import 'package:qiaoqiao_companion/shared/models/app_usage_filter.dart';
import 'package:qiaoqiao_companion/shared/models/daily_stats.dart';
import 'package:qiaoqiao_companion/features/parent_mode/presentation/parent_mode_entry.dart';
import 'package:qiaoqiao_companion/features/home/presentation/widgets/app_usage_list.dart';
import 'package:qiaoqiao_companion/features/home/presentation/widgets/daily_timeline_widget.dart';
import 'package:qiaoqiao_companion/features/report/domain/weekly_report.dart';
import 'package:qiaoqiao_companion/features/report/domain/weekly_report_service.dart';
import 'package:qiaoqiao_companion/shared/providers/task_provider.dart';
import 'package:qiaoqiao_companion/shared/models/task_definition.dart';
import 'package:qiaoqiao_companion/shared/providers/egg_provider.dart';
import 'package:qiaoqiao_companion/shared/widgets/egg_character.dart';
import 'package:qiaoqiao_companion/shared/widgets/egg_upgrade_overlay.dart';
import 'package:qiaoqiao_companion/shared/widgets/coupon_exchange_dialog.dart';
import 'package:qiaoqiao_companion/app/router.dart';
import 'package:qiaoqiao_companion/shared/widgets/design_system/app_card.dart';
import 'package:qiaoqiao_companion/shared/providers/theme_provider.dart';
import 'package:qiaoqiao_companion/shared/widgets/design_system/app_button.dart';
import 'package:qiaoqiao_companion/core/theme/app_solid_colors.dart';
import 'package:qiaoqiao_companion/features/tasks/presentation/widgets/task_checkin_dialog.dart';

/// 首页视图维度
enum HomeViewDimension { day, week }

/// 首页视图维度 Provider
final homeViewDimensionProvider = StateProvider<HomeViewDimension>((_) => HomeViewDimension.day);

/// 首页
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int? _selectedHour;
  String? _selectedDate;

  @override
  Widget build(BuildContext context) {
    final dimension = ref.watch(homeViewDimensionProvider);
    final themeType = ref.watch(themeTypeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        color: AppSolidColors.getBackgroundColor(themeType, isDark),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(DesignTokens.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 顶部标题栏
                Padding(
                  padding: const EdgeInsets.only(
                    top: DesignTokens.space8,
                    bottom: DesignTokens.space16,
                  ),
                  child: Row(
                    children: [
                      Text(
                        '纹纹小伙伴',
                        style: AppTextStyles.heading1.copyWith(
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                      const Spacer(),
                      _NotificationButton(onTap: () {
                        // TODO: 通知功能
                      }),
                    ],
                  ),
                ),

                // 巧巧形象卡片
                ParentModeEntry(
                  onAuthenticated: () => context.push('/parent-mode'),
                  child: _QiaoqiaoCard(
                    remainingTime: Duration.zero,
                    message: '新的一天开始啦，我们一起加油！',
                  ),
                ),
                const SizedBox(height: DesignTokens.space16),

                // 今日任务区域
                _buildTaskSection(context, ref),
                const SizedBox(height: DesignTokens.space16),

                // 日/周维度切换器
                _DimensionSwitcher(
                  currentDimension: dimension,
                  onChanged: (d) {
                    ref.read(homeViewDimensionProvider.notifier).state = d;
                    setState(() {
                      _selectedHour = null;
                      _selectedDate = null;
                    });
                  },
                ),
                const SizedBox(height: DesignTokens.space16),

                // 根据维度显示不同内容
                if (dimension == HomeViewDimension.day)
                  _DayViewContent(
                    selectedHour: _selectedHour,
                    onHourSelected: (hour) {
                      setState(() {
                        _selectedHour = hour;
                      });
                    },
                    onClearFilter: () {
                      setState(() {
                        _selectedHour = null;
                      });
                    },
                    onRefresh: () {
                      // 取消小时选中，显示全天数据
                      setState(() {
                        _selectedHour = null;
                      });
                    },
                  )
                else
                  _WeekViewContent(
                    selectedDate: _selectedDate,
                    onDateSelected: (date) {
                      setState(() {
                        _selectedDate = _selectedDate == date ? null : date;
                      });
                    },
                    onClearFilter: () {
                      setState(() {
                        _selectedDate = null;
                      });
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  /// 构建任务区域
  Widget _buildTaskSection(BuildContext context, WidgetRef ref) {
    final taskState = ref.watch(taskProvider);
    final eggState = ref.watch(eggProvider);
    final theme = Theme.of(context);

    if (taskState.isLoading) {
      return AppCard(
        type: AppCardType.standard,
        child: const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (taskState.tasks.isEmpty) {
      return AppCard(
        type: AppCardType.standard,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.assignment_rounded, size: 48, color: theme.colorScheme.outline),
              const SizedBox(height: 12),
              Text('今日暂无任务', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                '请让爸爸妈妈在家长模式中添加任务',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
              ),
            ],
          ),
        ),
      );
    }

    return AppCard(
      type: AppCardType.standard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          Row(
            children: [
              Text('今日任务', style: AppTextStyles.heading3),
              const Spacer(),
              _buildActionButton(
                icon: Icons.history_rounded,
                label: '历史',
                onTap: () => context.push('${AppRoutes.tasks}/history'),
              ),
              const SizedBox(width: 8),
              _buildActionButton(
                icon: Icons.chevron_right_rounded,
                label: '全部',
                onTap: () => context.push(AppRoutes.tasks),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 进度条区域
          _buildProgressSection(context, ref, taskState, eggState),
          const SizedBox(height: 16),

          // 任务网格（多行自适应，不再横向滚动）
          _buildTaskGrid(context, ref, taskState, theme),
          const SizedBox(height: 16),

          // 底部操作栏
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => CouponExchangeDialog.show(context),
                  icon: const Icon(Icons.card_giftcard_rounded, size: 18),
                  label: const Text('兑换加时券'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(color: AppColors.primary, fontSize: 13)),
              Icon(icon, size: 16, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressSection(BuildContext context, WidgetRef ref, TaskState taskState, dynamic eggState) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.08),
            AppColors.primary.withOpacity(0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          EggCharacter(
            style: eggState.eggStyle,
            stage: eggState.stage,
            size: 56,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${taskState.todayCompletedCount}/${taskState.totalTaskCount}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '已完成',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.stars_rounded, size: 14, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            '+${taskState.todayPoints}',
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
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: taskState.completionRate,
                    minHeight: 8,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskGrid(BuildContext context, WidgetRef ref, TaskState taskState, ThemeData theme) {
    // 每行显示4个任务，自动换行
    return LayoutBuilder(
      builder: (context, constraints) {
        const double spacing = 10;
        const int columns = 4;
        final itemWidth = (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: taskState.tasks.map((task) {
            final isCompleted = taskState.isTaskCompleted(task);
            final isExceeded = taskState.isTaskExceeded(task);
            final checkinCount = taskState.getCheckinCount(task.id!);
            final canCheckin = !isExceeded;

            return SizedBox(
              width: itemWidth,
              child: _TaskGridItem(
                task: task,
                checkinCount: checkinCount,
                isCompleted: isCompleted,
                canCheckin: canCheckin,
                onTap: canCheckin ? () => _handleTaskTap(context, ref, task, checkinCount) : null,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _handleTaskTap(BuildContext context, WidgetRef ref, TaskDefinition task, int currentCount) async {
    // 显示打卡确认弹窗
    final confirmed = await TaskCheckinDialog.show(
      context,
      task: task,
      currentCount: currentCount,
    );

    if (confirmed != true || !context.mounted) return;

    // 执行打卡
    final oldStage = ref.read(eggProvider).stage;
    final result = await ref.read(taskProvider.notifier).checkin(task);

    if (!context.mounted) return;

    if (result.success) {
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
}

/// 任务网格项
class _TaskGridItem extends StatelessWidget {
  final TaskDefinition task;
  final int checkinCount;
  final bool isCompleted;
  final bool canCheckin;
  final VoidCallback? onTap;

  const _TaskGridItem({
    required this.task,
    required this.checkinCount,
    required this.isCompleted,
    required this.canCheckin,
    this.onTap,
  });

  Color get _categoryColor => switch (task.category) {
        TaskCategory.health => Colors.green,
        TaskCategory.study => Colors.blue,
        TaskCategory.chore => Colors.orange,
        TaskCategory.discipline => Colors.purple,
      };

  @override
  Widget build(BuildContext context) {
    final isDisabled = !canCheckin && isCompleted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            color: isCompleted
                ? _categoryColor.withOpacity(0.1)
                : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isCompleted
                  ? _categoryColor.withOpacity(0.3)
                  : AppColors.dividerLight,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 图标区域
              Stack(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? _categoryColor.withOpacity(0.15)
                          : _categoryColor.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(task.emoji, style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                  if (isCompleted)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: _categoryColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const Icon(Icons.check_rounded, size: 10, color: Colors.white),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              // 任务名称
              Text(
                task.name,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isCompleted ? FontWeight.w600 : FontWeight.w500,
                  color: isCompleted ? _categoryColor : AppColors.textPrimaryLight,
                  decoration: isCompleted && !canCheckin ? TextDecoration.lineThrough : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              // 进度
              Text(
                isCompleted ? '已完成' : '$checkinCount/${task.minDailyCount}次',
                style: TextStyle(
                  fontSize: 10,
                  color: isCompleted ? _categoryColor : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 通知按钮
class _NotificationButton extends ConsumerWidget {
  final VoidCallback onTap;

  const _NotificationButton({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = ref.watch(colorSchemeProvider);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesignTokens.radius12),
        child: Container(
          padding: const EdgeInsets.all(DesignTokens.space10),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.surfaceDark
                : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(DesignTokens.radius12),
            boxShadow: AppShadows.card,
          ),
          child: Icon(
            Icons.notifications_outlined,
            color: colors.primary,
            size: 22,
          ),
        ),
      ),
    );
  }
}

/// 日/周维度切换器
class _DimensionSwitcher extends StatelessWidget {
  final HomeViewDimension currentDimension;
  final ValueChanged<HomeViewDimension> onChanged;

  const _DimensionSwitcher({
    required this.currentDimension,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(DesignTokens.space4),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.surfaceDark
            : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(DesignTokens.radiusCapsule),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SwitcherButton(
            label: '今日',
            isSelected: currentDimension == HomeViewDimension.day,
            onTap: () => onChanged(HomeViewDimension.day),
          ),
          _SwitcherButton(
            label: '本周',
            isSelected: currentDimension == HomeViewDimension.week,
            onTap: () => onChanged(HomeViewDimension.week),
          ),
        ],
      ),
    );
  }
}

/// 切换器按钮
class _SwitcherButton extends ConsumerWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SwitcherButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeType = ref.watch(themeTypeProvider);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: DesignTokens.animationNormal,
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.space16,
          vertical: DesignTokens.space8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppSolidColors.getPrimaryColor(themeType, false) : null,
          borderRadius: BorderRadius.circular(DesignTokens.radiusCapsule),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            color: isSelected ? Colors.white : AppColors.textSecondaryLight,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

/// 日视图内容
class _DayViewContent extends ConsumerWidget {
  final int? selectedHour;
  final ValueChanged<int?>? onHourSelected;
  final VoidCallback? onClearFilter;
  final VoidCallback? onRefresh;

  const _DayViewContent({
    this.selectedHour,
    this.onHourSelected,
    this.onClearFilter,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = selectedHour != null
        ? AppUsageFilter.todayHour(selectedHour)
        : const AppUsageFilter.todayAll();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DailyTimelineWidget(
          selectedHour: selectedHour,
          onHourSelected: onHourSelected,
          onRefresh: onRefresh,
        ),
        const SizedBox(height: DesignTokens.space16),
        AppUsageList(
          maxItems: 5,
          filter: filter,
          onClearFilter: selectedHour != null ? onClearFilter : null,
        ),
      ],
    );
  }
}

/// 周视图内容
class _WeekViewContent extends ConsumerWidget {
  final String? selectedDate;
  final ValueChanged<String?>? onDateSelected;
  final VoidCallback? onClearFilter;

  const _WeekViewContent({
    this.selectedDate,
    this.onDateSelected,
    this.onClearFilter,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weeklyReportAsync = ref.watch(weeklyReportProvider);

    return weeklyReportAsync.when(
      data: (report) => _WeekViewReport(
        report: report,
        selectedDate: selectedDate,
        onDateSelected: onDateSelected,
        onClearFilter: onClearFilter,
      ),
      loading: () => Center(
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.space48),
          child: SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.space32),
          child: Text(
            '加载周报失败: $error',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
          ),
        ),
      ),
    );
  }
}

/// 周视图报告内容
class _WeekViewReport extends ConsumerWidget {
  final WeeklyReport report;
  final String? selectedDate;
  final ValueChanged<String?>? onDateSelected;
  final VoidCallback? onClearFilter;

  const _WeekViewReport({
    required this.report,
    this.selectedDate,
    this.onDateSelected,
    this.onClearFilter,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(colorSchemeProvider);
    final filter = selectedDate != null
        ? AppUsageFilter.weekDay(selectedDate)
        : const AppUsageFilter.weekAll();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.space16,
              vertical: DesignTokens.space8,
            ),
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(DesignTokens.radiusCapsule),
            ),
            child: Text(
              '${_formatDate(report.startDate)} - ${_formatDate(report.endDate)}',
              style: AppTextStyles.labelMedium.copyWith(color: colors.primary),
            ),
          ),
        ),
        const SizedBox(height: DesignTokens.space16),
        _DailyUsageChart(
          dailyUsages: report.dailyUsages,
          selectedDate: selectedDate,
          onDateSelected: onDateSelected,
        ),
        const SizedBox(height: DesignTokens.space16),
        AppUsageList(
          maxItems: 5,
          filter: filter,
          onClearFilter: selectedDate != null ? onClearFilter : null,
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}';
  }
}

/// 每日使用柱状图
class _DailyUsageChart extends StatelessWidget {
  final List<DailyUsage> dailyUsages;
  final String? selectedDate;
  final ValueChanged<String?>? onDateSelected;

  const _DailyUsageChart({
    required this.dailyUsages,
    this.selectedDate,
    this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final maxMinutes = dailyUsages.isEmpty
        ? 60
        : dailyUsages.map((d) => d.totalMinutes).reduce((a, b) => a > b ? a : b);

    return AppCard(
      type: AppCardType.standard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('每日使用情况', style: AppTextStyles.heading3),
          const SizedBox(height: DesignTokens.space16),
          SizedBox(
            height: 140,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: dailyUsages.map((day) {
                final barHeight = maxMinutes > 0
                    ? (day.totalMinutes / maxMinutes * 80).clamp(8.0, 80.0)
                    : 8.0;
                final dateStr = DailyStats.formatDate(day.date);
                final isSelected = selectedDate == dateStr;

                return _DailyBar(
                  weekday: day.weekdayName,
                  minutes: day.totalMinutes,
                  height: barHeight,
                  complied: day.compliedWithRules,
                  isSelected: isSelected,
                  onTap: () {
                    if (onDateSelected != null) {
                      onDateSelected!(isSelected ? null : dateStr);
                    }
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

/// 每日柱状图条
class _DailyBar extends ConsumerWidget {
  final String weekday;
  final int minutes;
  final double height;
  final bool complied;
  final bool isSelected;
  final VoidCallback? onTap;

  const _DailyBar({
    required this.weekday,
    required this.minutes,
    required this.height,
    required this.complied,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeType = ref.watch(themeTypeProvider);
    final colors = ref.watch(colorSchemeProvider);
    final barColor = complied ? AppSolidColors.getPrimaryColor(themeType, false) : AppSolidColors.warning;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: DesignTokens.animationNormal,
        curve: Curves.easeOutCubic,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              '$minutes分',
              style: AppTextStyles.labelSmall.copyWith(
                color: isSelected ? colors.primary : AppColors.textSecondaryLight,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            const SizedBox(height: DesignTokens.space6),
            AnimatedContainer(
              duration: DesignTokens.animationNormal,
              curve: Curves.easeOutCubic,
              width: isSelected ? 32 : 28,
              height: height,
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(DesignTokens.radius8),
                border: isSelected
                    ? Border.all(color: colors.primary, width: 2)
                    : null,
                boxShadow: isSelected ? AppShadows.button : null,
              ),
            ),
            const SizedBox(height: DesignTokens.space6),
            Text(
              weekday,
              style: AppTextStyles.labelSmall.copyWith(
                color: isSelected ? colors.primary : AppColors.textSecondaryLight,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 巧巧形象卡片
class _QiaoqiaoCard extends ConsumerStatefulWidget {
  final Duration remainingTime;
  final String message;

  const _QiaoqiaoCard({
    required this.remainingTime,
    required this.message,
  });

  @override
  ConsumerState<_QiaoqiaoCard> createState() => _QiaoqiaoCardState();
}

class _QiaoqiaoCardState extends ConsumerState<_QiaoqiaoCard> {
  final AvatarService _avatarService = AvatarService();
  File? _avatarFile;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    final file = await _avatarService.getAvatarFile();
    if (mounted) {
      setState(() {
        _avatarFile = file;
      });
    }
  }

  Future<void> _showImageSourceDialog() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(DesignTokens.radius20),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(DesignTokens.space16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.dividerLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: DesignTokens.space20),
                AppButtonSecondary(
                  onPressed: () => Navigator.pop(context, 'camera'),
                  isFullWidth: true,
                  child: Row(
                    children: [
                      Icon(Icons.camera_alt_rounded, color: AppColors.primary),
                      const SizedBox(width: DesignTokens.space12),
                      Text('拍照'),
                    ],
                  ),
                ),
                const SizedBox(height: DesignTokens.space12),
                AppButtonSecondary(
                  onPressed: () => Navigator.pop(context, 'gallery'),
                  isFullWidth: true,
                  child: Row(
                    children: [
                      Icon(Icons.photo_library_rounded, color: AppColors.primary),
                      const SizedBox(width: DesignTokens.space12),
                      Text('从相册选择'),
                    ],
                  ),
                ),
                if (_avatarFile != null) ...[
                  const SizedBox(height: DesignTokens.space12),
                  AppButtonSecondary(
                    onPressed: () => Navigator.pop(context, 'delete'),
                    isFullWidth: true,
                    child: Row(
                      children: [
                        Icon(Icons.delete_rounded, color: AppColors.error),
                        const SizedBox(width: DesignTokens.space12),
                        Text('删除头像'),
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

    if (result == null || !mounted) return;

    setState(() {
      _isLoading = true;
    });

    File? newFile;
    switch (result) {
      case 'camera':
        newFile = await _avatarService.pickFromCamera();
        break;
      case 'gallery':
        newFile = await _avatarService.pickFromGallery();
        break;
      case 'delete':
        await _avatarService.deleteAvatar();
        newFile = null;
        break;
    }

    if (mounted) {
      setState(() {
        _avatarFile = newFile;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeType = ref.watch(themeTypeProvider);

    return AppCard(
      type: AppCardType.glass,
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space16),
        child: Row(
          children: [
            // 头像
            GestureDetector(
              onLongPress: _showImageSourceDialog,
              child: Stack(
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: AppSolidColors.qiaoqiaoHappy,
                      borderRadius: BorderRadius.circular(DesignTokens.radius24),
                      boxShadow: AppShadows.card,
                    ),
                    child: _isLoading
                        ? Center(
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : _avatarFile != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(DesignTokens.radius24),
                                child: Image.file(
                                  _avatarFile!,
                                  width: 76,
                                  height: 76,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Center(
                                child: Icon(
                                  Icons.wb_sunny_rounded,
                                  size: 38,
                                  color: Colors.white,
                                ),
                              ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(DesignTokens.space6),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(DesignTokens.radius12),
                        boxShadow: AppShadows.button,
                      ),
                      child: Icon(
                        Icons.edit_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: DesignTokens.space16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '纹纹小伙伴',
                    style: AppTextStyles.heading3,
                  ),
                  const SizedBox(height: DesignTokens.space8),
                  Text(
                    widget.message,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: DesignTokens.space12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesignTokens.space10,
                      vertical: DesignTokens.space4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.qiaoqiaoHappy.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(DesignTokens.radiusCapsule),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.favorite_rounded,
                          size: 14,
                          color: AppColors.qiaoqiaoHappy,
                        ),
                        const SizedBox(width: DesignTokens.space4),
                        Text(
                          '状态良好',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.qiaoqiaoHappy,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
