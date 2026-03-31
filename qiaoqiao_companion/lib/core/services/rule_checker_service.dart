import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/database/daos/daos.dart';
import 'package:qiaoqiao_companion/core/services/continuous_usage_service.dart';
import 'package:qiaoqiao_companion/shared/models/models.dart';
import 'package:qiaoqiao_companion/shared/providers/continuous_usage_provider.dart';
import 'package:qiaoqiao_companion/shared/providers/monitored_apps_provider.dart';
import 'package:qiaoqiao_companion/shared/providers/time_periods_provider.dart';
import 'package:qiaoqiao_companion/shared/providers/rules_provider.dart';

/// 规则检查结果
class RuleCheckResult {
  final bool allowed;
  final String? reason;
  final int? remainingSeconds;
  final String? ruleType;

  const RuleCheckResult({
    required this.allowed,
    this.reason,
    this.remainingSeconds,
    this.ruleType,
  });

  factory RuleCheckResult.allowed() {
    return const RuleCheckResult(allowed: true);
  }

  factory RuleCheckResult.blocked({
    required String reason,
    String? ruleType,
  }) {
    return RuleCheckResult(
      allowed: false,
      reason: reason,
      ruleType: ruleType,
    );
  }

  factory RuleCheckResult.limited({
    required int remainingSeconds,
    required String reason,
    String? ruleType,
  }) {
    return RuleCheckResult(
      allowed: true,
      remainingSeconds: remainingSeconds,
      reason: reason,
      ruleType: ruleType,
    );
  }
}

/// 规则检查服务
///
/// 新规则检查优先级：
/// 1. 检查强制休息状态（优先级最高，影响所有应用）
/// 2. 检查是否在 monitored_apps 中 → 不在则无限制
/// 3. 检查时间段规则（blocked/allowed）
/// 4. 检查连续使用限制
/// 5. 检查单个 app 每日时间限制
class RuleCheckerService {
  final Ref _ref;
  final AppUsageDao _appUsageDao;

  RuleCheckerService(AppDatabase db, this._ref) : _appUsageDao = AppUsageDao(db);

  /// 检查应用是否可以使用
  ///
  /// 新规则检查优先级：
  /// 1. 检查强制休息状态（全局规则，影响所有应用）
  /// 2. 检查是否在 monitored_apps 中 → 不在则无限制
  /// 3. 检查时间段规则（只针对被监控应用）
  /// 4. 检查总时长限制（只针对被监控应用）
  /// 5. 检查连续使用限制
  /// 6. 检查单个 app 每日时间限制
  Future<RuleCheckResult> checkAppUsage(String packageName) async {
    // 1. 检查强制休息状态（全局规则，影响所有应用）
    final restResult = await _checkForcedRest();
    if (!restResult.allowed) {
      return restResult;
    }

    // 2. 检查是否在 monitored_apps 中
    final monitoredApps = _ref.read(monitoredAppsProvider);
    if (!monitoredApps.isMonitored(packageName)) {
      // 未配置的应用无限制（包括本应用本身）
      return RuleCheckResult.allowed();
    }

    // 3. 检查时间段规则（只针对被监控应用）
    final timePeriodResult = await _checkTimePeriods();
    if (!timePeriodResult.allowed) {
      return timePeriodResult;
    }

    // 4. 检查总时长限制（只针对被监控应用）
    final totalTimeResult = await _checkTotalTimeLimit(monitoredApps);
    if (!totalTimeResult.allowed) {
      return totalTimeResult;
    }

    // 5. 检查连续使用限制
    final continuousResult = await _checkContinuousUsage();
    if (!continuousResult.allowed) {
      return continuousResult;
    }

    // 6. 检查单个 app 每日时间限制
    final appLimitResult = await _checkAppDailyLimit(packageName, monitoredApps);
    if (!appLimitResult.allowed) {
      return appLimitResult;
    }

    // 返回最严格的限制（最小的剩余时间）
    final results = [totalTimeResult, continuousResult, appLimitResult]
        .where((r) => r.remainingSeconds != null)
        .toList();

    if (results.isNotEmpty) {
      results.sort((a, b) => a.remainingSeconds!.compareTo(b.remainingSeconds!));
      return results.first;
    }

    return RuleCheckResult.allowed();
  }

  /// 检查强制休息状态
  Future<RuleCheckResult> _checkForcedRest() async {
    final continuousService = _ref.read(continuousUsageServiceProvider);
    final status = await continuousService.getStatus();

    if (status == ContinuousUsageStatus.inRest) {
      final remainingSeconds = await continuousService.getRemainingRestSeconds();

      // 使用更友好的时间格式
      final timeText = _formatRestTime(remainingSeconds);
      return RuleCheckResult.blocked(
        reason: '正在休息中，还需要 $timeText',
        ruleType: 'forced_rest',
      );
    }

    return RuleCheckResult.allowed();
  }

  /// 格式化休息时间显示
  String _formatRestTime(int? remainingSeconds) {
    if (remainingSeconds == null || remainingSeconds <= 0) return '一会儿';
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    if (minutes > 0) {
      return seconds > 0 ? '$minutes 分 $seconds 秒' : '$minutes 分钟';
    }
    return '$seconds 秒';
  }

  /// 检查总时长限制（只针对被监控应用）
  Future<RuleCheckResult> _checkTotalTimeLimit(MonitoredAppsState monitoredApps) async {
    final rulesState = _ref.read(rulesProvider);
    final totalTimeRule = rulesState.totalTimeRule;

    print('[RuleChecker] _checkTotalTimeLimit: totalTimeRule=$totalTimeRule, enabled=${totalTimeRule?.enabled}');

    // 如果没有启用总时长限制，跳过
    if (totalTimeRule == null || !totalTimeRule.enabled) {
      print('[RuleChecker] 总时长限制未启用，跳过检查');
      return RuleCheckResult.allowed();
    }

    final limitMinutes = totalTimeRule.getLimitForDate(DateTime.now());
    print('[RuleChecker] limitMinutes=$limitMinutes');
    if (limitMinutes == null || limitMinutes <= 0) {
      print('[RuleChecker] 限额为空或为0，跳过检查');
      return RuleCheckResult.allowed();
    }

    // 获取被监控应用的包名列表
    final monitoredPackageNames = monitoredApps.monitoredPackageNames;
    print('[RuleChecker] monitoredPackageNames=$monitoredPackageNames');
    if (monitoredPackageNames.isEmpty) {
      print('[RuleChecker] 没有监控任何应用，跳过检查');
      return RuleCheckResult.allowed();
    }

    // 计算被监控应用的今日总使用时间
    final today = DailyStats.formatDate(DateTime.now());
    final usedSeconds = await _appUsageDao.getTotalDurationByPackageNamesAndDate(
      monitoredPackageNames,
      today,
    );

    final limitSeconds = limitMinutes * 60;
    final remainingSeconds = limitSeconds - usedSeconds;

    print('[RuleChecker] usedSeconds=$usedSeconds, limitSeconds=$limitSeconds, remainingSeconds=$remainingSeconds');

    if (remainingSeconds <= 0) {
      print('[RuleChecker] 总时长已达上限，返回 blocked');
      return RuleCheckResult.blocked(
        reason: '今日监控应用总时长已达上限',
        ruleType: 'total_time_limit',
      );
    }

    // 如果剩余时间少于60秒，也返回 blocked，触发锁定提醒
    if (remainingSeconds <= 60) {
      print('[RuleChecker] 总时长即将用完（剩余${remainingSeconds}秒），返回 blocked');
      return RuleCheckResult.blocked(
        reason: '监控应用总时长即将用完，剩余 ${(remainingSeconds / 60).ceil()} 分钟',
        ruleType: 'total_time_limit_urgent',
      );
    }

    print('[RuleChecker] 总时长剩余 ${remainingSeconds ~/ 60} 分钟');
    return RuleCheckResult.limited(
      remainingSeconds: remainingSeconds,
      reason: '监控应用总时长剩余 ${(remainingSeconds / 60).ceil()} 分钟',
      ruleType: 'total_time_limit',
    );
  }

  /// 检查时间段规则
  Future<RuleCheckResult> _checkTimePeriods() async {
    final periods = _ref.read(timePeriodsProvider);

    // 调试日志: 输出时间段状态
    print('[RuleChecker] ========== 开始检查时间段规则 =========');
    print('[RuleChecker] enabledPeriods 数量: ${periods.enabledPeriods.length}');
    for (final period in periods.enabledPeriods) {
      print('[RuleChecker] 时段: ${period.timeStart}-${period.timeEnd}, mode=${period.mode.code}, enabled=${period.enabled}, days=${period.days}');
    }

    final status = periods.getCurrentTimeBlockStatus(DateTime.now());

    print('[RuleChecker] 当前时间: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}');
    print('[RuleChecker] 当前星期: ${DateTime.now().weekday}');
    print('[RuleChecker] 检查结果: isBlocked=${status.isBlocked}, reason=${status.reason}');

    if (status.isBlocked) {
      return RuleCheckResult.blocked(
        reason: status.reason ?? '当前时段禁止使用',
        ruleType: 'time_period',
      );
    }

    return RuleCheckResult.allowed();
  }

  /// 检查连续使用限制
  Future<RuleCheckResult> _checkContinuousUsage() async {
    final continuousService = _ref.read(continuousUsageServiceProvider);
    final status = await continuousService.getStatus();

    // 如果在休息中，已经被 _checkForcedRest 拦截
    if (status == ContinuousUsageStatus.atLimit) {
      return RuleCheckResult.blocked(
        reason: '连续使用时间已达限制，请休息',
        ruleType: 'continuous_usage',
      );
    }

    // 对于 warning 状态，仍然允许使用但返回剩余时间
    if (status == ContinuousUsageStatus.warning2min ||
        status == ContinuousUsageStatus.warning5min) {
      final settings = _ref.read(continuousUsageSettingsProvider);
      if (settings.enabled) {
        return RuleCheckResult.limited(
          remainingSeconds: status == ContinuousUsageStatus.warning2min
              ? 2 * 60
              : 5 * 60,
          reason: '连续使用即将达到限制',
          ruleType: 'continuous_usage',
        );
      }
    }

    return RuleCheckResult.allowed();
  }

  /// 检查单个 app 每日时间限制
  Future<RuleCheckResult> _checkAppDailyLimit(
    String packageName,
    MonitoredAppsState monitoredApps,
  ) async {
    final limitMinutes = monitoredApps.getDailyLimit(packageName);
    if (limitMinutes == null) {
      // 没有设置单独限制，允许使用
      return RuleCheckResult.allowed();
    }

    // 获取今日该应用的使用时间
    final today = DailyStats.formatDate(DateTime.now());
    final usedSeconds = await _getAppUsageSeconds(packageName, today);

    final limitSeconds = limitMinutes * 60;
    final remainingSeconds = limitSeconds - usedSeconds;

    if (remainingSeconds <= 0) {
      return RuleCheckResult.blocked(
        reason: '该应用今日时间已用完',
        ruleType: 'app_daily_limit',
      );
    }

    return RuleCheckResult.limited(
      remainingSeconds: remainingSeconds,
      reason: '该应用还有 ${(remainingSeconds / 60).ceil()} 分钟',
      ruleType: 'app_daily_limit',
    );
  }

  /// 获取指定应用今日使用时间（秒）
  Future<int> _getAppUsageSeconds(String packageName, String date) async {
    final records = await _appUsageDao.getByDate(date);
    final appRecords = records.where((r) => r.packageName == packageName);

    int totalSeconds = 0;
    for (final record in appRecords) {
      totalSeconds += record.durationSeconds;
    }

    return totalSeconds;
  }

  /// 获取今日剩余时间概要
  Future<TodayRemainingTime> getTodayRemainingTime() async {
    // 这个方法主要用于兼容性，新逻辑不依赖分类时间
    return const TodayRemainingTime(
      totalSeconds: 0,
      gameSeconds: 0,
      videoSeconds: 0,
    );
  }
}

/// 今日剩余时间
class TodayRemainingTime {
  final int totalSeconds;
  final int gameSeconds;
  final int videoSeconds;

  const TodayRemainingTime({
    required this.totalSeconds,
    required this.gameSeconds,
    required this.videoSeconds,
  });

  Duration get total => Duration(seconds: totalSeconds);
  Duration get game => Duration(seconds: gameSeconds);
  Duration get video => Duration(seconds: videoSeconds);

  int get totalMinutes => totalSeconds ~/ 60;
  int get gameMinutes => gameSeconds ~/ 60;
  int get videoMinutes => videoSeconds ~/ 60;
}

/// 规则检查服务 Provider
final ruleCheckerServiceProvider = Provider<RuleCheckerService>((ref) {
  final db = AppDatabase.instance;
  return RuleCheckerService(db, ref);
});
