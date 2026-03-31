import 'package:flutter/material.dart';
import 'package:qiaoqiao_companion/core/theme/app_theme.dart';

/// 欢迎步骤
class WelcomeStep extends StatelessWidget {
  const WelcomeStep({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(DesignTokens.space24),
      child: Column(
        children: [
          // Logo
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(DesignTokens.radius24),
              boxShadow: AppShadows.button,
            ),
            child: Stack(
              children: [
                // 装饰性圆形
                Positioned(
                  right: -20,
                  top: -20,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                // 图标
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(DesignTokens.space8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(DesignTokens.radius16),
                    ),
                    child: Icon(
                      Icons.wb_sunny_rounded,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: DesignTokens.space32),

          // 标题
          Text(
            '欢迎使用',
            style: AppTextStyles.heading2.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: DesignTokens.space8),
          Text(
              '纹纹小伙伴',
              style: AppTextStyles.display1.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          const SizedBox(height: DesignTokens.space24),

          // 描述
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.space20,
              vertical: DesignTokens.space12,
            ),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.surfaceDark.withValues(alpha: 0.5)
                  : AppColors.surfaceLight.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(DesignTokens.radius16),
            ),
            child: Text(
              '这是一个帮助你健康使用平板的小伙伴！\n让我们一起养成好习惯吧~',
              style: AppTextStyles.bodyMedium.copyWith(
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: DesignTokens.space32),

          // 特性列表
          _buildFeatureItem(
            icon: Icons.timer_rounded,
            text: '合理安排使用时间',
            color: AppSolidColors.info,
            isDark: isDark,
          ),
          const SizedBox(height: DesignTokens.space12),
          _buildFeatureItem(
            icon: Icons.stars_rounded,
            text: '完成目标赚取积分',
            color: AppSolidColors.pointsGold,
            isDark: isDark,
          ),
          const SizedBox(height: DesignTokens.space12),
          _buildFeatureItem(
            icon: Icons.emoji_events_rounded,
            text: '解锁各种成就',
            color: AppSolidColors.gold,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String text,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.space16,
        vertical: DesignTokens.space12,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(DesignTokens.radius14),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(DesignTokens.radius12),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: DesignTokens.space16),
          Text(
            text,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w500,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
        ],
      ),
    );
  }
}
