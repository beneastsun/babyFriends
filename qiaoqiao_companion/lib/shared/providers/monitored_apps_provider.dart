import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/database/daos/monitored_app_dao.dart';
import 'package:qiaoqiao_companion/shared/models/models.dart';

/// 被监控应用状态
class MonitoredAppsState {
  final List<MonitoredApp> allApps;
  final List<MonitoredApp> enabledApps;
  final Set<String> monitoredPackageNames;

  const MonitoredAppsState({
    this.allApps = const [],
    this.enabledApps = const [],
    this.monitoredPackageNames = const {},
  });

  MonitoredAppsState copyWith({
    List<MonitoredApp>? allApps,
    List<MonitoredApp>? enabledApps,
  }) {
    final all = allApps ?? this.allApps;
    final enabled = enabledApps ?? all.where((a) => a.enabled).toList();
    return MonitoredAppsState(
      allApps: all,
      enabledApps: enabled,
      monitoredPackageNames: enabled.map((a) => a.packageName).toSet(),
    );
  }

  /// 检查指定应用是否被监控
  bool isMonitored(String packageName) => monitoredPackageNames.contains(packageName);

  /// 获取指定应用的配置
  MonitoredApp? getApp(String packageName) {
    try {
      return allApps.firstWhere((a) => a.packageName == packageName);
    } catch (e) {
      return null;
    }
  }

  /// 获取指定应用的每日限制（分钟）
  int? getDailyLimit(String packageName) {
    return getApp(packageName)?.dailyLimitMinutes;
  }
}

/// 被监控应用状态 Notifier
class MonitoredAppsNotifier extends StateNotifier<MonitoredAppsState> {
  final MonitoredAppDao _dao;

  MonitoredAppsNotifier(this._dao) : super(const MonitoredAppsState());

  /// 加载所有被监控应用
  Future<void> load() async {
    final allApps = await _dao.getAll();
    state = state.copyWith(allApps: allApps);
  }

  /// 添加应用
  Future<void> addApp(MonitoredApp app) async {
    await _dao.insert(app);
    await load();
  }

  /// 批量添加应用
  Future<void> addApps(List<MonitoredApp> apps) async {
    await _dao.insertAll(apps);
    await load();
  }

  /// 更新应用配置
  Future<void> updateApp(MonitoredApp app) async {
    await _dao.update(app);
    await load();
  }

  /// 移除应用
  Future<void> removeApp(String packageName) async {
    await _dao.delete(packageName);
    await load();
  }

  /// 切换应用启用状态
  Future<void> toggleEnabled(String packageName) async {
    final app = await _dao.getByPackageName(packageName);
    if (app != null) {
      await _dao.update(app.copyWith(enabled: !app.enabled));
      await load();
    }
  }

  /// 设置应用每日限制
  Future<void> setDailyLimit(String packageName, int? limitMinutes) async {
    final app = await _dao.getByPackageName(packageName);
    if (app != null) {
      if (limitMinutes == null) {
        await _dao.update(app.copyWith(clearDailyLimit: true));
      } else {
        await _dao.update(app.copyWith(dailyLimitMinutes: limitMinutes));
      }
      await load();
    }
  }

  /// 刷新数据
  Future<void> refresh() async {
    await load();
  }
}

/// 被监控应用状态 Provider
final monitoredAppsProvider =
    StateNotifierProvider<MonitoredAppsNotifier, MonitoredAppsState>((ref) {
  return MonitoredAppsNotifier(MonitoredAppDao(AppDatabase.instance));
});
