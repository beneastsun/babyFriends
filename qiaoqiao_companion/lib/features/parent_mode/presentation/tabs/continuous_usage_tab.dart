import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/theme/app_theme.dart';
import 'package:qiaoqiao_companion/shared/providers/continuous_usage_provider.dart';

/// 连续使用设置 Tab
class ContinuousUsageTab extends ConsumerWidget {
  const ContinuousUsageTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(continuousUsageSettingsProvider);
    final notifier = ref.read(continuousUsageSettingsProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        // 功能开关
        _buildSwitchCard(
          title: '启用连续使用限制',
          subtitle: '连续使用应用一段时间后强制休息',
          value: settings.enabled,
          onChanged: (value) => notifier.setEnabled(value),
        ),
        SizedBox(height: AppSpacing.md),

        // 使用限制设置
        if (settings.enabled) ...[
          _buildSliderCard(
            title: '连续使用限制',
            subtitle: '达到限制后将强制休息',
            value: settings.limitMinutes.toDouble(),
            min: 1,
            max: 60,
            divisions: 59,
            unit: '分钟',
            labels: const ['1', '15', '30', '45', '60'],
            onChanged: (value) => notifier.setLimitMinutes(value.round()),
          ),
          SizedBox(height: AppSpacing.md),

          _buildSliderCard(
            title: '强制休息时长',
            subtitle: '休息期间禁止使用监控应用',
            value: settings.restMinutes.toDouble(),
            min: 1,
            max: 30,
            divisions: 29,
            unit: '分钟',
            labels: const ['1', '10', '20', '30'],
            onChanged: (value) => notifier.setRestMinutes(value.round()),
          ),
          SizedBox(height: AppSpacing.lg),

          // 说明卡片
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppBorderRadius.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.primary),
                    SizedBox(width: AppSpacing.sm),
                    Text(
                      '功能说明',
                      style: AppTextStyles.body1.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.sm),
                Text(
                  '• 连续使用时间是指不切换应用、不锁屏的持续使用时长\n'
                  '• 达到限制前 5 分钟和 2 分钟会弹出提醒\n'
                  '• 达到限制后需要强制休息，休息期间无法使用监控应用\n'
                  '• 休息结束后可以继续正常使用',
                  style: AppTextStyles.body2,
                ),
              ],
            ),
          ),
        ],

        // 预览卡片（当功能开启时显示）
        if (settings.enabled) ...[
          SizedBox(height: AppSpacing.lg),
          _buildPreviewCard(settings),
        ],
      ],
    );
  }

  Widget _buildSwitchCard({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.body1),
                  SizedBox(height: AppSpacing.xs),
                  Text(subtitle, style: AppTextStyles.caption),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderCard({
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String unit,
    required List<String> labels,
    required Function(double) onChanged,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.body1),
                    SizedBox(height: AppSpacing.xs),
                    Text(subtitle, style: AppTextStyles.caption),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppBorderRadius.md),
                  ),
                  child: Text(
                    '${value.round()} $unit',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.sm),
            Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
            // 刻度标签
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: labels
                    .map((label) => Text(
                          label,
                          style: AppTextStyles.caption.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard(ContinuousUsageSettings settings) {
    return Card(
      color: AppTheme.surfaceColor,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '设置预览',
              style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(Icons.timer_outlined, size: 20, color: AppTheme.textSecondary),
                SizedBox(width: AppSpacing.xs),
                Text(
                  '每连续使用 ${settings.limitMinutes} 分钟',
                  style: AppTextStyles.body2,
                ),
              ],
            ),
            SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Icon(Icons.coffee_outlined, size: 20, color: AppTheme.textSecondary),
                SizedBox(width: AppSpacing.xs),
                Text(
                  '需要休息 ${settings.restMinutes} 分钟',
                  style: AppTextStyles.body2,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
