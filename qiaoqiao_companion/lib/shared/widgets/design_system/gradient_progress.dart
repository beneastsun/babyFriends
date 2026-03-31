import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_solid_colors.dart';
import '../../providers/theme_provider.dart';

/// 纯色进度条 - Material 3 风格
class AppProgress extends ConsumerStatefulWidget {
  const AppProgress({
    super.key,
    required this.value,
    this.height = 8,
    this.borderRadius,
    this.color, // 纯色替代渐变
    this.backgroundColor,
    this.showAnimation = true,
    this.animationDuration = const Duration(milliseconds: 800),
  });

  final double value; // 0.0 到 1.0
  final double height;
  final double? borderRadius;
  final Color? color;
  final Color? backgroundColor;
  final bool showAnimation;
  final Duration animationDuration;

  @override
  ConsumerState<AppProgress> createState() => _AppProgressState();
}

class _AppProgressState extends ConsumerState<AppProgress>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: widget.value).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    if (widget.showAnimation) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(AppProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animation = Tween<double>(begin: oldWidget.value, end: widget.value).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeType = ref.watch(themeTypeProvider);
    final colors = ref.watch(colorSchemeProvider);
    final radius = widget.borderRadius ?? widget.height / 2;

    // 使用纯色
    final progressColor = widget.color ?? AppSolidColors.getPrimaryColor(themeType, isDark);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: widget.backgroundColor ??
                (isDark
                    ? colors.borderDark.withValues(alpha: 0.3)
                    : colors.borderLight.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(radius),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  // 背景轨道
                  Container(
                    decoration: BoxDecoration(
                      color: widget.backgroundColor ??
                          (isDark
                              ? colors.borderDark.withValues(alpha: 0.3)
                              : colors.borderLight.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(radius),
                    ),
                  ),
                  // 进度填充 - 使用纯色
                  AnimatedContainer(
                    duration: DesignTokens.animationNormal,
                    width: constraints.maxWidth * _animation.value.clamp(0.0, 1.0),
                    decoration: BoxDecoration(
                      color: progressColor,
                      borderRadius: BorderRadius.circular(radius),
                      boxShadow: [
                        BoxShadow(
                          color: progressColor.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

/// 圆形进度指示器 - Material 3 风格
class CircularProgress extends ConsumerStatefulWidget {
  const CircularProgress({
    super.key,
    required this.value,
    this.size = 64,
    this.strokeWidth = 6,
    this.color, // 纯色替代渐变
    this.backgroundColor,
    this.child,
    this.showAnimation = true,
  });

  final double value; // 0.0 到 1.0
  final double size;
  final double strokeWidth;
  final Color? color;
  final Color? backgroundColor;
  final Widget? child;
  final bool showAnimation;

  @override
  ConsumerState<CircularProgress> createState() => _CircularProgressState();
}

class _CircularProgressState extends ConsumerState<CircularProgress>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: widget.value).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    if (widget.showAnimation) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(CircularProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animation = Tween<double>(begin: oldWidget.value, end: widget.value).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeType = ref.watch(themeTypeProvider);
    final progressColor = widget.color ?? AppSolidColors.getPrimaryColor(themeType, isDark);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 背景圆
              SizedBox(
                width: widget.size,
                height: widget.size,
                child: CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: widget.strokeWidth,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    widget.backgroundColor ??
                        (isDark
                            ? AppColors.borderDark.withValues(alpha: 0.3)
                            : AppColors.borderLight.withValues(alpha: 0.3)),
                  ),
                ),
              ),
              // 进度圆 - 使用纯色
              SizedBox(
                width: widget.size,
                height: widget.size,
                child: CircularProgressIndicator(
                  value: _animation.value.clamp(0.0, 1.0),
                  strokeWidth: widget.strokeWidth,
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  strokeCap: StrokeCap.round,
                ),
              ),
              // 中心内容
              if (widget.child != null) widget.child!,
            ],
          ),
        );
      },
    );
  }
}

/// 带动画的数字进度显示
class AnimatedProgressValue extends StatelessWidget {
  const AnimatedProgressValue({
    super.key,
    required this.current,
    required this.total,
    this.suffix,
    this.style,
  });

  final int current;
  final int total;
  final String? suffix;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: current.toDouble()),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Text(
          '${value.round()}${suffix ?? ''}${total > 0 ? ' / $total' : ''}',
          style: style ??
              AppTextStyles.points.copyWith(
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
        );
      },
    );
  }
}

/// 根据使用比例自动变色的进度条
class UsageProgress extends ConsumerWidget {
  const UsageProgress({
    super.key,
    required this.percentage,
    this.height = 8,
    this.borderRadius,
    this.showAnimation = true,
  });

  final double percentage; // 0.0 到 1.0
  final double height;
  final double? borderRadius;
  final bool showAnimation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = AppSolidColors.getProgressColor(percentage, isDark);

    return AppProgress(
      value: percentage.clamp(0.0, 1.0),
      height: height,
      borderRadius: borderRadius,
      color: color,
      showAnimation: showAnimation,
    );
  }
}

// ========== 向后兼容别名 ==========
/// @deprecated 使用 AppProgress 替代
typedef GradientProgress = AppProgress;

/// @deprecated 使用 CircularProgress 替代
typedef CircularGradientProgress = CircularProgress;
