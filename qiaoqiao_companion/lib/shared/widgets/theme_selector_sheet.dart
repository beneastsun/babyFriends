import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/theme/app_theme.dart';
import 'package:qiaoqiao_companion/shared/providers/theme_provider.dart';
import 'package:qiaoqiao_companion/core/theme/app_solid_colors.dart';

/// 主题选择器底部弹窗
class ThemeSelectorSheet extends ConsumerWidget {
  const ThemeSelectorSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final isDark = themeState.isDarkMode;
    final colors = ref.watch(colorSchemeProvider);
    final themeType = ref.watch(themeTypeProvider);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(DesignTokens.radius24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖拽手柄
          Container(
            margin: const EdgeInsets.only(top: DesignTokens.space12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // 标题
          Padding(
            padding: const EdgeInsets.all(DesignTokens.space20),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppSolidColors.getPrimaryColor(themeType, false),
                    borderRadius: BorderRadius.circular(DesignTokens.radius12),
                  ),
                  child: const Icon(
                    Icons.palette_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: DesignTokens.space12),
                Text(
                  '主题设置',
                  style: AppTextStyles.heading2.copyWith(
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
              ],
            ),
          ),

          // 深色模式切换
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space20),
            child: Container(
              padding: const EdgeInsets.all(DesignTokens.space16),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.cardDark
                    : AppColors.cardLight,
                borderRadius: BorderRadius.circular(DesignTokens.radius16),
                border: Border.all(
                  color: isDark
                      ? AppColors.borderDark
                      : AppColors.borderLight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark
                          ? colors.primaryDark.withOpacity(0.2)
                          : colors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(DesignTokens.radius12),
                    ),
                    child: Icon(
                      isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                      color: isDark
                          ? colors.primaryDark
                          : colors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: DesignTokens.space12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '深色模式',
                          style: AppTextStyles.labelLarge.copyWith(
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: DesignTokens.space2),
                        Text(
                          isDark ? '当前已开启' : '当前已关闭',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: isDark
                                ? AppColors.textHintDark
                                : AppColors.textHintLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: isDark,
                    onChanged: (value) {
                      ref.read(themeProvider.notifier).setThemeMode(
                        value ? ThemeMode.dark : ThemeMode.light,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: DesignTokens.space20),

          // 主题颜色选择
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '主题颜色',
                style: AppTextStyles.labelLarge.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            ),
          ),

          const SizedBox(height: DesignTokens.space12),

          // 主题选项网格
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space20),
            child: GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              mainAxisSpacing: DesignTokens.space12,
              crossAxisSpacing: DesignTokens.space12,
              childAspectRatio: 1.5,
              children: AppColorSchemes.allTypes.map((type) {
                return _ThemeOptionCard(
                  themeType: type,
                  isSelected: themeState.themeType == type,
                  onTap: () {
                    ref.read(themeProvider.notifier).setThemeType(type);
                  },
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: DesignTokens.space24),

          // 底部安全区域
          SizedBox(height: MediaQuery.of(context).padding.bottom + DesignTokens.space16),
        ],
      ),
    );
  }

  /// 显示主题选择器
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ThemeSelectorSheet(),
    );
  }
}

/// 主题选项卡片
class _ThemeOptionCard extends StatefulWidget {
  final AppThemeType themeType;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOptionCard({
    required this.themeType,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_ThemeOptionCard> createState() => _ThemeOptionCardState();
}

class _ThemeOptionCardState extends State<_ThemeOptionCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorSchemes.getScheme(widget.themeType);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: DesignTokens.animationQuick,
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.all(DesignTokens.space14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [colors.primary, colors.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(DesignTokens.radius16),
            border: widget.isSelected
                ? Border.all(
                    color: Colors.white,
                    width: 3,
                  )
                : null,
            boxShadow: [
              BoxShadow(
                color: colors.primary.withOpacity(0.3),
                blurRadius: widget.isSelected ? 12 : 6,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // 内容
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 图标
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(DesignTokens.radius10),
                    ),
                    child: Icon(
                      widget.themeType.icon,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const Spacer(),
                  // 名称
                  Text(
                    widget.themeType.name,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: DesignTokens.space2),
                  // 描述
                  Text(
                    widget.themeType.description,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: Colors.white.withOpacity(0.85),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),

              // 选中指示器
              if (widget.isSelected)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      color: colors.primary,
                      size: 16,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 主题预览圆形按钮（用于紧凑显示）
class ThemePreviewButton extends StatelessWidget {
  final AppThemeType themeType;
  final bool isSelected;
  final VoidCallback? onTap;

  const ThemePreviewButton({
    super.key,
    required this.themeType,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: DesignTokens.animationQuick,
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              themeType.previewColor,
              themeType.previewColor.withOpacity(0.7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(color: Colors.white, width: 3)
              : null,
          boxShadow: [
            BoxShadow(
              color: themeType.previewColor.withOpacity(0.3),
              blurRadius: isSelected ? 10 : 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: isSelected
            ? const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 24,
              )
            : null,
      ),
    );
  }
}
