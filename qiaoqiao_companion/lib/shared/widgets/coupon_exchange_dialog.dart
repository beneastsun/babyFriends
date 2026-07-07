import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';
import 'package:qiaoqiao_companion/shared/providers/coupons_provider.dart';
import 'package:qiaoqiao_companion/shared/providers/points_provider.dart';

/// 加时券兑换对话框（3 按钮简洁版）
class CouponExchangeDialog extends ConsumerWidget {
  const CouponExchangeDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const CouponExchangeDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(pointsProvider).balance;
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('兑换加时券'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('当前积分: $balance', style: theme.textTheme.bodyLarge),
          const SizedBox(height: 16),
          ...CouponType.values.map((type) => _CouponOption(
                type: type,
                balance: balance,
                onExchange: () async {
                  final success = await ref
                      .read(couponsProvider.notifier)
                      .exchange(type);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(success
                            ? '兑换成功！获得 ${type.durationMinutes} 分钟加时券'
                            : '积分不足'),
                      ),
                    );
                  }
                },
              )),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}

class _CouponOption extends StatelessWidget {
  final CouponType type;
  final int balance;
  final VoidCallback onExchange;

  const _CouponOption({
    required this.type,
    required this.balance,
    required this.onExchange,
  });

  @override
  Widget build(BuildContext context) {
    final canAfford = balance >= type.cost;
    final theme = Theme.of(context);

    return Card(
      child: ListTile(
        leading: Icon(Icons.confirmation_num_rounded,
            color: canAfford ? theme.colorScheme.primary : theme.colorScheme.outline),
        title: Text('${type.durationMinutes} 分钟'),
        subtitle: Text('${type.cost} 积分'),
        trailing: FilledButton.tonal(
          onPressed: canAfford ? onExchange : null,
          child: const Text('兑换'),
        ),
      ),
    );
  }
}
