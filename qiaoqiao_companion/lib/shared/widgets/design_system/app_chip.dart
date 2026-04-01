import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_solid_colors.dart';
import '../../providers/theme_provider.dart';

/// 标签类型 - Kawaii Dream 风格
enum AppChipType {
  /// 填充标签 - 纯色背景
  filled,
  /// 描边标签 - 边框样式
  outlined,
  /// 幽灵标签 - 透明背景
  ghost,
  /// 渐变标签 - 粉紫渐变
  gradient,
  /// 分类标签 - 根据分类自动变色
  category,
}

/// 标签尺寸
enum AppChipSize {
  small,
  medium,
  large,
}

/// 应用标签组件 - Kawaii Dream 风格
/// 特点：胶囊形状、选中动画、发光效果
class AppChip extends ConsumerStatefulWidget {
  const AppChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onSelected,
    this.icon,
    this.onDeleted,
    this.isEnabled = true,
    this.type = AppChipType.filled,
    this.size = AppChipSize.medium,
    this.category,
    this.showGlow = false,
    this.onTap,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final Widget? icon;
  final VoidCallback? onDeleted;
  final bool isEnabled;
  final AppChipType type;
  final AppChipSize size;
  final String? category;
  final bool showGlow;
  final VoidCallback? onTap;

  @override
  ConsumerState<AppChip> createState() => _AppChipState();
}

class _AppChipState extends ConsumerState<AppChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppAnimations.quick,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: AppAnimations.elastic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (!widget.isEnabled) return;
    setState(() => _isPressed = true);
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  _ChipSizeConfig get _sizeConfig {
    switch (widget.size) {
      case AppChipSize.small:
        return const _ChipSizeConfig(
          height: 28,
          paddingHorizontal: DesignTokens.space8,
          fontSize: 12,
          iconSize: 14,
        );
      case AppChipSize.medium:
        return const _ChipSizeConfig(
          height: 36,
          paddingHorizontal: DesignTokens.space12,
          fontSize: 14,
          iconSize: 18,
        );
      case AppChipSize.large:
        return const _ChipSizeConfig(
          height: 44,
          paddingHorizontal: DesignTokens.space16,
          fontSize: 16,
          iconSize: 20,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeType = ref.watch(themeTypeProvider);

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: () {
        widget.onTap?.call();
        if (widget.onSelected != null) {
          widget.onSelected!(!widget.selected);
        }
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: AnimatedContainer(
          duration: AppAnimations.quick,
          curve: Curves.easeOutCubic,
          height: _sizeConfig.height,
          padding: EdgeInsets.symmetric(horizontal: _sizeConfig.paddingHorizontal),
          decoration: _buildDecoration(isDark, themeType),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                IconTheme(
                  data: IconThemeData(
                    size: _sizeConfig.iconSize,
                    color: _getIconColor(isDark, themeType),
                  ),
                  child: widget.icon!,
                ),
                const SizedBox(width: DesignTokens.space4),
              ],
              Text(
                widget.label,
                style: AppTextStyles.labelMedium.copyWith(
                  fontSize: _sizeConfig.fontSize,
                  color: _getTextColor(isDark, themeType),
                  fontWeight:
                      widget.selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              if (widget.onDeleted != null) ...[
                const SizedBox(width: DesignTokens.space4),
                GestureDetector(
                  onTap: widget.onDeleted,
                  child: Icon(
                    Icons.close_rounded,
                    size: _sizeConfig.iconSize,
                    color: _getTextColor(isDark, themeType).withOpacity(0.7),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration _buildDecoration(bool isDark, AppThemeType themeType) {
    final borderRadius = BorderRadius.circular(DesignTokens.radiusPill);
    final primaryColor = AppSolidColors.getPrimaryColor(themeType, isDark);
    final categoryColor = widget.category != null
        ? AppSolidColors.getCategoryColor(widget.category!)
        : primaryColor;

    List<BoxShadow>? shadows;
    if (widget.showGlow || widget.selected) {
      final glowColor = widget.type == AppChipType.category
          ? categoryColor
          : primaryColor;
      shadows = [
        BoxShadow(
          color: glowColor.withOpacity(0.3),
          blurRadius: 8,
          spreadRadius: 1,
        ),
      ];
    }

    switch (widget.type) {
      case AppChipType.filled:
        return BoxDecoration(
          color: widget.selected
              ? primaryColor
              : primaryColor.withOpacity(0.15),
          borderRadius: borderRadius,
          boxShadow: shadows,
        );

      case AppChipType.outlined:
        return BoxDecoration(
          color: widget.selected
              ? primaryColor.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: borderRadius,
          border: Border.all(
            color: widget.selected
                ? primaryColor
                : primaryColor.withOpacity(0.5),
            width: 1.5,
          ),
          boxShadow: shadows,
        );

      case AppChipType.ghost:
        return BoxDecoration(
          color: widget.selected
              ? primaryColor.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: borderRadius,
          boxShadow: shadows,
        );

      case AppChipType.gradient:
        if (widget.selected) {
          return BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppSolidColors.getPrimaryColor(themeType, isDark),
                AppSolidColors.getSecondaryColor(themeType, isDark),
              ],
            ),
            borderRadius: borderRadius,
            boxShadow: shadows,
          );
        }
        return BoxDecoration(
          color: Colors.transparent,
          borderRadius: borderRadius,
          border: Border.all(
            color: primaryColor.withOpacity(0.3),
            width: 1,
          ),
        );

      case AppChipType.category:
        return BoxDecoration(
          color: widget.selected
              ? categoryColor
              : categoryColor.withOpacity(0.15),
          borderRadius: borderRadius,
          boxShadow: shadows,
        );
    }
  }

  Color _getTextColor(bool isDark, AppThemeType themeType) {
    if (!widget.isEnabled) {
      return isDark
          ? AppColors.textHintDark.withOpacity(0.5)
          : AppColors.textHintLight.withOpacity(0.5);
    }

    final primaryColor = AppSolidColors.getPrimaryColor(themeType, isDark);
    final categoryColor = widget.category != null
        ? AppSolidColors.getCategoryColor(widget.category!)
        : primaryColor;

    switch (widget.type) {
      case AppChipType.filled:
      case AppChipType.gradient:
      case AppChipType.category:
        return widget.selected ? Colors.white : categoryColor;
      case AppChipType.outlined:
      case AppChipType.ghost:
        return primaryColor;
    }
  }

  Color _getIconColor(bool isDark, AppThemeType themeType) {
    return _getTextColor(isDark, themeType);
  }
}

class _ChipSizeConfig {
  final double height;
  final double paddingHorizontal;
  final double fontSize;
  final double iconSize;

  const _ChipSizeConfig({
    required this.height,
    required this.paddingHorizontal,
    required this.fontSize,
    required this.iconSize,
  });
}

/// 分类标签 - 根据分类自动变色
class CategoryChip extends ConsumerWidget {
  const CategoryChip({
    super.key,
    required this.category,
    this.selected = false,
    this.onSelected,
    this.size = AppChipSize.medium,
  });

  final String category;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final AppChipSize size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppChip(
      label: _getCategoryLabel(category),
      category: category,
      selected: selected,
      onSelected: onSelected,
      type: AppChipType.category,
      size: size,
      showGlow: selected,
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
        return category;
    }
  }
}

/// 状态标签 - 用于显示状态信息
class StatusChip extends ConsumerWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.status,
    this.size = AppChipSize.medium,
  });

  final String label;
  final ChipStatus status;
  final AppChipSize size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: _getHeight(),
      padding: EdgeInsets.symmetric(horizontal: _getPadding()),
      decoration: BoxDecoration(
        color: _getBackgroundColor(isDark),
        borderRadius: BorderRadius.circular(DesignTokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: _getStatusColor(),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: DesignTokens.space6),
          Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              fontSize: _getFontSize(),
              color: _getTextColor(isDark),
            ),
          ),
        ],
      ),
    );
  }

  double _getHeight() {
    switch (size) {
      case AppChipSize.small:
        return 24;
      case AppChipSize.medium:
        return 32;
      case AppChipSize.large:
        return 40;
    }
  }

  double _getPadding() {
    switch (size) {
      case AppChipSize.small:
        return DesignTokens.space8;
      case AppChipSize.medium:
        return DesignTokens.space12;
      case AppChipSize.large:
        return DesignTokens.space16;
    }
  }

  double _getFontSize() {
    switch (size) {
      case AppChipSize.small:
        return 11;
      case AppChipSize.medium:
        return 12;
      case AppChipSize.large:
        return 14;
    }
  }

  Color _getStatusColor() {
    switch (status) {
      case ChipStatus.success:
        return AppSolidColors.success;
      case ChipStatus.warning:
        return AppSolidColors.warning;
      case ChipStatus.error:
        return AppSolidColors.error;
      case ChipStatus.info:
        return AppSolidColors.info;
      case ChipStatus.neutral:
        return AppColors.textSecondaryLight;
    }
  }

  Color _getBackgroundColor(bool isDark) {
    return _getStatusColor().withOpacity(isDark ? 0.2 : 0.1);
  }

  Color _getTextColor(bool isDark) {
    return isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
  }
}

/// 标签状态
enum ChipStatus {
  success,
  warning,
  error,
  info,
  neutral,
}

/// 积分标签 - 显示积分变化
class PointsChip extends ConsumerWidget {
  const PointsChip({
    super.key,
    required this.points,
    this.size = AppChipSize.medium,
    this.showIcon = true,
  });

  final int points;
  final AppChipSize size;
  final bool showIcon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEarned = points > 0;
    final color = isEarned
        ? AppSolidColors.pointsEarned
        : AppSolidColors.pointsSpent;
    final bgColor = isEarned
        ? AppSolidColors.pointsEarned.withOpacity(0.15)
        : AppSolidColors.pointsSpent.withOpacity(0.15);

    return Container(
      height: _getHeight(),
      padding: EdgeInsets.symmetric(horizontal: _getPadding()),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(DesignTokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(
              isEarned
                  ? Icons.add_circle_rounded
                  : Icons.remove_circle_rounded,
              size: _getIconSize(),
              color: color,
            ),
            const SizedBox(width: DesignTokens.space4),
          ],
          Text(
            '${isEarned ? '+' : ''}${points.abs()}',
            style: AppTextStyles.labelLarge.copyWith(
              fontSize: _getFontSize(),
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  double _getHeight() {
    switch (size) {
      case AppChipSize.small:
        return 24;
      case AppChipSize.medium:
        return 32;
      case AppChipSize.large:
        return 40;
    }
  }

  double _getPadding() {
    switch (size) {
      case AppChipSize.small:
        return DesignTokens.space8;
      case AppChipSize.medium:
        return DesignTokens.space12;
      case AppChipSize.large:
        return DesignTokens.space16;
    }
  }

  double _getFontSize() {
    switch (size) {
      case AppChipSize.small:
        return 12;
      case AppChipSize.medium:
        return 14;
      case AppChipSize.large:
        return 16;
    }
  }

  double _getIconSize() {
    switch (size) {
      case AppChipSize.small:
        return 14;
      case AppChipSize.medium:
        return 16;
      case AppChipSize.large:
        return 18;
    }
  }
}

/// 标签组 - 用于选择多个标签
class AppChipGroup extends ConsumerStatefulWidget {
  const AppChipGroup({
    super.key,
    required this.chips,
    required this.selectedChips,
    this.onSelectionChanged,
    this.multiselect = true,
    this.type = AppChipType.filled,
    this.size = AppChipSize.medium,
    this.spacing = DesignTokens.space8,
    this.runSpacing = DesignTokens.space8,
  });

  final List<String> chips;
  final List<String> selectedChips;
  final ValueChanged<List<String>>? onSelectionChanged;
  final bool multiselect;
  final AppChipType type;
  final AppChipSize size;
  final double spacing;
  final double runSpacing;

  @override
  ConsumerState<AppChipGroup> createState() => _AppChipGroupState();
}

class _AppChipGroupState extends ConsumerState<AppChipGroup> {
  late List<String> _selectedChips;

  @override
  void initState() {
    super.initState();
    _selectedChips = List.from(widget.selectedChips);
  }

  void _handleChipSelected(String chip, bool selected) {
    setState(() {
      if (widget.multiselect) {
        if (selected) {
          _selectedChips.add(chip);
        } else {
          _selectedChips.remove(chip);
        }
      } else {
        _selectedChips.clear();
        if (selected) {
          _selectedChips.add(chip);
        }
      }
    });
    widget.onSelectionChanged?.call(_selectedChips);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: widget.spacing,
      runSpacing: widget.runSpacing,
      children: widget.chips.map((chip) {
        return AppChip(
          label: chip,
          selected: _selectedChips.contains(chip),
          onSelected: (selected) => _handleChipSelected(chip, selected),
          type: widget.type,
          size: widget.size,
        );
      }).toList(),
    );
  }
}
