import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/database/daos/daos.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';
import 'package:qiaoqiao_companion/core/platform/overlay_service.dart';
import 'package:qiaoqiao_companion/core/platform/usage_stats_service.dart';
import 'package:qiaoqiao_companion/core/services/continuous_usage_service.dart';
import 'package:qiaoqiao_companion/core/services/reminder_service.dart';
import 'package:qiaoqiao_companion/core/services/rule_checker_service.dart';
import 'package:qiaoqiao_companion/shared/models/models.dart';
import 'package:qiaoqiao_companion/shared/models/hourly_usage_stats.dart' as hourly_model;
import 'package:qiaoqiao_companion/shared/providers/monitored_apps_provider.dart';
import 'package:qiaoqiao_companion/shared/providers/today_usage_provider.dart';
import 'package:qiaoqiao_companion/shared/providers/continuous_usage_provider.dart';

/// 使用监控服务
///
/// 负责：
/// 1. 定时从系统同步应用使用统计（使用 Android UsageStatsManager 的精确数据）
/// 2. 更新数据库中的使用记录
/// 3. 检查规则并触发提醒
/// 4. 更新状态
class UsageMonitorService {
  final AppDatabase _database;
  final ReminderService _reminderService;
  final RuleCheckerService _ruleCheckerService;
  final ContinuousUsageService _continuousUsageService;
  final AppUsageDao _appUsageDao;
  final DailyStatsDao _dailyStatsDao;
  final RuleDao _ruleDao;
  final AppCategoryDao _appCategoryDao;
  final HourlyUsageDao _hourlyUsageDao;
  final Ref _ref;

  Timer? _monitorTimer;
  String? _lastForegroundApp;
  bool _isMonitoring = false;

  /// 跟踪是否已触发锁定状态（用于判断是否需要显示锁定界面）
  bool _totalTimeLocked = false;
  bool _categoryLocked = false;

  // === 连续使用跟踪状态 ===
  DateTime? _lastPollTime;
  String? _currentSessionApp;
  bool _isSessionActive = false;
  String? _lastPollDate;

  // === 倒计时悬浮窗状态 ===
  bool _countdownWidgetShowing = false;
  String? _countdownTriggerApp; // 触发倒计时的应用

  /// 监控间隔（秒）- 从系统同步数据的间隔
  static const int monitorIntervalSeconds = 5;

  UsageMonitorService(
    this._database,
    this._reminderService,
    this._ruleCheckerService,
    this._continuousUsageService,
    this._ref,
  )   : _appUsageDao = AppUsageDao(_database),
        _dailyStatsDao = DailyStatsDao(_database),
        _ruleDao = RuleDao(_database),
        _appCategoryDao = AppCategoryDao(_database),
        _hourlyUsageDao = HourlyUsageDao(_database);

  /// 开始监控
  void startMonitoring() {
    if (_isMonitoring) return;

    _isMonitoring = true;
    _monitorTimer = Timer.periodic(
      const Duration(seconds: monitorIntervalSeconds),
      (_) => _syncAndCheck(),
    );

    // 立即执行一次
    _syncAndCheck();
  }

  /// 停止监控
  void stopMonitoring() {
    // 记录最后的时长
    if (_isSessionActive && _currentSessionApp != null && _lastPollTime != null) {
      final now = DateTime.now();
      final durationSeconds = now.difference(_lastPollTime!).inSeconds;
      if (durationSeconds > 0 && durationSeconds <= monitorIntervalSeconds * 3) {
        _continuousUsageService.onAppStopped(_currentSessionApp!, durationSeconds);
        print('[UsageMonitor] Final accumulation: ${durationSeconds}s for $_currentSessionApp');
      }
    }

    _monitorTimer?.cancel();
    _monitorTimer = null;
    _isMonitoring = false;
    _currentSessionApp = null;
    _isSessionActive = false;
    _resetLockStates();
  }

  /// 重置锁定状态（每天午夜调用）
  void _resetLockStates() {
    _totalTimeLocked = false;
    _categoryLocked = false;
  }

  /// 处理连续使用跟踪的应用切换
  Future<void> _handleContinuousUsageTransition(String? currentApp, DateTime now) async {
    final monitoredApps = _ref.read(monitoredAppsProvider);

    // 计算上次轮询以来的时间
    final elapsedSeconds = _lastPollTime != null
        ? now.difference(_lastPollTime!).inSeconds
        : 0;

    // 验证时间合理性（防止大跳跃）
    final validElapsed = (elapsedSeconds > 0 && elapsedSeconds <= monitorIntervalSeconds * 3)
        ? elapsedSeconds
        : 0;

    // Step 1: 只有在会话活跃且监控应用在前台时才累加时间
    if (_isSessionActive && _currentSessionApp != null && validElapsed > 0) {
      await _continuousUsageService.onAppStopped(_currentSessionApp!, validElapsed);
      print('[UsageMonitor] Accumulated ${validElapsed}s for $_currentSessionApp');
    }

    // Step 2: 判断当前应用是否需要跟踪
    final shouldTrackCurrent = currentApp != null && monitoredApps.isMonitored(currentApp);

    // Step 3: 处理会话状态变化
    if (shouldTrackCurrent) {
      // 当前应用需要监控
      if (_currentSessionApp != currentApp) {
        // 应用切换或首次进入，通知会话（会处理恢复逻辑）
        await _continuousUsageService.onAppStarted(currentApp);
        print('[UsageMonitor] Session now tracking: $currentApp');
      }
      _currentSessionApp = currentApp;
      _isSessionActive = true;
    } else {
      // 离开监控应用（息屏或切换到非监控app）
      // 关键：不重置 _currentSessionApp，保留它用于5分钟内恢复
      // 只设置 _isSessionActive = false，停止累加时间
      if (_isSessionActive) {
        print('[UsageMonitor] Session paused (not tracking), currentApp: $currentApp');
      }
      _isSessionActive = false;
      // 不设置 _currentSessionApp = null！
    }
  }

  /// 同步系统统计数据并检查规则
  Future<void> _syncAndCheck() async {
    try {
      final now = DateTime.now();
      final today = DailyStats.formatDate(now);

      // === 跨天重置 ===
      if (_lastPollDate != null && _lastPollDate != today) {
        print('[UsageMonitor] Day changed, resetting continuous usage state');
        _currentSessionApp = null;
        _isSessionActive = false;
      }
      _lastPollDate = today;

      // 1. 获取前台应用
      final currentApp = await UsageStatsService.getCurrentForegroundApp();
      print('[UsageMonitor] Polling - currentApp: $currentApp, lastApp: $_lastForegroundApp');

      // === 检查会话恢复（30分钟无活动阈值）===
      await _continuousUsageService.restoreSession();

      // === 处理连续使用跟踪 ===
      await _handleContinuousUsageTransition(currentApp, now);

      // 更新状态
      if (currentApp != null) {
        _lastForegroundApp = currentApp;
      }
      _lastPollTime = now;

      // 2. 检查禁用应用
      if (currentApp != null) {
        await _checkForbiddenApp(currentApp);
      }

      // 3. 同步系统数据
      await _syncTodayUsageFromSystem();

      // 3.5 刷新今日使用数据（解决首次启动时不显示使用时长的问题）
      await _ref.read(todayUsageProvider.notifier).loadToday();

      // 4. 检查规则
      await _checkRules();

      // 5. 检查连续使用提醒和强制休息
      if (currentApp != null) {
        await _checkContinuousUsageAlerts(currentApp);
        await _checkAndTriggerRest(currentApp);
      }

    } catch (e, stackTrace) {
      print('[UsageMonitor] Error in _syncAndCheck: $e');
      print('[UsageMonitor] Stack trace: $stackTrace');
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

    print('[UsageMonitor] Syncing ${systemStats.length} apps from system');

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

      print('[UsageMonitor] App: $packageName, time: ${seconds}s, category: ${category.code}');
    }

    // 更新每日统计（直接设置值，而非增量更新）
    await _dailyStatsDao.setDurations(
      date: today,
      totalSeconds: totalSeconds,
      gameSeconds: gameSeconds,
      videoSeconds: videoSeconds,
      studySeconds: studySeconds,
    );

    print('[UsageMonitor] Synced today stats: total=${totalSeconds}s, game=${gameSeconds}s, video=${videoSeconds}s');

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
    // 先清除今日旧记录
    final deletedCount = await _appUsageDao.deleteByDate(date);
    print('[UsageMonitor] Deleted $deletedCount old records for $date');

    // 插入新的使用记录
    int insertedCount = 0;
    for (final stat in systemStats) {
      final seconds = stat.totalTimeInForeground ~/ 1000;
      if (seconds <= 0) continue;

      final packageName = stat.packageName;
      final category = categoryMap[packageName] ?? await _getAppCategory(packageName);
      final appName = stat.appName ?? packageName;

      // 创建汇总记录（今日该应用的总使用时间）
      final record = AppUsageRecord(
        packageName: packageName,
        appName: appName,
        category: category,
        startTime: DateTime.fromMillisecondsSinceEpoch(stat.firstTimeStamp),
        endTime: DateTime.fromMillisecondsSinceEpoch(stat.lastTimeStamp),
        durationSeconds: seconds,
        date: date,
      );

      await _appUsageDao.insert(record);
      insertedCount++;
    }
    print('[UsageMonitor] Inserted $insertedCount records for $date');
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
      print('[UsageMonitor] No hourly usage data from system');
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

    // 先清除今日旧的小时级数据
    await _hourlyUsageDao.deleteByDate(date);

    // 批量插入新数据
    await _hourlyUsageDao.upsertBatch(statsList);

    print('[UsageMonitor] Synced ${statsList.length} hourly usage records');
  }

  /// 获取应用分类
  Future<AppCategory> _getAppCategory(String packageName) async {
    final record = await AppCategoryDao(_database).getByPackageName(packageName);
    return record?.category ?? AppCategory.other;
  }

  /// 检查规则
  Future<void> _checkRules() async {
    final rules = await _ruleDao.getEnabled();
    print('[UsageMonitor] _checkRules: 找到 ${rules.length} 条启用规则');
    for (final r in rules) {
      print('[UsageMonitor] 规则: type=${r.ruleType.code}, enabled=${r.enabled}, target=${r.target}');
    }

    final today = DailyStats.formatDate(DateTime.now());
    final stats = await _dailyStatsDao.getByDate(today);

    if (stats == null) return;

    for (final rule in rules) {
      await _checkRule(rule, stats);
    }
  }

  /// 检查单个规则
  Future<void> _checkRule(Rule rule, DailyStats stats) async {
    switch (rule.ruleType) {
      case RuleType.totalTime:
        await _checkTotalTimeRule(rule, stats);
        break;
      case RuleType.appCategory:
        await _checkCategoryRule(rule, stats);
        break;
      case RuleType.timeBlock:
        await _checkTimeBlockRule(rule);
        break;
      case RuleType.appSingle:
        // TODO: 单个应用限制
        break;
    }
  }

  /// 检查总时间规则（只针对被监控应用）
  Future<void> _checkTotalTimeRule(Rule rule, DailyStats stats) async {
    final limitMinutes = rule.getLimitForDate(DateTime.now());
    print('[UsageMonitor] _checkTotalTimeRule: limitMinutes=$limitMinutes, rule.enabled=${rule.enabled}');
    if (limitMinutes == null) return;

    // 获取被监控应用的包名列表
    final monitoredApps = _ref.read(monitoredAppsProvider);
    final monitoredPackageNames = monitoredApps.monitoredPackageNames;
    print('[UsageMonitor] monitoredPackageNames: $monitoredPackageNames');

    if (monitoredPackageNames.isEmpty) {
      // 没有监控任何应用，不需要检查总时间限制
      print('[UsageMonitor] 没有监控任何应用，跳过总时间检查');
      return;
    }

    // 计算被监控应用的今日总使用时间
    final today = DailyStats.formatDate(DateTime.now());
    final monitoredUsedSeconds = await _appUsageDao.getTotalDurationByPackageNamesAndDate(
      monitoredPackageNames,
      today,
    );

    final limitSeconds = limitMinutes * 60;
    final remainingSeconds = limitSeconds - monitoredUsedSeconds;

    // 提前5分钟提醒
    if (remainingSeconds <= 300 && remainingSeconds > 0) {
      print('提醒：监控应用剩余 ${remainingSeconds ~/ 60} 分钟');
    }

    // 时间到 - 设置锁定状态（不直接显示锁定界面，由 _checkForbiddenApp 处理）
    if (remainingSeconds <= 0 && !_totalTimeLocked) {
      _totalTimeLocked = true;
      print('[UsageMonitor] 监控应用总时间已用完，标记为锁定状态');
    }
  }

  /// 检查分类规则
  Future<void> _checkCategoryRule(Rule rule, DailyStats stats) async {
    final limitMinutes = rule.getLimitForDate(DateTime.now());
    if (limitMinutes == null) return;

    final category = rule.target ?? '';
    int usedSeconds;

    switch (category) {
      case 'game':
        usedSeconds = stats.gameDurationSeconds;
        break;
      case 'video':
        usedSeconds = stats.videoDurationSeconds;
        break;
      default:
        return;
    }

    final limitSeconds = limitMinutes * 60;
    final remainingSeconds = limitSeconds - usedSeconds;

    // 时间到 - 设置锁定状态（不直接显示锁定界面，由 _checkForbiddenApp 处理）
    if (remainingSeconds <= 0 && !_categoryLocked) {
      _categoryLocked = true;
      final categoryLabel = category == 'game' ? '游戏' : '视频';
      print('[UsageMonitor] $categoryLabel 类别时间已用完，标记为锁定状态');
    }
  }

  /// 检查禁止时段规则
  Future<void> _checkTimeBlockRule(Rule rule) async {
    if (rule.timeStart == null || rule.timeEnd == null) return;

    final now = DateTime.now();
    final currentTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final start = rule.timeStart!;
    final end = rule.timeEnd!;

    bool isBlocked = false;

    // 处理跨天情况
    if (start.compareTo(end) > 0) {
      // 跨天（如 21:00-07:00）
      isBlocked = currentTime.compareTo(start) >= 0 || currentTime.compareTo(end) < 0;
    } else {
      // 同一天
      isBlocked = currentTime.compareTo(start) >= 0 && currentTime.compareTo(end) < 0;
    }

    // 检查是否只针对工作日
    if (isBlocked && rule.target == 'weekday') {
      final weekday = now.weekday;
      if (weekday == DateTime.saturday || weekday == DateTime.sunday) {
        isBlocked = false;
      }
    }

    if (isBlocked && _lastForegroundApp != null) {
      // 触发禁止时段锁定
      print('[UsageMonitor] 禁止时段检测到！阻止应用: $_lastForegroundApp');
      await _reminderService.showForbiddenTimeReminder('$start - $end');
    } else {
      // 如果不在禁用时段，尝试隐藏锁定界面
      await _reminderService.hideReminder();
    }
  }

  /// 检查禁用app
  Future<void> _checkForbiddenApp(String packageName) async {
    // 使用RuleCheckerService检查app是否被禁用
    final result = await _ruleCheckerService.checkAppUsage(packageName);

    print('[UsageMonitor] _checkForbiddenApp: packageName=$packageName, allowed=${result.allowed}, remainingSeconds=${result.remainingSeconds}, reason=${result.reason}');

    if (!result.allowed) {
      // app被禁用，显示递进式提醒
      print('[UsageMonitor] 检测到禁用app: $packageName, 原因: ${result.reason}, 规则类型: ${result.ruleType}');
      await _reminderService.checkAndShowForbiddenReminder(
        packageName: packageName,
        reason: result.reason ?? '该应用当前不可使用',
        ruleType: result.ruleType,
      );
    } else if (result.remainingSeconds != null && result.remainingSeconds! <= 60) {
      // 剩余时间少于60秒，显示即将到时的提醒
      print('[UsageMonitor] app即将到时: $packageName, 剩余 ${result.remainingSeconds} 秒');
      await _reminderService.checkAndShowForbiddenReminder(
        packageName: packageName,
        reason: result.reason ?? '即将到达时间限制',
        ruleType: result.ruleType ?? 'total_time_limit_warning',
      );
    } else if (result.ruleType == 'continuous_usage') {
      // 连续使用警告状态（allowed=true 但是连续使用警告），不隐藏弹窗
      // 弹窗由 _checkContinuousUsageAlerts 处理
      print('[UsageMonitor] 连续使用警告状态，保留弹窗');
    } else {
      // app被允许使用且剩余时间充足，隐藏提醒（用户切换到了非受限应用或时间充足）
      print('[UsageMonitor] app被允许使用: $packageName，隐藏提醒');
      await _reminderService.hideReminder();
    }
  }

  /// 检查连续使用提醒（5分钟/3分钟/2分钟警告）
  Future<void> _checkContinuousUsageAlerts(String currentApp) async {
    // 如果倒计时悬浮窗已经在显示，不再重复触发提醒
    if (_countdownWidgetShowing) {
      return;
    }

    final alertType = await _continuousUsageService.getAlertToShow();
    if (alertType == null) return;

    // 标记提醒已显示，避免重复
    await _continuousUsageService.markAlertShown(alertType);

    // 只处理 5 分钟警告，显示倒计时悬浮窗
    // 3 分钟、2 分钟警告被倒计时悬浮窗取代
    if (alertType == '5min') {
      final message = '连续使用即将达到限制，还剩 5 分钟，记得休息哦！';
      final ruleType = 'continuous_usage_5min';

      // 5分钟警告时，显示倒计时悬浮窗
      _countdownWidgetShowing = true;
      await OverlayService.showCountdownWidget(
        totalSeconds: 5 * 60, // 5分钟倒计时
        onEnded: () {
          // 倒计时结束，触发强制休息
          print('[UsageMonitor] 倒计时悬浮窗结束，触发强制休息');
          _countdownWidgetShowing = false;
          _triggerForcedRestAfterCountdown(currentApp);
        },
        onAlert: (alertType) {
          // 3分钟或2分钟提醒
          _handleCountdownAlert(currentApp, alertType);
        },
      );

      // 显示初始提醒弹窗
      await _reminderService.checkAndShowForbiddenReminder(
        packageName: currentApp,
        reason: message,
        ruleType: ruleType,
      );

      print('[UsageMonitor] 已显示倒计时悬浮窗，5分钟');
    }
  }

  /// 处理倒计时过程中的提醒（3分钟、2分钟）
  void _handleCountdownAlert(String currentApp, String alertType) {
    print('[UsageMonitor] 收到倒计时提醒: $alertType');

    String message;
    String ruleType;

    switch (alertType) {
      case '3min':
        message = '连续使用还剩 3 分钟，请准备休息~';
        ruleType = 'continuous_usage_3min';
        break;
      case '2min':
        message = '连续使用还剩 2 分钟！请尽快结束，纹纹要强制休息了哦！';
        ruleType = 'continuous_usage_2min';
        break;
      default:
        return;
    }

    // 显示提醒弹窗
    _reminderService.checkAndShowForbiddenReminder(
      packageName: currentApp,
      reason: message,
      ruleType: ruleType,
    );
  }

  /// 倒计时结束后触发强制休息
  Future<void> _triggerForcedRestAfterCountdown(String currentApp) async {
    // 触发强制休息
    final triggered = await _continuousUsageService.shouldTriggerRest();
    if (triggered) {
      final settings = _ref.read(continuousUsageSettingsProvider);

      await _reminderService.checkAndShowForbiddenReminder(
        packageName: currentApp,
        reason: '连续使用时间已达限制，需要休息 ${settings.restMinutes} 分钟！',
        ruleType: 'continuous_usage_limit',
        durationSeconds: settings.restSeconds,
      );
      print('[UsageMonitor] 倒计时结束，已触发强制休息弹窗');
    }
  }

  /// 检查并触发强制休息
  /// 注意：如果倒计时悬浮窗正在显示，则跳过检查（由倒计时结束时触发）
  Future<void> _checkAndTriggerRest(String currentApp) async {
    // 如果倒计时悬浮窗正在显示，强制休息由倒计时结束回调触发
    if (_countdownWidgetShowing) {
      return;
    }

    if (await _continuousUsageService.shouldTriggerRest()) {
      // shouldTriggerRest 内部已调用 _triggerRest()

      // 隐藏倒计时悬浮窗（如果有的话）
      await OverlayService.hideCountdownWidget();
      _countdownWidgetShowing = false;
      print('[UsageMonitor] 隐藏倒计时悬浮窗');

      final settings = _ref.read(continuousUsageSettingsProvider);

      await _reminderService.checkAndShowForbiddenReminder(
        packageName: currentApp,
        reason: '连续使用时间已达限制，需要休息 ${settings.restMinutes} 分钟！',
        ruleType: 'continuous_usage_limit',
        durationSeconds: settings.restSeconds, // 传递休息时长（秒）
      );
      print('[UsageMonitor] 触发强制休息');
    }
  }

  /// 是否正在监控
  bool get isMonitoring => _isMonitoring;
}

/// 使用监控服务 Provider
final usageMonitorServiceProvider = Provider<UsageMonitorService>((ref) {
  final db = AppDatabase.instance;
  final reminderService = ref.watch(reminderServiceProvider);
  final ruleCheckerService = ref.watch(ruleCheckerServiceProvider);
  final continuousUsageService = ref.watch(continuousUsageServiceProvider);
  return UsageMonitorService(
    db,
    reminderService,
    ruleCheckerService,
    continuousUsageService,
    ref,
  );
});
