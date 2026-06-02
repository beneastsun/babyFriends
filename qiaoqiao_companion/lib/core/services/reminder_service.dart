import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/platform/overlay_service.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';
import 'package:qiaoqiao_companion/core/services/forbidden_app_tracker.dart';
import 'package:qiaoqiao_companion/core/services/overlay_state_manager.dart';
import 'package:qiaoqiao_companion/shared/providers/points_provider.dart';

/// 提醒类型
enum ReminderLevel {
  gentle,   // 温和提醒
  serious,  // 认真警告
  final_,   // 最后警告
  locked,   // 锁定
}

/// 提醒服务
///
/// 负责根据使用情况显示不同级别的提醒
class ReminderService {
  final Ref _ref;
  final OverlayStateManager _overlayManager;

  /// 禁用app提醒跟踪器
  final ForbiddenAppTracker _forbiddenAppTracker = ForbiddenAppTracker();

  /// 跟踪是否已发送过各级别提醒
  bool _hasSentGentleReminder = false;
  bool _hasSentSeriousReminder = false;
  bool _hasSentFinalWarning = false;
  bool _hasLocked = false;

  /// 当前监控的应用包名
  String? _currentLockedPackage;

  /// 当前禁用的应用包名
  String? _currentForbiddenPackage;

  ReminderService(this._ref, this._overlayManager);

  /// 重置提醒状态（每天午夜或新应用使用时）
  void reset() {
    _hasSentGentleReminder = false;
    _hasSentSeriousReminder = false;
    _hasSentFinalWarning = false;
    _hasLocked = false;
    _currentLockedPackage = null;
    _currentForbiddenPackage = null;
    _forbiddenAppTracker.resetAll();
  }

  /// 检查并发送提醒
  Future<void> checkAndNotify({
    required int remainingMinutes,
    required int remainingSeconds,
    required bool isCategoryLimit,
    required String categoryOrTotal,
  }) async {
    // 检查是否需要锁定
    if (remainingSeconds <= 0) {
      if (!_hasLocked) {
        _hasLocked = true;
        await _showLockReminder(categoryOrTotal);
      }
      return;
    }

    // 最后3分钟警告
    if (remainingSeconds <= 180 && remainingSeconds > 0) {
      if (!_hasSentFinalWarning) {
        _hasSentFinalWarning = true;
        await _showFinalWarning(remainingSeconds);
      }
      return;
    }

    // 时间到提醒（0分钟）
    if (remainingMinutes <= 0 && remainingSeconds > 0) {
      if (!_hasSentSeriousReminder) {
        _hasSentSeriousReminder = true;
        await _showSeriousReminder();
      }
      return;
    }

    // 提前5分钟提醒
    if (remainingMinutes <= 5 && remainingMinutes > 0) {
      if (!_hasSentGentleReminder) {
        _hasSentGentleReminder = true;
        await _showGentleReminder(remainingMinutes);
      }
      return;
    }
  }

  /// 显示温和提醒（提前5分钟）
  Future<void> _showGentleReminder(int remainingMinutes) async {
    await _overlayManager.requestOverlay(OverlayRequest(
      id: 'gentle_${DateTime.now().millisecondsSinceEpoch}',
      priority: OverlayPriority.gentleReminder,
      type: OverlayType.reminder,
      title: '快到时间啦~',
      message: '还有 $remainingMinutes 分钟，记得休息哦！',
      reminderType: ReminderType.reminder,
    ));
  }

  /// 显示认真警告（时间到）
  Future<void> _showSeriousReminder() async {
    await _overlayManager.requestOverlay(OverlayRequest(
      id: 'serious_${DateTime.now().millisecondsSinceEpoch}',
      priority: OverlayPriority.forbiddenAppReminder,
      type: OverlayType.reminder,
      title: '时间到啦！',
      message: '纹纹提醒你该休息了~',
      reminderType: ReminderType.warning,
    ));
  }

  /// 显示最后警告（最后3分钟）
  Future<void> _showFinalWarning(int remainingSeconds) async {
    await _overlayManager.requestOverlay(OverlayRequest(
      id: 'final_${DateTime.now().millisecondsSinceEpoch}',
      priority: OverlayPriority.continuousUsageAlert,
      type: OverlayType.reminder,
      title: '最后警告',
      message: '还在玩的话...纹纹要强制休息了哦！',
      reminderType: ReminderType.serious,
      durationSeconds: remainingSeconds,
    ));
  }

  /// 显示锁定提醒
  Future<void> _showLockReminder(String categoryOrTotal) async {
    String message;
    if (categoryOrTotal == 'total') {
      message = '今天的时间用完啦，明天再来吧！纹纹会一直陪着你~';
    } else {
      message = '今天的$categoryOrTotal时间用完啦，明天再来吧！';
    }

    await _overlayManager.requestOverlay(OverlayRequest(
      id: 'lock_${DateTime.now().millisecondsSinceEpoch}',
      priority: OverlayPriority.totalLimitLock,
      type: OverlayType.lock,
      title: '时间结束',
      message: message,
      reminderType: ReminderType.lock,
    ));
  }

  /// 显示禁止时段提醒
  Future<void> showForbiddenTimeReminder(String timeRange) async {
    await _overlayManager.requestOverlay(OverlayRequest(
      id: 'timeblock_${DateTime.now().millisecondsSinceEpoch}',
      priority: OverlayPriority.timeBlockLock,
      type: OverlayType.lock,
      title: '现在是休息时间',
      message: '$timeRange 不能使用哦，纹纹在守护你~',
      reminderType: ReminderType.lock,
    ));
  }

  /// 显示主动结束奖励
  Future<void> showEarlyEndingReward() async {
    final pointsNotifier = _ref.read(pointsProvider.notifier);
    await pointsNotifier.rewardEndingEarly();

    await _overlayManager.requestOverlay(OverlayRequest(
      id: 'reward_${DateTime.now().millisecondsSinceEpoch}',
      priority: OverlayPriority.gentleReminder,
      type: OverlayType.reminder,
      title: '太棒了！',
      message: '你主动结束了使用！+${PointsConstants.pointsForEndingEarly} 阳光积分',
      reminderType: ReminderType.reminder,
    ));
  }

  /// 隐藏提醒
  Future<void> hideReminder() async {
    await _overlayManager.dismissCurrent();
  }

  /// 检查并显示禁用app提醒
  ///
  /// [ruleType] 规则类型，所有规则类型每次都弹窗，不受冷却间隔限制：
  ///   - 'time_period': 限制时段
  ///   - 'continuous_usage_5min/3min/2min/limit': 连续使用提醒
  ///   - 'total_time_limit': 总时长限制
  ///   - 'category_limit': 分类时长限制
  ///   - 'app_daily_limit': 单应用每日限制
  ///   - 'forced_rest': 强制休息
  ///
  /// [durationSeconds] 休息/限制时长（秒），用于显示倒计时
  ///
  /// 返回true表示显示了提醒，false表示未显示（弹窗已在显示中）
  Future<bool> checkAndShowForbiddenReminder({
    required String packageName,
    required String reason,
    String? ruleType,
    int? durationSeconds,
  }) async {
    final isTimePeriod = ruleType == 'time_period';
    final isContinuousUsage = ruleType != null && ruleType.startsWith('continuous_usage_');
    final isForcedRest = ruleType == 'continuous_usage_limit' || ruleType == 'forced_rest';
    final isTimeLimit = ruleType == 'total_time_limit' ||
                        ruleType == 'category_limit' ||
                        ruleType == 'app_daily_limit' ||
                        ruleType == 'forced_rest';
    final bypassCooldown = isTimePeriod || isContinuousUsage || isTimeLimit;
    final isHardLimit = isForcedRest || isTimePeriod || isTimeLimit;

    // 确定优先级
    int priority;
    if (isForcedRest) {
      priority = OverlayPriority.forcedRestLock;
    } else if (isTimePeriod) {
      priority = OverlayPriority.timeBlockLock;
    } else if (isTimeLimit) {
      priority = OverlayPriority.totalLimitLock;
    } else if (isContinuousUsage) {
      priority = OverlayPriority.continuousUsageAlert;
    } else {
      priority = OverlayPriority.forbiddenAppReminder;
    }

    // 通过状态管理器请求弹窗（原子化 hide-then-show，消除竞态）
    // 非 hard limit 且已有弹窗时，状态管理器会自动丢弃
    if (!isHardLimit && await _overlayManager.isOverlayActive()) {
      return false;
    }

    // 1. 检查是否应该显示提醒（限制时段和连续使用提醒始终显示）
    if (!bypassCooldown && !_forbiddenAppTracker.shouldShowReminder(packageName)) {
      return false;
    }

    // 2. 更新当前禁用的包名
    _currentForbiddenPackage = packageName;

    // 3. 记录已显示
    _forbiddenAppTracker.recordShown(packageName);

    // 4. 获取提醒次数和关闭状态
    final count = _forbiddenAppTracker.getReminderCount(packageName);
    final remainingSeconds = _forbiddenAppTracker.getDismissRemainingSeconds(packageName);

    // 5. 确定弹窗类型和关闭延迟
    ReminderType type;
    int dismissDelay;

    if (isForcedRest && durationSeconds != null && durationSeconds > 0) {
      type = ReminderType.lock;
      dismissDelay = durationSeconds;
    } else {
      type = count < 3
          ? ReminderType.forbiddenDismissible
          : ReminderType.forbiddenLocked;
      dismissDelay = count < 3 ? 0 : 60;
    }

    // 6. 通过状态管理器显示 overlay
    final request = OverlayRequest(
      id: 'forbidden_${packageName}_${DateTime.now().millisecondsSinceEpoch}',
      priority: priority,
      type: isHardLimit ? OverlayType.lock : OverlayType.reminder,
      packageName: packageName,
      title: _getForbiddenAppTitle(count),
      message: reason,
      reminderType: type,
      durationSeconds: durationSeconds ?? 0,
      dismissible: true,
      dismissDelaySeconds: dismissDelay,
      remainingDismissSeconds: remainingSeconds,
      launchAppOnDismiss: !isContinuousUsage,
      onDismissed: (pkg) {
        _forbiddenAppTracker.recordDismissal(pkg);
      },
    );

    return await _overlayManager.requestOverlay(request);
  }

  /// 获取禁用app提醒标题
  String _getForbiddenAppTitle(int closedCount) {
    // closedCount是已关闭次数，显示的是下一次
    switch (closedCount) {
      case 0:
        return '这个应用不能使用哦';
      case 1:
        return '纹纹提醒你';
      case 2:
        return '最后提醒';
      default:
        return '时间结束';
    }
  }

  /// 是否已锁定
  bool get isLocked => _hasLocked;

  /// 设置锁定的应用
  void setLockedPackage(String? packageName) {
    _currentLockedPackage = packageName;
  }

  /// 获取锁定的应用
  String? get lockedPackage => _currentLockedPackage;

  /// 获取禁用app跟踪器（用于调试）
  ForbiddenAppTracker get forbiddenAppTracker => _forbiddenAppTracker;
}

/// 提醒服务 Provider
final reminderServiceProvider = Provider<ReminderService>((ref) {
  final overlayManager = ref.watch(overlayStateManagerProvider);
  return ReminderService(ref, overlayManager);
});
