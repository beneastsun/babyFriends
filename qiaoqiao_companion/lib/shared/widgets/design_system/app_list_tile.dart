import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/theme_provider.dart';

/// 应用列表项组件
class AppListTile extends ConsumerWidget {
  const AppListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.isEnabled = true,
    this.showChevron = false,
    this.showDivider = true,
    this.leadingIcon,
    this.leadingIconColor,
    this.leadingIconBackgroundColor,
    this.trailingValue,
    this.minHeight,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isEnabled;
  final bool showChevron;
  final bool showDivider;
  final IconData? leadingIcon;
  final Color? leadingIconColor;
  final Color? leadingIconBackgroundColor;
  final String? trailingValue;
  final double? minHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = ref.watch(colorSchemeProvider);

    Widget? leadingWidget = leading;
    if (leadingWidget == null && leadingIcon != null) {
      leadingWidget = Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: leadingIconBackgroundColor ??
              (isDark
                  ? colors.primaryContainerDarkMode
                  : colors.primaryContainer),
          borderRadius: BorderRadius.circular(DesignTokens.radius8),
        ),
        child: Icon(
          leadingIcon,
          size: DesignTokens.iconMedium,
          color: leadingIconColor ??
              (isDark ? colors.primaryDark : colors.primary),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isEnabled ? onTap : null,
            onLongPress: isEnabled ? onLongPress : null,
            child: Container(
              constraints: BoxConstraints(
                minHeight: minHeight ?? DesignTokens.listItemHeight,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: DesignTokens.space16,
                vertical: DesignTokens.space12,
              ),
              child: Row(
                children: [
                  // 前导
                  if (leadingWidget != null) ...[
                    leadingWidget,
                    SizedBox(width: DesignTokens.space16),
                  ],
                  // 标题内容
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: isEnabled
                                ? (isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight)
                                : (isDark
                                    ? AppColors.textHintDark
                                    : AppColors.textHintLight),
                          ),
                        ),
                        if (subtitle != null) ...[
                          SizedBox(height: DesignTokens.space2),
                          Text(
                            subtitle!,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // 尾随值
                  if (trailingValue != null) ...[
                    SizedBox(width: DesignTokens.space8),
                    Text(
                      trailingValue!,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                  // 尾随组件
                  if (trailing != null) ...[
                    SizedBox(width: DesignTokens.space8),
                    trailing!,
                  ],
                  // 箭头
                  if (showChevron) ...[
                    SizedBox(width: DesignTokens.space4),
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: isDark
                          ? AppColors.textHintDark
                          : AppColors.textHintLight,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        // 分割线
        if (showDivider)
          Padding(
            padding: EdgeInsets.only(
              left: leadingWidget != null ? 72 : DesignTokens.space16,
            ),
            child: Divider(
              height: 1,
              color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
            ),
          ),
      ],
    );
  }
}

/// 带开关的列表项
class AppSwitchListTile extends StatelessWidget {
  const AppSwitchListTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    this.onChanged,
    this.leadingIcon,
    this.leadingIconColor,
    this.isEnabled = true,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool?>? onChanged;
  final IconData? leadingIcon;
  final Color? leadingIconColor;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppListTile(
      title: title,
      subtitle: subtitle,
      leadingIcon: leadingIcon,
      leadingIconColor: leadingIconColor,
      isEnabled: isEnabled,
      showDivider: true,
      trailing: Switch(
        value: value,
        onChanged: isEnabled ? onChanged : null,
      ),
    );
  }
}

/// 带复选框的列表项
class AppCheckboxListTile extends StatelessWidget {
  const AppCheckboxListTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    this.onChanged,
    this.isEnabled = true,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool?>? onChanged;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    return AppListTile(
      title: title,
      subtitle: subtitle,
      isEnabled: isEnabled,
      showDivider: true,
      leading: Checkbox(
        value: value,
        onChanged: isEnabled ? onChanged : null,
      ),
      onTap: isEnabled
          ? () {
              onChanged?.call(!value);
            }
          : null,
    );
  }
}

/// 分组标题
class AppSectionHeader extends ConsumerWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.action,
    this.padding,
  });

  final String title;
  final Widget? action;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = ref.watch(colorSchemeProvider);

    return Padding(
      padding: padding ??
          const EdgeInsets.fromLTRB(
            DesignTokens.space16,
            DesignTokens.space24,
            DesignTokens.space16,
            DesignTokens.space8,
          ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.labelLarge.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : colors.secondary,
              ),
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// 带应用图标的列表项
class AppUsageListTile extends StatelessWidget {
  const AppUsageListTile({
    super.key,
    required this.appName,
    this.category,
    this.usageTime,
    this.progress,
    this.onTap,
    this.appIcon,
    this.limitText,
  });

  final String appName;
  final String? category;
  final String? usageTime;
  final double? progress;
  final VoidCallback? onTap;
  final Widget? appIcon;
  final String? limitText;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppListTile(
      title: appName,
      subtitle: usageTime,
      leading: appIcon ??
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.surfaceDark
                  : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(DesignTokens.radius8),
            ),
            child: Icon(
              Icons.apps,
              color: isDark
                  ? AppColors.textHintDark
                  : AppColors.textHintLight,
            ),
          ),
      trailing: category != null
          ? _CategoryChip(category: category!)
          : null,
      onTap: onTap,
      minHeight: 72,
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.space8,
        vertical: DesignTokens.space4,
      ),
      decoration: BoxDecoration(
        color: AppColors.getCategoryColor(category).withOpacity(0.15),
        borderRadius: BorderRadius.circular(DesignTokens.radiusCapsule),
      ),
      child: Text(
        _getCategoryLabel(category),
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.getCategoryColor(category),
        ),
      ),
    );
  }

  String _getCategoryLabel(String category) {
    switch (category.toLowerCase()) {
      case 'game':
        return '游戏';
      case 'video':
        return '视频';
      case 'study':
        return '学习';
      case 'reading':
        return '阅读';
      default:
        return '其他';
    }
  }
}
