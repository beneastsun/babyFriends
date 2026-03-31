import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import 'app_button.dart';

/// 应用对话框样式
enum AppDialogType {
  /// 标准对话框
  standard,
  /// 玻璃拟态对话框
  glass,
  /// 成功对话框
  success,
  /// 错误对话框
  error,
  /// 警告对话框
  warning,
}

/// 显示应用对话框
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
    transitionDuration: DesignTokens.animationNormal,
    pageBuilder: (context, animation, secondaryAnimation) {
      return builder(context);
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        ),
        child: ScaleTransition(
          scale: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
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

/// 确认对话框
class ConfirmDialog extends ConsumerWidget {
  const ConfirmDialog({
    super.key,
    required this.title,
    required this.content,
    this.confirmText = '确认',
    this.cancelText = '取消',
    this.isDangerous = false,
  });

  final String title;
  final String content;
  final String confirmText;
  final String cancelText;
  final bool isDangerous;

  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String content,
    String confirmText = '确认',
    String cancelText = '取消',
    bool isDangerous = false,
  }) {
    return showAppDialog<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: title,
        content: content,
        confirmText: confirmText,
        cancelText: cancelText,
        isDangerous: isDangerous,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radius20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            SizedBox(height: DesignTokens.space16),
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
            SizedBox(height: DesignTokens.space24),
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
                SizedBox(width: DesignTokens.space16),
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

/// 成功对话框
class SuccessDialog extends StatefulWidget {
  const SuccessDialog({
    super.key,
    required this.title,
    this.subtitle,
    this.onConfirm,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onConfirm;

  static Future<void> show({
    required BuildContext context,
    required String title,
    String? subtitle,
    VoidCallback? onConfirm,
  }) {
    return showAppDialog<void>(
      context: context,
      builder: (context) => SuccessDialog(
        title: title,
        subtitle: subtitle,
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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
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
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radius20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 成功图标动画
            ScaleAnimation(
              animation: CurvedAnimation(
                parent: _controller,
                curve: Curves.elasticOut,
              ),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  size: 48,
                  color: AppColors.success,
                ),
              ),
            ),
            SizedBox(height: DesignTokens.space24),
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
              SizedBox(height: DesignTokens.space8),
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
            SizedBox(height: DesignTokens.space24),
            // 确认按钮
            AppButtonPrimary(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onConfirm?.call();
              },
              isFullWidth: true,
              child: Text('太棒了！'),
            ),
          ],
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
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(DesignTokens.radius20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: padding ?? const EdgeInsets.all(DesignTokens.space24),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.glassBackgroundDark
                  : AppColors.glassBackgroundLight,
              borderRadius: BorderRadius.circular(DesignTokens.radius20),
              border: Border.all(
                color: isDark
                    ? AppColors.glassBorderDark
                    : AppColors.glassBorderLight,
                width: 1,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 缩放动画包装器
class ScaleAnimation extends StatelessWidget {
  const ScaleAnimation({
    super.key,
    required this.animation,
    required this.child,
  });

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.scale(
          scale: animation.value,
          child: child,
        );
      },
      child: child,
    );
  }
}
