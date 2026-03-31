import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/platform/overlay_service.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';
import 'package:qiaoqiao_companion/core/services/forbidden_app_tracker.dart';
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

  ReminderService(this._ref);

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
    await OverlayService.showOverlay(
      title: '快到时间啦~',
      message: '还有 $remainingMinutes 分钟，记得休息哦！',
      type: ReminderType.reminder,
    );
  }

  /// 显示认真警告（时间到）
  Future<void> _showSeriousReminder() async {
    await OverlayService.showOverlay(
      title: '时间到啦！',
      message: '纹纹提醒你该休息了~',
      type: ReminderType.warning,
    );
  }

  /// 显示最后警告（最后3分钟）
  Future<void> _showFinalWarning(int remainingSeconds) async {
    await OverlayService.showOverlay(
      title: '最后警告',
      message: '还在玩的话...纹纹要强制休息了哦！',
      type: ReminderType.serious,
      durationSeconds: remainingSeconds,
    );
  }

  /// 显示锁定提醒
  Future<void> _showLockReminder(String categoryOrTotal) async {
    String message;
    if (categoryOrTotal == 'total') {
      message = '今天的时间用完啦，明天再来吧！纹纹会一直陪着你~';
    } else {
      message = '今天的$categoryOrTotal时间用完啦，明天再来吧！';
    }

    await OverlayService.showOverlay(
      title: '时间结束',
      message: message,
      type: ReminderType.lock,
    );
  }

  /// 显示禁止时段提醒
  Future<void> showForbiddenTimeReminder(String timeRange) async {
    await OverlayService.showOverlay(
      title: '现在是休息时间',
      message: '$timeRange 不能使用哦，纹纹在守护你~',
      type: ReminderType.lock,
    );
  }

  /// 显示主动结束奖励
  Future<void> showEarlyEndingReward() async {
    // 给予积分奖励
    final pointsNotifier = _ref.read(pointsProvider.notifier);
    await pointsNotifier.rewardEndingEarly();

    await OverlayService.showOverlay(
      title: '太棒了！',
      message: '你主动结束了使用！+${PointsConstants.pointsForEndingEarly} 阳光积分',
      type: ReminderType.reminder,
    );
  }

  /// 隐藏提醒
  Future<void> hideReminder() async {
    await OverlayService.hideOverlay();
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
    // 以下规则类型每次都弹窗，不受冷却间隔限制：
    // - 限制时段规则 (time_period)
    // - 连续使用提醒 (continuous_usage_*)
    // - 时长限制类规则 (total_time_limit, category_limit, app_daily_limit, forced_rest)
    final isTimePeriod = ruleType == 'time_period';
    final isContinuousUsage = ruleType != null && ruleType.startsWith('continuous_usage_');
    final isTimeLimit = ruleType == 'total_time_limit' ||
                        ruleType == 'category_limit' ||
                        ruleType == 'app_daily_limit' ||
                        ruleType == 'forced_rest';
    final bypassCooldown = isTimePeriod || isContinuousUsage || isTimeLimit;

    // 0. 如果弹窗已经在显示，不要重复创建（避免重置倒计时）
    if (await OverlayService.isOverlayShowing()) {
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
    final isForcedRest = ruleType == 'continuous_usage_limit' || ruleType == 'forced_rest';
    ReminderType type;
    int dismissDelay;

    if (isForcedRest && durationSeconds != null && durationSeconds! > 0) {
      // 强制休息：使用 lock 类型，关闭延迟等于休息时长
      type = ReminderType.lock;
      dismissDelay = durationSeconds!;
    } else {
      // 其他情况：根据提醒次数确定类型
      type = count < 3
          ? ReminderType.forbiddenDismissible
          : ReminderType.forbiddenLocked;
      dismissDelay = count < 3 ? 0 : 60; // 第4次+需等待60秒
    }

    // 6. 显示overlay
    await OverlayService.showOverlay(
      title: _getForbiddenAppTitle(count),
      message: reason,
      type: type,
      dismissible: true, // 始终可关闭
      packageName: packageName,
      dismissDelaySeconds: dismissDelay,
      remainingDismissSeconds: remainingSeconds, // 传递剩余秒数用于显示倒计时
      durationSeconds: durationSeconds ?? 0, // 传递休息/限制时长用于显示倒计时
      onDismissed: (pkg) {
        _forbiddenAppTracker.recordDismissal(pkg);
      },
    );

    return true;
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
  return ReminderService(ref);
});
