import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// 骨架屏加载组件
class ShimmerLoading extends StatefulWidget {
  const ShimmerLoading({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
    this.duration = const Duration(milliseconds: 1500),
  });

  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;
  final Duration duration;

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
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

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.baseColor ??
                    (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
                widget.highlightColor ??
                    (isDark
                        ? AppColors.surfaceLight.withOpacity(0.3)
                        : AppColors.primaryContainer),
                widget.baseColor ??
                    (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
              ],
              stops: [
                0.0,
                0.5,
                1.0,
              ],
              transform: _SlideGradientTransform(_animation.value),
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

class _SlideGradientTransform extends GradientTransform {
  const _SlideGradientTransform(this.percent);

  final double percent;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * percent, 0.0, 0.0);
  }
}

/// 骨架屏占位形状
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
  });

  final double? width;
  final double? height;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ShimmerLoading(
      child: Container(
        width: width,
        height: height ?? 16,
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(borderRadius ?? DesignTokens.radius8),
        ),
      ),
    );
  }
}

/// 圆形骨架屏
class ShimmerCircle extends StatelessWidget {
  const ShimmerCircle({
    super.key,
    required this.size,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ShimmerLoading(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// 列表项骨架屏
class ShimmerListItem extends StatelessWidget {
  const ShimmerListItem({
    super.key,
    this.hasLeading = true,
    this.lines = 2,
  });

  final bool hasLeading;
  final int lines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(DesignTokens.space16),
      child: Row(
        children: [
          if (hasLeading) ...[
            const ShimmerCircle(size: 48),
            SizedBox(width: DesignTokens.space16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(
                lines,
                (index) => Padding(
                  padding: EdgeInsets.only(
                    top: index == 0 ? 0 : DesignTokens.space8,
                  ),
                  child: ShimmerBox(
                    width: index == lines - 1 ? 100 : double.infinity,
                    height: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 卡片骨架屏
class ShimmerCard extends StatelessWidget {
  const ShimmerCard({
    super.key,
    this.headerLines = 1,
    this.contentLines = 3,
  });

  final int headerLines;
  final int contentLines;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.cardPadding),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(DesignTokens.radius12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题区域
          ...List.generate(
            headerLines,
            (index) => Padding(
              padding: EdgeInsets.only(
                bottom: index == headerLines - 1
                    ? DesignTokens.space16
                    : DesignTokens.space8,
              ),
              child: ShimmerBox(
                width: index == 0 ? 150 : double.infinity,
                height: 20,
              ),
            ),
          ),
          // 内容区域
          ...List.generate(
            contentLines,
            (index) => Padding(
              padding: EdgeInsets.only(
                bottom: index == contentLines - 1
                    ? 0
                    : DesignTokens.space8,
              ),
              child: ShimmerBox(
                width: index == contentLines - 1 ? 200 : double.infinity,
                height: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 概览卡片骨架屏
class ShimmerOverviewCard extends StatelessWidget {
  const ShimmerOverviewCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DesignTokens.radius16),
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.surfaceDark
            : AppColors.surfaceLight,
      ),
      child: const ShimmerLoading(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShimmerBox(width: 80, height: 32),
              SizedBox(height: DesignTokens.space8),
              ShimmerBox(width: 120, height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
