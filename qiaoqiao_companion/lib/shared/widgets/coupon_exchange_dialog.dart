import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/theme/app_theme.dart';
import 'package:qiaoqiao_companion/shared/providers/theme_provider.dart';
import 'package:qiaoqiao_companion/core/theme/app_solid_colors.dart';

/// 加时券类型
enum CouponDuration {
  minutes5,
  minutes15,
  minutes30,
  minutes60,
}

/// 加时券配置
class CouponConfig {
  final CouponDuration duration;
  final int minutes;
  final int cost;
  final String emoji;
  final String name;

  const CouponConfig({
    required this.duration,
    required this.minutes,
    required this.cost,
    required this.emoji,
    required this.name,
  });

  static const List<CouponConfig> available = [
    CouponConfig(
      duration: CouponDuration.minutes5,
      minutes: 5,
      cost: 50,
      emoji: '⏰',
      name: '5分钟加时券',
    ),
    CouponConfig(
      duration: CouponDuration.minutes15,
      minutes: 15,
      cost: 100,
      emoji: '⏱️',
      name: '15分钟加时券',
    ),
    CouponConfig(
      duration: CouponDuration.minutes30,
      minutes: 30,
      cost: 150,
      emoji: '⌛',
      name: '30分钟加时券',
    ),
    CouponConfig(
      duration: CouponDuration.minutes60,
      minutes: 60,
      cost: 200,
      emoji: '🕐',
      name: '1小时加时券',
    ),
  ];
}

/// 加时券兑换对话框 - 现代玻璃拟态风格
class CouponExchangeDialog extends ConsumerStatefulWidget {
  final int currentPoints;
  final Function(CouponConfig config) onExchange;

  const CouponExchangeDialog({
    super.key,
    required this.currentPoints,
    required this.onExchange,
  });

  @override
  ConsumerState<CouponExchangeDialog> createState() => _CouponExchangeDialogState();
}

class _CouponExchangeDialogState extends ConsumerState<CouponExchangeDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  CouponConfig? _selectedConfig;
  bool _isExchanging = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: DesignTokens.animationPageTransition,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _canAfford(CouponConfig config) {
    return widget.currentPoints >= config.cost;
  }

  Future<void> _handleExchange() async {
    if (_selectedConfig == null || !_canAfford(_selectedConfig!)) return;

    setState(() {
      _isExchanging = true;
    });

    try {
      await widget.onExchange(_selectedConfig!);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('兑换失败: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExchanging = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: child,
          ),
        );
      },
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: DesignTokens.space24),
            constraints: const BoxConstraints(maxWidth: 380),
            decoration: BoxDecoration(
              color: AppSolidColors.getPrimaryColor(ref.watch(themeTypeProvider), ref.watch(isDarkModeProvider)),
              borderRadius: BorderRadius.circular(DesignTokens.radius24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 30,
                  spreadRadius: 5,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(DesignTokens.radius24),
              child: Stack(
                children: [
                  // 装饰性背景
                  Positioned(
                    top: -40,
                    right: -30,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -30,
                    left: -40,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  ),

                  // 主要内容
                  Padding(
                    padding: const EdgeInsets.all(DesignTokens.space24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 标题
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(DesignTokens.radius12),
                              ),
                              child: const Center(
                                child: Text('🎁', style: TextStyle(fontSize: 24)),
                              ),
                            ),
                            const SizedBox(width: DesignTokens.space12),
                            Text(
                              '兑换加时券',
                              style: AppTextStyles.heading2.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: DesignTokens.space16),

                        // 当前积分
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: DesignTokens.space20,
                            vertical: DesignTokens.space12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(DesignTokens.radius16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
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
                                '当前积分',
                                style: AppTextStyles.labelMedium.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                              const SizedBox(width: DesignTokens.space8),
                              Text(
                                '${widget.currentPoints}',
                                style: AppTextStyles.heading3.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: DesignTokens.space20),

                        // 加时券选项
                        ...CouponConfig.available.map((config) => _buildCouponOption(config)),

                        const SizedBox(height: DesignTokens.space24),

                        // 按钮
                        _buildButtons(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCouponOption(CouponConfig config) {
    final isSelected = _selectedConfig == config;
    final canAfford = _canAfford(config);

    return Padding(
      padding: const EdgeInsets.only(bottom: DesignTokens.space10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canAfford
              ? () {
                  setState(() {
                    _selectedConfig = config;
                  });
                }
              : null,
          borderRadius: BorderRadius.circular(DesignTokens.radius16),
          child: AnimatedContainer(
            duration: DesignTokens.animationQuick,
            padding: const EdgeInsets.all(DesignTokens.space14),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(DesignTokens.radius16),
              border: Border.all(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.2),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                // Emoji图标
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: canAfford
                        ? LinearGradient(
                            colors: [
                              AppColors.secondary.withValues(alpha: 0.8),
                              AppColors.secondaryDark.withValues(alpha: 0.8),
                            ],
                          )
                        : null,
                    color: canAfford ? null : Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(DesignTokens.radius12),
                    boxShadow: canAfford
                        ? [
                            BoxShadow(
                              color: AppColors.secondary.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Opacity(
                      opacity: canAfford ? 1.0 : 0.5,
                      child: Text(
                        config.emoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: DesignTokens.space14),

                // 信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        config.name,
                        style: AppTextStyles.labelLarge.copyWith(
                          color: canAfford
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.5),
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: DesignTokens.space4),
                      Text(
                        '+${config.minutes}分钟游戏时间',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: canAfford
                              ? Colors.white.withValues(alpha: 0.8)
                              : Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),

                // 价格
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.space12,
                    vertical: DesignTokens.space8,
                  ),
                  decoration: BoxDecoration(
                    // color: canAfford ? AppSolidColors.pointsGold : null,
                    color: canAfford ? null : Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(DesignTokens.radius12),
                    boxShadow: canAfford
                        ? [
                            BoxShadow(
                              color: AppColors.gold.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.star_rounded,
                        size: 14,
                        color: canAfford ? Colors.white : Colors.white.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: DesignTokens.space4),
                      Text(
                        '${config.cost}',
                        style: AppTextStyles.labelMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: canAfford ? Colors.white : Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButtons() {
    final colorScheme = ref.watch(colorSchemeProvider);
    final isDark = ref.watch(isDarkModeProvider);

    return Row(
      children: [
        // 取消按钮
        Expanded(
          child: _GlassButton(
            label: '取消',
            isSecondary: true,
            primaryColor: colorScheme.primary,
            secondaryColor: colorScheme.primaryLight,
            onTap: _isExchanging ? null : () => Navigator.pop(context),
          ),
        ),
        const SizedBox(width: DesignTokens.space12),
        // 确认按钮
        Expanded(
          child: _GlassButton(
            label: '确认兑换',
            icon: Icons.card_giftcard_rounded,
            isLoading: _isExchanging,
            primaryColor: isDark ? colorScheme.secondaryDarkMode : colorScheme.secondary,
            secondaryColor: isDark
                ? colorScheme.secondaryLightDarkMode
                : colorScheme.secondaryLight,
            onTap: _selectedConfig != null &&
                    _canAfford(_selectedConfig!) &&
                    !_isExchanging
                ? _handleExchange
                : null,
          ),
        ),
      ],
    );
  }
}

/// 玻璃风格按钮
class _GlassButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final bool isSecondary;
  final bool isLoading;
  final Color primaryColor;
  final Color secondaryColor;
  final VoidCallback? onTap;

  const _GlassButton({
    required this.label,
    this.icon,
    this.isSecondary = false,
    this.isLoading = false,
    required this.primaryColor,
    required this.secondaryColor,
    this.onTap,
  });

  @override
  State<_GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<_GlassButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onTap != null;

    return GestureDetector(
      onTapDown: isEnabled ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: isEnabled ? (_) => setState(() => _isPressed = false) : null,
      onTapCancel: isEnabled ? () => setState(() => _isPressed = false) : null,
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: DesignTokens.animationQuick,
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.space16,
          vertical: DesignTokens.space14,
        ),
        decoration: BoxDecoration(
          gradient: widget.isSecondary
              ? null
              : LinearGradient(
                  colors: isEnabled
                      ? [
                          widget.primaryColor,
                          widget.secondaryColor,
                        ]
                      : [
                          Colors.grey.shade400,
                          Colors.grey.shade500,
                        ],
                ),
          color: widget.isSecondary
              ? Colors.white.withValues(alpha: _isPressed ? 0.35 : 0.2)
              : null,
          borderRadius: BorderRadius.circular(DesignTokens.radius14),
          border: Border.all(
            color: widget.isSecondary
                ? Colors.white.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: widget.isSecondary || !isEnabled
              ? null
              : [
                  BoxShadow(
                    color: widget.primaryColor.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.isLoading)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            else ...[
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  size: 18,
                  color: isEnabled
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.6),
                ),
                const SizedBox(width: DesignTokens.space8),
              ],
              Text(
                widget.label,
                style: AppTextStyles.labelMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isEnabled
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 加时券卡片组件（用于显示已拥有的加时券）
class CouponCard extends StatelessWidget {
  final int minutes;
  final int count;
  final VoidCallback? onUse;
  final bool isEnabled;

  const CouponCard({
    super.key,
    required this.minutes,
    required this.count,
    this.onUse,
    this.isEnabled = true,
  });

  String get _emoji {
    if (minutes <= 5) return '⏰';
    if (minutes <= 15) return '⏱️';
    if (minutes <= 30) return '⌛';
    return '🕐';
  }

  Color get _color {
    if (minutes <= 5) return AppColors.success;
    if (minutes <= 15) return AppColors.primary;
    if (minutes <= 30) return AppColors.warning;
    return AppColors.error;
  }

  Color get _gradientColor {
    if (minutes <= 5) return AppSolidColors.success;
    if (minutes <= 15) return AppColors.primary;
    if (minutes <= 30) return AppSolidColors.warning;
    return AppSolidColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: DesignTokens.space12),
      decoration: BoxDecoration(
        color: _gradientColor.withValues(alpha: isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(DesignTokens.radius16),
        border: Border.all(
          color: _color.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: _color.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space16),
        child: Row(
          children: [
            // 图标
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _gradientColor,
                borderRadius: BorderRadius.circular(DesignTokens.radius14),
                boxShadow: [
                  BoxShadow(
                    color: _color.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(_emoji, style: const TextStyle(fontSize: 28)),
              ),
            ),
            const SizedBox(width: DesignTokens.space16),

            // 信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$minutes分钟加时券',
                    style: AppTextStyles.labelLarge.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: DesignTokens.space4),
                  Row(
                    children: [
                      Icon(
                        Icons.confirmation_number_rounded,
                        size: 14,
                        color: _color,
                      ),
                      const SizedBox(width: DesignTokens.space4),
                      Text(
                        '剩余 $count 张',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: _color,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 使用按钮
            if (onUse != null && count > 0)
              Container(
                decoration: BoxDecoration(
                  color: _gradientColor,
                  borderRadius: BorderRadius.circular(DesignTokens.radius12),
                  boxShadow: [
                    BoxShadow(
                      color: _color.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: isEnabled ? onUse : null,
                    borderRadius: BorderRadius.circular(DesignTokens.radius12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DesignTokens.space16,
                        vertical: DesignTokens.space10,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: DesignTokens.space4),
                          Text(
                            '使用',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 显示加时券兑换对话框的辅助方法
Future<bool?> showCouponExchangeDialog(
  BuildContext context, {
  required int currentPoints,
  required Function(CouponConfig config) onExchange,
}) {
  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black38,
    builder: (context) => CouponExchangeDialog(
      currentPoints: currentPoints,
      onExchange: onExchange,
    ),
  );
}
