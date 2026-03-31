import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/features/parent_mode/data/parent_password_repository.dart';

/// 家长认证服务状态
class ParentAuthState {
  final bool hasPassword;
  final bool isAuthenticated;
  final bool isLoading;
  final String? error;

  const ParentAuthState({
    this.hasPassword = false,
    this.isAuthenticated = false,
    this.isLoading = false,
    this.error,
  });

  ParentAuthState copyWith({
    bool? hasPassword,
    bool? isAuthenticated,
    bool? isLoading,
    String? error,
  }) {
    return ParentAuthState(
      hasPassword: hasPassword ?? this.hasPassword,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 家长认证服务 Provider
final parentAuthProvider =
    StateNotifierProvider<ParentAuthNotifier, ParentAuthState>((ref) {
  return ParentAuthNotifier();
});

/// 家长认证服务 Notifier
class ParentAuthNotifier extends StateNotifier<ParentAuthState> {
  final _repository = ParentPasswordRepository();

  ParentAuthNotifier() : super(const ParentAuthState()) {
    _init();
  }

  /// 初始化
  Future<void> _init() async {
    state = state.copyWith(isLoading: true);
    final hasPassword = await _repository.hasPassword();
    state = ParentAuthState(hasPassword: hasPassword);
  }

  /// 设置密码
  Future<bool> setPassword(String password) async {
    if (password.length < 4) {
      state = state.copyWith(error: '密码至少需要4位');
      return false;
    }

    state = state.copyWith(isLoading: true);
    await _repository.setPassword(password);
    state = ParentAuthState(
      hasPassword: true,
      isAuthenticated: true,
    );
    return true;
  }

  /// 验证密码
  Future<bool> verifyPassword(String password) async {
    state = state.copyWith(isLoading: true, error: null);

    final isValid = await _repository.verifyPassword(password);

    if (isValid) {
      state = state.copyWith(isAuthenticated: true, isLoading: false);
    } else {
      state = state.copyWith(
        isLoading: false,
        error: '密码错误',
      );
    }

    return isValid;
  }

  /// 退出家长模式
  void logout() {
    state = ParentAuthState(hasPassword: state.hasPassword);
  }

  /// 清除错误
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// 刷新状态（从存储重新读取）
  Future<void> refreshState() async {
    final hasPassword = await _repository.hasPassword();
    state = ParentAuthState(
      hasPassword: hasPassword,
      isAuthenticated: state.isAuthenticated,
    );
  }

  /// 重置密码（需要先验证旧密码）
  Future<bool> resetPassword(String oldPassword, String newPassword) async {
    final isValid = await _repository.verifyPassword(oldPassword);
    if (!isValid) {
      state = state.copyWith(error: '旧密码错误');
      return false;
    }

    await _repository.setPassword(newPassword);
    state = state.copyWith(error: null);
    return true;
  }
}
