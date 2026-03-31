import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/theme_provider.dart';

/// 应用标签组件
class AppChip extends ConsumerWidget {
  const AppChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onSelected,
    this.icon,
    this.onDeleted,
    this.isEnabled = true,
    this.type = AppChipType.default_,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final Widget? icon;
  final VoidCallback? onDeleted;
  final bool isEnabled;
  final AppChipType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = ref.watch(colorSchemeProvider);

    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: isEnabled ? onSelected : null,
      avatar: icon,
      onDeleted: onDeleted,
      backgroundColor: _getBackgroundColor(isDark, colors),
      selectedColor: _getSelectedColor(isDark, colors),
      disabledColor: isDark
          ? AppColors.borderDark.withOpacity(0.5)
          : AppColors.borderLight.withOpacity(0.5),
      labelStyle: AppTextStyles.labelMedium.copyWith(
        color: selected
            ? Colors.white
            : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
      ),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusCapsule),
      ),
    );
  }

  Color _getBackgroundColor(bool isDark, ColorSchemeConfig colors) {
    if (selected) {
      return isDark ? colors.primaryDark : colors.primary;
    }
    return isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
  }

  Color _getSelectedColor(bool isDark, ColorSchemeConfig colors) {
    switch (type) {
      case AppChipType.default_:
        return isDark ? colors.primaryDark : colors.primary;
      case AppChipType.success:
        return AppColors.success;
      case AppChipType.warning:
        return AppColors.warning;
      case AppChipType.error:
        return AppColors.error;
    }
  }
}

/// 标签类型
enum AppChipType {
  default_,
  success,
  warning,
  error,
}

/// 分类标签
class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.category,
    this.selected = false,
    this.onSelected,
  });

  final String category;
  final bool selected;
  final ValueChanged<bool>? onSelected;

  @override
  Widget build(BuildContext context) {
    final categoryColor = AppColors.getCategoryColor(category);

    return FilterChip(
      label: Text(_getCategoryLabel(category)),
      selected: selected,
      onSelected: onSelected,
      backgroundColor: categoryColor.withOpacity(0.15),
      selectedColor: categoryColor,
      labelStyle: AppTextStyles.labelMedium.copyWith(
        color: selected ? Colors.white : categoryColor,
      ),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusCapsule),
      ),
    );
  }

  String _getCategoryLabel(String category) {
    switch (category.toLowerCase()) {
      case 'game':
        return '游戏';
      case 'video':
        return '视频';
      case 'study':
        return '学习';
      case 'reading':
        return '阅读';
      default:
        return '其他';
    }
  }
}

/// 状态标签
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.status,
    this.icon,
  });

  final String label;
  final ChipStatus status;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.space8,
        vertical: DesignTokens.space4,
      ),
      decoration: BoxDecoration(
        color: _getStatusColor(isDark).withOpacity(0.15),
        borderRadius: BorderRadius.circular(DesignTokens.radiusCapsule),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 14,
              color: _getStatusColor(isDark),
            ),
            SizedBox(width: DesignTokens.space4),
          ],
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: _getStatusColor(isDark),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(bool isDark) {
    switch (status) {
      case ChipStatus.success:
        return isDark ? AppColors.successDarkMode : AppColors.success;
      case ChipStatus.warning:
        return isDark ? AppColors.warningDarkMode : AppColors.warning;
      case ChipStatus.error:
        return isDark ? AppColors.errorDarkMode : AppColors.error;
      case ChipStatus.info:
        return isDark ? AppColors.infoDarkMode : AppColors.info;
    }
  }
}

/// 标签状态
enum ChipStatus {
  success,
  warning,
  error,
  info,
}

/// 积分变化标签
class PointsChangeChip extends StatelessWidget {
  const PointsChangeChip({
    super.key,
    required this.points,
    this.isEarned = true,
  });

  final int points;
  final bool isEarned;

  @override
  Widget build(BuildContext context) {
    final color = isEarned ? AppColors.pointsEarned : AppColors.pointsSpent;
    final prefix = isEarned ? '+' : '-';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.space8,
        vertical: DesignTokens.space2,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(DesignTokens.radiusCapsule),
      ),
      child: Text(
        '$prefix$points',
        style: AppTextStyles.labelMedium.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// 时间标签
class TimeBadge extends StatelessWidget {
  const TimeBadge({
    super.key,
    required this.minutes,
    this.limitMinutes,
    this.showProgress = false,
  });

  final int minutes;
  final int? limitMinutes;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final usagePercent = limitMinutes != null && limitMinutes! > 0
        ? minutes / limitMinutes!
        : 0.0;

    Color getBadgeColor() {
      if (usagePercent < 0.7) {
        return AppColors.success;
      } else if (usagePercent < 0.9) {
        return AppColors.warning;
      } else {
        return AppColors.error;
      }
    }

    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    final timeText = hours > 0 ? '${hours}h${mins}m' : '${mins}m';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.space8,
        vertical: DesignTokens.space4,
      ),
      decoration: BoxDecoration(
        color: getBadgeColor().withOpacity(0.15),
        borderRadius: BorderRadius.circular(DesignTokens.radius8),
      ),
      child: Text(
        timeText,
        style: AppTextStyles.labelMedium.copyWith(
          color: getBadgeColor(),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
