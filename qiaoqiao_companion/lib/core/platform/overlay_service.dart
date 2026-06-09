import 'package:flutter/services.dart';

/// 提醒类型
enum ReminderType {
  reminder('reminder'),               // 温和提醒
  warning('warning'),                 // 认真警告
  serious('serious'),                 // 严肃警告
  lock('lock'),                       // 锁定
  forbiddenDismissible('forbidden_dismissible'), // 可关闭的禁用提醒
  forbiddenLocked('forbidden_locked');           // 不可关闭的禁用锁定

  const ReminderType(this.code);
  final String code;

  static ReminderType fromCode(String code) {
    return ReminderType.values.firstWhere(
      (e) => e.code == code,
      orElse: () => ReminderType.reminder,
    );
  }
}

/// 悬浮窗服务
class OverlayService {
  static const MethodChannel _channel =
      MethodChannel('com.qiaoqiao.companion/overlay');

  /// 关闭回调（用于禁用app提醒）
  static void Function(String packageName)? _onOverlayDismissed;

  /// 全局覆盖层关闭回调（无论由谁创建的覆盖层，关闭时都会触发）
  /// 用于在锁定弹窗关闭后，触发 Flutter 侧恢复休息倒计时 widget
  static VoidCallback? _onGlobalOverlayDismissed;

  /// 注册全局覆盖层关闭回调
  static void setOnGlobalOverlayDismissed(VoidCallback callback) {
    _onGlobalOverlayDismissed = callback;
  }

  /// 倒计时结束回调
  static void Function()? _onCountdownEnded;

  /// 倒计时提醒回调（3分钟、2分钟）
  static void Function(String alertType)? _onCountdownAlert;

  /// 初始化服务（设置回调监听）
  static void init() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onOverlayDismissed') {
        final packageName = call.arguments['packageName'] as String? ?? '';
        _onOverlayDismissed?.call(packageName);
        _onOverlayDismissed = null;
        // 全局回调：无论覆盖层由谁创建，关闭时都通知
        _onGlobalOverlayDismissed?.call();
      } else if (call.method == 'onCountdownEnded') {
        _onCountdownEnded?.call();
        _onCountdownEnded = null;
      } else if (call.method == 'onCountdownAlert') {
        final alertType = call.arguments['alertType'] as String? ?? '';
        _onCountdownAlert?.call(alertType);
      }
    });
  }

  /// 检查是否有悬浮窗权限
  static Future<bool> hasPermission() async {
    final result = await _channel.invokeMethod<bool>('hasPermission');
    return result ?? false;
  }

  /// 请求悬浮窗权限
  static Future<void> requestPermission() async {
    await _channel.invokeMethod<void>('requestPermission');
  }

  /// 显示悬浮窗提醒
  static Future<void> showOverlay({
    required String title,
    required String message,
    ReminderType type = ReminderType.reminder,
    int durationSeconds = 0,
    bool dismissible = true,
    String packageName = '',
    int dismissDelaySeconds = 0,
    int remainingDismissSeconds = 0,
    bool launchAppOnDismiss = true,
    void Function(String packageName)? onDismissed,
  }) async {
    _onOverlayDismissed = onDismissed;

    await _channel.invokeMethod<void>(
      'showOverlay',
      {
        'title': title,
        'message': message,
        'type': type.code,
        'durationSeconds': durationSeconds,
        'dismissible': dismissible,
        'packageName': packageName,
        'dismissDelaySeconds': dismissDelaySeconds,
        'remainingDismissSeconds': remainingDismissSeconds,
        'launchAppOnDismiss': launchAppOnDismiss,
      },
    );
  }

  /// 隐藏悬浮窗
  static Future<void> hideOverlay() async {
    await _channel.invokeMethod<void>('hideOverlay');
  }

  /// 检查悬浮窗是否正在显示
  static Future<bool> isOverlayShowing() async {
    final result = await _channel.invokeMethod<bool>('isOverlayShowing');
    return result ?? false;
  }

  /// 显示倒计时悬浮窗（右上角，可拖动，不可关闭）
  ///
  /// [totalSeconds] 倒计时总时长（秒）
  /// [onEnded] 倒计时结束回调
  /// [onAlert] 倒计时提醒回调（3min、2min）
  /// [lockTitle] 倒计时结束后原生侧显示锁定弹窗的标题（Flutter 进程死亡时兜底）
  /// [lockMessage] 倒计时结束后原生侧显示锁定弹窗的消息
  /// [lockDurationSeconds] 锁定弹窗的持续秒数（休息时长）
  /// [lockPackageName] 锁定弹窗的应用包名
  static Future<void> showCountdownWidget({
    required int totalSeconds,
    void Function()? onEnded,
    void Function(String alertType)? onAlert,
    String? lockTitle,
    String? lockMessage,
    int? lockDurationSeconds,
    String? lockPackageName,
  }) async {
    _onCountdownEnded = onEnded;
    _onCountdownAlert = onAlert;

    await _channel.invokeMethod<void>(
      'showCountdownWidget',
      {
        'totalSeconds': totalSeconds,
        if (lockTitle != null) 'lockTitle': lockTitle,
        if (lockMessage != null) 'lockMessage': lockMessage,
        if (lockDurationSeconds != null) 'lockDurationSeconds': lockDurationSeconds,
        if (lockPackageName != null) 'lockPackageName': lockPackageName,
      },
    );
  }

  /// 隐藏倒计时悬浮窗
  static Future<void> hideCountdownWidget() async {
    await _channel.invokeMethod<void>('hideCountdownWidget');
  }

  /// 检查倒计时悬浮窗是否正在显示
  static Future<bool> isCountdownWidgetShowing() async {
    final result = await _channel.invokeMethod<bool>('isCountdownWidgetShowing');
    return result ?? false;
  }
}

/// 提醒消息工厂
class ReminderMessages {
  static ReminderMessage firstReminder(int remainingMinutes) {
    return ReminderMessage(
      title: '快到时间啦~',
      message: '还有 $remainingMinutes 分钟，记得休息哦！',
      type: ReminderType.reminder,
    );
  }

  static ReminderMessage secondReminder() {
    return ReminderMessage(
      title: '时间到啦！',
      message: '纹纹提醒你该休息了~',
      type: ReminderType.warning,
    );
  }

  static ReminderMessage seriousWarning(int remainingSeconds) {
    return ReminderMessage(
      title: '最后警告',
      message: '还在玩的话...纹纹要强制休息了哦！',
      type: ReminderType.serious,
      durationSeconds: remainingSeconds,
    );
  }

  static ReminderMessage lockMessage() {
    return ReminderMessage(
      title: '今天的时间用完啦',
      message: '明天再来吧！纹纹会一直陪着你~',
      type: ReminderType.lock,
    );
  }

  static ReminderMessage forbiddenTime(String timeRange) {
    return ReminderMessage(
      title: '现在是休息时间',
      message: '$timeRange 不能使用哦，纹纹在守护你~',
      type: ReminderType.lock,
    );
  }
}

/// 提醒消息
class ReminderMessage {
  final String title;
  final String message;
  final ReminderType type;
  final int durationSeconds;
  final bool dismissible;
  final String packageName;
  final int dismissDelaySeconds;
  final int remainingDismissSeconds;
  final bool launchAppOnDismiss;

  ReminderMessage({
    required this.title,
    required this.message,
    required this.type,
    this.durationSeconds = 0,
    this.dismissible = true,
    this.packageName = '',
    this.dismissDelaySeconds = 0,
    this.remainingDismissSeconds = 0,
    this.launchAppOnDismiss = true,
  });

  Future<void> show({void Function(String packageName)? onDismissed}) async {
    await OverlayService.showOverlay(
      title: title,
      message: message,
      type: type,
      durationSeconds: durationSeconds,
      dismissible: dismissible,
      packageName: packageName,
      dismissDelaySeconds: dismissDelaySeconds,
      remainingDismissSeconds: remainingDismissSeconds,
      launchAppOnDismiss: launchAppOnDismiss,
      onDismissed: onDismissed,
    );
  }
}
