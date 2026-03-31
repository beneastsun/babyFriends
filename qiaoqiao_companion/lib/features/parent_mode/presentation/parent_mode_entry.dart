import 'package:flutter/material.dart';
import 'package:qiaoqiao_companion/features/parent_mode/presentation/parent_password_dialog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/features/parent_mode/domain/parent_auth_service.dart';
import 'package:qiaoqiao_companion/features/parent_mode/data/parent_password_repository.dart';

/// 家长模式入口组件
/// 点击触发密码输入
class ParentModeEntry extends ConsumerStatefulWidget {
  final Widget child;
  final VoidCallback? onAuthenticated;

  const ParentModeEntry({
    super.key,
    required this.child,
    this.onAuthenticated,
  });

  @override
  ConsumerState<ParentModeEntry> createState() => _ParentModeEntryState();
}

class _ParentModeEntryState extends ConsumerState<ParentModeEntry> {
  Future<void> _showPasswordDialog() async {
    // 直接从存储检查，避免依赖可能未初始化完成的 Provider 状态
    final repository = ParentPasswordRepository();
    final hasPassword = await repository.hasPassword();

    if (!mounted) return;

    if (!hasPassword) {
      // 首次设置密码
      final success = await showParentPasswordDialog(
        context: context,
        isSettingPassword: true,
      );
      if (success == true && mounted) {
        // 设置成功后刷新 Provider 状态
        ref.read(parentAuthProvider.notifier).refreshState();
        widget.onAuthenticated?.call();
      }
    } else {
      // 验证密码
      final success = await showParentPasswordDialog(
        context: context,
        isSettingPassword: false,
      );
      if (success == true && mounted) {
        widget.onAuthenticated?.call();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _showPasswordDialog,
      child: widget.child,
    );
  }
}
