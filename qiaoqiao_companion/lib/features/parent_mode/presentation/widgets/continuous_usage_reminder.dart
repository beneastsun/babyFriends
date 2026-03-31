import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qiaoqiao_companion/core/theme/app_theme.dart';
import 'package:qiaoqiao_companion/shared/widgets/design_system/app_button.dart';

/// 连续使用提醒弹窗
///
/// 显示可拖动的提醒弹窗，用于连续使用时间限制的警告
class ContinuousUsageReminder extends StatefulWidget {
  final int remainingSeconds;
  final String alertLevel; // '5min', '2min', 'atLimit'
  final VoidCallback? onDismiss;
  final VoidCallback? onRestNow;

  const ContinuousUsageReminder({
    super.key,
    required this.remainingSeconds,
    required this.alertLevel,
    this.onDismiss,
    this.onRestNow,
  });

  @override
  State<ContinuousUsageReminder> createState() => _ContinuousUsageReminderState();
}

class _ContinuousUsageReminderState extends State<ContinuousUsageReminder> {
  late int _remainingSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.remainingSeconds;
    _startTimer();
  }

  @override
  void didUpdateWidget(ContinuousUsageReminder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.remainingSeconds != widget.remainingSeconds) {
      _remainingSeconds = widget.remainingSeconds;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.all(AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: _getBackgroundColor(),
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      _getIcon(),
                      color: _getIconColor(),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Text(
                      _getTitle(),
                      style: AppTextStyles.heading3.copyWith(color: Colors.white),
                    ),
                  ],
                ),
                if (widget.onDismiss != null)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: widget.onDismiss,
                  ),
              ],
            ),
            SizedBox(height: AppSpacing.sm),

            // 倒计时
            Text(
              _formatTime(_remainingSeconds),
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: AppSpacing.xs),
            Text(
              _getMessage(),
              style: AppTextStyles.body2.copyWith(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.md),

            // 按钮
            if (widget.alertLevel != 'atLimit')
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  AppButtonGhost(
                    onPressed: widget.onDismiss,
                    child: Text(
                      '继续使用',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                    ),
                  ),
                  AppButtonPrimary(
                    onPressed: widget.onRestNow,
                    child: Text('现在休息'),
                  ),
                ],
              )
            else
              AppButtonPrimary(
                onPressed: widget.onRestNow,
                isFullWidth: true,
                child: Text('开始休息'),
              ),
          ],
        ),
      ),
    );
  }

  Color _getBackgroundColor() {
    switch (widget.alertLevel) {
      case '5min':
        return AppColors.warning;
      case '2min':
        return AppColors.error.withValues(alpha: 0.8);
      case 'atLimit':
        return AppColors.error;
      default:
        return AppColors.primary;
    }
  }

  IconData _getIcon() {
    switch (widget.alertLevel) {
      case '5min':
        return Icons.info_outline;
      case '2min':
        return Icons.warning_amber_outlined;
      case 'atLimit':
        return Icons.timer_off_outlined;
      default:
        return Icons.timer_outlined;
    }
  }

  Color _getIconColor() {
    return Colors.white;
  }

  String _getTitle() {
    switch (widget.alertLevel) {
      case '5min':
        return '即将达到限制';
      case '2min':
        return '请注意休息';
      case 'atLimit':
        return '时间到啦';
      default:
        return '连续使用提醒';
    }
  }

  String _getMessage() {
    switch (widget.alertLevel) {
      case '5min':
        return '连续使用时间还有 5 分钟就要到了\n建议提前休息一下眼睛';
      case '2min':
        return '连续使用时间即将达到限制\n请准备结束当前活动';
      case 'atLimit':
        return '连续使用时间已达到限制\n现在需要休息一下才能继续';
      default:
        return '请注意连续使用时间';
    }
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}

/// 显示连续使用提醒的辅助函数
Future<void> showContinuousUsageReminder({
  required BuildContext context,
  required int remainingSeconds,
  required String alertLevel,
  VoidCallback? onDismiss,
  VoidCallback? onRestNow,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      child: ContinuousUsageReminder(
        remainingSeconds: remainingSeconds,
        alertLevel: alertLevel,
        onDismiss: () {
          Navigator.of(context).pop();
          onDismiss?.call();
        },
        onRestNow: () {
          Navigator.of(context).pop();
          onRestNow?.call();
        },
      ),
    ),
  );
}
