import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/database/daos/daos.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';
import 'package:qiaoqiao_companion/core/platform/overlay_service.dart';
import 'package:qiaoqiao_companion/core/platform/usage_stats_service.dart';
import 'package:qiaoqiao_companion/core/services/continuous_usage_service.dart';
import 'package:qiaoqiao_companion/core/services/overlay_state_manager.dart';
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
  final OverlayStateManager _overlayManager;
  final AppUsageDao _appUsageDao;
  final DailyStatsDao _dailyStatsDao;
  final RuleDao _ruleDao;
  final AppCategoryDao _appCategoryDao;
  final HourlyUsageDao _hourlyUsageDao;
  final Ref _ref;

  Timer? _monitorTimer;
  Timer? _fullSyncTimer;
  String? _lastForegroundApp;
  bool _isMonitoring = false;
  bool _syncInProgress = false;

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
  bool _countdownEnding = false; // 倒计时结束处理中标志（防止轮询重复触发）
  bool _forceRestInProgress = false; // 强制休息处理中标志（防止轮询干扰）
  String? _countdownTriggerApp; // 触发倒计时的应用

  // === 秒表悬浮窗状态 ===
  bool _stopwatchWidgetShowing = false;
  DateTime? _lastStopTime; // 上次停止使用监控应用的时间

  /// 监控间隔（秒）- 从系统同步数据的间隔
  static const int monitorIntervalSeconds = 30;

  UsageMonitorService(
    this._database,
    this._reminderService,
    this._ruleCheckerService,
    this._continuousUsageService,
    this._overlayManager,
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
    // 轻量轮询定时器（30秒）：前台应用检测 + 连续使用跟踪 + 规则检查
    _monitorTimer = Timer.periodic(
      const Duration(seconds: monitorIntervalSeconds),
      (_) => _syncAndCheck(),
    );
    // 全量同步定时器（5分钟）：从系统同步完整数据 + 更新 Provider
    _fullSyncTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => refreshTodayUsage(),
    );

    // 立即执行一次轻量轮询
    _syncAndCheck();
    // 立即执行一次全量同步
    refreshTodayUsage();
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
    _fullSyncTimer?.cancel();
    _fullSyncTimer = null;
    _isMonitoring = false;
    _currentSessionApp = null;
    _isSessionActive = false;
    _countdownWidgetShowing = false;
    _countdownEnding = false;
    _forceRestInProgress = false;
    _countdownTriggerApp = null;
    _stopwatchWidgetShowing = false;
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
    final settings = _ref.read(continuousUsageSettingsProvider);

    // 计算上次轮询以来的时间
    final elapsedSeconds = _lastPollTime != null
        ? now.difference(_lastPollTime!).inSeconds
        : 0;

    // 验证时间合理性（防止大跳跃）
    final validElapsed = (elapsedSeconds > 0 && elapsedSeconds <= monitorIntervalSeconds * 3)
        ? elapsedSeconds
        : 0;

    // 检查是否处于强制休息中（休息期间不累加时间，但仍允许显示 widget）
    final status = await _continuousUsageService.getStatus();
    final inRest = status == ContinuousUsageStatus.inRest;

    // Step 1: 只有在会话活跃、监控应用在前台且不在休息中时才累加时间
    if (!inRest && _isSessionActive && _currentSessionApp != null && validElapsed > 0) {
      await _continuousUsageService.onAppStopped(_currentSessionApp!, validElapsed);
      print('[UsageMonitor] Accumulated ${validElapsed}s for $_currentSessionApp');
    }

    // Step 2: 判断当前应用是否需要跟踪
    // 关键：去掉 inRest 限制 —— 休息期间也要让 widget 显示（显示休息倒计时），
    // 否则用户在休息期间划掉进程后重新打开受限 app 时，widget 永远不会出现。
    // 累加时间的保护在 Step 1 中，与 widget 显示解耦。
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

      // 如果 session 状态是 atLimit，跳过 widget 显示（强制休息流程会处理）
      if (status == ContinuousUsageStatus.atLimit && !inRest) {
        print('[UsageMonitor] Session atLimit, skip stopwatch widget (waiting for forced rest)');
      } else {
        await _showStopwatchWidget(inRest: inRest);
      }

      // 重置停止时间
      _lastStopTime = null;
    } else {
      // 离开监控应用（息屏或切换到非监控app）
      // 立即隐藏倒计时 widget（用户不在使用监控 app 时不应显示悬浮窗）
      if (_countdownWidgetShowing || _stopwatchWidgetShowing) {
        await _hideStopwatchWidget();
        print('[UsageMonitor] 离开监控应用，立即隐藏倒计时 widget');
      }

      // 关键：不重置 _currentSessionApp，保留它用于5分钟内恢复
      // 只设置 _isSessionActive = false，停止累加时间
      if (_isSessionActive) {
        print('[UsageMonitor] Session paused (not tracking), currentApp: $currentApp');
        _lastStopTime = now;
      }
      _isSessionActive = false;

      // 检查是否需要因长时间休息而重置会话
      await _checkHideStopwatchAfterRest(now, settings);
    }
  }

  /// 显示秒表悬浮窗（倒计时模式）
  ///
  /// [inRest] 为 true 时显示「休息倒计时」（距休息结束），不触发二次锁定；
  /// 为 false 时显示「使用倒计时」（距使用限制），结束后触发强制休息。
  Future<void> _showStopwatchWidget({bool inRest = false}) async {
    // 如果倒计时已经在显示或强制休息处理中，不显示新的
    if (_countdownWidgetShowing || _stopwatchWidgetShowing || _forceRestInProgress) {
      print('[Diag] [W] skip: cd=$_countdownWidgetShowing sw=$_stopwatchWidgetShowing fr=$_forceRestInProgress');
      return;
    }

    // 锁定弹窗正在显示时，不显示右上角 widget
    // 弹窗关闭后 _forceRestInProgress 复位，widget 方能出现
    if (_overlayManager.state == OverlayState.showingLock ||
        _overlayManager.state == OverlayState.showingReminder) {
      print('[Diag] [W] skip: overlay active (state=${_overlayManager.state})');
      return;
    }

    final settings = _ref.read(continuousUsageSettingsProvider);
    if (!settings.enabled) {
      print('[Diag] [W] skip: settings.enabled=false');
      return;
    }

    // 只有当前台 app 是被监控 app 时才显示 widget
    final currentApp = await UsageStatsService.getCurrentForegroundApp();
    final monitoredApps = _ref.read(monitoredAppsProvider);
    final isMonitored = currentApp != null && monitoredApps.isMonitored(currentApp);
    if (!isMonitored) {
      print('[Diag] [W] skip: currentApp=$currentApp, monitored=${monitoredApps.monitoredPackageNames.length} apps');
      return;
    }

    if (inRest) {
      // 休息期间：显示休息倒计时，不创建/更新 session（避免污染累加时长）
      final restRemaining = await _continuousUsageService.getRemainingRestSeconds();
      if (restRemaining == null || restRemaining <= 0) {
        print('[Diag] [W] skip rest: restRemaining=$restRemaining');
        return;
      }
      print('[UsageMonitor] inRest: 显示休息倒计时 ${restRemaining}s');
      await _showCountdownFromRemaining(
        remainingSeconds: restRemaining,
        isRestCountdown: true,
      );
      return;
    }

    final session = await _continuousUsageService.getActiveSession();
    if (session == null) {
      print('[Diag] [W] skip: session=null for $currentApp');
      return;
    }

    // 计算剩余时间
    final limitSeconds = settings.limitMinutes * 60;
    final remainingSeconds = limitSeconds - session.totalDurationSeconds;

    if (remainingSeconds <= 0) {
      print('[Diag] [W] skip: remaining=${remainingSeconds}s <= 0 (total=${session.totalDurationSeconds}s)');
      return;
    }

    // 始终显示倒计时，从剩余时间开始
    await _showCountdownFromRemaining(
      remainingSeconds: remainingSeconds.toInt(),
      isRestCountdown: false,
    );
  }

  /// 从剩余时间开始显示倒计时
  ///
  /// [isRestCountdown] 为 true 时显示休息倒计时（不锁定、不持久化到 session 的倒计时字段）；
  /// 为 false 时显示使用倒计时（结束后触发强制休息，并持久化到 session 供原生侧按挂钟恢复）。
  Future<void> _showCountdownFromRemaining({
    required int remainingSeconds,
    required bool isRestCountdown,
  }) async {
    if (_countdownWidgetShowing || _stopwatchWidgetShowing) {
      print('[UsageMonitor] _showCountdownFromRemaining - widget already showing, skip');
      return;
    }

    _countdownWidgetShowing = true;
    _stopwatchWidgetShowing = false;
    _countdownTriggerApp = _currentSessionApp;
    final settings = _ref.read(continuousUsageSettingsProvider);

    final String lockTitle;
    final String lockMessage;
    final int lockDurationSeconds;
    final String? lockPackageName;

    if (isRestCountdown) {
      lockTitle = '';
      lockMessage = '';
      lockDurationSeconds = 0;
      lockPackageName = null;
    } else {
      lockTitle = '时间结束';
      lockMessage = '连续使用时间已达限制';
      lockDurationSeconds = settings.restSeconds;
      lockPackageName = _countdownTriggerApp ?? _currentSessionApp;
    }

    print('[UsageMonitor] _showCountdownFromRemaining - showing countdown from: ${remainingSeconds}s '
        '(isRestCountdown=$isRestCountdown)');

    print('[Diag] [C] 准备显示 widget: ${remainingSeconds}s, isRest=$isRestCountdown');

    try {
      await OverlayService.showCountdownWidget(
        totalSeconds: remainingSeconds,
        onEnded: () {
          unawaited(_handleCountdownEnded());
        },
        onAlert: (alertType) {
          if (isRestCountdown) return; // 休息期间不触发 3min/2min 告警
          print('[UsageMonitor] Countdown alert: $alertType');
          final targetApp = _countdownTriggerApp ?? _currentSessionApp;
          if (targetApp != null) {
            _handleCountdownAlert(targetApp, alertType);
          }
        },
        lockTitle: lockTitle,
        lockMessage: lockMessage,
        lockDurationSeconds: lockDurationSeconds,
        lockPackageName: lockPackageName,
      );
      print('[Diag] [C] widget 调用成功, 应该在屏幕上看到');
    } catch (e, st) {
      print('[Diag] [C] widget 调用失败: $e');
      print('[UsageMonitor] showCountdownWidget failed: $e\n$st');
      _countdownWidgetShowing = false;
      _stopwatchWidgetShowing = false;
    }

    // 仅使用倒计时需要持久化状态，让原生侧在进程被杀后按挂钟恢复
    if (!isRestCountdown) {
      await _persistCountdownState(remainingSeconds);
    }
  }

  Future<void> _handleCountdownEnded([String? fallbackApp]) async {
    if (_countdownEnding) {
      print('[UsageMonitor] Countdown already ending, skip');
      return;
    }
    _countdownEnding = true;
    try {
      print('[UsageMonitor] Countdown ended!');
      final targetApp = _countdownTriggerApp ?? _currentSessionApp ?? fallbackApp;
      _stopwatchWidgetShowing = false;
      _countdownWidgetShowing = false;
      _countdownTriggerApp = null;
      _overlayManager.onCountdownEnded();
      await OverlayService.hideCountdownWidget();
      await _clearCountdownState();

      // 去重：如果原生兜底路径已经显示了锁定弹窗，不再重复创建
      if (await OverlayService.isOverlayShowing()) {
        print('[UsageMonitor] Native fallback already showed lock overlay, skip Flutter path');
        return;
      }

      if (targetApp != null) {
        await _triggerForcedRestAfterCountdown(targetApp);
      }
    } finally {
      _countdownEnding = false;
    }
  }

  /// 锁定弹窗关闭后的回调
  ///
  /// 当用户手动关闭锁定弹窗后：
  /// 1. 复位 _forceRestInProgress 标志
  /// 2. 重新设置休息结束时间（从关闭时刻开始计算完整休息时长）
  /// 3. 显示休息倒计时 widget
  Future<void> _onLockOverlayDismissed() async {
    print('[UsageMonitor] Lock overlay dismissed by user');
    // 清除全局回调，避免下次误触发
    OverlayService.setOnGlobalOverlayDismissed(() {});

    // === 关键逻辑 ===
    // Lock overlay 的倒计时 = restMinutes（用户已经在 lock overlay 上等了完整的休息时间），
    // 所以用户点击"知道了"时，休息时间已过。此时不应再显示休息倒计时 widget，
    // 而应停用旧会话，让新的使用计时从 0 开始。
    //
    // 1. 先停用旧会话（休息已结束），让下次 onAppStarted 创建新会话从 0 开始
    //    在 _forceRestInProgress = true 期间操作，防止轮询干扰
    await _continuousUsageService.deactivateActiveSession();
    print('[UsageMonitor] Session deactivated after lock dismiss, fresh start');

    // 2. 重置跟踪状态，让下个轮询周期创建新会话
    _currentSessionApp = null;
    _isSessionActive = false;
    _lastStopTime = null;

    // 3. 复位标志，让轮询可以正常工作
    _forceRestInProgress = false;

    // 4. 检查当前前台应用是否是被监控的应用，如果是，立即显示使用倒计时
    final currentApp = await UsageStatsService.getCurrentForegroundApp();
    final monitoredApps = _ref.read(monitoredAppsProvider);
    if (currentApp != null && monitoredApps.isMonitored(currentApp)) {
      // 创建新会话并显示使用倒计时
      // 先设置 _currentSessionApp，防止轮询重复创建会话
      _currentSessionApp = currentApp;
      _isSessionActive = true;
      await _continuousUsageService.onAppStarted(currentApp);
      print('[UsageMonitor] Lock dismissed, showing fresh usage countdown for $currentApp');
      await _showStopwatchWidget(inRest: false);
    }
  }

  /// 检查是否在休息后隐藏计时器
  Future<void> _checkHideStopwatchAfterRest(DateTime now, ContinuousUsageSettings settings) async {
    if (_lastStopTime == null) {
      return;
    }

    // 计算从停止到现在的时间
    final restDuration = now.difference(_lastStopTime!);
    final resetAfterRestSeconds = settings.resetAfterRestSeconds;

    // 如果休息时间超过设定的阈值，隐藏计时器并重置会话
    if (restDuration.inSeconds >= resetAfterRestSeconds) {
      print('[UsageMonitor] Rest duration exceeded threshold, hiding stopwatch and resetting session');
      
      // 隐藏计时器
      await _hideStopwatchWidget();
      
      // 重置连续使用会话
      await _resetContinuousSession();
      
      // 清除停止时间
      _lastStopTime = null;
    }
  }

  /// 隐藏秒表悬浮窗
  Future<void> _hideStopwatchWidget() async {
    if (_stopwatchWidgetShowing || _countdownWidgetShowing) {
      await OverlayService.hideCountdownWidget();
      _stopwatchWidgetShowing = false;
      _countdownWidgetShowing = false;
      _countdownTriggerApp = null;
      _countdownEnding = false;
      await _clearCountdownState();
    }
  }

  /// 重置连续使用会话
  Future<void> _resetContinuousSession() async {
    final session = await _continuousUsageService.getActiveSession();
    if (session != null) {
      // 停用当前会话
      await _continuousUsageService.restoreSession(); // 这会停用超过阈值的会话
      print('[UsageMonitor] Continuous session reset after rest period');
    }
  }

  /// 把当前倒计时状态写入活跃会话（countdown_started_at / countdown_total_seconds）。
  /// 必须在 OverlayService.showCountdownWidget 之后调用。
  /// 原生侧在服务重启后会读取这两列，按挂钟恢复倒计时。
  Future<void> _persistCountdownState(int remainingSeconds) async {
    try {
      final session = await _continuousUsageService.getActiveSession();
      if (session == null) return;
      await _continuousUsageService.updateSession(session.copyWith(
        countdownStartedAt: DateTime.now().millisecondsSinceEpoch,
        countdownTotalSeconds: remainingSeconds,
        updatedAt: DateTime.now(),
      ));
    } catch (e, st) {
      print('[UsageMonitor] _persistCountdownState failed: $e\n$st');
    }
  }

  /// 清空活跃会话的倒计时字段（倒计时结束/隐藏/重置时调用）。
  Future<void> _clearCountdownState() async {
    try {
      final session = await _continuousUsageService.getActiveSession();
      if (session == null) return;
      if (session.countdownStartedAt == null && session.countdownTotalSeconds == null) {
        return;
      }
      await _continuousUsageService.updateSession(session.copyWith(
        clearCountdown: true,
        updatedAt: DateTime.now(),
      ));
    } catch (e, st) {
      print('[UsageMonitor] _clearCountdownState failed: $e\n$st');
    }
  }

  /// 切换到倒计时模式
  Future<void> _switchToCountdownMode(int remainingSeconds) async {
    if (_countdownWidgetShowing) return;

    _countdownWidgetShowing = true;
    _stopwatchWidgetShowing = false;
    _countdownTriggerApp = _currentSessionApp;
    final settings = _ref.read(continuousUsageSettingsProvider);
    final lockApp = _countdownTriggerApp ?? _currentSessionApp;

    await OverlayService.hideCountdownWidget();

    await OverlayService.showCountdownWidget(
      totalSeconds: remainingSeconds,
      onEnded: () {
        unawaited(_handleCountdownEnded());
      },
      onAlert: (alertType) {
        final targetApp = _countdownTriggerApp ?? _currentSessionApp;
        if (targetApp != null) {
          _handleCountdownAlert(targetApp, alertType);
        }
      },
      lockTitle: '时间结束',
      lockMessage: '连续使用时间已达限制',
      lockDurationSeconds: settings.restSeconds,
      lockPackageName: lockApp,
    );

    // 持久化倒计时状态，让原生侧在进程被杀后能按挂钟恢复
    await _persistCountdownState(remainingSeconds);

    print('[UsageMonitor] Switched to countdown mode, remaining: ${remainingSeconds}s');
  }

  /// 同步系统统计数据并检查规则
  Future<void> _syncAndCheck() async {
    if (_syncInProgress) return;
    _syncInProgress = true;
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

      // === 检查休息是否已结束（结束后停用旧会话，让新会话从0开始）===
      // 关键：当 _forceRestInProgress = true 时，跳过 checkRestEnded()！
      // 原因：lock overlay 显示期间，restEndTime 可能已经过期（因为 lock overlay 的
      // 倒计时与 restEndTime 大致同时到期），如果此时 checkRestEnded() 停用会话，
      // 用户点击"知道了"后 _onLockOverlayDismissed 会因 getActiveSession()=null
      // 而提前 return，导致休息倒计时 widget 无法显示。
      if (!_forceRestInProgress) {
        await _continuousUsageService.checkRestEnded();
      }

      // 如果会话被停用，重置跟踪状态（让接下来的 onAppStarted 创建新会话）
      final activeSession = await _continuousUsageService.getActiveSession();
      if (activeSession == null) {
        _currentSessionApp = null;
        _isSessionActive = false;
      }

      // === 处理连续使用跟踪 ===
      await _handleContinuousUsageTransition(currentApp, now);

      // 更新状态
      if (currentApp != null) {
        _lastForegroundApp = currentApp;
      }
      _lastPollTime = now;

      // 2. 轻量轮询不刷新今日使用数据的 Provider（减少 widget 重建频率）
      // Provider 刷新由 5 分钟全量同步定时器 refreshTodayUsage() 负责
      // TodayUsageNotifier 自身也有 30 秒自动刷新机制，无需在此重复调用

      // 3. 检查规则
      await _checkRules();

      // 4. 检查禁用应用
      if (currentApp != null) {
        await _checkForbiddenApp(currentApp);
      }

      // 5. 检查连续使用提醒和强制休息
      if (currentApp != null) {
        await _checkContinuousUsageAlerts(currentApp);
        await _checkAndTriggerRest(currentApp);
      }

    } catch (e, stackTrace) {
      print('[UsageMonitor] Error in _syncAndCheck: $e');
      print('[UsageMonitor] Stack trace: $stackTrace');
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
    print('[UsageMonitor] Synced $syncedCount app records for $date');
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


    // 批量插入新数据
    await _hourlyUsageDao.upsertBatch(statsList);

    print('[UsageMonitor] Synced ${statsList.length} hourly usage records');
  }

  /// 获取应用分类
  Future<AppCategory> _getAppCategory(String packageName) async {
    final record = await _appCategoryDao.getByPackageName(packageName);
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
      // 如果不在禁用时段，且没有锁定弹窗显示，才隐藏提醒
      // 避免关闭由其他规则（如连续使用强制休息）触发的锁定弹窗
      if (_overlayManager.state != OverlayState.showingLock && !_forceRestInProgress) {
        await _reminderService.hideReminderUnlessLock();
      }
    }
  }

  /// 检查禁用app
  Future<void> _checkForbiddenApp(String packageName) async {
    // 强制休息中不重复弹窗（已在 _triggerForcedRestAfterCountdown 中显示 lock overlay）
    final restStatus = await _continuousUsageService.getStatus();
    if (restStatus == ContinuousUsageStatus.inRest) {
      print('[UsageMonitor] 强制休息中，跳过 _checkForbiddenApp 弹窗');
      return;
    }

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
    } else if (_forceRestInProgress) {
      // 强制休息处理中，不干扰由 _triggerForcedRestAfterCountdown 显示的弹窗
      print('[UsageMonitor] 强制休息处理中，保留弹窗');
    } else if (_overlayManager.state == OverlayState.showingLock) {
      // 锁定弹窗正在显示中，不应被 hideReminder 关闭
      print('[UsageMonitor] Lock overlay active, skip hideReminder');
    } else {
      // app被允许使用且剩余时间充足，隐藏提醒（用户切换到了非受限应用或时间充足）
      print('[UsageMonitor] app被允许使用: $packageName，隐藏提醒');
      await _reminderService.hideReminderUnlessLock();
    }
  }

  /// 检查连续使用提醒（5分钟/3分钟/2分钟警告）
  Future<void> _checkContinuousUsageAlerts(String currentApp) async {
    // 本应用不触发连续使用提醒
    if (currentApp == 'com.qiaoqiao.qiaoqiao_companion') {
      return;
    }

    // 如果倒计时悬浮窗已经在显示、正在结束或强制休息处理中，不再重复触发提醒
    if (_countdownWidgetShowing || _countdownEnding || _forceRestInProgress) {
      return;
    }

    final alertType = await _continuousUsageService.getAlertToShow();
    if (alertType == null) return;

    // 标记提醒已显示，避免重复
    await _continuousUsageService.markAlertShown(alertType);

    if (alertType == '5min') {
      final settings = _ref.read(continuousUsageSettingsProvider);
      final session = await _continuousUsageService.getActiveSession();
      final limitSeconds = settings.limitMinutes * 60;
      final currentRemaining = limitSeconds - (session?.totalDurationSeconds ?? 0);
      final countdownSeconds = currentRemaining.clamp(0, 5 * 60).toInt();

      _countdownWidgetShowing = true;
      _stopwatchWidgetShowing = false;
      _countdownTriggerApp = currentApp;
      await OverlayService.showCountdownWidget(
        totalSeconds: countdownSeconds,
        onEnded: () {
          print('[UsageMonitor] 倒计时悬浮窗结束，触发强制休息');
          unawaited(_handleCountdownEnded(currentApp));
        },
        onAlert: (alertType) {
          _handleCountdownAlert(currentApp, alertType);
        },
        lockTitle: '时间结束',
        lockMessage: '连续使用时间已达限制',
        lockDurationSeconds: settings.restSeconds,
        lockPackageName: currentApp,
      );

      // 持久化倒计时状态，让原生侧在进程被杀后能按挂钟恢复
      await _persistCountdownState(countdownSeconds);

      print('[UsageMonitor] 已显示倒计时悬浮窗，${countdownSeconds ~/ 60}分钟');
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
    _forceRestInProgress = true;
    try {
      final settings = _ref.read(continuousUsageSettingsProvider);

      await OverlayService.hideCountdownWidget();
      _countdownWidgetShowing = false;
      _stopwatchWidgetShowing = false;
      _countdownTriggerApp = null;

      await _continuousUsageService.forceTriggerRest(
        minTotalDurationSeconds: settings.limitMinutes * 60,
      );

      // 用户关闭锁定弹窗后，立即显示休息倒计时 widget
      // 同时在回调中重新设置 restEndTime（从关闭时刻计算完整休息时长）
      OverlayService.setOnGlobalOverlayDismissed(() {
        unawaited(_onLockOverlayDismissed());
      });

      await _reminderService.checkAndShowForbiddenReminder(
        packageName: currentApp,
        reason: '连续使用时间已达限制，需要休息 ${settings.restMinutes} 分钟！',
        ruleType: 'continuous_usage_limit',
        durationSeconds: settings.restSeconds,
      );
      print('[UsageMonitor] 倒计时结束，已触发强制休息弹窗');
    } catch (e, st) {
      print('[UsageMonitor] _triggerForcedRestAfterCountdown failed: $e\n$st');
      _forceRestInProgress = false;
    }
    // 注意：不在 finally 中复位 _forceRestInProgress
    // 改为在 _onLockOverlayDismissed 中复位，确保锁定弹窗显示期间不会被轮询干扰
  }

  /// 检查并触发强制休息
  /// 注意：如果倒计时悬浮窗正在显示，强制休息由倒计时结束回调触发
  Future<void> _checkAndTriggerRest(String currentApp) async {
    // 如果倒计时悬浮窗正在显示或强制休息处理中，跳过（由倒计时结束回调触发）
    if (_countdownWidgetShowing || _countdownEnding || _forceRestInProgress) {
      return;
    }

    if (await _continuousUsageService.shouldTriggerRest()) {
      // shouldTriggerRest 内部已调用 _triggerRest()

      // 隐藏倒计时悬浮窗（如果有的话）
      await OverlayService.hideCountdownWidget();
      _countdownWidgetShowing = false;
      _countdownEnding = false;
      _stopwatchWidgetShowing = false;
      _countdownTriggerApp = null;
      await _clearCountdownState();
      print('[UsageMonitor] 隐藏倒计时悬浮窗');

      _forceRestInProgress = true;
      try {
        final settings = _ref.read(continuousUsageSettingsProvider);

        // 用户关闭锁定弹窗后，立即显示休息倒计时 widget
        OverlayService.setOnGlobalOverlayDismissed(() {
          unawaited(_onLockOverlayDismissed());
        });

        await _reminderService.checkAndShowForbiddenReminder(
          packageName: currentApp,
          reason: '连续使用时间已达限制，需要休息 ${settings.restMinutes} 分钟！',
          ruleType: 'continuous_usage_limit',
          durationSeconds: settings.restSeconds,
        );
        print('[UsageMonitor] 触发强制休息');
      } catch (e, st) {
        print('[UsageMonitor] _checkAndTriggerRest failed: $e\n$st');
        _forceRestInProgress = false;
      }
      // 注意：不在 finally 中复位 _forceRestInProgress
      // 改为在 _onLockOverlayDismissed 中复位
    }
  }

  Future<void> refreshTodayUsage() async {
    await _syncTodayUsageFromSystem();
    await _ref.read(todayUsageProvider.notifier).loadToday();
    // 轻量刷新：使用 invalidate 仅在必要时触发（如页面正在显示时）
    // 不再每5分钟强制 invalidate 所有 Provider，避免页面闪烁和卡顿
    // hourly 和 filtered provider 有自身独立的刷新机制
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
  final overlayManager = ref.watch(overlayStateManagerProvider);
  return UsageMonitorService(
    db,
    reminderService,
    ruleCheckerService,
    continuousUsageService,
    overlayManager,
    ref,
  );
});
