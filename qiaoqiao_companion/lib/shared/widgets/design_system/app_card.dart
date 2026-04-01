import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_solid_colors.dart';
import '../../providers/theme_provider.dart';

/// 卡片类型 - Kawaii Dream 风格
enum AppCardType {
  /// 标准卡片 - 平面柔和阴影
  standard,
  /// 提升卡片 - 更明显的阴影
  elevated,
  /// 填充卡片 - 纯色背景
  filled,
  /// 描边卡片 - 粉色边框
  outlined,
  /// 渐变卡片 - 粉紫渐变 + 发光
  gradient,
  /// 玻璃拟态卡片
  glass,
  /// 交互卡片 - 带弹跳动画
  interactive,
  /// 用户卡片 - 人物信息展示
  user,
  /// 概览卡片 - 统计数据
  overview,
}

/// 应用卡片组件 - Kawaii Dream 风格
/// 特点：超大圆角、柔和粉紫阴影、可爱动画
class AppCard extends ConsumerStatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.type = AppCardType.standard,
    this.padding,
    this.margin,
    this.color,
    this.onTap,
    this.onLongPress,
    this.isEnabled = true,
    this.showShadow = true,
    this.borderRadius,
    this.showGlow = false,
  });

  final Widget child;
  final AppCardType type;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isEnabled;
  final bool showShadow;
  final double? borderRadius;
  final bool showGlow;

  @override
  ConsumerState<AppCard> createState() => _AppCardState();
}

class _AppCardState extends ConsumerState<AppCard>
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
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: AppAnimations.elastic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap == null || !widget.isEnabled) return;
    setState(() => _isPressed = true);
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  double get _borderRadius {
    if (widget.borderRadius != null) return widget.borderRadius!;
    // 根据卡片类型默认圆角
    switch (widget.type) {
      case AppCardType.gradient:
      case AppCardType.overview:
      case AppCardType.user:
        return DesignTokens.radius20;
      case AppCardType.glass:
        return DesignTokens.radius24;
      default:
        return DesignTokens.radius16;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeType = ref.watch(themeTypeProvider);
    final colors = ref.watch(colorSchemeProvider);

    Widget card = Container(
      padding: widget.padding ?? const EdgeInsets.all(DesignTokens.cardPadding),
      decoration: _buildDecoration(isDark, themeType, colors),
      child: widget.child,
    );

    // 添加交互动画
    if ((widget.type == AppCardType.interactive || widget.onTap != null) &&
        widget.isEnabled) {
      card = GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: child,
            );
          },
          child: card,
        ),
      );
    }

    // 添加外边距
    if (widget.margin != null) {
      card = Padding(
        padding: widget.margin!,
        child: card,
      );
    }

    return card;
  }

  BoxDecoration _buildDecoration(bool isDark, AppThemeType themeType, ColorSchemeConfig colors) {
    final borderRadius = BorderRadius.circular(_borderRadius);
    final cardColor = widget.color ?? AppSolidColors.getPrimaryColor(themeType, isDark);
    List<BoxShadow>? shadows;

    switch (widget.type) {
      case AppCardType.standard:
        shadows = widget.showShadow && !isDark ? AppShadows.card : null;
        return BoxDecoration(
          color: isDark ? colors.cardDark : colors.cardLight,
          borderRadius: borderRadius,
          boxShadow: shadows,
        );

      case AppCardType.elevated:
        shadows = widget.showShadow && !isDark ? AppShadows.cardElevated : null;
        return BoxDecoration(
          color: isDark ? colors.cardDark : colors.cardLight,
          borderRadius: borderRadius,
          boxShadow: shadows,
        );

      case AppCardType.filled:
        shadows = widget.showShadow && !isDark && widget.showGlow
            ? AppShadows.cardGradient
            : (widget.showShadow ? AppShadows.card : null);
        return BoxDecoration(
          color: cardColor,
          borderRadius: borderRadius,
          boxShadow: shadows,
        );

      case AppCardType.outlined:
        return BoxDecoration(
          color: isDark ? colors.cardDark : colors.cardLight,
          borderRadius: borderRadius,
          border: Border.all(
            color: isDark
                ? AppSolidColors.getPrimaryColor(themeType, isDark).withOpacity(0.5)
                : AppSolidColors.getPrimaryColor(themeType, isDark),
            width: 1.5,
          ),
        );

      case AppCardType.gradient:
        shadows = widget.showShadow && !isDark ? AppShadows.cardGradient : null;
        final gradient = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppSolidColors.getPrimaryColor(themeType, isDark),
            AppSolidColors.getSecondaryColor(themeType, isDark),
          ],
        );
        return BoxDecoration(
          gradient: gradient,
          borderRadius: borderRadius,
          boxShadow: shadows,
        );

      case AppCardType.glass:
        return BoxDecoration(
          color: isDark
              ? AppColors.glassBackgroundDark
              : AppColors.glassBackgroundLight,
          borderRadius: borderRadius,
          border: Border.all(
            color: isDark
                ? AppColors.glassBorderDark
                : AppColors.glassBorderLight,
            width: 1,
          ),
          boxShadow: widget.showShadow ? AppShadows.dialogGlass : null,
        );

      case AppCardType.interactive:
        shadows = widget.showShadow && !isDark
            ? (_isPressed ? AppShadows.card : AppShadows.cardInteractive)
            : null;
        return BoxDecoration(
          color: isDark ? colors.cardDark : colors.cardLight,
          borderRadius: borderRadius,
          boxShadow: shadows,
        );

      case AppCardType.user:
        shadows = widget.showShadow && !isDark ? AppShadows.cardUser : null;
        return BoxDecoration(
          color: isDark ? colors.cardDark : colors.cardLight,
          borderRadius: borderRadius,
          boxShadow: shadows,
        );

      case AppCardType.overview:
        shadows = widget.showShadow && !isDark ? AppShadows.cardOverview : null;
        final gradient = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cardColor,
            AppSolidColors.getPrimaryLightColor(themeType, isDark),
          ],
        );
        return BoxDecoration(
          gradient: gradient,
          borderRadius: borderRadius,
          boxShadow: shadows,
        );
    }
  }
}

// ============================================================
// 特殊卡片组件
// ============================================================

/// 概览卡片 - 用于展示统计数据
class OverviewCard extends ConsumerWidget {
  const OverviewCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.icon,
    this.color,
    this.onTap,
    this.padding,
    this.margin,
  });

  final String title;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final Color? color;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeType = ref.watch(themeTypeProvider);
    final cardColor = color ?? AppSolidColors.getPrimaryColor(themeType, isDark);

    return AppCard(
      type: AppCardType.overview,
      color: cardColor,
      padding: padding ?? const EdgeInsets.all(DesignTokens.space20),
      margin: margin,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 20,
                  color: Colors.white.withOpacity(0.9),
                ),
                const SizedBox(width: DesignTokens.space8),
              ],
              Text(
                title,
                style: AppTextStyles.labelMedium.copyWith(
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.space12),
          Text(
            value,
            style: AppTextStyles.points.copyWith(color: Colors.white),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: DesignTokens.space4),
            Text(
              subtitle!,
              style: AppTextStyles.bodySmall.copyWith(
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 玻璃拟态卡片
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.blur = 12,
    this.onTap,
    this.borderRadius,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double blur;
  final VoidCallback? onTap;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      type: AppCardType.glass,
      padding: padding,
      margin: margin,
      onTap: onTap,
      borderRadius: borderRadius,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius ?? DesignTokens.radius16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: child,
        ),
      ),
    );
  }
}

/// 用户卡片 - 用于展示用户信息
class UserCard extends ConsumerWidget {
  const UserCard({
    super.key,
    required this.avatar,
    required this.name,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.padding,
    this.margin,
  });

  final Widget avatar;
  final String name;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppCard(
      type: AppCardType.user,
      padding: padding ?? const EdgeInsets.all(DesignTokens.space16),
      margin: margin,
      onTap: onTap,
      child: Row(
        children: [
          // 头像
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: AppShadows.glowPrimary,
            ),
            child: avatar,
          ),
          const SizedBox(width: DesignTokens.space16),
          // 信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTextStyles.heading3.copyWith(
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: DesignTokens.space4),
                  Text(
                    subtitle!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // 尾部组件
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// 统计卡片 - 带图标的统计数据
class StatCard extends ConsumerWidget {
  const StatCard({
    super.key,
    required this.title,
    required this.value,
    this.icon,
    this.iconColor,
    this.backgroundColor,
    this.onTap,
  });

  final String title;
  final String value;
  final IconData? icon;
  final Color? iconColor;
  final Color? backgroundColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeType = ref.watch(themeTypeProvider);
    final colors = ref.watch(colorSchemeProvider);

    return AppCard(
      type: AppCardType.interactive,
      onTap: onTap,
      padding: const EdgeInsets.all(DesignTokens.space20),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: (iconColor ?? AppSolidColors.getPrimaryColor(themeType, isDark))
                    .withOpacity(0.15),
                borderRadius: BorderRadius.circular(DesignTokens.radius12),
              ),
              child: Icon(
                icon,
                color: iconColor ?? AppSolidColors.getPrimaryColor(themeType, isDark),
                size: 24,
              ),
            ),
            const SizedBox(width: DesignTokens.space16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: DesignTokens.space4),
                Text(
                  value,
                  style: AppTextStyles.heading1.copyWith(
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 向后兼容
// ============================================================

/// @deprecated 使用 OverviewCard 替代
typedef GradientOverviewCard = OverviewCard;
