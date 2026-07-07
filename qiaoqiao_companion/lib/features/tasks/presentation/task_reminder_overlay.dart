import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:qiaoqiao_companion/shared/models/task_definition.dart';

/// 任务提醒展示性弹窗（前台时使用 OverlayEntry）
/// 位置：屏幕顶部居中，不抢焦点，30秒自动关闭
class TaskReminderOverlay {
  static OverlayEntry? _entry;
  static Timer? _timer;
  static final AudioPlayer _audioPlayer = AudioPlayer();

  static void show(BuildContext context, TaskDefinition task) {
    // 如果已有弹窗显示，先移除
    _remove();

    _entry = OverlayEntry(
      builder: (context) => _ReminderWidget(
        task: task,
        onClose: () => _remove(),
      ),
    );

    Overlay.of(context).insert(_entry!);

    // 播放提示音
    _playReminderSound();

    // 30秒后自动关闭
    _timer = Timer(const Duration(seconds: 30), () => _remove());
  }

  static void _remove() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }

  static Future<void> _playReminderSound() async {
    try {
      await _audioPlayer.play(AssetSource('audio/reminder.mp3'));
    } catch (_) {}
  }
}

class _ReminderWidget extends StatefulWidget {
  final TaskDefinition task;
  final VoidCallback onClose;

  const _ReminderWidget({required this.task, required this.onClose});

  @override
  State<_ReminderWidget> createState() => _ReminderWidgetState();
}

class _ReminderWidgetState extends State<_ReminderWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnim,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Text(widget.task.emoji, style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.task.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '该完成啦！',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: widget.onClose,
                  iconSize: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
