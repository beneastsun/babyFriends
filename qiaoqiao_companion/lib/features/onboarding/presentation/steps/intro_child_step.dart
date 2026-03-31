import 'package:flutter/material.dart';
import 'package:qiaoqiao_companion/core/theme/app_theme.dart';

/// 介绍给孩子步骤
class IntroChildStep extends StatelessWidget {
  const IntroChildStep({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(DesignTokens.space24),
      child: Column(
        children: [
          // 庆祝图标
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              color: AppColors.success,
              borderRadius: BorderRadius.circular(DesignTokens.radius24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.success.withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                // 装饰性圆形
                Positioned(
                  right: -10,
                  top: -10,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  left: -5,
                  bottom: -5,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                // 图标
                Center(
                  child: Icon(
                    Icons.celebration_rounded,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: DesignTokens.space24),

          // 标题
          Text(
              '设置完成！',
              style: AppTextStyles.display1.copyWith(
                color: AppColors.success,
                fontWeight: FontWeight.w800,
              ),
            ),
          const SizedBox(height: DesignTokens.space12),

          // 说明
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.space16,
              vertical: DesignTokens.space8,
            ),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.successDarkMode.withValues(alpha: 0.15)
                  : AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(DesignTokens.radius12),
            ),
            child: Text(
              '现在可以把平板交给孩子了',
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.success,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: DesignTokens.space24),

          // 给孩子的话
          Container(
            padding: const EdgeInsets.all(DesignTokens.space20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withValues(alpha: 0.1),
                  AppColors.secondary.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(DesignTokens.radius20),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(DesignTokens.space8),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(DesignTokens.radius8),
                      ),
                      child: Icon(
                        Icons.favorite_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: DesignTokens.space10),
                    Text(
                      '给小朋友的话',
                      style: AppTextStyles.heading3.copyWith(
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DesignTokens.space16),
                Text(
                  '纹纹小伙伴会帮你养成健康使用平板的好习惯！',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: DesignTokens.space16),

                // 特性列表
                _buildFeatureItem(
                  icon: Icons.star_rounded,
                  text: '遵守时间规则可以赚阳光积分',
                  color: AppSolidColors.pointsGold,
                ),
                const SizedBox(height: DesignTokens.space8),
                _buildFeatureItem(
                  icon: Icons.card_giftcard_rounded,
                  text: '积分可以换额外的玩耍时间',
                  color: AppColors.success,
                ),
                const SizedBox(height: DesignTokens.space8),
                _buildFeatureItem(
                  icon: Icons.emoji_events_rounded,
                  text: '完成目标还能解锁各种成就',
                  color: AppSolidColors.gold,
                ),

                const SizedBox(height: DesignTokens.space16),
                Text(
                  '让我们一起加油吧！',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: DesignTokens.space20),

          // 使用提示
          Container(
            padding: const EdgeInsets.all(DesignTokens.space14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.info.withValues(alpha: 0.15),
                  AppColors.info.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(DesignTokens.radius14),
              border: Border.all(
                color: AppColors.info.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(DesignTokens.space8),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(DesignTokens.radius8),
                  ),
                  child: Icon(
                    Icons.tips_and_updates_rounded,
                    color: AppColors.info,
                    size: 20,
                  ),
                ),
                const SizedBox(width: DesignTokens.space12),
                Expanded(
                  child: Text(
                    '长按首页的纹纹形象5秒可以进入家长模式',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.info,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.space12,
        vertical: DesignTokens.space10,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(DesignTokens.radius10),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(DesignTokens.radius8),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: DesignTokens.space12),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.labelMedium.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
