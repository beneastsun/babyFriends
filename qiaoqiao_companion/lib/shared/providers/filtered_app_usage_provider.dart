import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/database/daos/daos.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';
import 'package:qiaoqiao_companion/shared/models/models.dart';
import 'package:qiaoqiao_companion/shared/providers/installed_apps_provider.dart';
import 'package:qiaoqiao_companion/shared/providers/rules_provider.dart';

/// 根据筛选条件获取应用使用明细的 Provider
///
/// 优化说明：
/// - 使用 autoDispose 自动释放不再使用的缓存
/// - 使用 installedAppsProvider 缓存已安装应用，避免重复 Native Bridge 调用
/// - 使用 rulesProvider 缓存规则，避免重复数据库查询
final filteredAppUsageProvider = FutureProvider.autoDispose
    .family<List<AppUsageSummary>, AppUsageFilter>((ref, filter) async {
  // 监听已安装应用缓存
  final installedAppsAsync = ref.watch(installedAppsProvider);

  // 监听规则缓存
  final rulesState = ref.watch(rulesProvider);
  final rules = rulesState.enabledRules;

  // 等待已安装应用数据加载完成
  final installedAppsData = installedAppsAsync.valueOrNull ?? InstalledAppsData.empty;

  switch (filter.type) {
    case AppUsageFilterType.todayAll:
      return _fetchTodayAll(rules, installedAppsData);
    case AppUsageFilterType.todayHour:
      return _fetchTodayHour(filter.hour ?? 0, rules, installedAppsData);
    case AppUsageFilterType.weekAll:
      return _fetchWeekAll(rules, installedAppsData);
    case AppUsageFilterType.weekDay:
      return _fetchWeekDay(filter.date ?? '', rules, installedAppsData);
  }
});

/// 获取今日全天数据
Future<List<AppUsageSummary>> _fetchTodayAll(
  List<Rule> rules,
  InstalledAppsData installedAppsData,
) async {
  final db = AppDatabase.instance;
  final appUsageDao = AppUsageDao(db);

  final today = DailyStats.formatDate(DateTime.now());
  final isWeekend = _isWeekend(DateTime.now());

  // 获取今日应用使用汇总
  final aggregatedData = await appUsageDao.getAggregatedByDate(today);

  // 计算总使用时间
  int totalUsageSeconds = 0;
  for (final data in aggregatedData) {
    totalUsageSeconds += data['total_duration'] as int;
  }

  // 构建汇总列表
  return _buildSummaries(
    aggregatedData: aggregatedData,
    rules: rules,
    installedAppsData: installedAppsData,
    totalUsageSeconds: totalUsageSeconds,
    isWeekend: isWeekend,
  );
}

/// 获取今日某小时数据
Future<List<AppUsageSummary>> _fetchTodayHour(
  int hour,
  List<Rule> rules,
  InstalledAppsData installedAppsData,
) async {
  final db = AppDatabase.instance;
  final hourlyUsageDao = HourlyUsageDao(db);

  final today = DailyStats.formatDate(DateTime.now());
  final isWeekend = _isWeekend(DateTime.now());

  // 获取指定小时的数据
  final hourlyStats = await hourlyUsageDao.getByDateAndHour(today, hour);

  if (hourlyStats.isEmpty) {
    return [];
  }

  // 转换为聚合数据格式
  final aggregatedData = hourlyStats.map((stat) => {
    'package_name': stat.packageName,
    'app_name': stat.appName,
    'category': stat.category.code,
    'total_duration': stat.durationSeconds,
  }).toList();

  // 计算总使用时间
  int totalUsageSeconds = 0;
  for (final stat in hourlyStats) {
    totalUsageSeconds += stat.durationSeconds;
  }

  return _buildSummaries(
    aggregatedData: aggregatedData,
    rules: rules,
    installedAppsData: installedAppsData,
    totalUsageSeconds: totalUsageSeconds,
    isWeekend: isWeekend,
  );
}

/// 获取本周汇总数据
Future<List<AppUsageSummary>> _fetchWeekAll(
  List<Rule> rules,
  InstalledAppsData installedAppsData,
) async {
  final db = AppDatabase.instance;
  final appUsageDao = AppUsageDao(db);

  final now = DateTime.now();
  final weekStart = now.subtract(Duration(days: now.weekday - 1)); // 本周一
  final startDate = DailyStats.formatDate(weekStart);
  final endDate = DailyStats.formatDate(now);
  final isWeekend = _isWeekend(now);

  // 获取本周数据范围
  final records = await appUsageDao.getByDateRange(startDate, endDate);

  if (records.isEmpty) {
    return [];
  }

  // 按包名聚合
  final aggregatedMap = <String, Map<String, dynamic>>{};
  for (final record in records) {
    final packageName = record.packageName;
    if (!aggregatedMap.containsKey(packageName)) {
      aggregatedMap[packageName] = {
        'package_name': packageName,
        'app_name': record.appName,
        'category': record.category.code,
        'total_duration': 0,
      };
    }
    aggregatedMap[packageName]!['total_duration'] =
        (aggregatedMap[packageName]!['total_duration'] as int) + record.durationSeconds;
  }

  final aggregatedData = aggregatedMap.values.toList();
  aggregatedData.sort((a, b) => (b['total_duration'] as int).compareTo(a['total_duration'] as int));

  // 计算总使用时间
  int totalUsageSeconds = 0;
  for (final data in aggregatedData) {
    totalUsageSeconds += data['total_duration'] as int;
  }

  return _buildSummaries(
    aggregatedData: aggregatedData,
    rules: rules,
    installedAppsData: installedAppsData,
    totalUsageSeconds: totalUsageSeconds,
    isWeekend: isWeekend,
  );
}

/// 获取本周某天数据
Future<List<AppUsageSummary>> _fetchWeekDay(
  String date,
  List<Rule> rules,
  InstalledAppsData installedAppsData,
) async {
  if (date.isEmpty) {
    return [];
  }

  final db = AppDatabase.instance;
  final appUsageDao = AppUsageDao(db);

  // 解析日期判断是否是周末
  final parts = date.split('-');
  DateTime? dateObj;
  if (parts.length == 3) {
    dateObj = DateTime(
      int.tryParse(parts[0]) ?? DateTime.now().year,
      int.tryParse(parts[1]) ?? 1,
      int.tryParse(parts[2]) ?? 1,
    );
  }
  final isWeekend = dateObj != null ? _isWeekend(dateObj) : false;

  // 获取指定日期数据
  final aggregatedData = await appUsageDao.getAggregatedByDate(date);

  if (aggregatedData.isEmpty) {
    return [];
  }

  // 计算总使用时间
  int totalUsageSeconds = 0;
  for (final data in aggregatedData) {
    totalUsageSeconds += data['total_duration'] as int;
  }

  return _buildSummaries(
    aggregatedData: aggregatedData,
    rules: rules,
    installedAppsData: installedAppsData,
    totalUsageSeconds: totalUsageSeconds,
    isWeekend: isWeekend,
  );
}

/// 构建汇总列表
List<AppUsageSummary> _buildSummaries({
  required List<Map<String, dynamic>> aggregatedData,
  required List<Rule> rules,
  required InstalledAppsData installedAppsData,
  required int totalUsageSeconds,
  required bool isWeekend,
}) {
  final List<AppUsageSummary> result = [];

  for (final data in aggregatedData) {
    final packageName = data['package_name'] as String;
    final dbAppName = data['app_name'] as String?;
    final category = AppCategory.fromCode(data['category'] as String? ?? 'other');
    final totalDuration = data['total_duration'] as int;

    // 确定应用名称（优先使用缓存的应用名称）
    final isDbNamePackageName = dbAppName != null &&
        (dbAppName.startsWith('com.') ||
         dbAppName.startsWith('org.') ||
         dbAppName.startsWith('io.') ||
         dbAppName.startsWith('tv.') ||
         dbAppName.startsWith('me.') ||
         dbAppName.startsWith('cn.'));

    String appName;
    if (dbAppName != null && dbAppName.isNotEmpty && !isDbNamePackageName) {
      appName = dbAppName;
    } else {
      // 使用缓存的应用名称
      final cachedName = installedAppsData.getName(packageName);
      if (cachedName != null && cachedName.isNotEmpty) {
        appName = cachedName;
      } else {
        appName = _generateFriendlyAppName(packageName);
      }
    }

    // 查找规则
    final appRule = rules
        .where((r) => r.ruleType == RuleType.appSingle && r.target == packageName)
        .firstOrNull;

    final categoryRule = rules
        .where((r) => r.ruleType == RuleType.appCategory && r.target == category.code)
        .firstOrNull;

    final totalRule = rules
        .where((r) => r.ruleType == RuleType.totalTime)
        .firstOrNull;

    // 确定限制
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

    // 使用缓存的图标
    final appIcon = installedAppsData.getIcon(packageName);

    result.add(AppUsageSummary(
      packageName: packageName,
      appName: appName,
      category: category,
      todayDurationSeconds: totalDuration,
      limitMinutes: limitMinutes,
      limitSource: limitSource,
      hasRule: hasRule,
      appIcon: appIcon,
      usagePercentage: usagePercentage,
    ));
  }

  // 按使用时间降序排序
  result.sort((a, b) => b.todayDurationSeconds.compareTo(a.todayDurationSeconds));

  return result;
}

bool _isWeekend(DateTime date) {
  final weekday = date.weekday;
  return weekday == DateTime.saturday || weekday == DateTime.sunday;
}

String _generateFriendlyAppName(String packageName) {
  final parts = packageName.split('.');
  final skipParts = {'com', 'org', 'io', 'tv', 'me', 'cn', 'android', 'google', 'xiaomi', 'miui', 'androidx'};

  for (var i = parts.length - 1; i >= 0; i--) {
    final part = parts[i];
    if (part.isEmpty || skipParts.contains(part) || _isAllDigits(part)) {
      continue;
    }
    return _capitalize(part);
  }

  return parts.isNotEmpty ? _capitalize(parts.last) : packageName;
}

String _capitalize(String s) {
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}

bool _isAllDigits(String s) {
  return s.isNotEmpty && s.codeUnits.every((c) => c >= 48 && c <= 57);
}
