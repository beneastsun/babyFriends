import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/theme/app_solid_colors.dart';
import 'package:qiaoqiao_companion/core/theme/app_theme.dart';
import 'package:qiaoqiao_companion/shared/models/hourly_usage_stats.dart';
import 'package:qiaoqiao_companion/shared/providers/hourly_usage_provider.dart';
import 'package:qiaoqiao_companion/shared/widgets/design_system/app_card.dart';

/// 每日时段时间线组件
///
/// 显示24小时使用情况柱状图，每个柱子代表1小时
/// 柱子高度表示使用强度（60分钟为满格）
class DailyTimelineWidget extends ConsumerWidget {
  final int? selectedHour;
  final ValueChanged<int?>? onHourSelected;
  final VoidCallback? onRefresh;

  const DailyTimelineWidget({
    super.key,
    this.selectedHour,
    this.onHourSelected,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timelineAsync = ref.watch(todayHourlyTimelineNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppCard(
      type: AppCardType.standard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(DesignTokens.space8),
                    decoration: BoxDecoration(
                      color: AppSolidColors.info,
                      borderRadius: BorderRadius.circular(DesignTokens.radius10),
                    ),
                    child: Icon(Icons.bar_chart_rounded, color: Colors.white, size: 18),
                  ),
                  SizedBox(width: DesignTokens.space12),
                  Text('每小时情况', style: AppTextStyles.heading3),
                ],
              ),
              // 刷新按钮
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    ref
                        .read(todayHourlyTimelineNotifierProvider.notifier)
                        .refresh();
                    onRefresh?.call();
                  },
                  borderRadius: BorderRadius.circular(DesignTokens.radius10),
                  child: Container(
                    padding: EdgeInsets.all(DesignTokens.space8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.surfaceDark
                          : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(DesignTokens.radius10),
                    ),
                    child: Icon(
                      Icons.refresh_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: DesignTokens.space16),
          timelineAsync.when(
            data: (timeline) => _TimelineGrid(
              timeline: timeline,
              selectedHour: selectedHour,
              onHourSelected: onHourSelected,
            ),
            loading: () => Center(
              child: Padding(
                padding: EdgeInsets.all(DesignTokens.space24),
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            error: (error, stack) => Center(
              child: Padding(
                padding: EdgeInsets.all(DesignTokens.space24),
                child: Text(
                  '加载失败: $error',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
                ),
              ),
            ),
          ),
          SizedBox(height: DesignTokens.space16),
          // 图例
          const _Legend(),
        ],
      ),
    );
  }
}

/// 时间线柱状图
class _TimelineGrid extends StatelessWidget {
  final HourlyTimeline timeline;
  final int? selectedHour;
  final ValueChanged<int?>? onHourSelected;

  const _TimelineGrid({
    required this.timeline,
    this.selectedHour,
    this.onHourSelected,
  });

  int _getMinutes(int hour) {
    final seconds = timeline.hourlyTotals[hour] ?? 0;
    return seconds ~/ 60;
  }

  @override
  Widget build(BuildContext context) {
    const maxBarHeight = 80.0;
    const maxSeconds = 3600;
    const yAxisWidth = 36.0;
    const labelHeight = 32.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Y轴刻度
            SizedBox(
              width: yAxisWidth,
              height: maxBarHeight,
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    child: Text(
                      '60分',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textHintLight,
                      ),
                    ),
                  ),
                  Positioned(
                    top: maxBarHeight / 2 - 8,
                    child: Text(
                      '30分',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textHintLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 柱状图
            Expanded(
              child: SizedBox(
                height: labelHeight + maxBarHeight,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final availableWidth = constraints.maxWidth;
                    const gapWidth = 2.0;
                    final barWidth = (availableWidth - 23 * gapWidth) / 24;

                    final bars = List.generate(24, (hour) {
                      final seconds = timeline.hourlyTotals[hour] ?? 0;
                      final status = timeline.getStatusForHour(hour);

                      final barHeight = seconds > 0
                          ? ((seconds / maxSeconds).clamp(0.0, 1.0) * maxBarHeight)
                              .clamp(4.0, maxBarHeight)
                          : 4.0;

                      return _HourBar(
                        hour: hour,
                        height: barHeight,
                        width: barWidth,
                        status: status,
                        seconds: seconds,
                        isSelected: selectedHour == hour,
                        onTap: () {
                          if (onHourSelected != null) {
                            onHourSelected!(selectedHour == hour ? null : hour);
                          }
                        },
                      );
                    });

                    final children = <Widget>[];
                    for (var i = 0; i < bars.length; i++) {
                      children.add(bars[i]);
                      if (i < bars.length - 1) {
                        children.add(SizedBox(width: gapWidth));
                      }
                    }

                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: children,
                          ),
                        ),
                        if (selectedHour != null)
                          Positioned(
                            top: 0,
                            left: selectedHour! * (barWidth + gapWidth),
                            child: _buildDetailLabel(selectedHour!, barWidth),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: DesignTokens.space8),
        // 时间轴标签
        Padding(
          padding: EdgeInsets.only(left: yAxisWidth),
          child: _TimeAxisLabels(),
        ),
      ],
    );
  }

  Widget _buildDetailLabel(int hour, double barWidth) {
    final minutes = _getMinutes(hour);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: DesignTokens.space10,
        vertical: DesignTokens.space6,
      ),
      decoration: BoxDecoration(
        color: AppSolidColors.info,
        borderRadius: BorderRadius.circular(DesignTokens.radius8),
        boxShadow: AppShadows.button,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            '$hour点',
            style: AppTextStyles.labelSmall.copyWith(color: Colors.white),
          ),
          SizedBox(width: DesignTokens.space4),
          Text(
            '$minutes',
            style: AppTextStyles.heading3.copyWith(color: Colors.white),
          ),
          Text(
            '分钟',
            style: AppTextStyles.labelSmall.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

/// 单个小时柱子
class _HourBar extends StatelessWidget {
  final int hour;
  final double height;
  final double width;
  final HourUsageStatus status;
  final int seconds;
  final bool isSelected;
  final VoidCallback? onTap;

  const _HourBar({
    required this.hour,
    required this.height,
    required this.width,
    required this.status,
    required this.seconds,
    this.isSelected = false,
    this.onTap,
  });

  Color _getBarColor() {
    switch (status) {
      case HourUsageStatus.none:
        return AppColors.textHintLight.withOpacity(0.1);
      case HourUsageStatus.light:
        return AppSolidColors.info;
      case HourUsageStatus.moderate:
        return AppSolidColors.warning;
      case HourUsageStatus.heavy:
        return AppSolidColors.error;
    }
  }

  String _getTooltip() {
    final minutes = seconds ~/ 60;
    if (minutes <= 0) {
      return '$hour:00 - 未使用';
    } else {
      return '$hour:00 - $minutes分钟';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: _getTooltip(),
        preferBelow: false,
        child: AnimatedContainer(
          duration: DesignTokens.animationQuick,
          curve: Curves.easeOut,
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: _getBarColor(),
            borderRadius: BorderRadius.circular(DesignTokens.radius4),
            border: isSelected
                ? Border.all(color: AppColors.primary, width: 2)
                : null,
            boxShadow: isSelected ? AppShadows.button : null,
          ),
        ),
      ),
    );
  }
}

/// 时间轴标签
class _TimeAxisLabels extends StatelessWidget {
  const _TimeAxisLabels();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        const gapWidth = 2.0;
        final barWidth = (availableWidth - 23 * gapWidth) / 24;

        return Row(
          children: _buildLabels(barWidth, gapWidth),
        );
      },
    );
  }

  List<Widget> _buildLabels(double barWidth, double gapWidth) {
    final labels = [0, 6, 12, 18, 23];
    final children = <Widget>[];

    for (var i = 0; i < 24; i++) {
      if (labels.contains(i)) {
        children.add(SizedBox(
          width: barWidth,
          child: Text(
            '$i',
            textAlign: TextAlign.center,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textHintLight,
            ),
          ),
        ));
      } else {
        children.add(SizedBox(width: barWidth));
      }
      if (i < 23) {
        children.add(SizedBox(width: gapWidth));
      }
    }

    return children;
  }
}

/// 图例
class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: DesignTokens.space16,
        vertical: DesignTokens.space12,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withOpacity(0.5),
        borderRadius: BorderRadius.circular(DesignTokens.radius12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _LegendItem(
            color: AppColors.textHintLight,
            label: '未使用',
          ),
          _LegendItem(
            color: AppColors.primary,
            label: '轻度',
          ),
          _LegendItem(
            color: AppColors.warning,
            label: '中度',
          ),
          _LegendItem(
            color: AppColors.error,
            label: '重度',
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(DesignTokens.radius4),
          ),
        ),
        SizedBox(width: DesignTokens.space6),
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }
}
