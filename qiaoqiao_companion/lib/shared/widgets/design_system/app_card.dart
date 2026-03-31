import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_solid_colors.dart';
import '../../providers/theme_provider.dart';

/// 卡片类型 - Material 3 风格
enum AppCardType {
  /// 标准卡片 - 平面
  standard,
  /// 提升卡片 - 带阴影
  elevated,
  /// 填充卡片 - 主色背景
  filled,
  /// 描边卡片 - 边框
  outlined,
  /// 玻璃拟态卡片
  glass,
  /// 交互卡片 - 带动画
  interactive,
}

/// 应用卡片组件 - Material 3 风格
class AppCard extends ConsumerStatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.type = AppCardType.standard,
    this.padding,
    this.margin,
    this.color, // 纯色替代渐变
    this.onTap,
    this.onLongPress,
    this.isEnabled = true,
    this.showShadow = true,
    this.borderRadius,
  });

  final Widget child;
  final AppCardType type;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color; // 纯色
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isEnabled;
  final bool showShadow;
  final double? borderRadius;

  @override
  ConsumerState<AppCard> createState() => _AppCardState();
}

class _AppCardState extends ConsumerState<AppCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: DesignTokens.animationQuick,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap == null || !widget.isEnabled) return;
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  double get _borderRadius =>
      widget.borderRadius ?? DesignTokens.radius12;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget card = Container(
      padding: widget.padding ?? const EdgeInsets.all(DesignTokens.cardPadding),
      decoration: _buildDecoration(isDark),
      child: widget.child,
    );

    // 添加动画
    if (widget.type == AppCardType.interactive && widget.onTap != null) {
      card = GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: widget.isEnabled ? widget.onTap : null,
        onLongPress: widget.isEnabled ? widget.onLongPress : null,
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
    } else if (widget.onTap != null) {
      card = InkWell(
        onTap: widget.isEnabled ? widget.onTap : null,
        onLongPress: widget.isEnabled ? widget.onLongPress : null,
        borderRadius: BorderRadius.circular(_borderRadius),
        child: card,
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

  BoxDecoration _buildDecoration(bool isDark) {
    final borderRadius = BorderRadius.circular(_borderRadius);
    final themeType = ref.watch(themeTypeProvider);
    final colors = ref.watch(colorSchemeProvider);
    final cardColor = widget.color ?? AppSolidColors.getPrimaryColor(themeType, isDark);

    switch (widget.type) {
      case AppCardType.standard:
        return BoxDecoration(
          color: isDark ? colors.cardDark : colors.cardLight,
          borderRadius: borderRadius,
          boxShadow: widget.showShadow && !isDark ? AppShadows.card : null,
        );

      case AppCardType.elevated:
        return BoxDecoration(
          color: isDark ? colors.cardDark : colors.cardLight,
          borderRadius: borderRadius,
          boxShadow: widget.showShadow && !isDark
              ? AppShadows.cardInteractive
              : null,
        );

      case AppCardType.filled:
        return BoxDecoration(
          color: cardColor,
          borderRadius: borderRadius,
          boxShadow: widget.showShadow && !isDark
              ? [
                  BoxShadow(
                    color: cardColor.withOpacity(0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        );

      case AppCardType.outlined:
        return BoxDecoration(
          color: isDark ? colors.cardDark : colors.cardLight,
          borderRadius: borderRadius,
          border: Border.all(
            color: isDark ? colors.borderDark : colors.borderLight,
            width: 1,
          ),
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
          boxShadow: widget.showShadow ? AppShadows.dialog : null,
        );

      case AppCardType.interactive:
        return BoxDecoration(
          color: isDark ? colors.cardDark : colors.cardLight,
          borderRadius: borderRadius,
          boxShadow: widget.showShadow && !isDark
              ? AppShadows.cardInteractive
              : null,
        );
    }
  }
}

/// 纯色概览卡片 (Material 3风格)
class GradientOverviewCard extends ConsumerWidget {
  const GradientOverviewCard({
    super.key,
    required this.child,
    this.color,
    this.padding,
    this.margin,
    this.borderRadius,
  });

  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? borderRadius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(colorSchemeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = color ?? colors.primary;

    return AppCard(
      type: AppCardType.filled,
      color: cardColor,
      padding: padding ?? const EdgeInsets.all(DesignTokens.cardPadding),
      margin: margin,
      borderRadius: borderRadius ?? DesignTokens.radius16,
      child: DefaultTextStyle(
        style: AppTextStyles.cardBody.copyWith(color: Colors.white),
        child: child,
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
    this.blur,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? blur;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      type: AppCardType.glass,
      padding: padding,
      margin: margin,
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(DesignTokens.radius12),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: blur ?? 10,
            sigmaY: blur ?? 10,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// 别名 - 向后兼容
typedef OverviewCard = GradientOverviewCard;
