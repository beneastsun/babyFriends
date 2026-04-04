import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qiaoqiao_companion/core/theme/app_theme.dart';
import 'package:qiaoqiao_companion/features/parent_mode/domain/parent_auth_service.dart';
import 'package:qiaoqiao_companion/shared/providers/app_lock_provider.dart';
import 'package:qiaoqiao_companion/shared/widgets/design_system/app_button.dart';

/// 家长模式主页
class ParentModePage extends ConsumerWidget {
  const ParentModePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
        ),
        child: SafeArea(
          child: CustomScrollView(
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '家长模式',
                        style: AppTextStyles.heading1.copyWith(
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _showChangePasswordDialog(context),
                          borderRadius: BorderRadius.circular(DesignTokens.radius10),
                          child: Container(
                            padding: const EdgeInsets.all(DesignTokens.space10),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.surfaceDark
                                  : AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(DesignTokens.radius10),
                              boxShadow: AppShadows.card,
                            ),
                            child: Icon(
                              Icons.key_rounded,
                              size: 20,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 标题卡片
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space16),
                sliver: SliverToBoxAdapter(
                  child: _buildHeaderCard(isDark),
                ),
              ),

              // 设置区域
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  DesignTokens.space16,
                  DesignTokens.space24,
                  DesignTokens.space16,
                  DesignTokens.space8,
                ),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    '设置',
                    style: AppTextStyles.heading3.copyWith(
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space16),
                sliver: SliverToBoxAdapter(
                  child: Consumer(
                    builder: (context, ref, child) {
                      final appLockState = ref.watch(appLockProvider);
                      return Container(
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.cardDark : AppColors.cardLight,
                          borderRadius: BorderRadius.circular(DesignTokens.radius16),
                          boxShadow: AppShadows.card,
                        ),
                        child: SwitchListTile(
                          title: const Text('防关闭保护'),
                          subtitle: const Text('防止孩子在最近任务中关闭App'),
                          secondary: const Icon(Icons.lock),
                          value: appLockState.isEnabled,
                          onChanged: appLockState.isLoading
                              ? null
                              : (value) async {
                                  final success = await ref
                                      .read(appLockProvider.notifier)
                                      .setEnabled(value);
                                  if (!success && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('设置失败，请重试')),
                                    );
                                  }
                                },
                        ),
                      );
                    },
                  ),
                ),
              ),

              // 功能列表
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  DesignTokens.space16,
                  DesignTokens.space24,
                  DesignTokens.space16,
                  DesignTokens.space8,
                ),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    '管理功能',
                    style: AppTextStyles.heading3.copyWith(
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildFunctionCard(
                      context: context,
                      icon: Icons.schedule_rounded,
                      title: '修改规则',
                      subtitle: '调整使用时间和应用分类',
                      color: AppColors.primary,
                      onTap: () => context.push('/parent-mode/rules'),
                    ),
                    const SizedBox(height: DesignTokens.space8),
                    _buildFunctionCard(
                      context: context,
                      icon: Icons.confirmation_num_rounded,
                      title: '发放加时券',
                      subtitle: '给孩子额外的使用时间',
                      color: AppColors.success,
                      onTap: () => context.push('/parent-mode/coupon'),
                    ),
                    const SizedBox(height: DesignTokens.space8),
                    _buildFunctionCard(
                      context: context,
                      icon: Icons.stars_rounded,
                      title: '调整积分',
                      subtitle: '手动增加或减少积分',
                      color: AppColors.pointsGold,
                      onTap: () => context.push('/parent-mode/points'),
                    ),
                    const SizedBox(height: DesignTokens.space8),
                    _buildFunctionCard(
                      context: context,
                      icon: Icons.pause_circle_rounded,
                      title: '暂停监控',
                      subtitle: '临时暂停监控功能',
                      color: AppColors.warning,
                      onTap: () => context.push('/parent-mode/pause'),
                    ),
                  ]),
                ),
              ),

              // 退出按钮
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  DesignTokens.space16,
                  DesignTokens.space32,
                  DesignTokens.space16,
                  DesignTokens.space32,
                ),
                sliver: SliverToBoxAdapter(
                  child: _buildLogoutButton(context, ref, isDark),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.space20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(DesignTokens.radius20),
        boxShadow: AppShadows.button,
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(DesignTokens.radius16),
            ),
            child: Icon(
              Icons.admin_panel_settings_rounded,
              size: 32,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: DesignTokens.space16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '家长管理',
                  style: AppTextStyles.heading3.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: DesignTokens.space4),
                Text(
                  '管理使用规则和奖励',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFunctionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesignTokens.radius16),
        child: Container(
          padding: const EdgeInsets.all(DesignTokens.space16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : AppColors.cardLight,
            borderRadius: BorderRadius.circular(DesignTokens.radius16),
            boxShadow: AppShadows.card,
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(DesignTokens.radius14),
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: DesignTokens.space16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    const SizedBox(height: DesignTokens.space2),
                    Text(
                      subtitle,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark
                    ? AppColors.textHintDark
                    : AppColors.textHintLight,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, WidgetRef ref, bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          ref.read(parentAuthProvider.notifier).logout();
          context.go('/home');
        },
        borderRadius: BorderRadius.circular(DesignTokens.radius16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: DesignTokens.space16),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.errorDarkMode.withValues(alpha: 0.15)
                : AppColors.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(DesignTokens.radius16),
            border: Border.all(
              color: AppColors.error.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.logout_rounded,
                color: AppColors.error,
                size: 20,
              ),
              const SizedBox(width: DesignTokens.space8),
              Text(
                '退出家长模式',
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _ChangePasswordDialog(),
    );
  }
}

/// 修改密码对话框
class _ChangePasswordDialog extends ConsumerStatefulWidget {
  @override
  ConsumerState<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_newPasswordController.text.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('新密码至少需要4位')),
      );
      return;
    }

    if (_newPasswordController.text != _confirmController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('两次输入的新密码不一致')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await ref.read(parentAuthProvider.notifier).resetPassword(
            _oldPasswordController.text,
            _newPasswordController.text,
          );

      if (success && mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('密码修改成功')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radius24),
      ),
      child: Container(
        padding: const EdgeInsets.all(DesignTokens.space24),
        decoration: BoxDecoration(
          color: AppColors.cardLight,
          borderRadius: BorderRadius.circular(DesignTokens.radius24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(DesignTokens.space10),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(DesignTokens.radius10),
                  ),
                  child: Icon(Icons.key_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: DesignTokens.space12),
                Text('修改密码', style: AppTextStyles.heading3),
              ],
            ),
            const SizedBox(height: DesignTokens.space20),

            // 输入框
            TextField(
              controller: _oldPasswordController,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '旧密码',
                prefixIcon: Icon(Icons.lock_outline_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DesignTokens.radius12),
                ),
              ),
            ),
            const SizedBox(height: DesignTokens.space12),
            TextField(
              controller: _newPasswordController,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '新密码',
                prefixIcon: Icon(Icons.lock_outline_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DesignTokens.radius12),
                ),
              ),
            ),
            const SizedBox(height: DesignTokens.space12),
            TextField(
              controller: _confirmController,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '确认新密码',
                prefixIcon: Icon(Icons.lock_outline_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DesignTokens.radius12),
                ),
              ),
            ),
            const SizedBox(height: DesignTokens.space24),

            // 按钮
            Row(
              children: [
                Expanded(
                  child: AppButtonGhost(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: DesignTokens.space12),
                Expanded(
                  child: AppButtonPrimary(
                    onPressed: _isLoading ? null : _submit,
                    isLoading: _isLoading,
                    child: const Text('确认'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
