import 'package:flutter/material.dart';
import 'package:qiaoqiao_companion/core/theme/app_theme.dart';
import 'package:qiaoqiao_companion/core/theme/app_solid_colors.dart';

/// 积分变化动画组件
class PointsAnimation extends StatefulWidget {
  final int points;
  final bool isPositive;
  final String? reason;
  final VoidCallback? onComplete;

  const PointsAnimation({
    super.key,
    required this.points,
    required this.isPositive,
    this.reason,
    this.onComplete,
  });

  @override
  State<PointsAnimation> createState() => _PointsAnimationState();
}

class _PointsAnimationState extends State<PointsAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    // 淡入淡出
    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: ConstantTween(1.0),
        weight: 55,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 30,
      ),
    ]).animate(_controller);

    // 向上滑动
    _slideAnimation = Tween<double>(
      begin: 0,
      end: -40,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    // 弹跳缩放
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.3, end: 1.3)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.3, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: ConstantTween(1.0),
        weight: 60,
      ),
    ]).animate(_controller);

    // 发光脉冲
    _glowAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.6)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.6, end: 0.8)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.8, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
    ]).animate(_controller);

    _controller.forward().then((_) {
      widget.onComplete?.call();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isPositive
        ? AppSolidColors.pointsEarned
        : AppSolidColors.pointsSpent;
    final sign = widget.isPositive ? '+' : '-';

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          top: 120 + _slideAnimation.value,
          left: 0,
          right: 0,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: child,
            ),
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, child) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: DesignTokens.space24),
              padding: const EdgeInsets.symmetric(
                horizontal: DesignTokens.space24,
                vertical: DesignTokens.space16,
              ),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(DesignTokens.radius24),
                boxShadow: [
                  BoxShadow(
                    color: (widget.isPositive ? AppColors.success : AppColors.error)
                        .withValues(alpha: 0.4 * _glowAnimation.value),
                    blurRadius: 24 * _glowAnimation.value + 8,
                    offset: const Offset(0, 8),
                    spreadRadius: 2 * _glowAnimation.value,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        widget.isPositive
                            ? Icons.add_circle_rounded
                            : Icons.remove_circle_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(width: DesignTokens.space10),
                      Text(
                        '$sign${widget.points}',
                        style: AppTextStyles.pointsLarge.copyWith(
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black26,
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: DesignTokens.space10),
                      Container(
                        padding: const EdgeInsets.all(DesignTokens.space6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(DesignTokens.radius8),
                        ),
                        child: Icon(
                          Icons.star_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  if (widget.reason != null) ...[
                    const SizedBox(height: DesignTokens.space8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DesignTokens.space12,
                        vertical: DesignTokens.space6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(DesignTokens.radius10),
                      ),
                      child: Text(
                        widget.reason!,
                        style: AppTextStyles.labelMedium.copyWith(
                          color: Colors.white.withValues(alpha: 0.95),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 积分动画显示管理器
class PointsAnimationManager {
  static final PointsAnimationManager _instance = PointsAnimationManager._internal();
  factory PointsAnimationManager() => _instance;
  PointsAnimationManager._internal();

  OverlayEntry? _currentEntry;

  /// 显示积分动画
  void show(
    BuildContext context, {
    required int points,
    required bool isPositive,
    String? reason,
  }) {
    // 先移除之前的动画
    hide();

    final overlay = Overlay.of(context);
    _currentEntry = OverlayEntry(
      builder: (context) => PointsAnimation(
        points: points,
        isPositive: isPositive,
        reason: reason,
        onComplete: hide,
      ),
    );

    overlay.insert(_currentEntry!);
  }

  /// 隐藏动画
  void hide() {
    _currentEntry?.remove();
    _currentEntry = null;
  }
}

/// 积分徽章组件
class PointsBadge extends StatelessWidget {
  final int points;
  final double fontSize;
  final bool showIcon;
  final bool compact;

  const PointsBadge({
    super.key,
    required this.points,
    this.fontSize = 16,
    this.showIcon = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? DesignTokens.space10 : DesignTokens.space14,
        vertical: DesignTokens.space6,
      ),
      decoration: BoxDecoration(
        color: AppSolidColors.pointsGold,
        borderRadius: BorderRadius.circular(DesignTokens.radiusCapsule),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(
              Icons.star_rounded,
              color: Colors.white,
              size: compact ? 14 : 16,
            ),
            const SizedBox(width: DesignTokens.space4),
          ],
          Text(
            '$points',
            style: AppTextStyles.labelLarge.copyWith(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// 积分变化指示器
class PointsChangeIndicator extends StatefulWidget {
  final int change;
  final bool isPositive;

  const PointsChangeIndicator({
    super.key,
    required this.change,
    required this.isPositive,
  });

  @override
  State<PointsChangeIndicator> createState() => _PointsChangeIndicatorState();
}

class _PointsChangeIndicatorState extends State<PointsChangeIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: DesignTokens.animationSlow,
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sign = widget.isPositive ? '+' : '-';
    final color = widget.isPositive
        ? AppSolidColors.pointsEarned
        : AppSolidColors.pointsSpent;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.space10,
            vertical: DesignTokens.space6,
          ),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(DesignTokens.radius10),
            boxShadow: [
              BoxShadow(
                color: (widget.isPositive ? AppColors.success : AppColors.error)
                    .withValues(alpha: 0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.isPositive
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                color: Colors.white,
                size: 12,
              ),
              const SizedBox(width: DesignTokens.space4),
              Text(
                '$sign${widget.change}',
                style: AppTextStyles.labelMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
