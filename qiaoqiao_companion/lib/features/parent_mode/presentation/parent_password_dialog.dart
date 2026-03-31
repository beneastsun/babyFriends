import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/theme/app_theme.dart';
import 'package:qiaoqiao_companion/features/parent_mode/domain/parent_auth_service.dart';
import 'package:qiaoqiao_companion/shared/widgets/design_system/app_button.dart';
import 'package:qiaoqiao_companion/core/theme/app_solid_colors.dart';

/// 显示家长密码对话框
Future<bool?> showParentPasswordDialog({
  required BuildContext context,
  required bool isSettingPassword,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _ParentPasswordSheet(
      isSettingPassword: isSettingPassword,
    ),
  );
}

class _ParentPasswordSheet extends ConsumerStatefulWidget {
  final bool isSettingPassword;

  const _ParentPasswordSheet({required this.isSettingPassword});

  @override
  ConsumerState<_ParentPasswordSheet> createState() => _ParentPasswordSheetState();
}

class _ParentPasswordSheetState extends ConsumerState<_ParentPasswordSheet> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_passwordController.text.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('密码至少需要4位'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (widget.isSettingPassword) {
      if (_confirmController.text != _passwordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('两次输入的密码不一致'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final authNotifier = ref.read(parentAuthProvider.notifier);
      bool success;

      if (widget.isSettingPassword) {
        success = await authNotifier.setPassword(_passwordController.text);
      } else {
        success = await authNotifier.verifyPassword(_passwordController.text);
      }

      if (success && mounted) {
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(parentAuthProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: AppSolidColors.getBackgroundColor(AppThemeType.current, isDark),
        borderRadius: BorderRadius.vertical(top: Radius.circular(DesignTokens.radius24)),
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
              color: AppColors.textHintLight,
              borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
            ),
          ),

          Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + DesignTokens.space24,
              left: DesignTokens.space20,
              right: DesignTokens.space20,
              top: DesignTokens.space20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(DesignTokens.space10),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(DesignTokens.radius10),
                            ),
                            child: Icon(
                              Icons.lock_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: DesignTokens.space12),
                          Text(
                            widget.isSettingPassword ? '设置家长密码' : '输入家长密码',
                            style: AppTextStyles.heading3.copyWith(
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                            ),
                          ),
                        ],
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.of(context).pop(false),
                          borderRadius: BorderRadius.circular(DesignTokens.radius10),
                          child: Container(
                            padding: const EdgeInsets.all(DesignTokens.space8),
                            child: Icon(
                              Icons.close_rounded,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: DesignTokens.space16),

                  // 说明
                  Container(
                    padding: const EdgeInsets.all(DesignTokens.space12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.primaryContainerDarkMode.withValues(alpha: 0.3)
                          : AppColors.primaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(DesignTokens.radius12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 20,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: DesignTokens.space10),
                        Expanded(
                          child: Text(
                            widget.isSettingPassword
                                ? '请设置家长密码，用于保护家长模式功能'
                                : '请输入家长密码以进入家长模式',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: DesignTokens.space20),

                  // 密码输入
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : Colors.white,
                      borderRadius: BorderRadius.circular(DesignTokens.radius14),
                      boxShadow: AppShadows.card,
                    ),
                    child: TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      style: AppTextStyles.bodyLarge,
                      decoration: InputDecoration(
                        labelText: widget.isSettingPassword ? '设置密码' : '密码',
                        labelStyle: TextStyle(color: AppColors.textSecondaryLight),
                        hintText: '请输入4-6位数字密码',
                        hintStyle: TextStyle(color: AppColors.textHintLight),
                        prefixIcon: Icon(Icons.lock_outline_rounded, color: AppColors.primary),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() => _obscurePassword = !_obscurePassword);
                          },
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(DesignTokens.radius14),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.transparent,
                      ),
                    ),
                  ),
                  const SizedBox(height: DesignTokens.space12),

                  // 确认密码（仅设置时显示）
                  if (widget.isSettingPassword) ...[
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceDark : Colors.white,
                        borderRadius: BorderRadius.circular(DesignTokens.radius14),
                        boxShadow: AppShadows.card,
                      ),
                      child: TextField(
                        controller: _confirmController,
                        obscureText: _obscureConfirm,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        style: AppTextStyles.bodyLarge,
                        decoration: InputDecoration(
                          labelText: '确认密码',
                          labelStyle: TextStyle(color: AppColors.textSecondaryLight),
                          hintText: '请再次输入密码',
                          hintStyle: TextStyle(color: AppColors.textHintLight),
                          prefixIcon: Icon(Icons.lock_outline_rounded, color: AppColors.primary),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() => _obscureConfirm = !_obscureConfirm);
                            },
                            icon: Icon(
                              _obscureConfirm
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                          counterText: '',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(DesignTokens.radius14),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.transparent,
                        ),
                      ),
                    ),
                    const SizedBox(height: DesignTokens.space12),
                  ],

                  // 错误信息
                  if (authState.error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(DesignTokens.space12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(DesignTokens.radius12),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                          const SizedBox(width: DesignTokens.space10),
                          Expanded(
                            child: Text(
                              authState.error!,
                              style: AppTextStyles.labelMedium.copyWith(
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: DesignTokens.space16),
                  ],

                  // 提交按钮
                  AppButtonPrimary(
                    onPressed: _isLoading ? null : _submit,
                    isLoading: _isLoading,
                    isFullWidth: true,
                    child: Text(widget.isSettingPassword ? '设置密码' : '确认'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
