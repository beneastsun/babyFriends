import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/theme_provider.dart';

/// 按钮类型
enum AppButtonType {
  /// 主按钮 - 渐变背景
  primary,
  /// 次要按钮 - 描边
  secondary,
  /// 幽灵按钮 - 低强调
  ghost,
  /// 危险按钮 - 红色
  danger,
}

/// 应用按钮组件
class AppButton extends ConsumerStatefulWidget {
  const AppButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.type = AppButtonType.primary,
    this.isEnabled = true,
    this.isLoading = false,
    this.isFullWidth = false,
    this.size = AppButtonSize.medium,
    this.icon,
    this.iconPosition = IconPosition.left,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final AppButtonType type;
  final bool isEnabled;
  final bool isLoading;
  final bool isFullWidth;
  final AppButtonSize size;
  final Widget? icon;
  final IconPosition iconPosition;

  @override
  ConsumerState<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends ConsumerState<AppButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: DesignTokens.animationQuick,
      vsync: this,
    );
    // candy 主题使用更有弹性的缩放效果
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (!widget.isEnabled || widget.isLoading) return;
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

  double get _height {
    switch (widget.size) {
      case AppButtonSize.small:
        return DesignTokens.buttonHeightSmall;
      case AppButtonSize.large:
        return DesignTokens.buttonHeightLarge;
      default:
        return DesignTokens.buttonHeight;
    }
  }

  double get _borderRadius {
    switch (widget.size) {
      case AppButtonSize.small:
        return DesignTokens.radius8;
      case AppButtonSize.large:
        return DesignTokens.radius16;
      default:
        return DesignTokens.radius12;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.isEnabled && !widget.isLoading ? widget.onPressed : null,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: Container(
          height: _height,
          width: widget.isFullWidth ? double.infinity : null,
          decoration: _buildDecoration(isDark),
          child: _buildContent(),
        ),
      ),
    );
  }

  BoxDecoration _buildDecoration(bool isDark) {
    final themeType = ref.watch(themeTypeProvider);
    final colors = ref.watch(colorSchemeProvider);

    if (!widget.isEnabled) {
      return BoxDecoration(
        color: isDark ? AppColors.borderDark : AppColors.borderLight,
        borderRadius: BorderRadius.circular(_borderRadius),
      );
    }

    switch (widget.type) {
      case AppButtonType.primary:
        // 使用纯色 + 阴影
        return BoxDecoration(
          color: colors.primary,
          borderRadius: BorderRadius.circular(_borderRadius),
          boxShadow: _isPressed
              ? null
              : isDark
                  ? null
                  : AppShadows.buttonPrimary,
        );
      case AppButtonType.secondary:
        return BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(_borderRadius),
          border: Border.all(
            color: isDark ? colors.primaryDark : colors.primary,
            width: 2,
          ),
        );
      case AppButtonType.ghost:
        return BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(_borderRadius),
        );
      case AppButtonType.danger:
        return BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(_borderRadius),
          boxShadow: _isPressed ? null : AppShadows.error,
        );
    }
  }

  Widget _buildContent() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = _getTextColor(isDark);

    List<Widget> children = [];

    if (widget.isLoading) {
      children.add(
        SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(textColor),
          ),
        ),
      );
    } else {
      if (widget.icon != null && widget.iconPosition == IconPosition.left) {
        children.add(Padding(
          padding: const EdgeInsets.only(right: DesignTokens.space8),
          child: IconTheme(
            data: IconThemeData(color: textColor, size: DesignTokens.iconMedium),
            child: widget.icon!,
          ),
        ));
      }

      children.add(
        DefaultTextStyle(
          style: AppTextStyles.button.copyWith(color: textColor),
          child: widget.child,
        ),
      );

      if (widget.icon != null && widget.iconPosition == IconPosition.right) {
        children.add(Padding(
          padding: const EdgeInsets.only(left: DesignTokens.space8),
          child: IconTheme(
            data: IconThemeData(color: textColor, size: DesignTokens.iconMedium),
            child: widget.icon!,
          ),
        ));
      }
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: DesignTokens.space24),
      child: Row(
        mainAxisSize: widget.isFullWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: children,
      ),
    );
  }

  Color _getTextColor(bool isDark) {
    final colors = ref.watch(colorSchemeProvider);

    if (!widget.isEnabled) {
      return isDark ? AppColors.textHintDark : AppColors.textHintLight;
    }

    switch (widget.type) {
      case AppButtonType.primary:
      case AppButtonType.danger:
        return Colors.white;
      case AppButtonType.secondary:
        return isDark ? colors.primaryDark : colors.primary;
      case AppButtonType.ghost:
        return isDark ? colors.primaryDark : colors.secondary;
    }
  }
}

/// 按钮尺寸
enum AppButtonSize {
  small,
  medium,
  large,
}

/// 图标位置
enum IconPosition {
  left,
  right,
}

/// 便捷构造函数
class AppButtonPrimary extends AppButton {
  AppButtonPrimary({
    super.key,
    required super.onPressed,
    required Widget child,
    super.isEnabled,
    super.isLoading,
    super.isFullWidth,
    super.size,
    super.icon,
  }) : super(type: AppButtonType.primary, child: child);
}

class AppButtonSecondary extends AppButton {
  AppButtonSecondary({
    super.key,
    required super.onPressed,
    required Widget child,
    super.isEnabled,
    super.isLoading,
    super.isFullWidth,
    super.size,
    super.icon,
  }) : super(type: AppButtonType.secondary, child: child);
}

class AppButtonGhost extends AppButton {
  AppButtonGhost({
    super.key,
    required super.onPressed,
    required Widget child,
    super.isEnabled,
    super.isLoading,
    super.isFullWidth,
    super.size,
    super.icon,
  }) : super(type: AppButtonType.ghost, child: child);
}

class AppButtonDanger extends AppButton {
  AppButtonDanger({
    super.key,
    required super.onPressed,
    required Widget child,
    super.isEnabled,
    super.isLoading,
    super.isFullWidth,
    super.size,
    super.icon,
  }) : super(type: AppButtonType.danger, child: child);
}
