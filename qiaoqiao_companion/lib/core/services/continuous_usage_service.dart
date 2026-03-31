import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/database/daos/continuous_session_dao.dart';
import 'package:qiaoqiao_companion/shared/models/models.dart';
import 'package:qiaoqiao_companion/shared/providers/continuous_usage_provider.dart';
import 'package:qiaoqiao_companion/shared/providers/monitored_apps_provider.dart';

/// 连续使用状态
enum ContinuousUsageStatus {
  normal, // 正常使用
  warning5min, // 5分钟警告
  warning3min, // 3分钟倒计时
  warning2min, // 2分钟警告
  atLimit, // 到达限制
  inRest, // 强制休息中
}

/// 连续使用监控服务
class ContinuousUsageService {
  final ContinuousSessionDao _sessionDao;
  final Ref _ref;

  static const _restoreThresholdMinutes = 5; // 恢复阈值：5分钟内切回算连续，超过5分钟重置

  ContinuousUsageService(this._sessionDao, this._ref);

  /// 获取当前日期字符串
  String _today() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  /// 获取当前状态
  Future<ContinuousUsageStatus> getStatus() async {
    final session = await _sessionDao.getActiveSession(_today());
    if (session == null) return ContinuousUsageStatus.normal;

    // 检查是否在休息中
    if (session.isInRest) return ContinuousUsageStatus.inRest;

    final settings = _ref.read(continuousUsageSettingsProvider);
    if (!settings.enabled) return ContinuousUsageStatus.normal;

    final limitSeconds = settings.limitMinutes * 60;
    final remainingSeconds = limitSeconds - session.totalDurationSeconds;

    if (remainingSeconds <= 0) return ContinuousUsageStatus.atLimit;
    if (remainingSeconds <= 2 * 60) return ContinuousUsageStatus.warning2min;
    if (remainingSeconds <= 3 * 60) return ContinuousUsageStatus.warning3min;
    if (remainingSeconds <= 5 * 60) return ContinuousUsageStatus.warning5min;

    return ContinuousUsageStatus.normal;
  }

  /// 记录 app 使用开始
  Future<void> onAppStarted(String packageName) async {
    final monitoredApps = _ref.read(monitoredAppsProvider);
    if (!monitoredApps.isMonitored(packageName)) return;

    var session = await _sessionDao.getActiveSession(_today());

    if (session == null) {
      // 创建新会话
      final now = DateTime.now();
      session = ContinuousSession(
        sessionDate: _today(),
        startTime: now,
        lastActivityTime: now,
        createdAt: now,
        updatedAt: now,
      );
      final id = await _sessionDao.insert(session);
      session = session.copyWith(id: id);
      print('[ContinuousUsage] Created new session, now tracking: $packageName');
    } else {
      // 更新活动时间
      session = session.copyWith(
        lastActivityTime: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _sessionDao.update(session);
      print('[ContinuousUsage] Started tracking: $packageName, session total: ${session.totalDurationSeconds}s');
    }
  }

  /// 记录 app 使用结束
  Future<void> onAppStopped(String packageName, int durationSeconds) async {
    final monitoredApps = _ref.read(monitoredAppsProvider);
    if (!monitoredApps.isMonitored(packageName)) return;

    final session = await _sessionDao.getActiveSession(_today());
    if (session == null) return;

    // 累加使用时间
    final updatedSession = session.copyWith(
      totalDurationSeconds: session.totalDurationSeconds + durationSeconds,
      lastActivityTime: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _sessionDao.update(updatedSession);
    print('[ContinuousUsage] Accumulated ${durationSeconds}s for $packageName, new total: ${updatedSession.totalDurationSeconds}s');
  }

  /// 检查是否需要触发强制休息
  Future<bool> shouldTriggerRest() async {
    final status = await getStatus();
    if (status == ContinuousUsageStatus.atLimit) {
      await _triggerRest();
      return true;
    }
    return false;
  }

  /// 触发强制休息
  Future<void> _triggerRest() async {
    final session = await _sessionDao.getActiveSession(_today());
    if (session == null) return;

    // 如果已经在休息中，不要重复设置休息时间
    if (session.isInRest) {
      print('[ContinuousUsage] Already in rest, skip setting restEndTime');
      return;
    }

    final settings = _ref.read(continuousUsageSettingsProvider);
    final restEndTime = DateTime.now().add(Duration(minutes: settings.restMinutes));

    final updatedSession = session.copyWith(
      restEndTime: restEndTime,
      updatedAt: DateTime.now(),
    );
    await _sessionDao.update(updatedSession);
    print('[ContinuousUsage] Rest triggered, restEndTime: $restEndTime');
  }

  /// 检查是否需要显示提醒
  Future<String?> getAlertToShow() async {
    final session = await _sessionDao.getActiveSession(_today());
    if (session == null) return null;

    final settings = _ref.read(continuousUsageSettingsProvider);
    if (!settings.enabled) return null;

    final limitSeconds = settings.limitMinutes * 60;
    final remainingSeconds = limitSeconds - session.totalDurationSeconds;

    // 按从宽松到紧急的顺序检查，确保不会跳过任何级别
    // 5分钟警告 - 必须先检查
    if (remainingSeconds <= 5 * 60 && !session.alertsShown.contains('5min')) {
      return '5min';
    }

    // 3分钟倒计时 - 在5分钟已显示后检查
    if (remainingSeconds <= 3 * 60 && !session.alertsShown.contains('3min')) {
      return '3min';
    }

    // 2分钟警告 - 在3分钟已显示后检查
    if (remainingSeconds <= 2 * 60 && !session.alertsShown.contains('2min')) {
      return '2min';
    }

    return null;
  }

  /// 标记提醒已显示
  Future<void> markAlertShown(String alertLevel) async {
    final session = await _sessionDao.getActiveSession(_today());
    if (session == null) return;

    final newAlerts = {...session.alertsShown, alertLevel};
    final updatedSession = session.copyWith(
      alertsShown: newAlerts,
      updatedAt: DateTime.now(),
    );
    await _sessionDao.update(updatedSession);
  }

  /// 恢复会话状态
  Future<void> restoreSession() async {
    final session = await _sessionDao.getActiveSession(_today());
    if (session == null) return;

    final lastActivity = session.lastActivityTime;
    if (lastActivity == null) return;

    final now = DateTime.now();
    final threshold = Duration(minutes: _restoreThresholdMinutes);
    final inactiveDuration = now.difference(lastActivity);

    print('[ContinuousUsage] Restore check: inactive=${inactiveDuration.inMinutes}min');

    // 超过阈值，停用会话
    if (inactiveDuration > threshold) {
      await _sessionDao.deactivate(session.id!);
      print('[ContinuousUsage] Session deactivated due to inactivity');
    }
  }

  /// 获取剩余休息时间（秒）
  Future<int?> getRemainingRestSeconds() async {
    final session = await _sessionDao.getRestingSession(_today());
    return session?.remainingRestSeconds;
  }
}

final continuousUsageServiceProvider = Provider<ContinuousUsageService>((ref) {
  final db = AppDatabase.instance;
  return ContinuousUsageService(ContinuousSessionDao(db), ref);
});
