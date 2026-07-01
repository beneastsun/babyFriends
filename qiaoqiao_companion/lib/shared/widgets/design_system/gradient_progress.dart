import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_solid_colors.dart';
import '../../providers/theme_provider.dart';

/// 线性进度条 - Kawaii Dream 风格
/// 特点：渐变背景、发光效果、闪光动画
class AppProgress extends ConsumerStatefulWidget {
  const AppProgress({
    super.key,
    required this.value,
    this.height = 8,
    this.borderRadius,
    this.color,
    this.backgroundColor,
    this.showAnimation = true,
    this.showGlow = true,
    this.showShimmer = false,
    this.animationDuration = const Duration(milliseconds: 800),
  });

  final double value; // 0.0 到 1.0
  final double height;
  final double? borderRadius;
  final Color? color;
  final Color? backgroundColor;
  final bool showAnimation;
  final bool showGlow;
  final bool showShimmer;
  final Duration animationDuration;

  @override
  ConsumerState<AppProgress> createState() => _AppProgressState();
}

class _AppProgressState extends ConsumerState<AppProgress>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late AnimationController? _shimmerController;
  late Animation<double>? _shimmerAnimation;
  double _previousValue = 0.0;

  @override
  void initState() {
    super.initState();
    _previousValue = 0.0;
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: widget.value).animate(
      CurvedAnimation(parent: _controller, curve: AppAnimations.elastic),
    );

    // 闪光动画
    if (widget.showShimmer) {
      _shimmerController = AnimationController(
        duration: const Duration(milliseconds: 1500),
        vsync: this,
      )..repeat();
      _shimmerAnimation = Tween<double>(begin: -2, end: 2).animate(
        CurvedAnimation(parent: _shimmerController!, curve: Curves.easeInOut),
      );
    } else {
      _shimmerController = null;
      _shimmerAnimation = null;
    }

    if (widget.showAnimation) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(AppProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _previousValue = oldWidget.value;
      _animation = Tween<double>(begin: _previousValue, end: widget.value).animate(
        CurvedAnimation(parent: _controller, curve: AppAnimations.elastic),
      );
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _shimmerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeType = ref.watch(themeTypeProvider);
    final colors = ref.watch(colorSchemeProvider);
    final radius = widget.borderRadius ?? widget.height / 2;

    // 获取进度颜色
    final progressColor = widget.color ??
        AppSolidColors.getPrimaryColor(themeType, isDark);

    // 构建发光阴影
    List<BoxShadow>? progressShadows;
    if (widget.showGlow) {
      progressShadows = [
        BoxShadow(
          color: progressColor.withOpacity(0.4),
          blurRadius: 8,
          spreadRadius: 0,
        ),
      ];
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_animation, _shimmerController].whereType<AnimationController>()),
      builder: (context, child) {
        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: widget.backgroundColor ??
                (isDark
                    ? colors.borderDark.withOpacity(0.3)
                    : colors.borderLight.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(radius),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final progressWidth = constraints.maxWidth * _animation.value.clamp(0.0, 1.0);
              final progressValue = _animation.value.clamp(0.0, 1.0);

              if (progressValue <= 0) {
                return const SizedBox.shrink();
              }

              return Stack(
                children: [
                  // 进度条
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: progressWidth,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          progressColor,
                          _getLighterColor(progressColor),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(radius),
                      boxShadow: progressShadows,
                    ),
                    child: widget.showShimmer && _shimmerAnimation != null
                        ? _buildShimmerEffect(progressWidth)
                        : null,
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildShimmerEffect(double width) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius ?? widget.height / 2),
      child: Stack(
        children: [
          // 闪光效果
          if (_shimmerAnimation != null)
            AnimatedBuilder(
              animation: _shimmerAnimation!,
              builder: (context, child) {
                return Positioned(
                  left: _shimmerAnimation!.value * width,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: width * 0.3,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.transparent,
                          Colors.white.withOpacity(0.3),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Color _getLighterColor(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness + 0.15).clamp(0.0, 1.0)).toColor();
  }
}

/// 圆形进度指示器 - Kawaii Dream 风格
class CircularProgress extends ConsumerStatefulWidget {
  const CircularProgress({
    super.key,
    required this.value,
    this.size = 64,
    this.strokeWidth = 6,
    this.color,
    this.backgroundColor,
    this.child,
    this.showAnimation = true,
    this.showGlow = true,
  });

  final double value; // 0.0 到 1.0
  final double size;
  final double strokeWidth;
  final Color? color;
  final Color? backgroundColor;
  final Widget? child;
  final bool showAnimation;
  final bool showGlow;

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
      CurvedAnimation(parent: _controller, curve: AppAnimations.elastic),
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
        CurvedAnimation(parent: _controller, curve: AppAnimations.elastic),
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
    final progressColor = widget.color ??
        AppSolidColors.getPrimaryColor(themeType, isDark);

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
                            ? AppColors.borderDark.withOpacity(0.3)
                            : AppColors.borderLight.withOpacity(0.3)),
                  ),
                ),
              ),
              // 进度圆 - 带发光
              if (widget.showGlow)
                Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: progressColor.withOpacity(0.3),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
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
      curve: AppAnimations.elastic,
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
    this.showGlow = true,
    this.showShimmer = false,
  });

  final double percentage; // 0.0 到 1.0
  final double height;
  final double? borderRadius;
  final bool showAnimation;
  final bool showGlow;
  final bool showShimmer;

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
      showGlow: showGlow,
      showShimmer: showShimmer,
    );
  }
}

/// 巧巧心情进度条 - 根据使用比例显示不同心情颜色
class QiaoqiaoMoodProgress extends ConsumerWidget {
  const QiaoqiaoMoodProgress({
    super.key,
    required this.percentage,
    this.height = 12,
    this.borderRadius,
    this.showAnimation = true,
    this.showGlow = true,
  });

  final double percentage;
  final double height;
  final double? borderRadius;
  final bool showAnimation;
  final bool showGlow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final moodColor = AppSolidColors.getQiaoqiaoMoodColor(percentage);
    final moodLightColor = AppSolidColors.getQiaoqiaoMoodLightColor(percentage);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.borderDark.withOpacity(0.3)
            : AppColors.borderLight.withOpacity(0.3),
        borderRadius: BorderRadius.circular(borderRadius ?? height / 2),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: percentage.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 800),
            curve: AppAnimations.elastic,
            builder: (context, value, child) {
              return Stack(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: constraints.maxWidth * value,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [moodColor, moodLightColor],
                      ),
                      borderRadius: BorderRadius.circular(borderRadius ?? height / 2),
                      boxShadow: showGlow
                          ? [
                              BoxShadow(
                                color: moodColor.withOpacity(0.4),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// 分段进度条 - 用于显示多个分类
class SegmentedProgress extends ConsumerWidget {
  const SegmentedProgress({
    super.key,
    required this.segments,
    this.height = 12,
    this.borderRadius,
    this.showAnimation = true,
    this.gap = 4,
  });

  final List<ProgressSegment> segments;
  final double height;
  final double? borderRadius;
  final bool showAnimation;
  final double gap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = borderRadius ?? height / 2;

    return Row(
      children: [
        for (int i = 0; i < segments.length; i++) ...[
          Expanded(
            flex: (segments[i].value * 100).round(),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 800),
              curve: AppAnimations.elastic,
              builder: (context, animValue, child) {
                return Opacity(
                  opacity: animValue,
                  child: Container(
                    height: height,
                    decoration: BoxDecoration(
                      color: segments[i].color,
                      borderRadius: BorderRadius.circular(radius),
                      boxShadow: [
                        BoxShadow(
                          color: segments[i].color.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (i < segments.length - 1)
            SizedBox(width: gap),
        ],
      ],
    );
  }
}

/// 分段数据
class ProgressSegment {
  final double value;
  final Color color;
  final String? label;

  const ProgressSegment({
    required this.value,
    required this.color,
    this.label,
  });
}

/// 脉冲加载指示器 - 可爱的加载效果
class PulsingProgress extends ConsumerStatefulWidget {
  const PulsingProgress({
    super.key,
    this.size = 48,
    this.color,
    this.strokeWidth = 4,
  });

  final double size;
  final Color? color;
  final double strokeWidth;

  @override
  ConsumerState<PulsingProgress> createState() => _PulsingProgressState();
}

class _PulsingProgressState extends ConsumerState<PulsingProgress>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
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
    final progressColor = widget.color ??
        AppSolidColors.getPrimaryColor(themeType, isDark);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CircularProgressIndicator(
            value: _animation.value,
            strokeWidth: widget.strokeWidth,
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            strokeCap: StrokeCap.round,
          ),
        );
      },
    );
  }
}

// ============================================================
// 向后兼容别名
// ============================================================

/// @deprecated 使用 AppProgress 替代
typedef GradientProgress = AppProgress;

/// @deprecated 使用 CircularProgress 替代
typedef CircularGradientProgress = CircularProgress;
