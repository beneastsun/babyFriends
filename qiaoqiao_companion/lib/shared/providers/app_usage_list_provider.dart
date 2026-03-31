import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/database/daos/daos.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';
import 'package:qiaoqiao_companion/core/platform/usage_stats_service.dart';
import 'package:qiaoqiao_companion/shared/models/models.dart';

/// 应用使用汇总列表 Notifier
/// 每30秒自动刷新，与 UsageMonitorService 同步
class AppUsageListNotifier extends StateNotifier<AsyncValue<List<AppUsageSummary>>> {
  Timer? _refreshTimer;

  AppUsageListNotifier() : super(const AsyncValue.loading()) {
    // 立即加载
    _loadData();
    // 启动定时刷新（每30秒）
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadData(),
    );
  }

  Future<void> _loadData() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchAppUsageSummaries());
  }

  Future<List<AppUsageSummary>> _fetchAppUsageSummaries() async {
    final db = AppDatabase.instance;
    final appUsageDao = AppUsageDao(db);
    final ruleDao = RuleDao(db);

    final today = DailyStats.formatDate(DateTime.now());
    final isWeekend = _isWeekend(DateTime.now());
    print('[AppUsageList] Fetching data for date: $today');

    // 1. 获取今日应用使用汇总
    final aggregatedData = await appUsageDao.getAggregatedByDate(today);
    print('[AppUsageList] Aggregated data count: ${aggregatedData.length}');

    // 2. 获取所有启用的规则
    final rules = await ruleDao.getEnabled();

    // 3. 获取已安装应用列表（包含图标）
    final installedApps = await UsageStatsService.getInstalledApps();
    print('[AppUsageList] Installed apps count: ${installedApps.length}');
    for (final data in aggregatedData) {
      print('[AppUsageList] App: ${data['package_name']}, app_name in DB: ${data['app_name']}, duration: ${data['total_duration']}');
    }
    final appIconMap = <String, String?>{};
    final appNameMap = <String, String>{};
    for (var app in installedApps) {
      appIconMap[app.packageName] = app.appIcon;
      appNameMap[app.packageName] = app.appName;
      print('[AppUsageList] InstalledApp: ${app.packageName} -> ${app.appName}');
    }

    // 4. 计算总使用时间（用于计算百分比）
    int totalUsageSeconds = 0;
    for (final data in aggregatedData) {
      final totalDuration = data['total_duration'] as int;
      totalUsageSeconds += totalDuration;
    }

    // 5. 构建汇总列表
    final List<AppUsageSummary> result = [];

    for (final data in aggregatedData) {
      final packageName = data['package_name'] as String;
      final dbAppName = data['app_name'] as String?;
      // 优先使用已安装应用列表中的名称
      // 如果数据库中的名称看起来像包名，则忽略它
      final isDbNamePackageName = dbAppName != null &&
          (dbAppName.startsWith('com.') ||
           dbAppName.startsWith('org.') ||
           dbAppName.startsWith('io.') ||
           dbAppName.startsWith('tv.') ||
           dbAppName.startsWith('me.') ||
           dbAppName.startsWith('cn.'));

      // 优先使用数据库中的名称（来自原生 queryUsageStats 的 getAppName）
      // 这与系统统计数据来源一致
      String appName;
      if (dbAppName != null && dbAppName.isNotEmpty && !isDbNamePackageName) {
        // 使用数据库中存储的名称（来自原生 queryUsageStats）
        appName = dbAppName;
      } else if (appNameMap.containsKey(packageName) && appNameMap[packageName]!.isNotEmpty) {
        // 备选：使用已安装应用列表中的名称
        appName = appNameMap[packageName]!;
      } else {
        // 最后备选：从包名生成友好名称
        appName = _generateFriendlyAppName(packageName);
      }
      final category = AppCategory.fromCode(data['category'] as String? ?? 'other');
      final totalDuration = data['total_duration'] as int;

      // 与系统设置保持一致，不过滤任何有使用时间的应用

      // 查找单应用规则
      final appRule = rules
          .where((r) =>
              r.ruleType == RuleType.appSingle && r.target == packageName)
          .firstOrNull;

      // 查找分类规则
      final categoryRule = rules
          .where((r) =>
              r.ruleType == RuleType.appCategory && r.target == category.code)
          .firstOrNull;

      // 查找总时间规则
      final totalRule = rules
          .where((r) => r.ruleType == RuleType.totalTime)
          .firstOrNull;

      // 确定限制来源和限额
      int? limitMinutes;
      LimitSource limitSource;
      bool hasRule = false;

      if (appRule != null) {
        limitMinutes = isWeekend
            ? appRule.weekendLimitMinutes ?? appRule.weekdayLimitMinutes
            : appRule.weekdayLimitMinutes;
        limitSource = LimitSource.singleApp;
        hasRule = true;
      } else if (categoryRule != null) {
        limitMinutes = isWeekend
            ? categoryRule.weekendLimitMinutes ?? categoryRule.weekdayLimitMinutes
            : categoryRule.weekdayLimitMinutes;
        limitSource = LimitSource.category;
      } else if (totalRule != null) {
        limitMinutes = isWeekend
            ? totalRule.weekendLimitMinutes ?? totalRule.weekdayLimitMinutes
            : totalRule.weekdayLimitMinutes;
        limitSource = LimitSource.total;
      } else {
        limitMinutes = null;
        limitSource = LimitSource.none;
      }

      // 计算使用占比
      final usagePercentage = totalUsageSeconds > 0
          ? totalDuration / totalUsageSeconds
          : 0.0;

      result.add(AppUsageSummary(
        packageName: packageName,
        appName: appName,
        category: category,
        todayDurationSeconds: totalDuration,
        limitMinutes: limitMinutes,
        limitSource: limitSource,
        hasRule: hasRule,
        appIcon: appIconMap[packageName],
        usagePercentage: usagePercentage,
      ));
    }

    // 按使用时间降序排序
    result.sort((a, b) => b.todayDurationSeconds.compareTo(a.todayDurationSeconds));

    return result;
  }

  /// 手动刷新
  Future<void> refresh() async {
    await _loadData();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}

/// 应用使用汇总列表 Provider（自动刷新）
final appUsageListProvider =
    StateNotifierProvider<AppUsageListNotifier, AsyncValue<List<AppUsageSummary>>>((ref) {
  return AppUsageListNotifier();
});

/// 今日总使用时间 Provider
final todayTotalUsageProvider = Provider<AsyncValue<int>>((ref) {
  final asyncSummaries = ref.watch(appUsageListProvider);
  return asyncSummaries.when(
    data: (summaries) {
      int total = 0;
      for (final s in summaries) {
        total += s.todayDurationSeconds;
      }
      return AsyncValue.data(total);
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

/// 今日总限额 Provider
final todayTotalLimitProvider = FutureProvider<int?>((ref) async {
  final db = AppDatabase.instance;
  final ruleDao = RuleDao(db);
  final rules = await ruleDao.getEnabled();
  final totalRule = rules.where((r) => r.ruleType == RuleType.totalTime).firstOrNull;

  if (totalRule == null) return null;

  return _isWeekend(DateTime.now())
      ? totalRule.weekendLimitMinutes ?? totalRule.weekdayLimitMinutes
      : totalRule.weekdayLimitMinutes;
});

bool _isWeekend(DateTime date) {
  final weekday = date.weekday;
  return weekday == DateTime.saturday || weekday == DateTime.sunday;
}

/// 从包名生成友好的应用名称
/// 例如：com.ss.android.yumme.video -> Yumme
///      com.tencent.mm -> MM
///      com.android.settings -> Settings
String _generateFriendlyAppName(String packageName) {
  final parts = packageName.split('.');

  // 过滤掉常见的公司/组织前缀
  final skipParts = {'com', 'org', 'io', 'tv', 'me', 'cn', 'android', 'google', 'xiaomi', 'miui', 'androidx'};

  // 从后往前找第一个有意义的部分
  for (var i = parts.length - 1; i >= 0; i--) {
    final part = parts[i];
    if (part.isEmpty || skipParts.contains(part) || _isAllDigits(part)) {
      continue;
    }
    // 首字母大写并返回
    return _capitalize(part);
  }

  // 如果都过滤掉了，返回最后一个非空部分
  return parts.isNotEmpty ? _capitalize(parts.last) : packageName;
}

/// 首字母大写
String _capitalize(String s) {
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}

/// 检查字符串是否全是数字
bool _isAllDigits(String s) {
  return s.isNotEmpty && s.codeUnits.every((c) => c >= 48 && c <= 57);
}
