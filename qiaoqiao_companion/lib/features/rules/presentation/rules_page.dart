import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qiaoqiao_companion/core/theme/app_theme.dart';
import 'package:qiaoqiao_companion/shared/providers/providers.dart';
import 'package:qiaoqiao_companion/shared/models/models.dart';
import 'package:qiaoqiao_companion/shared/widgets/design_system/app_card.dart';
import 'package:qiaoqiao_companion/shared/widgets/design_system/app_bottom_sheet.dart';
import 'package:qiaoqiao_companion/features/parent_mode/presentation/parent_password_dialog.dart';
import 'package:qiaoqiao_companion/features/parent_mode/data/parent_password_repository.dart';
import 'package:qiaoqiao_companion/features/parent_mode/domain/parent_auth_service.dart';
import 'package:qiaoqiao_companion/shared/providers/theme_provider.dart';
import 'package:qiaoqiao_companion/core/theme/app_solid_colors.dart';

/// 规则页面
class RulesPage extends ConsumerStatefulWidget {
  const RulesPage({super.key});

  @override
  ConsumerState<RulesPage> createState() => _RulesPageState();
}

class _RulesPageState extends ConsumerState<RulesPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(timePeriodsProvider.notifier).load();
      ref.read(monitoredAppsProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeType = ref.watch(themeTypeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: AppSolidColors.getBackgroundColor(themeType, isDark),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(DesignTokens.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题栏
                Padding(
                  padding: const EdgeInsets.only(
                    top: DesignTokens.space8,
                    bottom: DesignTokens.space20,
                  ),
                  child: Row(
                    children: [
                      Text(
                        '规则',
                        style: AppTextStyles.heading1.copyWith(
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                      const Spacer(),
                      _HelpButton(onTap: () => _showRulesHelp(context)),
                    ],
                  ),
                ),

                // 家长设置入口（顶部）
                _ParentSettingsCard(),
                const SizedBox(height: DesignTokens.space20),

                // 时间规则卡片
                _TimeRulesCard(),
                const SizedBox(height: DesignTokens.space20),

                // 时段规则（禁止/开放）
                _TimePeriodRulesCard(),
                const SizedBox(height: DesignTokens.space20),

                // 连续使用限制
                _ContinuousUsageCard(),
                const SizedBox(height: DesignTokens.space20),

                // 被监控应用规则（底部）
                _MonitoredAppsCard(),
                const SizedBox(height: DesignTokens.space32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRulesHelp(BuildContext context) {
    AppBottomSheet.show(
      context: context,
      builder: (context) => BottomSheetContainer(
        title: '规则说明',
        showCloseButton: true,
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.space16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HelpItem(
                icon: Icons.access_time_rounded,
                color: AppColors.primary,
                title: '总时间限制',
                description: '每天可使用的总时间',
              ),
              const SizedBox(height: DesignTokens.space16),
              _HelpItem(
                icon: Icons.category_rounded,
                color: AppColors.secondary,
                title: '分类限制',
                description: '特定类型应用的时间限制',
              ),
              const SizedBox(height: DesignTokens.space16),
              _HelpItem(
                icon: Icons.block_rounded,
                color: AppColors.error,
                title: '禁止时段',
                description: '不能使用设备的时间段',
              ),
              const SizedBox(height: DesignTokens.space24),
              Container(
                padding: const EdgeInsets.all(DesignTokens.space12),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(DesignTokens.radius12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: DesignTokens.space8),
                    Expanded(
                      child: Text(
                        '长按纹纹头像5秒可进入家长模式修改规则',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 帮助按钮
class _HelpButton extends StatelessWidget {
  final VoidCallback onTap;

  const _HelpButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesignTokens.radius12),
        child: Container(
          padding: const EdgeInsets.all(DesignTokens.space8),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(DesignTokens.radius12),
          ),
          child: Icon(
            Icons.help_outline_rounded,
            color: AppColors.primary,
            size: 20,
          ),
        ),
      ),
    );
  }
}

/// 帮助项
class _HelpItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  const _HelpItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(DesignTokens.space8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(DesignTokens.radius8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: DesignTokens.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.bodyLarge),
              Text(description, style: AppTextStyles.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

/// 时间规则卡片
class _TimeRulesCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeType = ref.watch(themeTypeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rules = ref.watch(rulesProvider);
    final totalRule = rules.totalTimeRule;
    final weekdayMinutes = totalRule?.weekdayLimitMinutes ?? 120;
    final weekendMinutes = totalRule?.weekendLimitMinutes ?? 180;

    return AppCard(
      type: AppCardType.standard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(DesignTokens.space8),
                decoration: BoxDecoration(
                  color: AppSolidColors.getPrimaryColor(themeType, isDark),
                  borderRadius: BorderRadius.circular(DesignTokens.radius10),
                ),
                child: Icon(Icons.access_time_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: DesignTokens.space12),
              Text('时间限制', style: AppTextStyles.heading3),
            ],
          ),
          const SizedBox(height: DesignTokens.space16),
          _RuleItem(
            icon: Icons.wb_sunny_rounded,
            label: '工作日每日限额',
            value: _formatMinutes(weekdayMinutes),
            color: AppColors.primary,
          ),
          const Divider(height: DesignTokens.space24),
          _RuleItem(
            icon: Icons.weekend_rounded,
            label: '周末每日限额',
            value: _formatMinutes(weekendMinutes),
            color: AppColors.secondary,
          ),
        ],
      ),
    );
  }

  String _formatMinutes(int minutes) {
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      if (mins > 0) return '$hours小时$mins分';
      return '$hours小时';
    }
    return '$minutes分钟';
  }
}

/// 规则项
class _RuleItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _RuleItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: DesignTokens.space12),
        Expanded(child: Text(label, style: AppTextStyles.bodyMedium)),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.space12,
            vertical: DesignTokens.space6,
          ),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(DesignTokens.radiusCapsule),
          ),
          child: Text(value, style: AppTextStyles.labelMedium.copyWith(color: color)),
        ),
      ],
    );
  }
}

/// 排序方式枚举
enum _SortBy { category, name }

/// 被监控应用规则卡片
class _MonitoredAppsCard extends ConsumerStatefulWidget {
  @override
  ConsumerState<_MonitoredAppsCard> createState() => _MonitoredAppsCardState();
}

class _MonitoredAppsCardState extends ConsumerState<_MonitoredAppsCard> {
  _SortBy _sortBy = _SortBy.category;

  @override
  Widget build(BuildContext context) {
    final appsState = ref.watch(monitoredAppsProvider);
    final apps = appsState.enabledApps;

    return AppCard(
      type: AppCardType.standard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(DesignTokens.space8),
                decoration: BoxDecoration(
                  color: AppSolidColors.video,
                  borderRadius: BorderRadius.circular(DesignTokens.radius10),
                ),
                child: Icon(Icons.apps_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: DesignTokens.space12),
              Text('应用限制', style: AppTextStyles.heading3),
              const Spacer(),
              // 排序切换
              Container(
                padding: const EdgeInsets.all(DesignTokens.space2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusCapsule),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _SortChip(
                      label: '分类',
                      selected: _sortBy == _SortBy.category,
                      onTap: () => setState(() => _sortBy = _SortBy.category),
                    ),
                    _SortChip(
                      label: '名称',
                      selected: _sortBy == _SortBy.name,
                      onTap: () => setState(() => _sortBy = _SortBy.name),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.space16),
          _buildAppList(apps),
        ],
      ),
    );
  }

  Widget _buildAppList(List<MonitoredApp> apps) {
    if (apps.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.space24),
          child: Text('暂无被监控应用', style: AppTextStyles.bodyMedium),
        ),
      );
    }

    final sortedApps = List<MonitoredApp>.from(apps);

    if (_sortBy == _SortBy.category) {
      sortedApps.sort((a, b) {
        final categoryOrder = {'game': 0, 'video': 1, 'study': 2, 'reading': 3};
        final aOrder = categoryOrder[a.category] ?? 4;
        final bOrder = categoryOrder[b.category] ?? 4;
        final cmp = aOrder.compareTo(bOrder);
        if (cmp != 0) return cmp;
        return (a.appName ?? a.packageName).compareTo(b.appName ?? b.packageName);
      });
    } else {
      sortedApps.sort((a, b) =>
          (a.appName ?? a.packageName).compareTo(b.appName ?? b.packageName));
    }

    return Column(
      children: [
        for (int i = 0; i < sortedApps.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          _MonitoredAppItem(app: sortedApps[i]),
        ],
      ],
    );
  }
}

/// 排序切换按钮
class _SortChip extends ConsumerWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SortChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeType = ref.watch(themeTypeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space12, vertical: DesignTokens.space6),
        decoration: BoxDecoration(
          color: selected ? AppSolidColors.getPrimaryColor(themeType, isDark) : Colors.transparent,
          borderRadius: BorderRadius.circular(DesignTokens.radiusCapsule),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: selected ? Colors.white : AppColors.textSecondaryLight,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

/// 被监控应用限制项
class _MonitoredAppItem extends ConsumerWidget {
  final MonitoredApp app;

  const _MonitoredAppItem({required this.app});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoryColor = _getCategoryColor(app.category);
    final limitText = _formatLimit(app);
    final installedAppsAsync = ref.watch(installedAppsProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DesignTokens.space8),
      child: Row(
        children: [
          installedAppsAsync.when(
            data: (data) => _buildAppIcon(data),
            loading: () => _buildFallbackIcon(),
            error: (error, stack) => _buildFallbackIcon(),
          ),
          const SizedBox(width: DesignTokens.space12),
          Expanded(
            child: Text(
              app.appName ?? app.packageName,
              style: AppTextStyles.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.space10,
              vertical: DesignTokens.space4,
            ),
            decoration: BoxDecoration(
              color: categoryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(DesignTokens.radiusCapsule),
            ),
            child: Text(
              limitText,
              style: AppTextStyles.labelSmall.copyWith(color: categoryColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppIcon(InstalledAppsData data) {
    final iconBase64 = data.getIcon(app.packageName);
    if (iconBase64 != null && iconBase64.isNotEmpty) {
      try {
        final bytes = base64Decode(iconBase64);
        return ClipRRect(
          borderRadius: BorderRadius.circular(DesignTokens.radius8),
          child: Image.memory(
            bytes,
            width: 36,
            height: 36,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildFallbackIcon(),
          ),
        );
      } catch (e) {
        return _buildFallbackIcon();
      }
    }
    return _buildFallbackIcon();
  }

  Widget _buildFallbackIcon() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: _getCategoryColor(app.category).withOpacity(0.15),
        borderRadius: BorderRadius.circular(DesignTokens.radius8),
      ),
      child: Icon(
        _getCategoryIconData(app.category),
        color: _getCategoryColor(app.category),
        size: 20,
      ),
    );
  }

  IconData _getCategoryIconData(String? category) {
    switch (category) {
      case 'game': return Icons.sports_esports_rounded;
      case 'video': return Icons.play_circle_rounded;
      case 'study': return Icons.school_rounded;
      case 'reading': return Icons.menu_book_rounded;
      default: return Icons.apps_rounded;
    }
  }

  Color _getCategoryColor(String? category) {
    switch (category) {
      case 'game': return AppColors.gameColor;
      case 'video': return AppColors.videoColor;
      case 'study': return AppColors.studyColor;
      case 'reading': return AppColors.readingColor;
      default: return AppColors.other;
    }
  }

  String _formatLimit(MonitoredApp app) {
    if (app.dailyLimitMinutes == null) return '无限制';
    return '${app.dailyLimitMinutes}分/天';
  }
}

/// 时段规则卡片（支持禁止时段和开放时段）
class _TimePeriodRulesCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeType = ref.watch(themeTypeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final periodsState = ref.watch(timePeriodsProvider);
    final blockedPeriods = periodsState.enabledPeriods
        .where((p) => p.mode == TimePeriodMode.blocked)
        .toList();
    final allowedPeriods = periodsState.enabledPeriods
        .where((p) => p.mode == TimePeriodMode.allowed)
        .toList();

    // 根据配置决定显示内容
    final hasBlocked = blockedPeriods.isNotEmpty;
    final hasAllowed = allowedPeriods.isNotEmpty;

    // 如果两者都没有，显示空状态
    if (!hasBlocked && !hasAllowed) {
      return AppCard(
        type: AppCardType.standard,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(DesignTokens.space8),
                  decoration: BoxDecoration(
                    color: AppSolidColors.getPrimaryColor(themeType, isDark),
                    borderRadius: BorderRadius.circular(DesignTokens.radius10),
                  ),
                  child: Icon(Icons.schedule_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: DesignTokens.space12),
                Text('时段规则', style: AppTextStyles.heading3),
              ],
            ),
            const SizedBox(height: DesignTokens.space16),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(DesignTokens.space12),
                child: Text('暂未设置时段规则', style: AppTextStyles.bodyMedium),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // 禁止时段（如果有）
        if (hasBlocked) _buildBlockedCard(blockedPeriods, themeType),
        if (hasBlocked && hasAllowed) const SizedBox(height: DesignTokens.space20),
        // 开放时段（如果有）
        if (hasAllowed) _buildAllowedCard(allowedPeriods, themeType),
      ],
    );
  }

  Widget _buildBlockedCard(List<TimePeriod> blockedPeriods, AppThemeType themeType) {
    return AppCard(
      type: AppCardType.standard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(DesignTokens.space8),
                decoration: BoxDecoration(
                  color: AppSolidColors.error,
                  borderRadius: BorderRadius.circular(DesignTokens.radius10),
                ),
                child: Icon(Icons.block_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: DesignTokens.space12),
              Text('禁止时段', style: AppTextStyles.heading3),
            ],
          ),
          const SizedBox(height: DesignTokens.space16),
          Column(
            children: [
              for (int i = 0; i < blockedPeriods.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _TimeBlockItem(
                  period: blockedPeriods[i],
                  label: _getTimeBlockLabel(blockedPeriods[i].timeStart),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAllowedCard(List<TimePeriod> allowedPeriods, AppThemeType themeType) {
    return AppCard(
      type: AppCardType.standard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(DesignTokens.space8),
                decoration: BoxDecoration(
                  color: AppSolidColors.success,
                  borderRadius: BorderRadius.circular(DesignTokens.radius10),
                ),
                child: Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: DesignTokens.space12),
              Text('开放时段', style: AppTextStyles.heading3),
            ],
          ),
          const SizedBox(height: DesignTokens.space16),
          Column(
            children: [
              for (int i = 0; i < allowedPeriods.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _TimeAllowedItem(
                  period: allowedPeriods[i],
                  label: _getTimeAllowedLabel(allowedPeriods[i].timeStart),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _getTimeBlockLabel(String timeStart) {
    if (timeStart == '21:00') return '睡觉时间';
    if (timeStart == '09:00') return '上课时间（上午）';
    if (timeStart == '14:00') return '上课时间（下午）';
    return '禁止时段';
  }

  String _getTimeAllowedLabel(String timeStart) {
    if (timeStart == '16:00') return '游戏时间';
    if (timeStart == '18:00') return '娱乐时间';
    if (timeStart == '19:00') return '放松时间';
    return '开放时段';
  }
}

/// 禁止时段项
class _TimeBlockItem extends StatelessWidget {
  final TimePeriod period;
  final String label;

  const _TimeBlockItem({
    required this.period,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DesignTokens.space8),
      child: Row(
        children: [
          Icon(Icons.timer_off_rounded, color: AppColors.error, size: 20),
          const SizedBox(width: DesignTokens.space12),
          Expanded(child: Text(label, style: AppTextStyles.bodyMedium)),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.space10,
              vertical: DesignTokens.space4,
            ),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(DesignTokens.radiusCapsule),
            ),
            child: Text(
              period.displayText,
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

/// 开放时段项
class _TimeAllowedItem extends StatelessWidget {
  final TimePeriod period;
  final String label;

  const _TimeAllowedItem({
    required this.period,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DesignTokens.space8),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 20),
          const SizedBox(width: DesignTokens.space12),
          Expanded(child: Text(label, style: AppTextStyles.bodyMedium)),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.space10,
              vertical: DesignTokens.space4,
            ),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(DesignTokens.radiusCapsule),
            ),
            child: Text(
              period.displayText,
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.success),
            ),
          ),
        ],
      ),
    );
  }
}

/// 连续使用限制卡片
class _ContinuousUsageCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(continuousUsageSettingsProvider);
    if (!settings.enabled) return const SizedBox.shrink();

    return AppCard(
      type: AppCardType.standard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(DesignTokens.space8),
                decoration: BoxDecoration(
                  color: AppSolidColors.warning,
                  borderRadius: BorderRadius.circular(DesignTokens.radius10),
                ),
                child: Icon(Icons.timer_outlined, color: Colors.white, size: 20),
              ),
              const SizedBox(width: DesignTokens.space12),
              Text('连续使用限制', style: AppTextStyles.heading3),
            ],
          ),
          const SizedBox(height: DesignTokens.space16),
          _RuleItem(
            icon: Icons.warning_amber_rounded,
            label: '连续使用上限',
            value: '${settings.limitMinutes}分钟',
            color: AppColors.warning,
          ),
          const Divider(height: DesignTokens.space24),
          _RuleItem(
            icon: Icons.coffee_rounded,
            label: '强制休息时间',
            value: '${settings.restMinutes}分钟',
            color: AppColors.info,
          ),
        ],
      ),
    );
  }
}

/// 家长设置入口卡片
class _ParentSettingsCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeType = ref.watch(themeTypeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppCard(
      type: AppCardType.glass,
      child: InkWell(
        borderRadius: BorderRadius.circular(DesignTokens.radius16),
        onTap: () => _showPasswordDialog(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.space16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(DesignTokens.space12),
                decoration: BoxDecoration(
                  color: AppSolidColors.getPrimaryColor(themeType, isDark),
                  borderRadius: BorderRadius.circular(DesignTokens.radius12),
                ),
                child: Icon(Icons.settings_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: DesignTokens.space16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('家长设置', style: AppTextStyles.heading3),
                    const SizedBox(height: DesignTokens.space4),
                    Text(
                      '点击进入家长设置',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPasswordDialog(BuildContext context, WidgetRef ref) async {
    final repository = ParentPasswordRepository();
    final hasPassword = await repository.hasPassword();

    if (!context.mounted) return;

    if (!hasPassword) {
      // 首次设置密码
      final success = await showParentPasswordDialog(
        context: context,
        isSettingPassword: true,
      );
      if (success == true && context.mounted) {
        ref.read(parentAuthProvider.notifier).refreshState();
        context.push('/parent-mode');
      }
    } else {
      // 验证密码
      final success = await showParentPasswordDialog(
        context: context,
        isSettingPassword: false,
      );
      if (success == true && context.mounted) {
        context.push('/parent-mode');
      }
    }
  }
}
