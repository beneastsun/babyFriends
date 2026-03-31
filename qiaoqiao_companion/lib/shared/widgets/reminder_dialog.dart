import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:qiaoqiao_companion/core/theme/app_theme.dart';
import 'package:qiaoqiao_companion/core/theme/app_solid_colors.dart';
import 'package:qiaoqiao_companion/shared/widgets/qiaoqiao_character.dart';

/// 提醒对话框类型
enum ReminderDialogType {
  gentle, // 温和提醒
  serious, // 认真警告
  final_, // 最后警告
  locked, // 锁定
}

/// 提醒对话框组件 - 可爱糖果风格
class ReminderDialog extends StatefulWidget {
  final String title;
  final String message;
  final ReminderDialogType type;
  final int? countdownSeconds;
  final VoidCallback? onConfirm;
  final VoidCallback? onExtend; // 使用加时券

  const ReminderDialog({
    super.key,
    required this.title,
    required this.message,
    required this.type,
    this.countdownSeconds,
    this.onConfirm,
    this.onExtend,
  });

  @override
  State<ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends State<ReminderDialog>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _pulseController;
  late AnimationController _floatController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _floatAnimation;

  int? _remainingSeconds;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.countdownSeconds;

    // 主入场动画
    _mainController = AnimationController(
      duration: DesignTokens.animationPageTransition,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: Curves.easeOut),
    );

    // 脉冲动画
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // 浮动动画
    _floatController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _floatAnimation = Tween<double>(begin: 0, end: 1.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _mainController.forward();
    _pulseController.repeat(reverse: true);
    _floatController.repeat(reverse: true);

    // 开始倒计时
    if (_remainingSeconds != null && _remainingSeconds! > 0) {
      _startCountdown();
    }
  }

  /// 获取纯色配色
  Color _getGradient() {
    switch (widget.type) {
      case ReminderDialogType.gentle:
        return AppSolidColors.qiaoqiaoHappy;
      case ReminderDialogType.serious:
        return AppSolidColors.qiaoqiaoRemind;
      case ReminderDialogType.final_:
        return AppSolidColors.qiaoqiaoSerious;
      case ReminderDialogType.locked:
        return AppSolidColors.qiaoqiaoSad;
    }
  }

  /// 获取强调色 - 使用糖果主题配色
  Color _getAccentColor() {
    switch (widget.type) {
      case ReminderDialogType.gentle:
        return const Color(0xFF81C784); // 薄荷绿
      case ReminderDialogType.serious:
        return const Color(0xFFFFB74D); // 蜜桃橙
      case ReminderDialogType.final_:
        return const Color(0xFFFFAB91); // 蜜桃粉
      case ReminderDialogType.locked:
        return const Color(0xFFFF6B6B); // 糖果红
    }
  }

  void _startCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      if (_remainingSeconds != null && _remainingSeconds! > 0) {
        setState(() {
          _remainingSeconds = _remainingSeconds! - 1;
        });
        _startCountdown();
      }
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _pulseController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _getGradient();
    final accentColor = _getAccentColor();

    return AnimatedBuilder(
      animation: _mainController,
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
            constraints: const BoxConstraints(maxWidth: 360),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(DesignTokens.radius24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.3),
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
                  ..._buildDecorations(),

                  // 主要内容
                  Padding(
                    padding: const EdgeInsets.all(DesignTokens.space24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 巧巧头像
                        _buildAvatar(accentColor),

                        const SizedBox(height: DesignTokens.space16),

                        // 标题
                        Text(
                          widget.title,
                          style: AppTextStyles.heading2.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: DesignTokens.space12),

                        // 消息
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: DesignTokens.space16,
                            vertical: DesignTokens.space12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(DesignTokens.radius16),
                          ),
                          child: Text(
                            widget.message,
                            style: AppTextStyles.labelMedium.copyWith(
                              color: Colors.white.withValues(alpha: 0.95),
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                        // 倒计时
                        if (_remainingSeconds != null &&
                            _remainingSeconds! > 0) ...[
                          const SizedBox(height: DesignTokens.space20),
                          _buildCountdown(),
                        ],

                        const SizedBox(height: DesignTokens.space24),

                        // 按钮
                        _buildButtons(accentColor),
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

  /// 构建装饰性元素
  List<Widget> _buildDecorations() {
    return [
      Positioned(
        top: -30 + (_floatAnimation.value * 10),
        right: -20,
        child: AnimatedBuilder(
          animation: _floatController,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _floatAnimation.value * 8),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
            );
          },
        ),
      ),
      Positioned(
        bottom: -20 + (_floatAnimation.value * 8),
        left: -30,
        child: AnimatedBuilder(
          animation: _floatController,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, -_floatAnimation.value * 6),
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
            );
          },
        ),
      ),
    ];
  }

  /// 构建头像 - 使用小熊角色组件
  Widget _buildAvatar(Color accentColor) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.9),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.3),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: QiaoqiaoBear(
              mood: _getBearMood(),
              size: 80,
              enableAnimation: true,
              showDecorations: true,
            ),
          ),
        );
      },
    );
  }

  /// 根据提醒类型获取小熊心情
  QiaoqiaoBearMood _getBearMood() {
    switch (widget.type) {
      case ReminderDialogType.gentle:
        return QiaoqiaoBearMood.happy;
      case ReminderDialogType.serious:
        return QiaoqiaoBearMood.thinking;
      case ReminderDialogType.final_:
        return QiaoqiaoBearMood.worried;
      case ReminderDialogType.locked:
        return QiaoqiaoBearMood.sad;
    }
  }

  /// 构建倒计时
  Widget _buildCountdown() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.space24,
        vertical: DesignTokens.space12,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(DesignTokens.radius20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_outlined,
            color: Colors.white,
            size: 28,
          ),
          const SizedBox(width: DesignTokens.space10),
          Text(
            '$_remainingSeconds',
            style: AppTextStyles.displaySmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: DesignTokens.space6),
          Text(
            '秒',
            style: AppTextStyles.labelMedium.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建按钮
  Widget _buildButtons(Color accentColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.type != ReminderDialogType.locked &&
            widget.onExtend != null) ...[
          _GlassButton(
            label: '使用加时券',
            icon: Icons.card_giftcard_rounded,
            isSecondary: true,
            primaryColor: accentColor,
            secondaryColor: accentColor.withValues(alpha: 0.8),
            onTap: widget.onExtend!,
          ),
          const SizedBox(width: DesignTokens.space12),
        ],
        _GlassButton(
          label: widget.type == ReminderDialogType.locked ? '知道了' : '去休息',
          icon: widget.type == ReminderDialogType.locked
              ? Icons.check_circle_outline_rounded
              : Icons.bedtime_rounded,
          primaryColor: accentColor,
          secondaryColor: accentColor.withValues(alpha: 0.8),
          onTap: widget.onConfirm ?? () => Navigator.pop(context),
        ),
      ],
    );
  }
}

/// 玻璃风格按钮
class _GlassButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isSecondary;
  final Color primaryColor;
  final Color secondaryColor;
  final VoidCallback onTap;

  const _GlassButton({
    required this.label,
    required this.icon,
    this.isSecondary = false,
    required this.primaryColor,
    required this.secondaryColor,
    required this.onTap,
  });

  @override
  State<_GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<_GlassButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: DesignTokens.animationQuick,
        padding: EdgeInsets.symmetric(
          horizontal: widget.isSecondary ? DesignTokens.space16 : DesignTokens.space20,
          vertical: DesignTokens.space12,
        ),
        decoration: BoxDecoration(
          gradient: widget.isSecondary
              ? null
              : LinearGradient(
                  colors: [
                    widget.primaryColor,
                    widget.secondaryColor,
                  ],
                ),
          color: widget.isSecondary
              ? Colors.white.withValues(alpha: _isPressed ? 0.7 : 0.5)
              : null,
          borderRadius: BorderRadius.circular(DesignTokens.radius14),
          border: Border.all(
            color: widget.isSecondary
                ? Colors.white.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: widget.isSecondary
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.icon,
              size: 18,
              color: widget.isSecondary
                  ? Colors.white.withValues(alpha: 0.9)
                  : Colors.white,
            ),
            const SizedBox(width: DesignTokens.space8),
            Text(
              widget.label,
              style: AppTextStyles.labelMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 显示提醒对话框的辅助方法
class ReminderDialogHelper {
  static Future<void> showGentle(
    BuildContext context, {
    required int remainingMinutes,
    VoidCallback? onConfirm,
    VoidCallback? onExtend,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black38,
      builder: (context) => ReminderDialog(
        title: '快到时间啦~',
        message: '还有 $remainingMinutes 分钟，记得休息哦！',
        type: ReminderDialogType.gentle,
        onConfirm: onConfirm,
        onExtend: onExtend,
      ),
    );
  }

  static Future<void> showSerious(
    BuildContext context, {
    VoidCallback? onConfirm,
    VoidCallback? onExtend,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black38,
      builder: (context) => ReminderDialog(
        title: '时间到啦！',
        message: '纹纹提醒你该休息了~',
        type: ReminderDialogType.serious,
        onConfirm: onConfirm,
        onExtend: onExtend,
      ),
    );
  }

  static Future<void> showFinal(
    BuildContext context, {
    required int remainingSeconds,
    VoidCallback? onConfirm,
    VoidCallback? onExtend,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black38,
      builder: (context) => ReminderDialog(
        title: '最后警告',
        message: '还在玩的话...纹纹要强制休息了哦！',
        type: ReminderDialogType.final_,
        countdownSeconds: remainingSeconds,
        onConfirm: onConfirm,
        onExtend: onExtend,
      ),
    );
  }

  static Future<void> showLocked(
    BuildContext context, {
    required String reason,
    VoidCallback? onConfirm,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black38,
      builder: (context) => ReminderDialog(
        title: '时间结束',
        message: reason,
        type: ReminderDialogType.locked,
        onConfirm: onConfirm,
      ),
    );
  }
}
