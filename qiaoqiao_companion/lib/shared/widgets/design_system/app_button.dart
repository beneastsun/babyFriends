import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_solid_colors.dart';
import '../../providers/theme_provider.dart';

/// 按钮类型
enum AppButtonType {
  /// 主按钮 - 渐变背景
  primary,
  /// 次要按钮 - 紫色
  secondary,
  /// 点缀按钮 - 薄荷绿
  tertiary,
  /// 幽灵按钮 - 描边
  ghost,
  /// 描边按钮 - 白色背景
  outline,
  /// 危险按钮 - 珊瑚红
  danger,
}

/// 按钮形状
enum AppButtonShape {
  /// 胶囊形 (默认)
  capsule,
  /// 圆角矩形
  rounded,
  /// 圆形
  circle,
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

/// 按钮尺寸配置
class _ButtonSizeConfig {
  final double height;
  final double minWidth;
  final double iconSize;
  final double horizontalPadding;
  final double borderRadius;

  const _ButtonSizeConfig({
    required this.height,
    required this.minWidth,
    required this.iconSize,
    required this.horizontalPadding,
    required this.borderRadius,
  });
}

/// 应用按钮组件 - Kawaii Dream 风格
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
    this.shape = AppButtonShape.capsule,
    this.icon,
    this.iconPosition = IconPosition.left,
    this.showGlow = true,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final AppButtonType type;
  final bool isEnabled;
  final bool isLoading;
  final bool isFullWidth;
  final AppButtonSize size;
  final AppButtonShape shape;
  final Widget? icon;
  final IconPosition iconPosition;
  final bool showGlow;

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
      duration: AppAnimations.quick,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: AppAnimations.buttonPressScale).animate(
      CurvedAnimation(parent: _controller, curve: AppAnimations.elastic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  _ButtonSizeConfig get _sizeConfig {
    switch (widget.size) {
      case AppButtonSize.small:
        return _ButtonSizeConfig(
          height: 40,
          minWidth: 80,
          iconSize: 18,
          horizontalPadding: DesignTokens.space16,
          borderRadius: DesignTokens.radius12,
        );
      case AppButtonSize.medium:
        return _ButtonSizeConfig(
          height: DesignTokens.buttonHeight,
          minWidth: DesignTokens.buttonMinWidth,
          iconSize: 20,
          horizontalPadding: DesignTokens.space24,
          borderRadius: DesignTokens.radius16,
        );
      case AppButtonSize.large:
        return _ButtonSizeConfig(
          height: DesignTokens.buttonHeightLarge,
          minWidth: 160,
          iconSize: 24,
          horizontalPadding: DesignTokens.space32,
          borderRadius: DesignTokens.radius20,
        );
    }
  }

  double get _borderRadius {
    if (widget.shape == AppButtonShape.capsule) {
      return DesignTokens.radiusPill;
    } else if (widget.shape == AppButtonShape.circle) {
      return _sizeConfig.height / 2;
    }
    return _sizeConfig.borderRadius;
  }

  void _handleTapDown(TapDownDetails details) {
    if (!widget.isEnabled || widget.isLoading) return;
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeType = ref.watch(themeTypeProvider);
    final colors = ref.watch(colorSchemeProvider);

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
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
          height: _sizeConfig.height,
          constraints: BoxConstraints(
            minWidth: widget.isFullWidth ? double.infinity : _sizeConfig.minWidth,
          ),
          decoration: _buildDecoration(isDark, themeType, colors),
          child: _buildContent(isDark),
        ),
      ),
    );
  }

  BoxDecoration _buildDecoration(bool isDark, AppThemeType themeType, ColorSchemeConfig colors) {
    final borderRadius = BorderRadius.circular(_borderRadius);
    final effectiveType = widget.isEnabled ? widget.type : AppButtonType.ghost;

    // 根据类型获取背景和阴影
    Color backgroundColor;
    List<BoxShadow>? shadows;
    Border? border;

    switch (effectiveType) {
      case AppButtonType.primary:
        backgroundColor = AppSolidColors.getPrimaryColor(themeType, isDark);
        shadows = widget.showGlow && !isDark ? AppShadows.buttonPrimary : null;
        break;
      case AppButtonType.secondary:
        backgroundColor = AppSolidColors.getSecondaryColor(themeType, isDark);
        shadows = widget.showGlow && !isDark ? AppShadows.buttonSecondary : null;
        break;
      case AppButtonType.tertiary:
        backgroundColor = AppSolidColors.getTertiaryColor(themeType, isDark);
        shadows = widget.showGlow && !isDark ? AppShadows.glowSuccess : null;
        break;
      case AppButtonType.ghost:
        backgroundColor = Colors.transparent;
        border = Border.all(
          color: AppSolidColors.getPrimaryColor(themeType, isDark),
          width: 1.5,
        );
        break;
      case AppButtonType.outline:
        backgroundColor = isDark ? colors.cardDark : Colors.white;
        border = Border.all(
          color: AppSolidColors.getPrimaryColor(themeType, isDark),
          width: 1.5,
        );
        shadows = widget.showGlow && !isDark ? AppShadows.card : null;
        break;
      case AppButtonType.danger:
        backgroundColor = AppSolidColors.error;
        shadows = widget.showGlow && !isDark ? AppShadows.error : null;
        break;
    }

    // 按下状态时减小阴影
    if (_isPressed && shadows != null) {
      shadows = shadows.map((s) => BoxShadow(
        color: s.color.withOpacity(s.color.opacity * 0.5),
        blurRadius: s.blurRadius * 0.5,
        offset: Offset(s.offset.dx, s.offset.dy * 0.5),
        spreadRadius: s.spreadRadius,
      )).toList();
    }

    return BoxDecoration(
      color: backgroundColor,
      borderRadius: borderRadius,
      border: border,
      boxShadow: shadows,
    );
  }

  Widget _buildContent(bool isDark) {
    final themeType = ref.watch(themeTypeProvider);

    // 确定文字颜色
    Color textColor;
    if (!widget.isEnabled) {
      textColor = isDark
          ? AppColors.textHintDark.withOpacity(0.5)
          : AppColors.textHintLight.withOpacity(0.5);
    } else if (widget.type == AppButtonType.ghost) {
      textColor = AppSolidColors.getPrimaryColor(themeType, isDark);
    } else if (widget.type == AppButtonType.outline) {
      textColor = AppSolidColors.getPrimaryColor(themeType, isDark);
    } else if (widget.type == AppButtonType.tertiary) {
      textColor = const Color(0xFF2D1F3D); // 薄荷绿用深色文字
    } else {
      textColor = Colors.white;
    }

    final textStyle = AppTextStyles.button.copyWith(color: textColor);

    List<Widget> children = [];

    // 加载指示器
    if (widget.isLoading) {
      children.add(SizedBox(
        width: _sizeConfig.iconSize,
        height: _sizeConfig.iconSize,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(textColor),
        ),
      ));
    } else {
      // 图标
      if (widget.icon != null && widget.iconPosition == IconPosition.left) {
        children.add(Padding(
          padding: const EdgeInsets.only(right: DesignTokens.space8),
          child: IconTheme(
            data: IconThemeData(
              size: _sizeConfig.iconSize,
              color: textColor,
            ),
            child: widget.icon!,
          ),
        ));
      }

      // 文字
      if (widget.child is Text) {
        final textWidget = widget.child as Text;
        children.add(Text(
          textWidget.data ?? '',
          style: textWidget.style?.merge(textStyle) ?? textStyle,
          textAlign: textWidget.textAlign,
          maxLines: textWidget.maxLines,
          overflow: textWidget.overflow,
        ));
      } else {
        children.add(DefaultTextStyle(
          style: textStyle,
          child: widget.child,
        ));
      }

      // 右侧图标
      if (widget.icon != null && widget.iconPosition == IconPosition.right) {
        children.add(Padding(
          padding: const EdgeInsets.only(left: DesignTokens.space8),
          child: IconTheme(
            data: IconThemeData(
              size: _sizeConfig.iconSize,
              color: textColor,
            ),
            child: widget.icon!,
          ),
        ));
      }
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: _sizeConfig.horizontalPadding),
      child: Row(
        mainAxisSize: widget.isFullWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: children,
      ),
    );
  }
}

// ============================================================
// 便捷构造函数
// ============================================================

/// 主按钮 - 渐变背景
class AppButtonPrimary extends AppButton {
  AppButtonPrimary({
    super.key,
    required super.onPressed,
    required Widget child,
    super.isEnabled = true,
    super.isLoading = false,
    super.isFullWidth = false,
    super.size = AppButtonSize.medium,
    super.shape = AppButtonShape.capsule,
    super.icon,
    super.iconPosition = IconPosition.left,
    super.showGlow = true,
  }) : super(
          type: AppButtonType.primary,
          child: child,
        );
}

/// 次要按钮 - 紫色
class AppButtonSecondary extends AppButton {
  AppButtonSecondary({
    super.key,
    required super.onPressed,
    required Widget child,
    super.isEnabled = true,
    super.isLoading = false,
    super.isFullWidth = false,
    super.size = AppButtonSize.medium,
    super.shape = AppButtonShape.capsule,
    super.icon,
    super.iconPosition = IconPosition.left,
    super.showGlow = true,
  }) : super(
          type: AppButtonType.secondary,
          child: child,
        );
}

/// 点缀按钮 - 薄荷绿
class AppButtonTertiary extends AppButton {
  AppButtonTertiary({
    super.key,
    required super.onPressed,
    required Widget child,
    super.isEnabled = true,
    super.isLoading = false,
    super.isFullWidth = false,
    super.size = AppButtonSize.medium,
    super.shape = AppButtonShape.capsule,
    super.icon,
    super.iconPosition = IconPosition.left,
    super.showGlow = true,
  }) : super(
          type: AppButtonType.tertiary,
          child: child,
        );
}

/// 幽灵按钮 - 描边
class AppButtonGhost extends AppButton {
  AppButtonGhost({
    super.key,
    required super.onPressed,
    required Widget child,
    super.isEnabled = true,
    super.isLoading = false,
    super.isFullWidth = false,
    super.size = AppButtonSize.medium,
    super.shape = AppButtonShape.capsule,
    super.icon,
    super.iconPosition = IconPosition.left,
  }) : super(
          type: AppButtonType.ghost,
          showGlow: false,
          child: child,
        );
}

/// 描边按钮 - 白色背景
class AppButtonOutline extends AppButton {
  AppButtonOutline({
    super.key,
    required super.onPressed,
    required Widget child,
    super.isEnabled = true,
    super.isLoading = false,
    super.isFullWidth = false,
    super.size = AppButtonSize.medium,
    super.shape = AppButtonShape.capsule,
    super.icon,
    super.iconPosition = IconPosition.left,
  }) : super(
          type: AppButtonType.outline,
          showGlow: false,
          child: child,
        );
}

/// 危险按钮 - 珊瑚红
class AppButtonDanger extends AppButton {
  AppButtonDanger({
    super.key,
    required super.onPressed,
    required Widget child,
    super.isEnabled = true,
    super.isLoading = false,
    super.isFullWidth = false,
    super.size = AppButtonSize.medium,
    super.shape = AppButtonShape.capsule,
    super.icon,
    super.iconPosition = IconPosition.left,
    super.showGlow = true,
  }) : super(
          type: AppButtonType.danger,
          child: child,
        );
}

/// 图标按钮
class AppIconButton extends AppButton {
  AppIconButton({
    super.key,
    required super.onPressed,
    required Widget icon,
    super.isEnabled = true,
    super.isLoading = false,
    super.type = AppButtonType.primary,
    super.size = AppButtonSize.medium,
    String? tooltip,
  }) : super(
          shape: AppButtonShape.circle,
          icon: icon,
          child: const SizedBox.shrink(),
        );
}
