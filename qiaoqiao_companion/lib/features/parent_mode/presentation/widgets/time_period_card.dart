import 'package:flutter/material.dart';
import 'package:qiaoqiao_companion/core/theme/app_theme.dart';
import 'package:qiaoqiao_companion/shared/models/models.dart';

class TimePeriodCard extends StatelessWidget {
  final TimePeriod period;
  final VoidCallback onEdit;
  final Function(TimePeriod) onUpdate;
  final VoidCallback onDelete;

  const TimePeriodCard({
    super.key,
    required this.period,
    required this.onEdit,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: period.enabled ? 1.0 : 0.5,
      child: Card(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 时间和模式显示
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${period.timeStart} - ${period.timeEnd}',
                              style: AppTextStyles.heading3,
                            ),
                            if (!period.enabled) ...[
                              SizedBox(width: AppSpacing.sm),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.textHintLight.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '已禁用',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textHintLight,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        SizedBox(height: AppSpacing.xs),
                        _buildModeChip(),
                      ],
                    ),
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: period.enabled,
                      onChanged: (value) => onUpdate(period.copyWith(enabled: value)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: onEdit,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: onDelete,
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: AppSpacing.sm),

            // 适用日期
            Wrap(
              spacing: AppSpacing.xs,
              children: _buildDayChips(),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildModeChip() {
    final isBlocked = period.mode == TimePeriodMode.blocked;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: isBlocked ? AppColors.error.withValues(alpha: 0.1) : AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
      ),
      child: Text(
        period.mode.label,
        style: TextStyle(
          fontSize: 12,
          color: isBlocked ? AppColors.error : AppColors.success,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  List<Widget> _buildDayChips() {
    const dayNames = ['一', '二', '三', '四', '五', '六', '日'];
    return List.generate(7, (index) {
      final day = index + 1;
      final isSelected = period.days.contains(day);
      return FilterChip(
        label: Text(dayNames[index]),
        selected: isSelected,
        onSelected: (_) {
          final newDays = List<int>.from(period.days);
          if (isSelected) {
            newDays.remove(day);
          } else {
            newDays.add(day);
          }
          newDays.sort();
          onUpdate(period.copyWith(days: newDays));
        },
        selectedColor: AppColors.primary.withValues(alpha: 0.3),
        checkmarkColor: AppColors.primary,
      );
    });
  }
}
