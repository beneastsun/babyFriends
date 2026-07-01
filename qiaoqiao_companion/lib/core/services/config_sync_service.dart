import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';
import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/database/daos/daos.dart';
import 'package:qiaoqiao_companion/core/platform/usage_stats_service.dart';
import 'package:qiaoqiao_companion/shared/models/models.dart';
import 'package:qiaoqiao_companion/shared/models/hourly_usage_stats.dart' as hourly_model;
import 'package:qiaoqiao_companion/shared/providers/today_usage_provider.dart';

/// 配置同步服务
///
/// Phase 2 轻量化替代 UsageMonitorService，仅负责：
/// 1. 每 5 分钟从系统同步应用使用统计（使用 Android UsageStatsManager 的精确数据）
/// 2. 更新数据库中的使用记录
/// 3. 刷新今日使用 Provider
///
/// 不包含：规则检查、提醒、浮窗控制、连续使用跟踪
class ConfigSyncService {
  // ignore: unused_field - kept for DAO construction consistency
  final AppDatabase _database;
  final AppUsageDao _appUsageDao;
  final DailyStatsDao _dailyStatsDao;
  final AppCategoryDao _appCategoryDao;
  final HourlyUsageDao _hourlyUsageDao;
  final Ref _ref;

  Timer? _syncTimer;
  bool _isSyncing = false;
  bool _syncInProgress = false;

  /// 同步间隔（5 分钟）
  static const int syncIntervalMinutes = 5;

  ConfigSyncService(
    this._database,
    this._ref,
  )   : _appUsageDao = AppUsageDao(_database),
        _dailyStatsDao = DailyStatsDao(_database),
        _appCategoryDao = AppCategoryDao(_database),
        _hourlyUsageDao = HourlyUsageDao(_database);

  /// 开始定时同步
  void startSync() {
    if (_isSyncing) return;

    _isSyncing = true;
    _syncTimer = Timer.periodic(
      const Duration(minutes: syncIntervalMinutes),
      (_) => refreshTodayUsage(),
    );

    // 立即执行一次全量同步
    refreshTodayUsage();
  }

  /// 停止定时同步
  void stopSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    _isSyncing = false;
  }

  /// 刷新今日使用数据（从系统同步 + 更新 Provider）
  Future<void> refreshTodayUsage() async {
    if (_syncInProgress) return;
    _syncInProgress = true;
    try {
      await _syncTodayUsageFromSystem();
      await _ref.read(todayUsageProvider.notifier).loadToday();
    } catch (e, stackTrace) {
      print('[ConfigSyncService] Error in refreshTodayUsage: $e');
      print('[ConfigSyncService] Stack trace: $stackTrace');
    } finally {
      _syncInProgress = false;
    }
  }

  /// 从系统同步今日使用统计（使用 Android UsageStatsManager 的精确数据）
  Future<void> _syncTodayUsageFromSystem() async {
    final now = DateTime.now();
    final today = DailyStats.formatDate(now);

    // 获取今日开始时间（0点）
    final todayStart = DateTime(now.year, now.month, now.day);

    // 从系统获取今日使用统计
    final systemStats = await UsageStatsService.queryUsageStats(
      startTime: todayStart,
      endTime: now,
    );

    print('[ConfigSyncService] Syncing ${systemStats.length} apps from system');

    // 获取所有应用的分类信息
    final categories = await _appCategoryDao.getAll();
    final categoryMap = {for (var c in categories) c.packageName: c.category};

    // 计算各类别总时间
    int totalSeconds = 0;
    int gameSeconds = 0;
    int videoSeconds = 0;
    int studySeconds = 0;

    // 按应用记录使用时间（使用系统的 totalTimeInForeground）
    for (final stat in systemStats) {
      final packageName = stat.packageName;
      final foregroundMs = stat.totalTimeInForeground;
      final seconds = foregroundMs ~/ 1000;

      if (seconds <= 0) continue;

      // 获取应用分类
      final category = categoryMap[packageName] ?? await _getAppCategory(packageName);

      totalSeconds += seconds;
      switch (category) {
        case AppCategory.game:
          gameSeconds += seconds;
          break;
        case AppCategory.video:
          videoSeconds += seconds;
          break;
        case AppCategory.study:
          studySeconds += seconds;
          break;
        default:
          break;
      }

      print('[ConfigSyncService] App: $packageName, time: ${seconds}s, category: ${category.code}');
    }

    // 更新每日统计（直接设置值，而非增量更新）
    await _dailyStatsDao.setDurations(
      date: today,
      totalSeconds: totalSeconds,
      gameSeconds: gameSeconds,
      videoSeconds: videoSeconds,
      studySeconds: studySeconds,
    );

    print('[ConfigSyncService] Synced today stats: total=${totalSeconds}s, game=${gameSeconds}s, video=${videoSeconds}s');

    // 更新应用使用记录（用于显示详情）
    await _syncAppUsageRecords(today, systemStats, categoryMap);

    // 同步小时级数据（用于时间线展示）
    await _syncHourlyUsage(today, categoryMap);
  }

  /// 同步应用使用记录到数据库
  Future<void> _syncAppUsageRecords(
    String date,
    List<UsageStats> systemStats,
    Map<String, AppCategory> categoryMap,
  ) async {
    // 增量更新：检查每个应用是否存在，存在则更新，不存在则插入
    int syncedCount = 0;
    for (final stat in systemStats) {
      final seconds = stat.totalTimeInForeground ~/ 1000;
      if (seconds <= 0) continue;

      final packageName = stat.packageName;
      final category = categoryMap[packageName] ?? await _getAppCategory(packageName);
      final appName = stat.appName ?? packageName;

      // 检查是否已有记录
      final existing = await _appUsageDao.getByPackageAndDate(packageName, date);
      if (existing.isNotEmpty) {
        // 更新已有记录
        final record = existing.first.copyWith(
          durationSeconds: seconds,
          endTime: DateTime.fromMillisecondsSinceEpoch(stat.lastTimeStamp),
        );
        await _appUsageDao.update(record);
      } else {
        // 插入新记录
        final record = AppUsageRecord(
          packageName: packageName,
          appName: appName,
          category: category,
          startTime: DateTime.fromMillisecondsSinceEpoch(stat.firstTimeStamp),
          endTime: DateTime.fromMillisecondsSinceEpoch(stat.lastTimeStamp),
          durationSeconds: seconds,
          date: date,
        );
        await _appUsageDao.insertOrUpdate(record);
      }
      syncedCount++;
    }
    print('[ConfigSyncService] Synced $syncedCount app records for $date');
  }

  /// 同步小时级使用数据到数据库
  Future<void> _syncHourlyUsage(
    String date,
    Map<String, AppCategory> categoryMap,
  ) async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    // 从原生通道获取小时级数据
    final hourlyData = await UsageStatsService.queryHourlyUsage(
      startTime: todayStart,
      endTime: now,
    );

    if (hourlyData.isEmpty) {
      print('[ConfigSyncService] No hourly usage data from system');
      return;
    }

    // 转换为数据库模型
    final statsList = hourlyData.map((data) {
      final category = categoryMap[data.packageName] ?? AppCategory.other;
      return hourly_model.HourlyUsageStats(
        date: data.date,
        hour: data.hour,
        packageName: data.packageName,
        appName: data.appName,
        category: category,
        durationSeconds: data.durationSeconds,
        updatedAt: now,
      );
    }).toList();

    // 批量插入新数据
    await _hourlyUsageDao.upsertBatch(statsList);

    print('[ConfigSyncService] Synced ${statsList.length} hourly usage records');
  }

  /// 获取应用分类
  Future<AppCategory> _getAppCategory(String packageName) async {
    final record = await _appCategoryDao.getByPackageName(packageName);
    return record?.category ?? AppCategory.other;
  }

  /// 是否正在同步
  bool get isSyncing => _isSyncing;
}

/// 配置同步服务 Provider
final configSyncServiceProvider = Provider<ConfigSyncService>((ref) {
  final db = AppDatabase.instance;
  return ConfigSyncService(db, ref);
});
