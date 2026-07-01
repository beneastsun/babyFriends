import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/platform/app_lock_service.dart';

/// App锁状态
class AppLockState {
  final bool isEnabled;
  final bool isLoading;
  final int lastTriggerTime;
  final String? error;

  const AppLockState({
    this.isEnabled = true,
    this.isLoading = false,
    this.lastTriggerTime = 0,
    this.error,
  });

  AppLockState copyWith({
    bool? isEnabled,
    bool? isLoading,
    int? lastTriggerTime,
    String? error,
  }) {
    return AppLockState(
      isEnabled: isEnabled ?? this.isEnabled,
      isLoading: isLoading ?? this.isLoading,
      lastTriggerTime: lastTriggerTime ?? this.lastTriggerTime,
      error: error,
    );
  }
}

/// App锁Provider
final appLockProvider =
    StateNotifierProvider<AppLockNotifier, AppLockState>((ref) {
  return AppLockNotifier();
});

/// App锁Notifier
class AppLockNotifier extends StateNotifier<AppLockState> {
  AppLockNotifier() : super(const AppLockState()) {
    _init();
  }

  /// 初始化，加载当前状态
  Future<void> _init() async {
    state = state.copyWith(isLoading: true);
    final isEnabled = await AppLockService.isLockEnabled();
    final lastTriggerTime = await AppLockService.getLastTriggerTime();
    state = AppLockState(
      isEnabled: isEnabled,
      lastTriggerTime: lastTriggerTime,
    );
  }

  /// 设置启用状态
  Future<bool> setEnabled(bool enabled) async {
    state = state.copyWith(isLoading: true, error: null);

    final success = await AppLockService.setLockEnabled(enabled);

    if (success) {
      state = state.copyWith(
        isEnabled: enabled,
        isLoading: false,
      );
      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        error: '设置失败',
      );
      return false;
    }
  }

  /// 刷新状态
  Future<void> refresh() async {
    await _init();
  }

  /// 清除错误
  void clearError() {
    state = state.copyWith(error: null);
  }
}
