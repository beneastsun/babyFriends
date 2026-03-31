import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qiaoqiao_companion/core/theme/app_theme.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';
import 'package:qiaoqiao_companion/shared/providers/providers.dart';
import 'package:qiaoqiao_companion/shared/models/app_usage_summary.dart';
import 'package:qiaoqiao_companion/shared/models/app_usage_filter.dart';
import 'package:qiaoqiao_companion/shared/widgets/design_system/app_card.dart';
import 'package:qiaoqiao_companion/shared/widgets/design_system/gradient_progress.dart';

/// 应用使用列表组件
class AppUsageList extends ConsumerWidget {
  final int maxItems;
  final bool showViewAll;
  final AppUsageFilter? filter;
  final VoidCallback? onClearFilter;

  const AppUsageList({
    super.key,
    this.maxItems = 5,
    this.showViewAll = true,
    this.filter,
    this.onClearFilter,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providerFilter = ref.watch(appUsageFilterProvider);
    final effectiveFilter = filter ?? providerFilter;
    final asyncSummaries = ref.watch(filteredAppUsageProvider(effectiveFilter));

    return asyncSummaries.when(
      data: (summaries) => _buildList(context, summaries, effectiveFilter),
      loading: () => AppCard(
        type: AppCardType.standard,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(DesignTokens.space32),
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
      ),
      error: (error, stack) => AppCard(
        type: AppCardType.standard,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(DesignTokens.space24),
            child: Text(
              '加载失败: $error',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<AppUsageSummary> summaries, AppUsageFilter filter) {
    final displaySummaries = summaries.take(maxItems).toList();
    final title = filter.getDisplayTitle();
    final isFiltered = filter.type != AppUsageFilterType.todayAll;

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
                    padding: const EdgeInsets.all(DesignTokens.space8),
                    decoration: BoxDecoration(
                      color: AppSolidColors.video,
                      borderRadius: BorderRadius.circular(DesignTokens.radius10),
                    ),
                    child: Icon(Icons.apps_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: DesignTokens.space12),
                  Text(
                    title,
                    style: AppTextStyles.heading3,
                  ),
                ],
              ),
              if (isFiltered && onClearFilter != null)
                TextButton.icon(
                  onPressed: onClearFilter,
                  icon: Icon(Icons.close_rounded, size: 16, color: AppColors.primary),
                  label: Text(
                    '清除',
                    style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space8),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
          const SizedBox(height: DesignTokens.space16),

          if (displaySummaries.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(DesignTokens.space24),
                child: Column(
                  children: [
                    Icon(
                      Icons.hourglass_empty_rounded,
                      size: 48,
                      color: AppColors.textHintLight,
                    ),
                    const SizedBox(height: DesignTokens.space12),
                    Text(
                      filter.type == AppUsageFilterType.todayHour
                          ? '该时段没有使用应用'
                          : filter.type == AppUsageFilterType.weekDay
                              ? '该天没有使用应用'
                              : '还没有使用应用',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondaryLight,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: displaySummaries
                  .asMap()
                  .entries
                  .map((entry) => Column(
                        children: [
                          if (entry.key > 0)
                            Divider(
                              height: 1,
                              color: AppColors.dividerLight,
                            ),
                          _AppUsageItem(summary: entry.value),
                        ],
                      ))
                  .toList(),
            ),

          if (showViewAll && summaries.length > maxItems) ...[
            const SizedBox(height: DesignTokens.space12),
            Center(
              child: TextButton.icon(
                onPressed: () => context.push('/app-list'),
                icon: Icon(
                  Icons.expand_more_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
                label: Text(
                  '查看全部应用',
                  style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 单个应用使用项
class _AppUsageItem extends StatelessWidget {
  final AppUsageSummary summary;

  const _AppUsageItem({
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final categoryColor = _getCategoryColor();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DesignTokens.space12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 第一行：图标 + 应用名称 + 使用时长
          Row(
            children: [
              // 应用图标
              _buildAppIcon(),
              const SizedBox(width: DesignTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.appName,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: DesignTokens.space2),
                    // 分类标签
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DesignTokens.space6,
                        vertical: DesignTokens.space2,
                      ),
                      decoration: BoxDecoration(
                        color: categoryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(DesignTokens.radius4),
                      ),
                      child: Text(
                        _getCategoryLabel(),
                        style: AppTextStyles.labelSmall.copyWith(
                          color: categoryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 使用时长
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.space10,
                  vertical: DesignTokens.space4,
                ),
                decoration: BoxDecoration(
                  color: categoryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(DesignTokens.radius8),
                ),
                child: Text(
                  _formatDuration(summary.todayDuration),
                  style: AppTextStyles.labelMedium.copyWith(
                    color: categoryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.space10),
          // 进度条
          GradientProgress(
            value: summary.usagePercentage.clamp(0.0, 1.0),
            color: _getCategoryColor(),
            height: 6,
          ),
        ],
      ),
    );
  }

  /// 构建应用图标
  Widget _buildAppIcon() {
    if (summary.appIcon != null && summary.appIcon!.isNotEmpty) {
      try {
        final bytes = base64Decode(summary.appIcon!);
        return Container(
          padding: const EdgeInsets.all(DesignTokens.space2),
          decoration: BoxDecoration(
            color: _getCategoryColor(),
            borderRadius: BorderRadius.circular(DesignTokens.radius12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(DesignTokens.radius10),
            child: Image.memory(
              bytes,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _buildFallbackIcon(),
            ),
          ),
        );
      } catch (e) {
        return _buildFallbackIcon();
      }
    }
    return _buildFallbackIcon();
  }

  /// 构建备用图标
  Widget _buildFallbackIcon() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: _getCategoryColor(),
        borderRadius: BorderRadius.circular(DesignTokens.radius12),
      ),
      child: Center(
        child: Icon(
          _getCategoryIconData(),
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }

  IconData _getCategoryIconData() {
    switch (summary.category) {
      case AppCategory.game:
        return Icons.sports_esports_rounded;
      case AppCategory.video:
        return Icons.play_circle_rounded;
      case AppCategory.study:
        return Icons.school_rounded;
      case AppCategory.reading:
        return Icons.menu_book_rounded;
      default:
        return Icons.apps_rounded;
    }
  }

  Color _getCategoryColor() {
    switch (summary.category) {
      case AppCategory.game:
        return AppSolidColors.game;
      case AppCategory.video:
        return AppSolidColors.video;
      case AppCategory.study:
        return AppSolidColors.study;
      case AppCategory.reading:
        return AppSolidColors.reading;
      default:
        return AppColors.primary;
    }
  }

  String _getCategoryLabel() {
    switch (summary.category) {
      case AppCategory.game:
        return '游戏';
      case AppCategory.video:
        return '视频';
      case AppCategory.study:
        return '学习';
      case AppCategory.reading:
        return '阅读';
      default:
        return '其他';
    }
  }

  /// 格式化时长
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    if (minutes < 1) return '<1分';
    if (minutes < 60) return '$minutes分';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (remainingMinutes == 0) return '$hours时';
    return '$hours时${remainingMinutes}分';
  }
}
