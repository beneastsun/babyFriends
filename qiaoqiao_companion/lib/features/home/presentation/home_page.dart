import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qiaoqiao_companion/core/theme/app_theme.dart';
import 'package:qiaoqiao_companion/core/services/avatar_service.dart';
import 'package:qiaoqiao_companion/shared/models/app_usage_filter.dart';
import 'package:qiaoqiao_companion/shared/models/daily_stats.dart';
import 'package:qiaoqiao_companion/features/parent_mode/presentation/parent_mode_entry.dart';
import 'package:qiaoqiao_companion/features/home/presentation/widgets/app_usage_list.dart';
import 'package:qiaoqiao_companion/features/home/presentation/widgets/daily_timeline_widget.dart';
import 'package:qiaoqiao_companion/features/report/domain/weekly_report.dart';
import 'package:qiaoqiao_companion/features/report/domain/weekly_report_service.dart';
import 'package:qiaoqiao_companion/shared/providers/filtered_app_usage_provider.dart';
import 'package:qiaoqiao_companion/shared/widgets/design_system/app_card.dart';
import 'package:qiaoqiao_companion/shared/providers/theme_provider.dart';
import 'package:qiaoqiao_companion/shared/widgets/design_system/app_button.dart';
import 'package:qiaoqiao_companion/core/theme/app_solid_colors.dart';

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
                    bottom: DesignTokens.space20,
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
                const SizedBox(height: DesignTokens.space20),

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
                const SizedBox(height: DesignTokens.space20),

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
                      // 刷新 app 列表数据
                      ref.invalidate(filteredAppUsageProvider);
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
          horizontal: DesignTokens.space20,
          vertical: DesignTokens.space10,
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
        const SizedBox(height: DesignTokens.space20),
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
        const SizedBox(height: DesignTokens.space20),
        _DailyUsageChart(
          dailyUsages: report.dailyUsages,
          selectedDate: selectedDate,
          onDateSelected: onDateSelected,
        ),
        const SizedBox(height: DesignTokens.space20),
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
        padding: const EdgeInsets.all(DesignTokens.space20),
        child: Row(
          children: [
            // 头像
            GestureDetector(
              onLongPress: _showImageSourceDialog,
              child: Stack(
                children: [
                  Container(
                    width: 88,
                    height: 88,
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
                                  width: 88,
                                  height: 88,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Center(
                                child: Icon(
                                  Icons.wb_sunny_rounded,
                                  size: 44,
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
