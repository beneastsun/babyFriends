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
///
/// 监控/提醒/锁定功能已迁移至原生 EnforcementEngine，
/// Flutter 侧仅保留查询方法和回调监听。
class OverlayService {
  static const MethodChannel _channel =
      MethodChannel('com.qiaoqiao.companion/overlay');

  /// 全局覆盖层关闭回调（无论由谁创建的覆盖层，关闭时都会触发）
  static VoidCallback? _onGlobalOverlayDismissed;

  /// 注册全局覆盖层关闭回调
  static void setOnGlobalOverlayDismissed(VoidCallback callback) {
    _onGlobalOverlayDismissed = callback;
  }

  /// 初始化服务（设置回调监听）
  static void init() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onOverlayDismissed') {
        // 全局回调：无论覆盖层由谁创建，关闭时都通知
        _onGlobalOverlayDismissed?.call();
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

  /// 隐藏悬浮窗
  static Future<void> hideOverlay() async {
    await _channel.invokeMethod<void>('hideOverlay');
  }

  /// 检查悬浮窗是否正在显示
  static Future<bool> isOverlayShowing() async {
    final result = await _channel.invokeMethod<bool>('isOverlayShowing');
    return result ?? false;
  }

  /// 检查倒计时悬浮窗是否正在显示
  static Future<bool> isCountdownWidgetShowing() async {
    final result = await _channel.invokeMethod<bool>('isCountdownWidgetShowing');
    return result ?? false;
  }
}
