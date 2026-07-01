import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_solid_colors.dart';
import '../../providers/theme_provider.dart';
import 'app_button.dart';

/// 对话框类型 - Kawaii Dream 风格
enum AppDialogType {
  /// 标准对话框
  standard,
  /// 玻璃拟态对话框
  glass,
  /// 成功对话框 - 薄荷绿
  success,
  /// 错误对话框 - 珊瑚红
  error,
  /// 警告对话框 - 橙黄色
  warning,
  /// 信息对话框 - 天蓝色
  info,
  /// 可爱对话框 - 粉紫渐变
  cute,
}

/// 显示应用对话框 - Kawaii Dream 风格
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  AppDialogType type = AppDialogType.standard,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor ?? Colors.black54,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    transitionDuration: AppAnimations.normal,
    pageBuilder: (context, animation, secondaryAnimation) {
      return builder(context);
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: AppAnimations.enter,
        ),
        child: ScaleTransition(
          scale: CurvedAnimation(
            parent: animation,
            curve: AppAnimations.playful,
          ),
          child: type == AppDialogType.glass
              ? BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: child,
                )
              : child,
        ),
      );
    },
  );
}

/// 确认对话框 - Kawaii Dream 风格
class ConfirmDialog extends ConsumerWidget {
  const ConfirmDialog({
    super.key,
    required this.title,
    required this.content,
    this.confirmText = '确认',
    this.cancelText = '取消',
    this.isDangerous = false,
    this.icon,
  });

  final String title;
  final String content;
  final String confirmText;
  final String cancelText;
  final bool isDangerous;
  final IconData? icon;

  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String content,
    String confirmText = '确认',
    String cancelText = '取消',
    bool isDangerous = false,
    IconData? icon,
  }) {
    return showAppDialog<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: title,
        content: content,
        confirmText: confirmText,
        cancelText: cancelText,
        isDangerous: isDangerous,
        icon: icon,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeType = ref.watch(themeTypeProvider);
    final colors = ref.watch(colorSchemeProvider);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(DesignTokens.space24),
        decoration: BoxDecoration(
          color: isDark ? colors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(DesignTokens.radius24),
          boxShadow: AppShadows.dialog,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 图标 (如果提供)
            if (icon != null) ...[
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: (isDangerous
                          ? AppSolidColors.error
                          : AppSolidColors.getPrimaryColor(themeType, isDark))
                      .withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: isDangerous
                      ? AppSolidColors.error
                      : AppSolidColors.getPrimaryColor(themeType, isDark),
                ),
              ),
              const SizedBox(height: DesignTokens.space16),
            ],
            // 标题
            Text(
              title,
              style: AppTextStyles.heading2.copyWith(
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DesignTokens.space12),
            // 内容
            Text(
              content,
              style: AppTextStyles.bodyMedium.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DesignTokens.space24),
            // 按钮
            Row(
              children: [
                Expanded(
                  child: AppButtonGhost(
                    onPressed: () => Navigator.of(context).pop(false),
                    isFullWidth: true,
                    child: Text(cancelText),
                  ),
                ),
                const SizedBox(width: DesignTokens.space12),
                Expanded(
                  child: isDangerous
                      ? AppButtonDanger(
                          onPressed: () => Navigator.of(context).pop(true),
                          isFullWidth: true,
                          child: Text(confirmText),
                        )
                      : AppButtonPrimary(
                          onPressed: () => Navigator.of(context).pop(true),
                          isFullWidth: true,
                          child: Text(confirmText),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 成功对话框 - 可爱的庆祝效果
class SuccessDialog extends StatefulWidget {
  const SuccessDialog({
    super.key,
    required this.title,
    this.subtitle,
    this.confirmText = '太棒了！',
    this.icon,
    this.onConfirm,
  });

  final String title;
  final String? subtitle;
  final String confirmText;
  final IconData? icon;
  final VoidCallback? onConfirm;

  static Future<void> show({
    required BuildContext context,
    required String title,
    String? subtitle,
    String confirmText = '太棒了！',
    IconData? icon,
    VoidCallback? onConfirm,
  }) {
    return showAppDialog<void>(
      context: context,
      type: AppDialogType.success,
      builder: (context) => SuccessDialog(
        title: title,
        subtitle: subtitle,
        confirmText: confirmText,
        icon: icon,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  State<SuccessDialog> createState() => _SuccessDialogState();
}

class _SuccessDialogState extends State<SuccessDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppAnimations.slow,
      vsync: this,
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2), weight: 0.5),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 0.5),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: AppAnimations.elastic,
    ));
    _rotateAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: -0.1, end: 0.1), weight: 0.5),
      TweenSequenceItem(tween: Tween(begin: 0.1, end: 0.0), weight: 0.5),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(DesignTokens.space24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(DesignTokens.radius24),
          boxShadow: AppShadows.success,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 成功图标动画
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Transform.rotate(
                    angle: _rotateAnimation.value,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppSolidColors.success.withOpacity(0.15),
                        shape: BoxShape.circle,
                        boxShadow: AppShadows.glowSuccess,
                      ),
                      child: Icon(
                        widget.icon ?? Icons.check_circle_rounded,
                        size: 48,
                        color: AppSolidColors.success,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: DesignTokens.space20),
            // 标题
            Text(
              widget.title,
              style: AppTextStyles.heading2.copyWith(
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
              textAlign: TextAlign.center,
            ),
            if (widget.subtitle != null) ...[
              const SizedBox(height: DesignTokens.space8),
              Text(
                widget.subtitle!,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: DesignTokens.space24),
            // 确认按钮
            AppButtonTertiary(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onConfirm?.call();
              },
              isFullWidth: true,
              child: Text(widget.confirmText),
            ),
          ],
        ),
      ),
    );
  }
}

/// 错误对话框 - 抖动效果
class ErrorDialog extends StatefulWidget {
  const ErrorDialog({
    super.key,
    required this.title,
    this.subtitle,
    this.confirmText = '我知道了',
    this.onConfirm,
  });

  final String title;
  final String? subtitle;
  final String confirmText;
  final VoidCallback? onConfirm;

  static Future<void> show({
    required BuildContext context,
    required String title,
    String? subtitle,
    String confirmText = '我知道了',
    VoidCallback? onConfirm,
  }) {
    return showAppDialog<void>(
      context: context,
      type: AppDialogType.error,
      builder: (context) => ErrorDialog(
        title: title,
        subtitle: subtitle,
        confirmText: confirmText,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  State<ErrorDialog> createState() => _ErrorDialogState();
}

class _ErrorDialogState extends State<ErrorDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    // 抖动动画
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -10), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10, end: 10), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 10, end: -6), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -6, end: 6), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 6, end: 0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: AnimatedBuilder(
        animation: _shakeAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(_shakeAnimation.value, 0),
            child: child,
          );
        },
        child: Container(
          padding: const EdgeInsets.all(DesignTokens.space24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(DesignTokens.radius24),
            boxShadow: AppShadows.error,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 错误图标
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppSolidColors.error.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_rounded,
                  size: 48,
                  color: AppSolidColors.error,
                ),
              ),
              const SizedBox(height: DesignTokens.space20),
              // 标题
              Text(
                widget.title,
                style: AppTextStyles.heading2.copyWith(
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
                textAlign: TextAlign.center,
              ),
              if (widget.subtitle != null) ...[
                const SizedBox(height: DesignTokens.space8),
                Text(
                  widget.subtitle!,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: DesignTokens.space24),
              // 确认按钮
              AppButtonDanger(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onConfirm?.call();
                },
                isFullWidth: true,
                child: Text(widget.confirmText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 玻璃拟态对话框
class GlassDialog extends StatelessWidget {
  const GlassDialog({
    super.key,
    required this.child,
    this.padding,
    this.showBorder = true,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(DesignTokens.radius24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: padding ?? const EdgeInsets.all(DesignTokens.space24),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.glassBackgroundDark
                  : AppColors.glassBackgroundLight,
              borderRadius: BorderRadius.circular(DesignTokens.radius24),
              border: showBorder
                  ? Border.all(
                      color: isDark
                          ? AppColors.glassBorderDark
                          : AppColors.glassBorderLight,
                      width: 1,
                    )
                  : null,
              boxShadow: AppShadows.dialogGlass,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 可爱对话框 - 粉紫渐变标题栏
class CuteDialog extends ConsumerWidget {
  const CuteDialog({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.icon,
    this.showGradientHeader = true,
  });

  final String title;
  final Widget child;
  final List<Widget> actions;
  final IconData? icon;
  final bool showGradientHeader;

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget child,
    List<Widget> actions = const [],
    IconData? icon,
    bool showGradientHeader = true,
  }) {
    return showAppDialog<T>(
      context: context,
      type: AppDialogType.cute,
      builder: (context) => CuteDialog(
        title: title,
        child: child,
        actions: actions,
        icon: icon,
        showGradientHeader: showGradientHeader,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeType = ref.watch(themeTypeProvider);

    return Dialog(
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radius24),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(DesignTokens.radius24),
          boxShadow: AppShadows.dialog,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 渐变标题栏
            if (showGradientHeader)
              Container(
                padding: const EdgeInsets.all(DesignTokens.space20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppSolidColors.getPrimaryColor(themeType, isDark),
                      AppSolidColors.getSecondaryColor(themeType, isDark),
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(DesignTokens.radius24),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(
                        icon,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: DesignTokens.space8),
                    ],
                    Text(
                      title,
                      style: AppTextStyles.heading3.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(DesignTokens.space20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(
                        icon,
                        color: AppSolidColors.getPrimaryColor(themeType, isDark),
                        size: 24,
                      ),
                      const SizedBox(width: DesignTokens.space8),
                    ],
                    Text(
                      title,
                      style: AppTextStyles.heading3.copyWith(
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            // 内容
            Padding(
              padding: const EdgeInsets.all(DesignTokens.space20),
              child: child,
            ),
            // 操作按钮
            if (actions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  DesignTokens.space20,
                  0,
                  DesignTokens.space20,
                  DesignTokens.space20,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: actions,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 提醒对话框 - 巧巧专用
class ReminderDialog extends ConsumerWidget {
  const ReminderDialog({
    super.key,
    required this.title,
    required this.message,
    required this.usagePercentage,
    this.onConfirm,
    this.onExtend,
    this.showExtend = false,
  });

  final String title;
  final String message;
  final double usagePercentage;
  final VoidCallback? onConfirm;
  final VoidCallback? onExtend;
  final bool showExtend;

  static Future<void> show({
    required BuildContext context,
    required String title,
    required String message,
    required double usagePercentage,
    VoidCallback? onConfirm,
    VoidCallback? onExtend,
    bool showExtend = false,
  }) {
    return showAppDialog<void>(
      context: context,
      builder: (context) => ReminderDialog(
        title: title,
        message: message,
        usagePercentage: usagePercentage,
        onConfirm: onConfirm,
        onExtend: onExtend,
        showExtend: showExtend,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final moodColor = AppSolidColors.getQiaoqiaoMoodColor(usagePercentage);
    final moodLightColor = AppSolidColors.getQiaoqiaoMoodLightColor(usagePercentage);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(DesignTokens.space24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [moodColor, moodLightColor],
          ),
          borderRadius: BorderRadius.circular(DesignTokens.radius24),
          boxShadow: AppShadows.qiaoqiaoMood(usagePercentage),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题
            Text(
              title,
              style: AppTextStyles.heading2.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DesignTokens.space12),
            // 消息
            Text(
              message,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.white.withOpacity(0.95),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DesignTokens.space24),
            // 按钮
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onConfirm?.call();
                    },
                    type: AppButtonType.outline,
                    child: const Text('我知道了'),
                  ),
                ),
                if (showExtend) ...[
                  const SizedBox(width: DesignTokens.space12),
                  Expanded(
                    child: AppButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        onExtend?.call();
                      },
                      type: AppButtonType.primary,
                      child: const Text('延长时间'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
