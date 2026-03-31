import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/theme/app_theme.dart';
import 'package:qiaoqiao_companion/core/services/services.dart';
import 'package:qiaoqiao_companion/shared/widgets/design_system/app_button.dart';

/// 暂停监控页面
class PauseMonitorPage extends ConsumerStatefulWidget {
  const PauseMonitorPage({super.key});

  @override
  ConsumerState<PauseMonitorPage> createState() => _PauseMonitorPageState();
}

class _PauseMonitorPageState extends ConsumerState<PauseMonitorPage> {
  int _duration = 30; // 分钟
  String _reason = '';
  bool _isSubmitting = false;
  bool _isCurrentlyPaused = false;

  @override
  void initState() {
    super.initState();
    _checkPauseStatus();
  }

  Future<void> _checkPauseStatus() async {
    // TODO: 检查当前是否暂停
    setState(() => _isCurrentlyPaused = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('暂停监控'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 警告卡片
            Card(
              color: AppColors.warning.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber,
                      color: AppColors.warning,
                    ),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '注意',
                            style: AppTextStyles.heading3.copyWith(
                              color: AppColors.warning,
                            ),
                          ),
                          SizedBox(height: AppSpacing.sm),
                          Text(
                            '暂停监控期间，使用时间将不会被记录和限制。请谨慎使用此功能。',
                            style: AppTextStyles.body2.copyWith(
                              color: AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: AppSpacing.lg),

            // 当前状态
            if (_isCurrentlyPaused) ...[
              _buildCurrentPauseStatus(),
              SizedBox(height: AppSpacing.lg),
            ],

            // 暂停时长选择
            Text('暂停时长', style: AppTextStyles.heading3),
            SizedBox(height: AppSpacing.md),
            _buildDurationSelector(),
            SizedBox(height: AppSpacing.lg),

            // 原因输入
            Text('暂停原因', style: AppTextStyles.heading3),
            SizedBox(height: AppSpacing.md),
            TextField(
              onChanged: (value) => _reason = value,
              decoration: const InputDecoration(
                hintText: '例如：需要使用学习软件',
                prefixIcon: Icon(Icons.edit_note),
              ),
            ),
            SizedBox(height: AppSpacing.xl),

            // 操作按钮
            if (_isCurrentlyPaused) ...[
              AppButtonPrimary(
                onPressed: _isSubmitting ? null : _resumeMonitor,
                icon: const Icon(Icons.play_arrow),
                isFullWidth: true,
                child: const Text('恢复监控'),
              ),
            ] else ...[
              AppButtonPrimary(
                onPressed: _isSubmitting ? null : _pauseMonitor,
                icon: _isSubmitting ? null : const Icon(Icons.pause),
                isLoading: _isSubmitting,
                isFullWidth: true,
                child: Text(_isSubmitting ? '处理中...' : '暂停监控'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentPauseStatus() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.pause_circle,
                color: AppColors.warning,
              ),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '监控已暂停',
                    style: AppTextStyles.heading3,
                  ),
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    '将在设定时间后自动恢复',
                    style: AppTextStyles.body2,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationSelector() {
    final durations = [
      (15, '15分钟'),
      (30, '30分钟'),
      (60, '1小时'),
      (120, '2小时'),
      (180, '3小时'),
      (360, '6小时'),
    ];

    return Column(
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: durations.map((item) {
            final (minutes, label) = item;
            final isSelected = _duration == minutes;

            return FilterChip(
              label: Text(label),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _duration = minutes);
                }
              },
              selectedColor: AppColors.warning,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textPrimary,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<void> _pauseMonitor() async {
    setState(() => _isSubmitting = true);

    try {
      // TODO: 实现暂停监控
      // await ref.read(usageMonitorServiceProvider.notifier).pause(_duration);

      await Future.delayed(const Duration(milliseconds: 500)); // 模拟操作

      if (mounted) {
        setState(() => _isCurrentlyPaused = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('监控已暂停 $_duration 分钟'),
            backgroundColor: AppColors.warning,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('操作失败: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _resumeMonitor() async {
    setState(() => _isSubmitting = true);

    try {
      // TODO: 实现恢复监控
      // await ref.read(usageMonitorServiceProvider.notifier).resume();

      await Future.delayed(const Duration(milliseconds: 500)); // 模拟操作

      if (mounted) {
        setState(() => _isCurrentlyPaused = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('监控已恢复'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('操作失败: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
