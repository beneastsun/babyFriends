import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/theme/app_theme.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';
import 'package:qiaoqiao_companion/shared/models/models.dart';
import 'package:qiaoqiao_companion/shared/providers/rules_provider.dart';

/// 总时长设置 Tab
class TotalTimeTab extends ConsumerStatefulWidget {
  const TotalTimeTab({super.key});

  @override
  ConsumerState<TotalTimeTab> createState() => _TotalTimeTabState();
}

class _TotalTimeTabState extends ConsumerState<TotalTimeTab> {
  @override
  void initState() {
    super.initState();
    // 加载数据
    Future.microtask(() => ref.read(rulesProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final rulesState = ref.watch(rulesProvider);
    final notifier = ref.read(rulesProvider.notifier);
    final totalTimeRule = rulesState.totalTimeRule;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        // 功能开关
        _buildSwitchCard(
          title: '启用每日总时长限制',
          subtitle: '限制每天使用平板的总时间',
          value: totalTimeRule?.enabled ?? false,
          onChanged: (value) => _updateEnabled(notifier, totalTimeRule, value),
        ),
        SizedBox(height: AppSpacing.md),

        // 时长设置
        if (totalTimeRule?.enabled ?? false) ...[
          _buildSliderCard(
            title: '工作日每日限额',
            subtitle: '周一至周五的使用时长限制',
            value: (totalTimeRule?.weekdayLimitMinutes ?? 120).toDouble(),
            min: 0,
            max: 480,
            divisions: 16,
            unit: '分钟',
            labels: const ['0', '1h', '2h', '3h', '4h', '5h', '6h', '7h', '8h'],
            formatValue: _formatMinutes,
            onChanged: (value) => _updateWeekdayLimit(notifier, totalTimeRule, value.round()),
          ),
          SizedBox(height: AppSpacing.md),

          _buildSliderCard(
            title: '周末每日限额',
            subtitle: '周六、周日的使用时长限制',
            value: (totalTimeRule?.weekendLimitMinutes ?? 180).toDouble(),
            min: 0,
            max: 480,
            divisions: 16,
            unit: '分钟',
            labels: const ['0', '1h', '2h', '3h', '4h', '5h', '6h', '7h', '8h'],
            formatValue: _formatMinutes,
            onChanged: (value) => _updateWeekendLimit(notifier, totalTimeRule, value.round()),
          ),
          SizedBox(height: AppSpacing.lg),

          // 说明卡片
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppBorderRadius.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.info),
                    SizedBox(width: AppSpacing.sm),
                    Text(
                      '功能说明',
                      style: AppTextStyles.body1.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.info,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.sm),
                Text(
                  '• 总时长限制只针对【应用】中添加的监控应用\n'
                  '• 未添加到监控列表的应用不受此限制\n'
                  '• 工作日和周末可以设置不同的时间限额\n'
                  '• 达到限额前 5 分钟会弹出提醒\n'
                  '• 超过限额后 8 分钟将强制锁定',
                  style: AppTextStyles.body2,
                ),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.lg),

          // 预览卡片
          _buildPreviewCard(totalTimeRule),
        ],
      ],
    );
  }

  Widget _buildSwitchCard({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
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
    required String Function(int) formatValue,
    required ValueChanged<double> onChanged,
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
                    formatValue(value.round()),
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

  Widget _buildPreviewCard(Rule? totalTimeRule) {
    final weekdayMinutes = totalTimeRule?.weekdayLimitMinutes ?? 0;
    final weekendMinutes = totalTimeRule?.weekendLimitMinutes ?? 0;

    return Card(
      color: AppTheme.surfaceColor,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '当前设置',
              style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(Icons.weekend_outlined, size: 20, color: AppTheme.textSecondary),
                SizedBox(width: AppSpacing.xs),
                Text(
                  '工作日：${_formatMinutes(weekdayMinutes)}',
                  style: AppTextStyles.body2,
                ),
              ],
            ),
            SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 20, color: AppTheme.textSecondary),
                SizedBox(width: AppSpacing.xs),
                Text(
                  '周末：${_formatMinutes(weekendMinutes)}',
                  style: AppTextStyles.body2,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatMinutes(int minutes) {
    if (minutes == 0) {
      return '无限制';
    } else if (minutes < 60) {
      return '$minutes 分钟';
    } else {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      if (mins == 0) {
        return '$hours 小时';
      } else {
        return '$hours 小时 $mins 分钟';
      }
    }
  }

  Future<void> _updateEnabled(RulesNotifier notifier, Rule? rule, bool enabled) async {
    print('[TotalTimeTab] _updateEnabled: rule=$rule, rule.id=${rule?.id}, enabled=$enabled');
    if (rule == null || rule.id == null) {
      // 创建新规则
      print('[TotalTimeTab] 创建新规则: enabled=$enabled');
      final newRule = Rule(
        ruleType: RuleType.totalTime,
        weekdayLimitMinutes: 120,
        weekendLimitMinutes: 180,
        enabled: enabled,
      );
      await notifier.addRule(newRule);
    } else {
      // 更新现有规则
      print('[TotalTimeTab] 更新现有规则: id=${rule.id}, oldEnabled=${rule.enabled}, newEnabled=$enabled');
      final updated = rule.copyWith(enabled: enabled);
      await notifier.updateRule(updated);
    }
    print('[TotalTimeTab] _updateEnabled 完成');
  }

  Future<void> _updateWeekdayLimit(RulesNotifier notifier, Rule? rule, int minutes) async {
    if (rule == null) return;
    final updated = rule.copyWith(weekdayLimitMinutes: minutes);
    await notifier.updateRule(updated);
  }

  Future<void> _updateWeekendLimit(RulesNotifier notifier, Rule? rule, int minutes) async {
    if (rule == null) return;
    final updated = rule.copyWith(weekendLimitMinutes: minutes);
    await notifier.updateRule(updated);
  }
}
