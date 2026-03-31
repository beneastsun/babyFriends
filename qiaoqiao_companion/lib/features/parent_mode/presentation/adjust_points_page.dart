import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/theme/app_theme.dart';
import 'package:qiaoqiao_companion/shared/providers/providers.dart';
import 'package:qiaoqiao_companion/shared/widgets/design_system/app_button.dart';

/// 调整积分页面
class AdjustPointsPage extends ConsumerStatefulWidget {
  const AdjustPointsPage({super.key});

  @override
  ConsumerState<AdjustPointsPage> createState() => _AdjustPointsPageState();
}

class _AdjustPointsPageState extends ConsumerState<AdjustPointsPage> {
  bool _isAdding = true;
  int _amount = 10;
  String _reason = '';
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final points = ref.watch(pointsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('调整积分'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 当前积分卡片
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('当前积分', style: AppTextStyles.body2),
                        SizedBox(height: AppSpacing.xs),
                        Text('阳光积分', style: AppTextStyles.caption),
                      ],
                    ),
                    Text(
                      '${points.balance}',
                      style: AppTextStyles.points,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: AppSpacing.lg),

            // 调整类型选择
            Text('调整类型', style: AppTextStyles.heading3),
            SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _buildTypeButton(
                    icon: Icons.add,
                    label: '增加积分',
                    isSelected: _isAdding,
                    color: AppColors.success,
                    onTap: () => setState(() => _isAdding = true),
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _buildTypeButton(
                    icon: Icons.remove,
                    label: '减少积分',
                    isSelected: !_isAdding,
                    color: AppColors.error,
                    onTap: () => setState(() => _isAdding = false),
                  ),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.lg),

            // 数量选择
            Text(
              _isAdding ? '增加数量' : '减少数量',
              style: AppTextStyles.heading3,
            ),
            SizedBox(height: AppSpacing.md),
            _buildAmountSelector(),
            SizedBox(height: AppSpacing.lg),

            // 原因输入
            Text('调整原因（可选）', style: AppTextStyles.heading3),
            SizedBox(height: AppSpacing.md),
            TextField(
              onChanged: (value) => _reason = value,
              decoration: InputDecoration(
                hintText: '例如：${_isAdding ? "帮忙做家务" : "违反约定"}',
                prefixIcon: const Icon(Icons.edit_note),
              ),
            ),
            SizedBox(height: AppSpacing.xl),

            // 结果预览
            _buildResultPreview(points.balance),
            SizedBox(height: AppSpacing.xl),

            // 确认按钮
            AppButtonPrimary(
              isLoading: _isSubmitting,
              isFullWidth: true,
              onPressed: _isSubmitting ? null : _adjustPoints,
              icon: _isSubmitting
                  ? null
                  : Icon(_isAdding ? Icons.add : Icons.remove),
              child: Text(_isSubmitting
                  ? '处理中...'
                  : '${_isAdding ? "增加" : "减少"} $_amount 积分'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.white : color),
            SizedBox(height: AppSpacing.sm),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : color,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountSelector() {
    final amounts = [5, 10, 20, 30, 50, 100];

    return Column(
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: amounts.map((amount) {
            final isSelected = _amount == amount;

            return FilterChip(
              label: Text('$amount'),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _amount = amount);
                }
              },
              selectedColor: _isAdding ? AppColors.success : AppColors.error,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textPrimary,
              ),
            );
          }).toList(),
        ),
        SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Text('自定义: ', style: AppTextStyles.body2),
            Expanded(
              child: Slider(
                value: _amount.toDouble(),
                min: 1,
                max: 200,
                divisions: 199,
                onChanged: (value) {
                  setState(() => _amount = value.toInt());
                },
              ),
            ),
            Text('$_amount', style: AppTextStyles.heading3),
          ],
        ),
      ],
    );
  }

  Widget _buildResultPreview(int currentBalance) {
    final newBalance = _isAdding
        ? currentBalance + _amount
        : currentBalance - _amount;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                Text('当前', style: AppTextStyles.caption),
                Text('$currentBalance', style: AppTextStyles.heading2),
              ],
            ),
            Icon(
              _isAdding ? Icons.arrow_forward : Icons.arrow_forward,
              color: _isAdding ? AppColors.success : AppColors.error,
            ),
            Column(
              children: [
                Text('调整后', style: AppTextStyles.caption),
                Text(
                  '$newBalance',
                  style: AppTextStyles.heading2.copyWith(
                    color: _isAdding ? AppColors.success : AppColors.error,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _adjustPoints() async {
    if (!_isAdding && _amount > ref.read(pointsProvider).balance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('积分不足')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (_isAdding) {
        await ref.read(pointsProvider.notifier).addPoints(
              _amount,
              _reason.isNotEmpty ? _reason : '家长调整',
            );
      } else {
        await ref.read(pointsProvider.notifier).deductPoints(
              _amount,
              _reason.isNotEmpty ? _reason : '家长调整',
            );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('成功${_isAdding ? "增加" : "减少"}$_amount积分'),
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
