import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/platform/usage_stats_service.dart';

/// 已安装应用缓存数据
class InstalledAppsData {
  /// 原始列表
  final List<AppInfo> apps;

  /// 按包名索引的 Map，用于快速查找
  final Map<String, AppInfo> appMap;

  /// 应用图标 Map (packageName -> base64 icon)
  final Map<String, String?> iconMap;

  /// 应用名称 Map (packageName -> appName)
  final Map<String, String> nameMap;

  const InstalledAppsData({
    required this.apps,
    required this.appMap,
    required this.iconMap,
    required this.nameMap,
  });

  /// 空数据
  static const empty = InstalledAppsData(
    apps: [],
    appMap: {},
    iconMap: {},
    nameMap: {},
  );

  /// 获取指定包名的应用信息
  AppInfo? getApp(String packageName) => appMap[packageName];

  /// 获取指定包名的应用图标
  String? getIcon(String packageName) => iconMap[packageName];

  /// 获取指定包名的应用名称
  String? getName(String packageName) => nameMap[packageName];
}

/// 已安装应用缓存 Provider
///
/// 使用 keepAlive 确保数据常驻内存，避免重复的 Native Bridge 调用。
/// 这是一个昂贵的操作，应该在整个应用生命周期内缓存。
///
/// 使用方式：
/// ```dart
/// final installedAppsAsync = ref.watch(installedAppsProvider);
/// if (installedAppsAsync.hasValue) {
///   final data = installedAppsAsync.value!;
///   final appName = data.getName(packageName);
///   final appIcon = data.getIcon(packageName);
/// }
/// ```
final installedAppsProvider = FutureProvider<InstalledAppsData>((ref) async {
  // 保持缓存，不自动释放
  ref.keepAlive();

  final apps = await UsageStatsService.getInstalledApps();

  // 构建索引 Map
  final appMap = <String, AppInfo>{};
  final iconMap = <String, String?>{};
  final nameMap = <String, String>{};

  for (final app in apps) {
    appMap[app.packageName] = app;
    iconMap[app.packageName] = app.appIcon;
    nameMap[app.packageName] = app.appName;
  }

  return InstalledAppsData(
    apps: apps,
    appMap: appMap,
    iconMap: iconMap,
    nameMap: nameMap,
  );
});

/// 刷新已安装应用缓存的 Provider
///
/// 调用此 Provider 的 refresh 方法可以重新获取应用列表
final installedAppsRefreshProvider = StateProvider<int>((ref) => 0);

/// 可刷新的已安装应用 Provider
///
/// 当需要刷新应用列表时，调用：
/// ```dart
/// ref.read(installedAppsRefreshProvider.notifier).state++;
/// ```
final installedAppsRefreshableProvider = FutureProvider<InstalledAppsData>((ref) async {
  // 监听刷新触发器
  ref.watch(installedAppsRefreshProvider);

  // 保持缓存
  ref.keepAlive();

  final apps = await UsageStatsService.getInstalledApps();

  final appMap = <String, AppInfo>{};
  final iconMap = <String, String?>{};
  final nameMap = <String, String>{};

  for (final app in apps) {
    appMap[app.packageName] = app;
    iconMap[app.packageName] = app.appIcon;
    nameMap[app.packageName] = app.appName;
  }

  return InstalledAppsData(
    apps: apps,
    appMap: appMap,
    iconMap: iconMap,
    nameMap: nameMap,
  );
});
