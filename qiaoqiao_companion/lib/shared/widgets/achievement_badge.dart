import 'package:flutter/material.dart';
import 'package:qiaoqiao_companion/core/theme/app_theme.dart';
import 'package:qiaoqiao_companion/core/theme/app_solid_colors.dart';

/// 成就徽章组件
class AchievementBadge extends StatelessWidget {
  final String achievementId;
  final String name;
  final String emoji;
  final DateTime? unlockedAt;
  final int rewardPoints;
  final double progress;
  final bool isUnlocked;
  final bool compact;

  const AchievementBadge({
    super.key,
    required this.achievementId,
    required this.name,
    required this.emoji,
    this.unlockedAt,
    required this.rewardPoints,
    this.progress = 0.0,
    this.isUnlocked = false,
    this.compact = false,
  });

  /// 成就等级
  String get tier {
    if (rewardPoints >= 100) return 'gold';
    if (rewardPoints >= 50) return 'silver';
    return 'bronze';
  }

  /// 获取等级颜色
  Color _getTierGradientColor(String tier) {
    switch (tier) {
      case 'gold':
        return AppSolidColors.gold;
      case 'silver':
        return AppSolidColors.silver;
      case 'bronze':
        return AppSolidColors.bronze;
      default:
        return AppSolidColors.bronze;
    }
  }

  /// 获取等级颜色
  Color _getTierColor(String tier) {
    switch (tier) {
      case 'gold':
        return AppColors.gold;
      case 'silver':
        return AppColors.silver;
      case 'bronze':
        return AppColors.bronze;
      default:
        return Colors.grey;
    }
  }

  /// 获取等级名称
  String _getTierName(String tier) {
    switch (tier) {
      case 'gold':
        return '金';
      case 'silver':
        return '银';
      case 'bronze':
        return '铜';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final tierGradientColor = _getTierGradientColor(tier);
    final tierColor = _getTierColor(tier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? DesignTokens.space10 : DesignTokens.space14,
        vertical: compact ? DesignTokens.space8 : DesignTokens.space10,
      ),
      decoration: BoxDecoration(
        color: isUnlocked ? tierGradientColor : (isDark ? AppColors.surfaceDark : Colors.grey.shade200),
        borderRadius: BorderRadius.circular(DesignTokens.radiusCapsule),
        boxShadow: isUnlocked
            ? [
                BoxShadow(
                  color: tierColor.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
        border: !isUnlocked
            ? Border.all(
                color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
              )
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 徽章图标
          Container(
            width: compact ? 28 : 36,
            height: compact ? 28 : 36,
            decoration: BoxDecoration(
              gradient: isUnlocked ? LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.3),
                  Colors.white.withValues(alpha: 0.1),
                ],
              ) : null,
              color: isUnlocked ? null : (isDark ? AppColors.surfaceDark : Colors.grey.shade100),
              borderRadius: BorderRadius.circular(compact ? DesignTokens.radius8 : DesignTokens.radius10),
              border: !isUnlocked
                  ? Border.all(
                      color: isDark ? AppColors.dividerDark : Colors.grey.shade300,
                    )
                  : null,
            ),
            child: Center(
              child: Opacity(
                opacity: isUnlocked ? 1.0 : 0.4,
                child: Text(
                  emoji,
                  style: TextStyle(fontSize: compact ? 14 : 18),
                ),
              ),
            ),
          ),
          SizedBox(width: compact ? DesignTokens.space6 : DesignTokens.space10),

          // 积分奖励
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? DesignTokens.space8 : DesignTokens.space10,
              vertical: DesignTokens.space4,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(DesignTokens.radiusCapsule),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.star_rounded,
                  color: isUnlocked ? tierColor : Colors.grey,
                  size: compact ? 10 : 12,
                ),
                const SizedBox(width: DesignTokens.space2),
                Text(
                  '$rewardPoints',
                  style: AppTextStyles.labelSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isUnlocked ? tierColor : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: compact ? DesignTokens.space6 : DesignTokens.space8),

          // 等级标签
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? DesignTokens.space6 : DesignTokens.space10,
              vertical: DesignTokens.space4,
            ),
            decoration: BoxDecoration(
              color: isUnlocked
                  ? Colors.white.withValues(alpha: 0.25)
                  : (isDark ? AppColors.surfaceDark : Colors.grey.shade100),
              borderRadius: BorderRadius.circular(DesignTokens.radiusCapsule),
            ),
            child: Text(
              _getTierName(tier),
              style: AppTextStyles.labelSmall.copyWith(
                fontWeight: FontWeight.w600,
                color: isUnlocked ? Colors.white : (isDark ? AppColors.textHintDark : Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 成就解锁庆祝动画
class AchievementUnlockAnimation extends StatefulWidget {
  final String emoji;
  final String name;
  final int rewardPoints;
  final VoidCallback? onComplete;

  const AchievementUnlockAnimation({
    super.key,
    required this.emoji,
    required this.name,
    required this.rewardPoints,
    this.onComplete,
  });

  @override
  State<AchievementUnlockAnimation> createState() => _AchievementUnlockAnimationState();
}

class _AchievementUnlockAnimationState extends State<AchievementUnlockAnimation>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _particleController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();

    _mainController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    _particleController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.2)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.2, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: ConstantTween(1.0),
        weight: 50,
      ),
    ]).animate(_mainController);

    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: ConstantTween(1.0),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
    ]).animate(_mainController);

    _rotateAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 0.1)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.1, end: -0.05)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -0.05, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: ConstantTween(0.0),
        weight: 30,
      ),
    ]).animate(_mainController);

    _mainController.forward();
    _particleController.forward();

    _mainController.forward().then((_) {
      widget.onComplete?.call();
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 粒子效果背景
          AnimatedBuilder(
            animation: _particleController,
            builder: (context, child) {
              return CustomPaint(
                size: const Size(300, 300),
                painter: _ParticlePainter(
                  progress: _particleController.value,
                  color: AppColors.gold,
                ),
              );
            },
          ),

          // 主要内容
          AnimatedBuilder(
            animation: _mainController,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Transform.rotate(
                    angle: _rotateAnimation.value,
                    child: child,
                  ),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: DesignTokens.space32),
              padding: const EdgeInsets.all(DesignTokens.space24),
              decoration: BoxDecoration(
                color: AppSolidColors.gold,
                borderRadius: BorderRadius.circular(DesignTokens.radius24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.4),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 徽章图标
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(DesignTokens.radius20),
                    ),
                    child: Center(
                      child: Text(
                        widget.emoji,
                        style: const TextStyle(fontSize: 48),
                      ),
                    ),
                  ),
                  const SizedBox(height: DesignTokens.space16),

                  // 解锁文字
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesignTokens.space12,
                      vertical: DesignTokens.space6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(DesignTokens.radiusCapsule),
                    ),
                    child: Text(
                      '成就解锁',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: DesignTokens.space12),

                  // 成就名称
                  Text(
                    widget.name,
                    style: AppTextStyles.heading2.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: DesignTokens.space16),

                  // 奖励积分
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesignTokens.space16,
                      vertical: DesignTokens.space10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(DesignTokens.radius14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star_rounded,
                          color: AppColors.gold,
                          size: 20,
                        ),
                        const SizedBox(width: DesignTokens.space8),
                        Text(
                          '+${widget.rewardPoints}',
                          style: AppTextStyles.heading3.copyWith(
                            color: AppColors.gold,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 粒子画笔
class _ParticlePainter extends CustomPainter {
  final double progress;
  final Color color;

  _ParticlePainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.6 * (1 - progress))
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = 60 + progress * 80;
    final particleCount = 12;

    for (var i = 0; i < particleCount; i++) {
      canvas.drawCircle(
        Offset(
          center.dx + radius * progress * (i % 3 - 1) * 0.8,
          center.dy + radius * progress * (i % 2 == 0 ? -0.5 : 0.5),
        ),
        4 + progress * 6,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) {
    return progress != oldDelegate.progress;
  }
}
