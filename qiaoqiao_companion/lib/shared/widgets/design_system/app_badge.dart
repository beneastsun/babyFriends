import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_solid_colors.dart';

/// 徽章类型 - Kawaii Dream 风格
enum AppBadgeType {
  /// 圆点徽章 - 小圆点
  dot,
  /// 数字徽章 - 显示数字
  number,
  /// 图标徽章 - 显示图标
  icon,
  /// 文字徽章 - 显示文字
  text,
  /// 发光徽章 - 带发光效果
  glow,
}

/// 徽章尺寸
enum AppBadgeSize {
  small,
  medium,
  large,
}

/// 徽章颜色主题
enum AppBadgeColor {
  primary,
  secondary,
  success,
  warning,
  error,
  info,
}

/// 应用徽章组件 - Kawaii Dream 风格
/// 特点：可爱圆点、弹跳动画、发光效果
class AppBadge extends ConsumerStatefulWidget {
  const AppBadge({
    super.key,
    required this.child,
    this.type = AppBadgeType.dot,
    this.size = AppBadgeSize.medium,
    this.color = AppBadgeColor.primary,
    this.value,
    this.text,
    this.icon,
    this.showAnimation = true,
    this.showGlow = false,
    this.position = AppBadgePosition.topRight,
    this.offset,
  });

  final Widget child;
  final AppBadgeType type;
  final AppBadgeSize size;
  final AppBadgeColor color;
  final int? value;
  final String? text;
  final IconData? icon;
  final bool showAnimation;
  final bool showGlow;
  final AppBadgePosition position;
  final Offset? offset;

  @override
  ConsumerState<AppBadge> createState() => _AppBadgeState();
}

class _AppBadgeState extends ConsumerState<AppBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController? _controller;
  late Animation<double>? _scaleAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.showAnimation) {
      _controller = AnimationController(
        duration: AppAnimations.normal,
        vsync: this,
      );
      _scaleAnimation = TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.3), weight: 0.5),
        TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 0.5),
      ]).animate(CurvedAnimation(
        parent: _controller!,
        curve: AppAnimations.elastic,
      ));
      _controller!.forward();
    } else {
      _controller = null;
      _scaleAnimation = null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final badgeWidget = _buildBadgeWidget(context);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        Positioned(
          top: _getVerticalPosition(),
          right: _getHorizontalPosition(),
          child: widget.offset != null
              ? Transform.translate(
                  offset: widget.offset!,
                  child: badgeWidget,
                )
              : badgeWidget,
        ),
      ],
    );
  }

  double? _getVerticalPosition() {
    if (widget.position == AppBadgePosition.bottomRight ||
        widget.position == AppBadgePosition.bottomLeft) {
      return null;
    }
    return -_getSizeConfig().badgeSize / 2;
  }

  double? _getHorizontalPosition() {
    if (widget.position == AppBadgePosition.topLeft ||
        widget.position == AppBadgePosition.bottomLeft) {
      return null;
    }
    return -_getSizeConfig().badgeSize / 2;
  }

  Widget _buildBadgeWidget(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final badgeColor = _getBadgeColor();
    final sizeConfig = _getSizeConfig();

    Widget badge;

    switch (widget.type) {
      case AppBadgeType.dot:
        badge = Container(
          width: sizeConfig.dotSize,
          height: sizeConfig.dotSize,
          decoration: BoxDecoration(
            color: badgeColor,
            shape: BoxShape.circle,
            boxShadow: widget.showGlow ? _getGlowShadow(badgeColor) : null,
          ),
        );
        break;

      case AppBadgeType.number:
        final displayValue = widget.value?.clamp(1, 99) ?? 0;
        badge = Container(
          constraints: BoxConstraints(
            minWidth: sizeConfig.badgeSize,
            minHeight: sizeConfig.badgeSize,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: badgeColor,
            borderRadius: BorderRadius.circular(DesignTokens.radiusPill),
            boxShadow: widget.showGlow ? _getGlowShadow(badgeColor) : null,
          ),
          child: Center(
            child: Text(
              displayValue > 99 ? '99+' : displayValue.toString(),
              style: AppTextStyles.labelSmall.copyWith(
                color: Colors.white,
                fontSize: sizeConfig.fontSize,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
        break;

      case AppBadgeType.icon:
        badge = Container(
          width: sizeConfig.badgeSize,
          height: sizeConfig.badgeSize,
          decoration: BoxDecoration(
            color: badgeColor,
            shape: BoxShape.circle,
            boxShadow: widget.showGlow ? _getGlowShadow(badgeColor) : null,
          ),
          child: Icon(
            widget.icon ?? Icons.notifications_rounded,
            size: sizeConfig.iconSize,
            color: Colors.white,
          ),
        );
        break;

      case AppBadgeType.text:
        badge = Container(
          constraints: BoxConstraints(
            minWidth: sizeConfig.badgeSize,
            minHeight: sizeConfig.badgeSize,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: badgeColor,
            borderRadius: BorderRadius.circular(DesignTokens.radiusPill),
            boxShadow: widget.showGlow ? _getGlowShadow(badgeColor) : null,
          ),
          child: Center(
            child: Text(
              widget.text ?? '',
              style: AppTextStyles.labelSmall.copyWith(
                color: Colors.white,
                fontSize: sizeConfig.fontSize,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
        break;

      case AppBadgeType.glow:
        badge = Container(
          width: sizeConfig.badgeSize,
          height: sizeConfig.badgeSize,
          decoration: BoxDecoration(
            color: badgeColor,
            shape: BoxShape.circle,
            boxShadow: _getGlowShadow(badgeColor),
          ),
          child: widget.icon != null
              ? Icon(widget.icon, size: sizeConfig.iconSize, color: Colors.white)
              : null,
        );
        break;
    }

    // 添加动画
    if (widget.showAnimation && _scaleAnimation != null) {
      badge = AnimatedBuilder(
        animation: _scaleAnimation!,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation!.value,
            child: child,
          );
        },
        child: badge,
      );
    }

    return badge;
  }

  Color _getBadgeColor() {
    switch (widget.color) {
      case AppBadgeColor.primary:
        return AppColors.primary;
      case AppBadgeColor.secondary:
        return AppColors.secondary;
      case AppBadgeColor.success:
        return AppSolidColors.success;
      case AppBadgeColor.warning:
        return AppSolidColors.warning;
      case AppBadgeColor.error:
        return AppSolidColors.error;
      case AppBadgeColor.info:
        return AppSolidColors.info;
    }
  }

  List<BoxShadow> _getGlowShadow(Color color) {
    return [
      BoxShadow(
        color: color.withOpacity(0.5),
        blurRadius: 8,
        spreadRadius: 1,
      ),
    ];
  }

  _BadgeSizeConfig _getSizeConfig() {
    switch (widget.size) {
      case AppBadgeSize.small:
        return const _BadgeSizeConfig(
          dotSize: 6,
          badgeSize: 16,
          fontSize: 10,
          iconSize: 10,
        );
      case AppBadgeSize.medium:
        return const _BadgeSizeConfig(
          dotSize: 8,
          badgeSize: 20,
          fontSize: 11,
          iconSize: 12,
        );
      case AppBadgeSize.large:
        return const _BadgeSizeConfig(
          dotSize: 10,
          badgeSize: 24,
          fontSize: 12,
          iconSize: 14,
        );
    }
  }
}

class _BadgeSizeConfig {
  final double dotSize;
  final double badgeSize;
  final double fontSize;
  final double iconSize;

  const _BadgeSizeConfig({
    required this.dotSize,
    required this.badgeSize,
    required this.fontSize,
    required this.iconSize,
  });
}

/// 徽章位置
enum AppBadgePosition {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}

// ============================================================
// 便捷徽章组件
// ============================================================

/// 通知徽章 - 显示未读数量
class NotificationBadge extends ConsumerWidget {
  const NotificationBadge({
    super.key,
    required this.child,
    required this.count,
    this.size = AppBadgeSize.medium,
    this.showAnimation = true,
    this.showGlow = true,
  });

  final Widget child;
  final int count;
  final AppBadgeSize size;
  final bool showAnimation;
  final bool showGlow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (count <= 0) return child;

    return AppBadge(
      type: AppBadgeType.number,
      value: count,
      size: size,
      color: AppBadgeColor.error,
      showAnimation: showAnimation,
      showGlow: showGlow,
      child: child,
    );
  }
}

/// 新消息徽章 - 小红点
class NewBadge extends ConsumerWidget {
  const NewBadge({
    super.key,
    required this.child,
    this.size = AppBadgeSize.small,
    this.showAnimation = true,
    this.showGlow = true,
  });

  final Widget child;
  final AppBadgeSize size;
  final bool showAnimation;
  final bool showGlow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppBadge(
      type: AppBadgeType.dot,
      size: size,
      color: AppBadgeColor.error,
      showAnimation: showAnimation,
      showGlow: showGlow,
      child: child,
    );
  }
}

/// 积分徽章 - 显示积分变化
class PointsBadge extends ConsumerStatefulWidget {
  const PointsBadge({
    super.key,
    required this.points,
    this.size = AppBadgeSize.medium,
    this.showAnimation = true,
    this.onTap,
  });

  final int points;
  final AppBadgeSize size;
  final bool showAnimation;
  final VoidCallback? onTap;

  @override
  ConsumerState<PointsBadge> createState() => _PointsBadgeState();
}

class _PointsBadgeState extends ConsumerState<PointsBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController? _controller;
  late Animation<double>? _scaleAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.showAnimation) {
      _controller = AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      );
      _scaleAnimation = TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 0.4),
        TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 0.6),
      ]).animate(CurvedAnimation(
        parent: _controller!,
        curve: AppAnimations.elastic,
      ));
      _controller!.forward();
    } else {
      _controller = null;
      _scaleAnimation = null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEarned = widget.points > 0;
    final color =
        isEarned ? AppSolidColors.pointsEarned : AppSolidColors.pointsSpent;
    final bgColor = isEarned
        ? AppSolidColors.pointsEarned.withOpacity(0.15)
        : AppSolidColors.pointsSpent.withOpacity(0.15);
    final iconData = isEarned
        ? Icons.arrow_upward_rounded
        : Icons.arrow_downward_rounded;

    final sizeConfig = _getSizeConfig();

    Widget badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(DesignTokens.radiusPill),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 6,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            iconData,
            size: sizeConfig.iconSize,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            '${isEarned ? '+' : ''}${widget.points}',
            style: AppTextStyles.labelMedium.copyWith(
              color: color,
              fontSize: sizeConfig.fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    if (widget.showAnimation && _scaleAnimation != null) {
      badge = AnimatedBuilder(
        animation: _scaleAnimation!,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation!.value,
            child: child,
          );
        },
        child: badge,
      );
    }

    if (widget.onTap != null) {
      badge = GestureDetector(onTap: widget.onTap, child: badge);
    }

    return badge;
  }

  _BadgeSizeConfig _getSizeConfig() {
    switch (widget.size) {
      case AppBadgeSize.small:
        return const _BadgeSizeConfig(
          dotSize: 6,
          badgeSize: 16,
          fontSize: 10,
          iconSize: 10,
        );
      case AppBadgeSize.medium:
        return const _BadgeSizeConfig(
          dotSize: 8,
          badgeSize: 20,
          fontSize: 12,
          iconSize: 14,
        );
      case AppBadgeSize.large:
        return const _BadgeSizeConfig(
          dotSize: 10,
          badgeSize: 24,
          fontSize: 14,
          iconSize: 16,
        );
    }
  }
}

/// 成就徽章 - 显示成就等级
class AchievementBadge extends ConsumerWidget {
  const AchievementBadge({
    super.key,
    required this.level,
    this.size = AppBadgeSize.medium,
    this.showGlow = true,
  });

  final int level;
  final AppBadgeSize size;
  final bool showGlow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (medalColor, medalLightColor) = _getMedalColors();
    final sizeConfig = _getSizeConfig();

    return Container(
      width: sizeConfig.badgeSize,
      height: sizeConfig.badgeSize,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [medalColor, medalLightColor],
        ),
        shape: BoxShape.circle,
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: medalColor.withOpacity(0.4),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Center(
        child: Text(
          'Lv.$level',
          style: AppTextStyles.labelSmall.copyWith(
            color: Colors.white,
            fontSize: sizeConfig.fontSize,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  (Color, Color) _getMedalColors() {
    if (level >= 10) {
      return (AppSolidColors.gold, AppSolidColors.goldLight);
    } else if (level >= 5) {
      return (AppSolidColors.silver, AppSolidColors.silverLight);
    } else {
      return (AppSolidColors.bronze, AppSolidColors.bronzeLight);
    }
  }

  _BadgeSizeConfig _getSizeConfig() {
    switch (size) {
      case AppBadgeSize.small:
        return const _BadgeSizeConfig(
          dotSize: 6,
          badgeSize: 24,
          fontSize: 8,
          iconSize: 10,
        );
      case AppBadgeSize.medium:
        return const _BadgeSizeConfig(
          dotSize: 8,
          badgeSize: 32,
          fontSize: 10,
          iconSize: 14,
        );
      case AppBadgeSize.large:
        return const _BadgeSizeConfig(
          dotSize: 10,
          badgeSize: 40,
          fontSize: 12,
          iconSize: 16,
        );
    }
  }
}

/// 状态徽章 - 在线/离线等
class StatusBadge extends ConsumerWidget {
  const StatusBadge({
    super.key,
    required this.child,
    required this.isOnline,
    this.size = AppBadgeSize.medium,
    this.showGlow = true,
  });

  final Widget child;
  final bool isOnline;
  final AppBadgeSize size;
  final bool showGlow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = isOnline ? AppSolidColors.success : AppColors.textHintLight;
    final dotSize = size == AppBadgeSize.small
        ? 8.0
        : size == AppBadgeSize.medium
            ? 10.0
            : 12.0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 2,
              ),
              boxShadow: showGlow && isOnline
                  ? [
                      BoxShadow(
                        color: statusColor.withOpacity(0.5),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}
