import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';
import 'package:qiaoqiao_companion/shared/providers/coupons_provider.dart';
import 'package:qiaoqiao_companion/shared/providers/points_provider.dart';

/// 加时券兑换对话框 - 自由输入分钟数，10 积分 = 1 分钟
class CouponExchangeDialog extends ConsumerStatefulWidget {
  const CouponExchangeDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => const CouponExchangeDialog(),
    );
  }

  @override
  ConsumerState<CouponExchangeDialog> createState() => _CouponExchangeDialogState();
}

class _CouponExchangeDialogState extends ConsumerState<CouponExchangeDialog> {
  final _controller = TextEditingController(text: '10');
  int _minutes = 10;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _cost => _minutes * PointsConstants.exchangePointsPerMinute;

  void _setMinutes(int value) {
    setState(() {
      _minutes = value;
      _controller.text = value.toString();
    });
  }

  void _onTextChanged(String text) {
    final parsed = int.tryParse(text);
    if (parsed != null && parsed > 0 && parsed <= 60) {
      setState(() {
        _minutes = parsed;
      });
    } else if (text.isEmpty) {
      setState(() {
        _minutes = 0;
      });
    }
  }

  Future<void> _doExchange() async {
    if (_minutes <= 0) return;

    final balance = ref.read(pointsProvider).balance;
    if (balance < _cost) return;

    final success = await ref.read(couponsProvider.notifier).exchange(_minutes);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                success ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(success
                  ? '兑换成功！获得 $_minutes 分钟加时券'
                  : '积分不足，无法兑换'),
            ],
          ),
          backgroundColor: success ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final balance = ref.watch(pointsProvider).balance;
    final theme = Theme.of(context);
    final canAfford = balance >= _cost && _minutes > 0;
    final maxMinutes = (balance ~/ PointsConstants.exchangePointsPerMinute).clamp(0, 60);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 顶部渐变头部
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primary.withOpacity(0.85),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: Text('🎫', style: const TextStyle(fontSize: 24)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '兑换加时券',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.stars_rounded, color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '当前积分: $balance',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            // 兑换内容
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // 比例说明
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 16, color: theme.colorScheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          '兑换比例：${PointsConstants.exchangePointsPerMinute} 积分 = 1 分钟',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // 分钟数输入框
                  Text('想要兑换的分钟数', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: _controller,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        suffixText: '分',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onChanged: _onTextChanged,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 快捷按钮
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [5, 10, 15, 30].map((m) {
                      final isSelected = _minutes == m;
                      return ChoiceChip(
                        label: Text('$m 分钟'),
                        selected: isSelected,
                        onSelected: (_) => _setMinutes(m),
                        selectedColor: theme.colorScheme.primary,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                          fontSize: 12,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  // 积分计算
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('所需积分', style: theme.textTheme.bodyMedium),
                        Row(
                          children: [
                            Icon(Icons.stars_rounded,
                                color: canAfford ? Colors.amber : theme.colorScheme.error,
                                size: 18),
                            const SizedBox(width: 4),
                            Text(
                              '$_cost',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: canAfford ? Colors.amber.shade700 : theme.colorScheme.error,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!canAfford && _minutes > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      '积分不足，最多可兑换 $maxMinutes 分钟',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  // 兑换按钮
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: canAfford ? _doExchange : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        disabledBackgroundColor: theme.colorScheme.surfaceContainerHighest,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        canAfford ? '兑换 $_minutes 分钟' : '积分不足',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
