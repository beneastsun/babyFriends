import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/theme/app_theme.dart';
import 'package:qiaoqiao_companion/shared/models/achievement.dart';
import 'package:qiaoqiao_companion/shared/providers/achievement_provider.dart';
import 'package:qiaoqiao_companion/shared/providers/theme_provider.dart';
import 'package:qiaoqiao_companion/shared/widgets/design_system/gradient_progress.dart';
import 'package:qiaoqiao_companion/core/theme/app_solid_colors.dart';

/// 成就页面
class AchievementPage extends ConsumerWidget {
  const AchievementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(achievementProvider);
    final themeType = ref.watch(themeTypeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        color: AppSolidColors.getBackgroundColor(themeType, isDark),
        child: SafeArea(
          child: state.isLoading
              ? Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.primary,
                    ),
                  ),
                )
              : _buildContent(context, state, isDark, themeType),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, AchievementState state, bool isDark, AppThemeType themeType) {
    return CustomScrollView(
      slivers: [
        // 标题栏
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            DesignTokens.space16,
            DesignTokens.space8,
            DesignTokens.space16,
            DesignTokens.space16,
          ),
          sliver: SliverToBoxAdapter(
            child: Text(
              '我的成就',
              style: AppTextStyles.heading1.copyWith(
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
          ),
        ),

        // 概览卡片
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space16),
          sliver: SliverToBoxAdapter(
            child: _buildOverviewCard(state),
          ),
        ),

        // 已解锁成就
        if (state.unlockedAchievements.isNotEmpty) ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              DesignTokens.space16,
              DesignTokens.space24,
              DesignTokens.space16,
              DesignTokens.space8,
            ),
            sliver: SliverToBoxAdapter(
              child: _buildSectionHeader(
                '已解锁',
                Icons.emoji_events_rounded,
                state.totalUnlocked,
                AppSolidColors.success,
                themeType,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildAchievementItem(
                  state.unlockedAchievements[index],
                  true,
                  isDark,
                ),
                childCount: state.unlockedAchievements.length,
              ),
            ),
          ),
        ],

        // 进行中成就
        if (state.inProgressAchievements.isNotEmpty) ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              DesignTokens.space16,
              DesignTokens.space24,
              DesignTokens.space16,
              DesignTokens.space8,
            ),
            sliver: SliverToBoxAdapter(
              child: _buildSectionHeader(
                '进行中',
                Icons.trending_up_rounded,
                state.inProgressAchievements.length,
                AppSolidColors.warning,
                themeType,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildAchievementItem(
                  state.inProgressAchievements[index],
                  false,
                  isDark,
                ),
                childCount: state.inProgressAchievements.length,
              ),
            ),
          ),
        ],

        // 待解锁成就
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            DesignTokens.space16,
            DesignTokens.space24,
            DesignTokens.space16,
            DesignTokens.space8,
          ),
          sliver: SliverToBoxAdapter(
            child: _buildSectionHeader(
              '待解锁',
              Icons.lock_outline_rounded,
              AchievementDefinition.all
                  .where((def) => !state.achievements.any(
                        (a) => a.achievementId == def.id && a.isUnlocked,
                      ))
                  .length,
              AppColors.primary,
              themeType,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final lockedDefs = AchievementDefinition.all
                    .where((def) => !state.achievements.any(
                          (a) => a.achievementId == def.id && a.isUnlocked,
                        ))
                    .toList();
                return _buildLockedAchievementItem(lockedDefs[index], isDark);
              },
              childCount: AchievementDefinition.all
                  .where((def) => !state.achievements.any(
                        (a) => a.achievementId == def.id && a.isUnlocked,
                      ))
                  .length,
            ),
          ),
        ),

        // 底部间距
        const SliverPadding(
          padding: EdgeInsets.only(bottom: DesignTokens.space32),
        ),
      ],
    );
  }

  Widget _buildOverviewCard(AchievementState state) {
    return Container(
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: AppSolidColors.pointsGold,
        borderRadius: BorderRadius.circular(DesignTokens.radius20),
        boxShadow: AppShadows.button,
      ),
      child: Stack(
        children: [
          // 装饰性元素
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: -20,
            bottom: -20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // 内容
          Padding(
            padding: const EdgeInsets.all(DesignTokens.space24),
            child: Column(
              children: [
                // 成就数字
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(DesignTokens.space10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(DesignTokens.radius12),
                      ),
                      child: Icon(
                        Icons.emoji_events_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: DesignTokens.space12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${state.totalUnlocked}',
                          style: AppTextStyles.pointsLarge.copyWith(
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Colors.black26,
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '已解锁成就',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: DesignTokens.space20),

                // 进度条
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '总体进度',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                        Text(
                          '${(state.overallProgress * 100).toInt()}%',
                          style: AppTextStyles.labelLarge.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: DesignTokens.space8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(DesignTokens.radius10),
                      child: AppProgress(
                        value: state.overallProgress,
                        color: Colors.white,
                        height: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, int count, Color color, AppThemeType themeType) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.space16,
        vertical: DesignTokens.space10,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(DesignTokens.radius12),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: Colors.white),
          const SizedBox(width: DesignTokens.space8),
          Text(
            '$title ($count)',
            style: AppTextStyles.labelLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementItem(UserAchievement achievement, bool isUnlocked, bool isDark) {
    final def = achievement.definition;
    if (def == null) return const SizedBox.shrink();

    final tierColor = _getTierColor(def.tier);
    final progress = achievement.progressPercent;

    return Container(
      margin: const EdgeInsets.only(bottom: DesignTokens.space8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(DesignTokens.radius16),
        boxShadow: AppShadows.card,
        border: isUnlocked
            ? Border.all(
                color: tierColor.withValues(alpha: 0.3),
                width: 1.5,
              )
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space16),
        child: Row(
          children: [
            // 图标容器
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isUnlocked ? tierColor : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(DesignTokens.radius14),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Text(
                      def.emoji,
                      style: TextStyle(
                        fontSize: 28,
                        color: isUnlocked ? null : AppColors.textHintLight,
                      ),
                    ),
                  ),
                  if (isUnlocked)
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: AppSolidColors.success,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.success.withValues(alpha: 0.4),
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Icon(Icons.check, size: 10, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: DesignTokens.space12),

            // 内容
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          def.name,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: DesignTokens.space8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DesignTokens.space8,
                          vertical: DesignTokens.space2,
                        ),
                        decoration: BoxDecoration(
                          color: tierColor,
                          borderRadius: BorderRadius.circular(DesignTokens.radius6),
                        ),
                        child: Text(
                          _getTierName(def.tier),
                          style: AppTextStyles.labelSmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: DesignTokens.space4),
                  Text(
                    def.description,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  if (!isUnlocked) ...[
                    const SizedBox(height: DesignTokens.space8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(DesignTokens.radius6),
                      child: GradientProgress(
                        value: progress,
                        color: tierColor,
                        height: 6,
                      ),
                    ),
                    const SizedBox(height: DesignTokens.space4),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: tierColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLockedAchievementItem(AchievementDefinition def, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: DesignTokens.space8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(DesignTokens.radius16),
        border: Border.all(
          color: isDark
              ? AppColors.dividerDark
              : AppColors.dividerLight,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space16),
        child: Row(
          children: [
            // 锁定图标
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.surfaceDark
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(DesignTokens.radius14),
              ),
              child: Center(
                child: Icon(
                  Icons.lock_outline_rounded,
                  size: 24,
                  color: isDark
                      ? AppColors.textHintDark
                      : AppColors.textHintLight,
                ),
              ),
            ),
            const SizedBox(width: DesignTokens.space12),

            // 内容
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    def.name,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: DesignTokens.space4),
                  Text(
                    def.description,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: isDark
                          ? AppColors.textHintDark
                          : AppColors.textHintLight,
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

  Color _getTierColor(int tier) {
    switch (tier) {
      case 1:
        return AppSolidColors.bronze;
      case 2:
        return AppSolidColors.silver;
      case 3:
        return AppSolidColors.gold;
      default:
        return AppSolidColors.bronze;
    }
  }

  String _getTierName(int tier) {
    switch (tier) {
      case 1:
        return '铜';
      case 2:
        return '银';
      case 3:
        return '金';
      default:
        return '';
    }
  }
}
