import 'package:flutter/material.dart';
import 'package:qiaoqiao_companion/core/theme/app_theme.dart';
import 'package:qiaoqiao_companion/core/platform/platform.dart';
import 'package:qiaoqiao_companion/shared/widgets/miui_permission_guide_card.dart';

/// 权限引导步骤
class PermissionGuideStep extends StatefulWidget {
  const PermissionGuideStep({super.key});

  @override
  State<PermissionGuideStep> createState() => _PermissionGuideStepState();
}

class _PermissionGuideStepState extends State<PermissionGuideStep> {
  bool _hasUsageStats = false;
  bool _hasOverlay = false;
  bool _needsAutoStart = false;
  bool _isIgnoringBattery = false;

  // 用户确认状态
  bool _autoStartConfirmed = false;
  bool _batteryOptConfirmed = false;
  bool _powerSavingConfirmed = false;

  String _romType = 'OTHER';

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
  bool get _allBasicPermissionsGranted => _hasUsageStats && _hasOverlay;
  bool get _allMiuiPermissionsGranted =>
      _allBasicPermissionsGranted &&
      (_autoStartConfirmed || !_needsAutoStart) &&
      (_batteryOptConfirmed || _isIgnoringBattery) &&
      (_powerSavingConfirmed || !_isMiui);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(DesignTokens.space24),
      child: Column(
        children: [
          // 标题
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(DesignTokens.space10),
                decoration: BoxDecoration(
                  color: _allMiuiPermissionsGranted ? AppColors.success : AppColors.warning,
                  borderRadius: BorderRadius.circular(DesignTokens.radius10),
                ),
                child: Icon(
                  _allMiuiPermissionsGranted ? Icons.verified_user_rounded : Icons.security_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: DesignTokens.space12),
              Text(
                '授权必要权限',
                style: AppTextStyles.heading2.copyWith(
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.space8),
          Text(
            '为了正常工作，需要以下权限',
            style: AppTextStyles.labelMedium.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DesignTokens.space24),

          // 基础权限卡片
          _buildPermissionCard(
            icon: Icons.analytics_rounded,
            title: '使用统计',
            description: '用于统计应用使用时间',
            isGranted: _hasUsageStats,
            isDark: isDark,
            color: AppSolidColors.info,
            onTap: () async {
              await UsageStatsService.requestPermission();
              _checkPermissions();
            },
          ),
          const SizedBox(height: DesignTokens.space10),

          _buildPermissionCard(
            icon: Icons.layers_rounded,
            title: '悬浮窗',
            description: '用于显示提醒通知',
            isGranted: _hasOverlay,
            isDark: isDark,
            color: AppColors.primary,
            onTap: () async {
              await OverlayService.requestPermission();
              _checkPermissions();
            },
          ),

          // MIUI额外权限引导
          if (_needsAutoStart && _allBasicPermissionsGranted) ...[
            const SizedBox(height: DesignTokens.space20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space8),
              child: Row(
                children: [
                  Icon(
                    Icons.phone_android_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: DesignTokens.space8),
                  Text(
                    '小米平板额外设置',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: DesignTokens.space12),

            // 自启动权限
            MiuiPermissionGuideCard(
              icon: Icons.start_rounded,
              title: '开机自启动',
              description: '确保应用开机后自动运行',
              steps: [
                '设置 → 应用设置 → 自启动管理',
                '找到「巧巧小伙伴」并开启开关',
              ],
              isCompleted: _autoStartConfirmed,
              isDark: isDark,
              onTapSettings: () async {
                await MonitorService.openAutoStartSettings();
              },
              onTapCompleted: () {
                setState(() {
                  _autoStartConfirmed = true;
                });
              },
            ),

            // 电池优化
            MiuiPermissionGuideCard(
              icon: Icons.battery_saver_rounded,
              title: '电池优化白名单',
              description: '避免系统杀死后台服务',
              steps: _isIgnoringBattery
                  ? ['已自动加入电池优化白名单']
                  : [
                      '点击「去设置」打开系统设置',
                      '选择「不限制」或「允许」',
                    ],
              isCompleted: _isIgnoringBattery || _batteryOptConfirmed,
              isDark: isDark,
              onTapSettings: () async {
                await MonitorService.openBatterySettings();
              },
              onTapCompleted: () {
                setState(() {
                  _batteryOptConfirmed = true;
                });
              },
            ),

            // 省电策略
            if (_isMiui)
              MiuiPermissionGuideCard(
                icon: Icons.power_settings_new_rounded,
                title: '省电策略',
                description: '设置为「无限制」确保后台运行',
                steps: [
                  '设置 → 省电与电池 → 场景配置',
                  '找到「巧巧小伙伴」',
                  '选择「无限制」',
                ],
                isCompleted: _powerSavingConfirmed,
                isDark: isDark,
                onTapSettings: () async {
                  await MonitorService.openPowerSavingSettings();
                },
                onTapCompleted: () {
                  setState(() {
                    _powerSavingConfirmed = true;
                  });
                },
              ),
          ],

          const SizedBox(height: DesignTokens.space24),

          // 提示
          Container(
            padding: const EdgeInsets.all(DesignTokens.space14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  (isDark ? AppColors.infoDarkMode : AppColors.info)
                      .withValues(alpha: 0.15),
                  (isDark ? AppColors.infoDarkMode : AppColors.info)
                      .withValues(alpha: 0.05),
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
                    Icons.info_outline_rounded,
                    color: AppColors.info,
                    size: 20,
                  ),
                ),
                const SizedBox(width: DesignTokens.space12),
                Expanded(
                  child: Text(
                    _getTipText(),
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.info,
                    ),
                  ),
                ),
                if (_allMiuiPermissionsGranted)
                  Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.success,
                    size: 20,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getTipText() {
    if (!_allBasicPermissionsGranted) {
      return '请先授予使用统计和悬浮窗权限';
    }
    if (_needsAutoStart && !_autoStartConfirmed) {
      return '请完成小米平板的额外设置';
    }
    if (!_isIgnoringBattery && !_batteryOptConfirmed) {
      return '请完成电池优化设置';
    }
    if (_isMiui && !_powerSavingConfirmed) {
      return '请完成省电策略设置';
    }
    return '权限已全部设置完成，点击下一步继续';
  }

  Widget _buildPermissionCard({
    required IconData icon,
    required String title,
    required String description,
    required bool isGranted,
    required bool isDark,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isGranted ? null : onTap,
        borderRadius: BorderRadius.circular(DesignTokens.radius16),
        child: AnimatedContainer(
          duration: DesignTokens.animationQuick,
          padding: const EdgeInsets.all(DesignTokens.space16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : AppColors.cardLight,
            borderRadius: BorderRadius.circular(DesignTokens.radius16),
            boxShadow: AppShadows.card,
            border: isGranted
                ? Border.all(
                    color: AppColors.success.withValues(alpha: 0.5),
                    width: 1.5,
                  )
                : null,
          ),
          child: Row(
            children: [
              // 图标
              AnimatedContainer(
                duration: DesignTokens.animationQuick,
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isGranted ? AppColors.success : color,
                  borderRadius: BorderRadius.circular(DesignTokens.radius14),
                ),
                child: Icon(
                  isGranted ? Icons.check_rounded : icon,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: DesignTokens.space14),

              // 文字
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
                        if (isGranted) ...[
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
                              '已授权',
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

              // 箭头
              if (!isGranted)
                Container(
                  padding: const EdgeInsets.all(DesignTokens.space8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.surfaceDark
                        : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(DesignTokens.radius8),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: AppColors.primary,
                    size: 16,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
