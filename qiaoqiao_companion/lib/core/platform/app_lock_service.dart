import 'package:flutter/services.dart';

/// App锁服务
/// 管理应用防关闭锁屏功能
class AppLockService {
  AppLockService._();

  static const MethodChannel _channel =
      MethodChannel('com.qiaoqiao.qiaoqiao_companion/app_lock');

  /// 检查是否启用锁屏
  static Future<bool> isLockEnabled() async {
    try {
      final result = await _channel.invokeMethod<bool>('isLockEnabled');
      return result ?? true;
    } on PlatformException {
      return true; // 默认启用，安全第一
    }
  }

  /// 设置锁屏启用状态
  static Future<bool> setLockEnabled(bool enabled) async {
    try {
      final result = await _channel.invokeMethod<bool>('setLockEnabled', {
        'enabled': enabled,
      });
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// 验证家长密码
  static Future<bool> verifyPassword(String password) async {
    try {
      final result = await _channel.invokeMethod<bool>('verifyPassword', {
        'password': password,
      });
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// 获取上次触发时间
  static Future<int> getLastTriggerTime() async {
    try {
      final result = await _channel.invokeMethod<int>('getLastTriggerTime');
      return result ?? 0;
    } on PlatformException {
      return 0;
    }
  }
}
