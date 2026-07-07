import 'package:flutter/material.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';

/// 蛋仔形象组件
/// 根据 style + stage 显示对应图片
/// 当前使用占位渲染，后续替换为 Image.asset
class EggCharacter extends StatelessWidget {
  final EggStyle style;
  final int stage;
  final double size;

  const EggCharacter({
    super.key,
    required this.style,
    required this.stage,
    this.size = 120,
  });

  /// 阶段对应的 emoji
  static const _stageEmojis = ['🥚', '🐣', '🐤', '🐥', '🏆'];

  /// 阶段对应的名称
  static const _stageNames = ['蛋宝宝', '小蛋仔', '活力蛋', '闪亮蛋', '超级蛋'];

  /// 风格对应的 emoji
  static const _styleEmojis = {
    EggStyle.princess: '👸',
    EggStyle.sporty: '🏃',
    EggStyle.fairy: '🧚',
    EggStyle.school: '📚',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clampedStage = stage.clamp(0, 4);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 背景圆
          Container(
            width: size * 0.9,
            height: size * 0.9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
            ),
          ),
          // 蛋仔 emoji
          Text(
            _stageEmojis[clampedStage],
            style: TextStyle(fontSize: size * 0.45),
          ),
          // 风格标记（右上角小 emoji）
          Positioned(
            top: size * 0.15,
            right: size * 0.15,
            child: Text(
              _styleEmojis[style] ?? '⭐',
              style: TextStyle(fontSize: size * 0.15),
            ),
          ),
          // 阶段名称（底部）
          Positioned(
            bottom: size * 0.1,
            child: Text(
              _stageNames[clampedStage],
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 获取图片资源路径（供后续替换为真实图片使用）
  String get assetPath => 'assets/images/egg/${style.code}/stage_$stage.png';
}
