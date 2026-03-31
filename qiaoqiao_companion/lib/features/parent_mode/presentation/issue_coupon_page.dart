import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/theme/app_theme.dart';
import 'package:qiaoqiao_companion/shared/providers/providers.dart';
import 'package:qiaoqiao_companion/shared/widgets/design_system/app_button.dart';

/// 发放加时券页面
class IssueCouponPage extends ConsumerStatefulWidget {
  const IssueCouponPage({super.key});

  @override
  ConsumerState<IssueCouponPage> createState() => _IssueCouponPageState();
}

class _IssueCouponPageState extends ConsumerState<IssueCouponPage> {
  int _minutes = 30;
  int _validityDays = 7;
  String _reason = '';
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('发放加时券'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 说明卡片
            Card(
              color: AppColors.success.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: AppColors.success,
                    ),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        '加时券可以让孩子在规定时间外额外使用设备',
                        style: AppTextStyles.body2.copyWith(
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: AppSpacing.lg),

            // 时长选择
            Text('加时时长', style: AppTextStyles.heading3),
            SizedBox(height: AppSpacing.md),
            _buildDurationSelector(),
            SizedBox(height: AppSpacing.lg),

            // 有效期选择
            Text('有效期', style: AppTextStyles.heading3),
            SizedBox(height: AppSpacing.md),
            _buildValiditySelector(),
            SizedBox(height: AppSpacing.lg),

            // 原因输入
            Text('发放原因（可选）', style: AppTextStyles.heading3),
            SizedBox(height: AppSpacing.md),
            TextField(
              onChanged: (value) => _reason = value,
              decoration: const InputDecoration(
                hintText: '例如：完成作业奖励',
                prefixIcon: Icon(Icons.edit_note),
              ),
            ),
            SizedBox(height: AppSpacing.xl),

            // 预览卡片
            _buildPreviewCard(),
            SizedBox(height: AppSpacing.xl),

            // 发放按钮
            AppButtonPrimary(
              onPressed: _isSubmitting ? null : _issueCoupon,
              isFullWidth: true,
              isLoading: _isSubmitting,
              icon: const Icon(Icons.card_giftcard),
              child: Text(_isSubmitting ? '发放中...' : '发放加时券'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationSelector() {
    final durations = [15, 30, 45, 60, 90, 120];

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: durations.map((duration) {
        final isSelected = _minutes == duration;
        final hours = duration ~/ 60;
        final mins = duration % 60;
        final label = hours > 0
            ? '$hours小时${mins > 0 ? '$mins分钟' : ''}'
            : '$mins分钟';

        return FilterChip(
          label: Text(label),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) {
              setState(() => _minutes = duration);
            }
          },
          selectedColor: AppColors.primary,
          checkmarkColor: Colors.white,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textPrimary,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildValiditySelector() {
    final validities = [1, 3, 7, 14, 30];

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: validities.map((days) {
        final isSelected = _validityDays == days;

        return FilterChip(
          label: Text('$days天'),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) {
              setState(() => _validityDays = days);
            }
          },
          selectedColor: AppColors.primary,
          checkmarkColor: Colors.white,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textPrimary,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPreviewCard() {
    final hours = _minutes ~/ 60;
    final mins = _minutes % 60;
    final durationText = hours > 0
        ? '$hours小时${mins > 0 ? '$mins分钟' : ''}'
        : '$mins分钟';
    final expiryDate = DateTime.now().add(Duration(days: _validityDays));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            const Icon(
              Icons.confirmation_num,
              size: 48,
              color: AppColors.primary,
            ),
            SizedBox(height: AppSpacing.md),
            Text(
              '加时券预览',
              style: AppTextStyles.heading3,
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              '时长: $durationText',
              style: AppTextStyles.body1,
            ),
            Text(
              '有效期至: ${expiryDate.month}月${expiryDate.day}日',
              style: AppTextStyles.body2,
            ),
            if (_reason.isNotEmpty) ...[
              SizedBox(height: AppSpacing.sm),
              Text(
                '原因: $_reason',
                style: AppTextStyles.caption,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _issueCoupon() async {
    setState(() => _isSubmitting = true);

    try {
      // 直接使用 parentGrant 方法
      await ref.read(couponsProvider.notifier).parentGrant(_minutes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('成功发放${_minutes}分钟加时券'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('发放失败: $e'),
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
