import 'package:flutter/material.dart';
import 'package:qiaoqiao_companion/core/theme/app_theme.dart';
import 'package:qiaoqiao_companion/core/theme/app_solid_colors.dart';
import 'package:qiaoqiao_companion/shared/widgets/design_system/app_button.dart';

/// MIUI权限引导卡片
/// 用于引导用户设置自启动、省电策略等权限
class MiuiPermissionGuideCard extends StatelessWidget {
  const MiuiPermissionGuideCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.steps,
    required this.isCompleted,
    required this.onTapSettings,
    required this.onTapCompleted,
    this.isDark = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final List<String> steps;
  final bool isCompleted;
  final VoidCallback onTapSettings;
  final VoidCallback onTapCompleted;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: DesignTokens.space12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(DesignTokens.radius16),
        boxShadow: AppShadows.card,
        border: isCompleted
            ? Border.all(
                color: AppColors.success.withValues(alpha: 0.5),
                width: 1.5,
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Padding(
            padding: const EdgeInsets.all(DesignTokens.space16),
            child: Row(
              children: [
                // 图标
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isCompleted ? AppSolidColors.success : AppColors.primary,
                    borderRadius: BorderRadius.circular(DesignTokens.radius12),
                  ),
                  child: Icon(
                    isCompleted ? Icons.check_rounded : icon,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: DesignTokens.space12),
                // 标题和描述
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                            ),
                          ),
                          if (isCompleted) ...[
                            const SizedBox(width: DesignTokens.space8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: DesignTokens.space6,
                                vertical: DesignTokens.space2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(DesignTokens.radius6),
                              ),
                              child: Text(
                                '已完成',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: DesignTokens.space4),
                      Text(
                        description,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 步骤说明
          if (!isCompleted && steps.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: DesignTokens.space16),
              padding: const EdgeInsets.all(DesignTokens.space12),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.surfaceDark.withValues(alpha: 0.5)
                    : AppColors.surfaceLight.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(DesignTokens.radius10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: steps.map((step) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: DesignTokens.space4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '• ',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            step,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

          // 操作按钮
          if (!isCompleted)
            Padding(
              padding: const EdgeInsets.all(DesignTokens.space16),
              child: Row(
                children: [
                  Expanded(
                    child: AppButtonSecondary(
                      onPressed: onTapSettings,
                      icon: const Icon(Icons.settings_rounded),
                      isFullWidth: true,
                      child: const Text('去设置'),
                    ),
                  ),
                  const SizedBox(width: DesignTokens.space12),
                  Expanded(
                    child: AppButtonPrimary(
                      onPressed: onTapCompleted,
                      icon: const Icon(Icons.check_rounded),
                      isFullWidth: true,
                      child: const Text('已完成'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
