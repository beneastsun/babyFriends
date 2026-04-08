import 'package:flutter/services.dart';

/// 监控服务
/// 管理Android前台服务，保持应用在后台运行
class MonitorService {
  MonitorService._();

  static const _channel = MethodChannel('com.qiaoqiao.qiaoqiao_companion/service');

  /// 启动前台服务
  static Future<bool> startForegroundService() async {
    try {
      final result = await _channel.invokeMethod<bool>('startForegroundService');
      return result ?? false;
    } on PlatformException catch (e) {
      print('启动前台服务失败: ${e.message}');
      return false;
    }
  }

  /// 停止前台服务
  static Future<bool> stopForegroundService() async {
    try {
      final result = await _channel.invokeMethod<bool>('stopForegroundService');
      return result ?? false;
    } on PlatformException catch (e) {
      print('停止前台服务失败: ${e.message}');
      return false;
    }
  }

  /// 检查服务是否正在运行
  static Future<bool> isServiceRunning() async {
    try {
      final result = await _channel.invokeMethod<bool>('isServiceRunning');
      return result ?? false;
    } on PlatformException catch (e) {
      print('检查服务状态失败: ${e.message}');
      return false;
    }
  }

  /// 更新通知内容
  static Future<bool> updateNotification({
    required String title,
    required String message,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('updateNotification', {
        'title': title,
        'message': message,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      print('更新通知失败: ${e.message}');
      return false;
    }
  }

  /// 检查是否需要自启动权限引导
  static Future<bool> checkAutoStartPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('checkAutoStartPermission');
      return result ?? false;
    } on PlatformException catch (e) {
      print('检查自启动权限失败: ${e.message}');
      return false;
    }
  }

  /// 打开自启动设置页面
  static Future<bool> openAutoStartSettings() async {
    try {
      final result = await _channel.invokeMethod<bool>('openAutoStartSettings');
      return result ?? false;
    } on PlatformException catch (e) {
      print('打开自启动设置失败: ${e.message}');
      return false;
    }
  }

  /// 打开应用详情设置（作为备选方案）
  static Future<bool> openAppDetailSettings() async {
    try {
      const channel = MethodChannel('com.qiaoqiao.qiaoqiao_companion/usage_stats');
      await channel.invokeMethod('openAppSettings');
      return true;
    } catch (e) {
      print('打开应用详情设置失败: $e');
      return false;
    }
  }

  /// 获取ROM类型
  static Future<String> getRomType() async {
    try {
      final result = await _channel.invokeMethod<String>('getRomType');
      return result ?? 'OTHER';
    } on PlatformException catch (e) {
      print('获取ROM类型失败: ${e.message}');
      return 'OTHER';
    }
  }

  /// 检查是否忽略电池优化（是否在白名单中）
  static Future<bool> checkBatteryOptimization() async {
    try {
      final result = await _channel.invokeMethod<bool>('checkBatteryOptimization');
      return result ?? false;
    } on PlatformException catch (e) {
      print('检查电池优化失败: ${e.message}');
      return false;
    }
  }

  /// 打开电池优化设置
  static Future<bool> openBatterySettings() async {
    try {
      final result = await _channel.invokeMethod<bool>('openBatterySettings');
      return result ?? false;
    } on PlatformException catch (e) {
      print('打开电池设置失败: ${e.message}');
      return false;
    }
  }

  /// 打开省电设置（厂商特定）
  static Future<bool> openPowerSavingSettings() async {
    try {
      final result = await _channel.invokeMethod<bool>('openPowerSavingSettings');
      return result ?? false;
    } on PlatformException catch (e) {
      print('打开省电设置失败: ${e.message}');
      return false;
    }
  }

  /// 将应用移动到后台
  static Future<bool> moveToBackground() async {
    try {
      const channel = MethodChannel('com.qiaoqiao.qiaoqiao_companion/app');
      final result = await channel.invokeMethod<bool>('moveToBackground');
      return result ?? false;
    } on PlatformException catch (e) {
      print('移动到后台失败: ${e.message}');
      return false;
    }
  }

  /// 启动守护服务（独立进程）
  static Future<bool> startGuardService() async {
    try {
      final result = await _channel.invokeMethod<bool>('startGuardService');
      return result ?? false;
    } on PlatformException catch (e) {
      print('启动守护服务失败: ${e.message}');
      return false;
    }
  }

  /// 停止守护服务
  static Future<bool> stopGuardService() async {
    try {
      final result = await _channel.invokeMethod<bool>('stopGuardService');
      return result ?? false;
    } on PlatformException catch (e) {
      print('停止守护服务失败: ${e.message}');
      return false;
    }
  }

  /// 检查守护服务是否正在运行
  static Future<bool> isGuardServiceRunning() async {
    try {
      final result = await _channel.invokeMethod<bool>('isGuardServiceRunning');
      return result ?? false;
    } on PlatformException catch (e) {
      print('检查守护服务状态失败: ${e.message}');
      return false;
    }
  }
}
