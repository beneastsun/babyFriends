import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';
import 'package:qiaoqiao_companion/shared/providers/egg_provider.dart';
import 'package:qiaoqiao_companion/shared/widgets/egg_character.dart';

class EggStylePage extends ConsumerWidget {
  const EggStylePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eggState = ref.watch(eggProvider);
    final theme = Theme.of(context);

    final styles = [
      (EggStyle.princess, '👸 甜美公主', '小肚兜 → 草莓裙 → 薰衣草套裙 → 公主裙 → 彩虹魔法袍'),
      (EggStyle.sporty, '🏃 运动活力', '小背心 → 网球裙 → 运动套装 → 啦啦队服 → 冠军战袍'),
      (EggStyle.fairy, '🧚 奇幻精灵', '小翅膀 → 花仙子裙 → 月光精灵 → 星辰巫师 → 彩虹独角兽'),
      (EggStyle.school, '📚 校园学霸', 'ABC 围嘴 → 校服裙 → 学院风 → 博士服 → 诺贝尔礼服'),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('蛋仔风格')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: styles.map((item) {
          final (style, title, desc) = item;
          final isSelected = eggState.eggStyle == style;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              side: isSelected
                  ? BorderSide(color: theme.colorScheme.primary, width: 2)
                  : BorderSide.none,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: EggCharacter(style: style, stage: eggState.stage, size: 60),
              title: Text(title, style: theme.textTheme.titleMedium),
              subtitle: Text(desc, style: theme.textTheme.bodySmall),
              trailing: isSelected
                  ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                  : null,
              onTap: () async {
                await ref.read(eggProvider.notifier).changeStyle(style);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已切换为$title')),
                  );
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}
