import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/platform/overlay_service.dart';

/// 弹窗状态枚举
enum OverlayState {
  idle,
  showingReminder,
  showingCountdown,
  showingLock,
  transitioning,
}

/// 弹窗优先级（数值越大越紧急）
class OverlayPriority {
  static const int forcedRestLock = 100;
  static const int timeBlockLock = 90;
  static const int totalLimitLock = 85;
  static const int countdownWidget = 50;
  static const int continuousUsageAlert = 40;
  static const int forbiddenAppReminder = 30;
  static const int gentleReminder = 10;
}

/// 弹窗请求
class OverlayRequest {
  final String id;
  final int priority;
  final OverlayType type;
  final String? packageName;
  final DateTime createdAt;

  // overlay 参数
  final String? title;
  final String? message;
  final ReminderType? reminderType;
  final int durationSeconds;
  final bool dismissible;
  final int dismissDelaySeconds;
  final int remainingDismissSeconds;
  final bool launchAppOnDismiss;
  final void Function(String packageName)? onDismissed;

  // countdown widget 参数
  final int? countdownTotalSeconds;
  final void Function()? onCountdownEnded;
  final void Function(String alertType)? onCountdownAlert;
  final String? lockTitle;
  final String? lockMessage;
  final int? lockDurationSeconds;
  final String? lockPackageName;

  OverlayRequest({
    required this.id,
    required this.priority,
    required this.type,
    this.packageName,
    DateTime? createdAt,
    this.title,
    this.message,
    this.reminderType,
    this.durationSeconds = 0,
    this.dismissible = true,
    this.dismissDelaySeconds = 0,
    this.remainingDismissSeconds = 0,
    this.launchAppOnDismiss = true,
    this.onDismissed,
    this.countdownTotalSeconds,
    this.onCountdownEnded,
    this.onCountdownAlert,
    this.lockTitle,
    this.lockMessage,
    this.lockDurationSeconds,
    this.lockPackageName,
  }) : createdAt = createdAt ?? DateTime.now();
}

/// 弹窗类型
enum OverlayType {
  reminder,
  countdown,
  lock,
}

/// 集中式弹窗状态管理器
///
/// 确保同一时间只有一个弹窗，高优先级可抢占低优先级，
/// 所有 hide-then-show 操作在锁内原子执行。
class OverlayStateManager {
  OverlayState _state = OverlayState.idle;
  OverlayRequest? _currentRequest;
  DateTime? _lastShownAt;

  /// 串行化锁，防止并发请求竞态
  final List<Completer<void>> _lockQueue = [];

  /// 去重窗口（毫秒），同一弹窗在此时间内不重复显示
  static const int _dedupWindowMs = 2000;

  OverlayState get state => _state;
  OverlayRequest? get currentRequest => _currentRequest;

  /// 请求显示弹窗
  ///
  /// 高优先级可抢占当前弹窗，同级或低优先级请求被丢弃。
  /// 所有操作串行化执行，避免 hide-then-show 竞态。
  Future<bool> requestOverlay(OverlayRequest request) async {
    await _acquireLock();
    try {
      // 去重：同一类型、同一包名、在去重窗口内 → 跳过
      if (_isDuplicate(request)) {
        print('[OverlayState] Duplicate request skipped: ${request.id}');
        return false;
      }

      // 优先级判断
      if (_state != OverlayState.idle && _currentRequest != null) {
        if (request.priority <= _currentRequest!.priority) {
          // 同级或低优先级 → 一律丢弃（不管是否 hard limit）
          // 同级 hard limit 互相抢占只会导致相同的弹窗被重新创建（倒计时被重置）
          print('[OverlayState] Lower/equal priority request dropped: ${request.id} '
              '(current: ${_currentRequest!.priority}, new: ${request.priority})');
          return false;
        }
        // 高优先级 → 抢占（先关闭当前弹窗）
        await _dismissCurrentInternal();
      }

      // 显示新弹窗
      await _showOverlay(request);
      _currentRequest = request;
      _lastShownAt = DateTime.now();

      switch (request.type) {
        case OverlayType.lock:
          _state = OverlayState.showingLock;
          break;
        case OverlayType.countdown:
          _state = OverlayState.showingCountdown;
          break;
        case OverlayType.reminder:
          _state = OverlayState.showingReminder;
          break;
      }

      print('[OverlayState] Showing overlay: ${request.id}, type: ${request.type}, priority: ${request.priority}');
      return true;
    } finally {
      _releaseLock();
    }
  }

  /// 关闭当前弹窗
  Future<void> dismissCurrent() async {
    await _acquireLock();
    try {
      await _dismissCurrentInternal();
    } finally {
      _releaseLock();
    }
  }

  /// 通知弹窗已被用户关闭（由 _showOverlay 的包装回调触发）
  void onOverlayDismissed(String packageName) {
    _state = OverlayState.idle;
    _currentRequest = null;
    print('[OverlayState] Overlay dismissed by user: $packageName');
  }

  /// 通知倒计时结束（由 OverlayService 回调触发）
  void onCountdownEnded() {
    if (_state == OverlayState.showingCountdown) {
      _state = OverlayState.idle;
      _currentRequest = null;
    }
  }

  /// 关闭倒计时 widget
  Future<void> dismissCountdown() async {
    await _acquireLock();
    try {
      if (_state == OverlayState.showingCountdown) {
        await OverlayService.hideCountdownWidget();
        _state = OverlayState.idle;
        _currentRequest = null;
      }
    } finally {
      _releaseLock();
    }
  }

  /// 原生兜底路径创建 overlay 后，同步 OverlayStateManager 的内部状态
  ///
  /// 原生兜底 overlay（countdown widget 结束后自动创建的 lock overlay）
  /// 绕过了 OverlayStateManager 的 requestOverlay 流程，导致 _state 仍为 idle。
  /// 这使得后续轮询中的弹窗请求绕过优先级检查，直接替换原生兜底的 overlay。
  /// 调用此方法将 _state 同步为实际状态，让优先级机制正常工作。
  void syncStateFromNativeFallback(OverlayState nativeState) {
    _state = nativeState;
    _currentRequest = null; // 原生兜底路径没有 OverlayRequest
    _lastShownAt = DateTime.now();
    print('[OverlayState] Synced state from native fallback: $nativeState');
  }

  /// 检查是否有 overlay 在显示（不含 countdown widget）
  Future<bool> isOverlayActive() async {
    if (_state == OverlayState.showingReminder || _state == OverlayState.showingLock) {
      return true;
    }
    // 兜底：查询原生侧
    return await OverlayService.isOverlayShowing();
  }

  /// 检查是否有倒计时 widget 在显示
  bool isCountdownActive() {
    return _state == OverlayState.showingCountdown;
  }

  /// 冷启动/引擎重建时与原生侧同步状态
  ///
  /// 进程被划掉后 Flutter 引擎重启，OverlayStateManager 是新实例（_state = idle），
  /// 但原生侧 OverlayChannel 的 isOverlayShowing 标志和残留 overlay 可能仍在。
  /// 调用此方法清掉原生残留，让随后的监控轮询按规则重新决策弹窗。
  Future<void> syncWithNative() async {
    try {
      if (await OverlayService.isOverlayShowing()) {
        await OverlayService.hideOverlay();
        print('[OverlayState] syncWithNative: cleared residual overlay');
      }
      if (await OverlayService.isCountdownWidgetShowing()) {
        await OverlayService.hideCountdownWidget();
        print('[OverlayState] syncWithNative: cleared residual countdown widget');
      }
    } catch (e) {
      print('[OverlayState] syncWithNative error: $e');
    }
    _state = OverlayState.idle;
    _currentRequest = null;
    _lastShownAt = null;
  }

  // --- 内部方法 ---

  Future<void> _showOverlay(OverlayRequest request) async {
    switch (request.type) {
      case OverlayType.countdown:
        await OverlayService.showCountdownWidget(
          totalSeconds: request.countdownTotalSeconds ?? 300,
          onEnded: () {
            request.onCountdownEnded?.call();
            onCountdownEnded();
          },
          onAlert: request.onCountdownAlert,
          lockTitle: request.lockTitle,
          lockMessage: request.lockMessage,
          lockDurationSeconds: request.lockDurationSeconds,
          lockPackageName: request.lockPackageName,
        );
        break;

      case OverlayType.reminder:
      case OverlayType.lock:
        await OverlayService.showOverlay(
          title: request.title ?? '',
          message: request.message ?? '',
          type: request.reminderType ?? ReminderType.reminder,
          durationSeconds: request.durationSeconds,
          dismissible: request.dismissible,
          packageName: request.packageName ?? '',
          dismissDelaySeconds: request.dismissDelaySeconds,
          remainingDismissSeconds: request.remainingDismissSeconds,
          launchAppOnDismiss: request.launchAppOnDismiss,
          onDismissed: (pkg) {
            request.onDismissed?.call(pkg);
            onOverlayDismissed(pkg);
          },
        );
        break;
    }
  }

  Future<void> _dismissCurrentInternal() async {
    if (_state == OverlayState.idle || _currentRequest == null) return;

    _state = OverlayState.transitioning;
    try {
      switch (_currentRequest!.type) {
        case OverlayType.countdown:
          await OverlayService.hideCountdownWidget();
          break;
        case OverlayType.reminder:
        case OverlayType.lock:
          await OverlayService.hideOverlay();
          break;
      }
    } catch (e) {
      print('[OverlayState] Error dismissing overlay: $e');
    }

    _state = OverlayState.idle;
    _currentRequest = null;
  }

  bool _isDuplicate(OverlayRequest request) {
    if (_lastShownAt == null || _currentRequest == null) return false;

    final elapsed = DateTime.now().millisecondsSinceEpoch - _lastShownAt!.millisecondsSinceEpoch;
    if (elapsed > _dedupWindowMs) return false;

    return _currentRequest!.type == request.type &&
        _currentRequest!.packageName == request.packageName;
  }

  Future<void> _acquireLock() async {
    final completer = Completer<void>();
    _lockQueue.add(completer);
    if (_lockQueue.length > 1) {
      await completer.future;
    }
  }

  void _releaseLock() {
    if (_lockQueue.isNotEmpty) {
      _lockQueue.removeAt(0);
      if (_lockQueue.isNotEmpty) {
        _lockQueue.first.complete();
      }
    }
  }
}

/// Provider
final overlayStateManagerProvider = Provider<OverlayStateManager>((ref) {
  return OverlayStateManager();
});
