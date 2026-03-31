import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/database/database_service.dart';
import 'package:qiaoqiao_companion/core/platform/platform.dart';
import 'package:qiaoqiao_companion/shared/providers/providers.dart';
import 'package:qiaoqiao_companion/core/services/services.dart';
import 'package:qiaoqiao_companion/features/onboarding/data/onboarding_state.dart';

/// 应用初始化状态
class AppInitializationState {
  final bool isDatabaseReady;
  final bool isPermissionsGranted;
  final bool isOnboardingCompleted;
  final String? error;

  const AppInitializationState({
    this.isDatabaseReady = false,
    this.isPermissionsGranted = false,
    this.isOnboardingCompleted = false,
    this.error,
  });

  bool get isFullyInitialized => isDatabaseReady;

  AppInitializationState copyWith({
    bool? isDatabaseReady,
    bool? isPermissionsGranted,
    bool? isOnboardingCompleted,
    String? error,
  }) {
    return AppInitializationState(
      isDatabaseReady: isDatabaseReady ?? this.isDatabaseReady,
      isPermissionsGranted: isPermissionsGranted ?? this.isPermissionsGranted,
      isOnboardingCompleted: isOnboardingCompleted ?? this.isOnboardingCompleted,
      error: error ?? this.error,
    );
  }
}

/// 应用初始化状态 Provider
final appInitializationProvider =
    StateNotifierProvider<AppInitializationNotifier, AppInitializationState>((ref) {
  return AppInitializationNotifier(ref);
});

/// 应用初始化 Notifier
class AppInitializationNotifier extends StateNotifier<AppInitializationState> {
  final Ref _ref;

  AppInitializationNotifier(this._ref) : super(const AppInitializationState());

  /// 执行初始化
  Future<void> initialize() async {
    try {
      // 1. 初始化数据库
      final dbService = await DatabaseService.getInstance();
      await dbService.initialize();

      // 2. 加载状态
      await Future.wait([
        _ref.read(todayUsageProvider.notifier).loadToday(),
        _ref.read(pointsProvider.notifier).load(),
        _ref.read(rulesProvider.notifier).load(),
        _ref.read(couponsProvider.notifier).load(),
        // 新增：加载监控应用和时间段数据
        _ref.read(monitoredAppsProvider.notifier).load(),
        _ref.read(timePeriodsProvider.notifier).load(),
      ]);

      // 3. 初始化 OverlayService 回调监听（用于禁用app提醒）
      OverlayService.init();

      // 4. 检查权限
      final hasUsageStats = await UsageStatsService.hasPermission();
      final hasOverlay = await OverlayService.hasPermission();

      // 4. 检查Onboarding是否完成
      final isOnboardingCompleted = await _checkOnboardingCompleted();

      state = AppInitializationState(
        isDatabaseReady: true,
        isPermissionsGranted: hasUsageStats && hasOverlay,
        isOnboardingCompleted: isOnboardingCompleted,
      );

      // 5. 如果权限已授予，启动监控和前台服务
      if (hasUsageStats && hasOverlay) {
        _ref.read(usageMonitorServiceProvider).startMonitoring();
        await MonitorService.startForegroundService();
      }
    } catch (e) {
      state = AppInitializationState(error: e.toString());
    }
  }

  /// 检查权限（从设置返回时调用）
  Future<void> checkPermissions() async {
    final hasUsageStats = await UsageStatsService.hasPermission();
    final hasOverlay = await OverlayService.hasPermission();
    final granted = hasUsageStats && hasOverlay;

    state = state.copyWith(isPermissionsGranted: granted);

    if (granted) {
      _ref.read(usageMonitorServiceProvider).startMonitoring();
      await MonitorService.startForegroundService();
    }
  }

  /// 标记Onboarding完成
  Future<void> completeOnboarding() async {
    state = state.copyWith(isOnboardingCompleted: true);

    // Onboarding完成后启动监控服务（权限已在onboarding流程中授予）
    _ref.read(usageMonitorServiceProvider).startMonitoring();
    await MonitorService.startForegroundService();
    print('[AppInitializer] Onboarding completed, monitoring service started');
  }

  /// 检查Onboarding是否完成
  Future<bool> _checkOnboardingCompleted() async {
    // 调用 OnboardingNotifier 的静态方法
    return await OnboardingNotifier.isCompleted();
  }
}
