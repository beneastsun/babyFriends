import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qiaoqiao_companion/core/theme/app_theme.dart';
import 'package:qiaoqiao_companion/core/platform/platform.dart';
import 'package:qiaoqiao_companion/shared/providers/providers.dart';
import 'package:qiaoqiao_companion/shared/providers/theme_provider.dart';
import 'package:qiaoqiao_companion/shared/widgets/design_system/app_button.dart';
import 'package:qiaoqiao_companion/shared/widgets/design_system/app_card.dart';
import 'package:qiaoqiao_companion/shared/widgets/design_system/app_list_tile.dart';
import 'package:qiaoqiao_companion/shared/widgets/theme_selector_sheet.dart';
import 'package:qiaoqiao_companion/core/theme/app_solid_colors.dart';

/// 设置页面 - 我的
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                // 标题
                Padding(
                  padding: const EdgeInsets.only(
                    top: DesignTokens.space8,
                    bottom: DesignTokens.space20,
                  ),
                  child: Text(
                    '我的',
                    style: AppTextStyles.heading1.copyWith(
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                ),

                // 用户信息卡片
                _UserProfileCard(),
                const SizedBox(height: DesignTokens.space20),

                // 我的物品卡片
                _MyItemsCard(),
                const SizedBox(height: DesignTokens.space24),

                // 快捷操作
                _QuickActionsSection(),
                const SizedBox(height: DesignTokens.space24),

                // 设置项
                _SettingsSection(),
                const SizedBox(height: DesignTokens.space24),

                // 关于
                _AboutSection(),
                const SizedBox(height: DesignTokens.space32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 用户信息卡片 - 渐变背景
class _UserProfileCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeType = ref.watch(themeTypeProvider);

    final colors = ref.watch(colorSchemeProvider);
    return AppCard(
      type: AppCardType.filled,
      color: colors.primary,
      padding: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.all(DesignTokens.space20),
        decoration: BoxDecoration(
          color: colors.primary,
          borderRadius: BorderRadius.circular(DesignTokens.radius20),
        ),
        child: Row(
          children: [
            // 头像
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(DesignTokens.radius20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.face,
                  size: 40,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: DesignTokens.space16),
            // 用户信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '小朋友',
                    style: AppTextStyles.heading2.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: DesignTokens.space4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesignTokens.space8,
                      vertical: DesignTokens.space4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(DesignTokens.radiusCapsule),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.local_fire_department,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: DesignTokens.space4),
                        Text(
                          '已坚持 15 天',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // 编辑按钮
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(DesignTokens.radius12),
              ),
              child: IconButton(
                icon: Icon(Icons.edit_outlined, color: Colors.white),
                onPressed: () {
                  // TODO: 编辑昵称
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 我的物品卡片（显示实时数据）
class _MyItemsCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final points = ref.watch(pointsProvider);
    final coupons = ref.watch(couponsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppCard(
      type: AppCardType.standard,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _ItemButton(
                  icon: Icons.star_rounded,
                  label: '阳光积分',
                  value: '${points.balance}',
                  color: AppColors.pointsGold,
                  onTap: () => context.push('/points'),
                ),
              ),
              Container(
                width: 1,
                height: 48,
                color: isDark
                    ? AppColors.dividerDark
                    : AppColors.dividerLight,
              ),
              Expanded(
                child: _ItemButton(
                  icon: Icons.card_giftcard_rounded,
                  label: '加时券',
                  value: '${coupons.availableCount}',
                  color: AppColors.secondary,
                  onTap: () {
                    // TODO: 加时券列表
                  },
                ),
              ),
              Container(
                width: 1,
                height: 48,
                color: isDark
                    ? AppColors.dividerDark
                    : AppColors.dividerLight,
              ),
              Expanded(
                child: _ItemButton(
                  icon: Icons.emoji_events_rounded,
                  label: '成就',
                  value: '5',
                  color: AppColors.primary,
                  onTap: () => context.push('/achievement'),
                ),
              ),
            ],
          ),
          if (points.todayEarned > 0) ...[
            const SizedBox(height: DesignTokens.space12),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: DesignTokens.space12,
                vertical: DesignTokens.space6,
              ),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(DesignTokens.radiusCapsule),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.trending_up_rounded,
                    size: 16,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: DesignTokens.space4),
                  Text(
                    '今日已获得 +${points.todayEarned} 积分',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 物品按钮
class _ItemButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  const _ItemButton({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesignTokens.radius12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: DesignTokens.space12),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(DesignTokens.space8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(DesignTokens.radius12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: DesignTokens.space8),
              Text(
                value,
                style: AppTextStyles.heading3.copyWith(color: color),
              ),
              const SizedBox(height: DesignTokens.space2),
              Text(
                label,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 快捷操作区域
class _QuickActionsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(title: '快捷操作'),
        const SizedBox(height: DesignTokens.space8),
        Row(
          children: [
            Expanded(
              child: _QuickActionButton(
                icon: Icons.card_giftcard_rounded,
                label: '兑换加时券',
                colorBuilder: (themeType) => AppSolidColors.getSecondaryColor(themeType, false),
                onTap: () => _showExchangeDialog(context),
              ),
            ),
            const SizedBox(width: DesignTokens.space12),
            Expanded(
              child: _QuickActionButton(
                icon: Icons.history_rounded,
                label: '使用记录',
                colorBuilder: (themeType) => AppSolidColors.getPrimaryColor(themeType, false),
                onTap: () => context.push('/report'),
              ),
            ),
            const SizedBox(width: DesignTokens.space12),
            Expanded(
              child: _QuickActionButton(
                icon: Icons.rule_rounded,
                label: '查看规则',
                colorBuilder: (_) => AppSolidColors.game,
                onTap: () => context.push('/rules'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showExchangeDialog(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('兑换加时券功能开发中...'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// 快捷操作按钮
class _QuickActionButton extends ConsumerStatefulWidget {
  final IconData icon;
  final String label;
  final Color Function(AppThemeType) colorBuilder;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.colorBuilder,
    required this.onTap,
  });

  @override
  ConsumerState<_QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends ConsumerState<_QuickActionButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final themeType = ref.watch(themeTypeProvider);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: DesignTokens.animationQuick,
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.space8,
            vertical: DesignTokens.space16,
          ),
          decoration: BoxDecoration(
            color: widget.colorBuilder(themeType),
            borderRadius: BorderRadius.circular(DesignTokens.radius16),
            boxShadow: AppShadows.button,
          ),
          child: Column(
            children: [
              Icon(widget.icon, size: 28, color: Colors.white),
              const SizedBox(height: DesignTokens.space8),
              Text(
                widget.label,
                style: AppTextStyles.labelMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 设置项区域
class _SettingsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final themeModeText = themeState.themeMode == ThemeMode.system
        ? '跟随系统'
        : (themeState.isDarkMode ? '深色' : '浅色');
    final themeName = '${themeState.themeType.name} · $themeModeText';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(title: '设置'),
        const SizedBox(height: DesignTokens.space8),
        AppCard(
          type: AppCardType.standard,
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              AppSwitchListTile(
                title: '提醒音效',
                leadingIcon: Icons.volume_up_rounded,
                value: true,
                onChanged: (value) {
                  // TODO: 切换音效
                },
              ),
              AppListTile(
                title: '通知设置',
                leadingIcon: Icons.notifications_rounded,
                showChevron: true,
                onTap: () {
                  // TODO: 通知设置
                },
              ),
              AppListTile(
                title: '主题设置',
                leadingIcon: Icons.palette_rounded,
                trailingValue: themeName,
                showChevron: true,
                onTap: () => ThemeSelectorSheet.show(context),
              ),
              AppListTile(
                title: '系统权限检查',
                leadingIcon: Icons.security_rounded,
                trailingValue: 'MIUI优化',
                showChevron: true,
                onTap: () => _showPermissionCheckSheet(context),
              ),
              AppListTile(
                title: '语言',
                leadingIcon: Icons.language_rounded,
                trailingValue: '简体中文',
                showChevron: true,
                showDivider: false,
                onTap: () {
                  // TODO: 语言设置
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 关于区域
class _AboutSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(title: '关于'),
        const SizedBox(height: DesignTokens.space8),
        AppCard(
          type: AppCardType.standard,
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              AppListTile(
                title: '帮助与反馈',
                leadingIcon: Icons.help_outline_rounded,
                showChevron: true,
                onTap: () {
                  // TODO: 帮助与反馈
                },
              ),
              AppListTile(
                title: '关于',
                leadingIcon: Icons.info_outline_rounded,
                trailingValue: 'v1.0.0',
                showChevron: true,
                showDivider: false,
                onTap: () => _showAboutDialog(context, ref),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showAboutDialog(BuildContext context, WidgetRef ref) {
    final themeType = ref.watch(themeTypeProvider);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(DesignTokens.space8),
              decoration: BoxDecoration(
                color: AppSolidColors.getPrimaryColor(themeType, false),
                borderRadius: BorderRadius.circular(DesignTokens.radius12),
              ),
              child: Icon(Icons.child_care, color: Colors.white, size: 24),
            ),
            const SizedBox(width: DesignTokens.space12),
            Text('纹纹小伙伴', style: AppTextStyles.heading3),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('版本：1.0.0', style: AppTextStyles.bodyMedium),
            const SizedBox(height: DesignTokens.space16),
            Text(
              '纹纹小伙伴是一款帮助儿童健康使用平板的陪伴应用。'
              '通过游戏化的方式，让孩子主动配合，建立良好的数字使用习惯。',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: DesignTokens.space16),
            Center(
              child: Text(
                'Made with ❤️ by Dad',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        actions: [
          AppButtonGhost(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}

/// 显示权限检查底部弹窗
void _showPermissionCheckSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _PermissionCheckSheet(),
  );
}

/// 权限检查底部弹窗内容
class _PermissionCheckSheet extends StatefulWidget {
  @override
  State<_PermissionCheckSheet> createState() => _PermissionCheckSheetState();
}

class _PermissionCheckSheetState extends State<_PermissionCheckSheet> {
  bool _hasUsageStats = false;
  bool _hasOverlay = false;
  bool _needsAutoStart = false;
  bool _isIgnoringBattery = false;
  String _romType = 'OTHER';

  bool _autoStartConfirmed = false;
  bool _batteryOptConfirmed = false;
  bool _powerSavingConfirmed = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final hasUsageStats = await UsageStatsService.hasPermission();
    final hasOverlay = await OverlayService.hasPermission();
    final needsAutoStart = await MonitorService.checkAutoStartPermission();
    final isIgnoringBattery = await MonitorService.checkBatteryOptimization();
    final romType = await MonitorService.getRomType();

    setState(() {
      _hasUsageStats = hasUsageStats;
      _hasOverlay = hasOverlay;
      _needsAutoStart = needsAutoStart;
      _isIgnoringBattery = isIgnoringBattery;
      _romType = romType;
    });
  }

  bool get _isMiui => _romType == 'MIUI';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : AppColors.cardLight,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(DesignTokens.radius20),
            ),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: DesignTokens.space12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textSecondaryLight.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(DesignTokens.space20),
                child: Row(
                  children: [
                    Icon(Icons.security_rounded, color: AppColors.primary),
                    const SizedBox(width: DesignTokens.space12),
                    Text(
                      '系统权限检查',
                      style: AppTextStyles.heading2.copyWith(
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded),
                      onPressed: _checkPermissions,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space20),
                  children: [
                    _buildPermissionTile(
                      icon: Icons.analytics_rounded,
                      title: '使用统计',
                      subtitle: '用于统计应用使用时间',
                      isGranted: _hasUsageStats,
                      onTap: () async {
                        await UsageStatsService.requestPermission();
                        _checkPermissions();
                      },
                    ),
                    const SizedBox(height: DesignTokens.space8),
                    _buildPermissionTile(
                      icon: Icons.layers_rounded,
                      title: '悬浮窗',
                      subtitle: '用于显示提醒通知',
                      isGranted: _hasOverlay,
                      onTap: () async {
                        await OverlayService.requestPermission();
                        _checkPermissions();
                      },
                    ),
                    if (_needsAutoStart) ...[
                      const SizedBox(height: DesignTokens.space20),
                      Text(
                        '小米平板额外设置',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: DesignTokens.space12),
                      _buildMiuiTile(
                        icon: Icons.start_rounded,
                        title: '开机自启动',
                        subtitle: '确保应用开机后自动运行',
                        isCompleted: _autoStartConfirmed,
                        steps: ['设置 → 应用设置 → 自启动管理', '找到本应用并开启'],
                        onSettings: () => MonitorService.openAutoStartSettings(),
                        onConfirm: () => setState(() => _autoStartConfirmed = true),
                      ),
                      const SizedBox(height: DesignTokens.space8),
                      _buildMiuiTile(
                        icon: Icons.battery_saver_rounded,
                        title: '电池优化白名单',
                        subtitle: '避免系统杀死后台服务',
                        isCompleted: _isIgnoringBattery || _batteryOptConfirmed,
                        steps: _isIgnoringBattery
                            ? ['已自动加入白名单']
                            : ['点击去设置，选择「不限制」'],
                        onSettings: () => MonitorService.openBatterySettings(),
                        onConfirm: () => setState(() => _batteryOptConfirmed = true),
                      ),
                      if (_isMiui) ...[
                        const SizedBox(height: DesignTokens.space8),
                        _buildMiuiTile(
                          icon: Icons.power_settings_new_rounded,
                          title: '省电策略',
                          subtitle: '设置为「无限制」',
                          isCompleted: _powerSavingConfirmed,
                          steps: ['设置 → 省电与电池', '找到本应用，选择无限制'],
                          onSettings: () => MonitorService.openPowerSavingSettings(),
                          onConfirm: () => setState(() => _powerSavingConfirmed = true),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPermissionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isGranted,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isGranted ? null : onTap,
        borderRadius: BorderRadius.circular(DesignTokens.radius16),
        child: Container(
          padding: const EdgeInsets.all(DesignTokens.space16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(DesignTokens.radius16),
            border: isGranted
                ? Border.all(color: AppColors.success.withValues(alpha: 0.5), width: 1.5)
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isGranted ? AppSolidColors.success : AppColors.primary,
                  borderRadius: BorderRadius.circular(DesignTokens.radius12),
                ),
                child: Icon(isGranted ? Icons.check_rounded : icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: DesignTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(title, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                        if (isGranted) ...[
                          const SizedBox(width: DesignTokens.space8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('已授权', style: AppTextStyles.labelSmall.copyWith(color: AppColors.success)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: AppTextStyles.labelSmall),
                  ],
                ),
              ),
              if (!isGranted) Icon(Icons.arrow_forward_ios_rounded, color: AppColors.primary, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiuiTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isCompleted,
    required List<String> steps,
    required VoidCallback onSettings,
    required VoidCallback onConfirm,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(DesignTokens.space16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(DesignTokens.radius16),
        border: isCompleted
            ? Border.all(color: AppColors.success.withValues(alpha: 0.5), width: 1.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isCompleted ? AppSolidColors.success : AppSolidColors.warning,
                  borderRadius: BorderRadius.circular(DesignTokens.radius12),
                ),
                child: Icon(isCompleted ? Icons.check_rounded : icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: DesignTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: AppTextStyles.labelSmall),
                  ],
                ),
              ),
            ],
          ),
          if (!isCompleted && steps.isNotEmpty) ...[
            const SizedBox(height: DesignTokens.space12),
            Container(
              padding: const EdgeInsets.all(DesignTokens.space12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : AppColors.cardLight,
                borderRadius: BorderRadius.circular(DesignTokens.radius10),
              ),
              child: Column(
                children: steps.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• $s', style: AppTextStyles.labelSmall),
                )).toList(),
              ),
            ),
          ],
          if (!isCompleted) ...[
            const SizedBox(height: DesignTokens.space12),
            Row(
              children: [
                Expanded(
                  child: AppButtonSecondary(
                    onPressed: onSettings,
                    icon: const Icon(Icons.settings_rounded, size: 18),
                    child: const Text('去设置'),
                  ),
                ),
                const SizedBox(width: DesignTokens.space12),
                Expanded(
                  child: AppButtonPrimary(
                    onPressed: onConfirm,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    child: const Text('已完成'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
