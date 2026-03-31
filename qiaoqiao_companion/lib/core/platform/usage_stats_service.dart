import 'package:flutter/services.dart';

/// 使用统计服务
class UsageStatsService {
  static const MethodChannel _channel =
      MethodChannel('com.qiaoqiao.companion/usage_stats');

  /// 检查是否有使用统计权限
  static Future<bool> hasPermission() async {
    final result = await _channel.invokeMethod<bool>('hasPermission');
    return result ?? false;
  }

  /// 请求使用统计权限
  static Future<void> requestPermission() async {
    await _channel.invokeMethod<void>('requestPermission');
  }

  /// 查询指定时间段的应用使用统计
  static Future<List<UsageStats>> queryUsageStats({
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final List<dynamic>? result = await _channel.invokeMethod<List<dynamic>>(
      'queryUsageStats',
      {
        'startTime': startTime.millisecondsSinceEpoch,
        'endTime': endTime.millisecondsSinceEpoch,
      },
    );

    if (result == null) return [];

    return result
        .map((e) => UsageStats.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// 查询指定时间段的应用使用事件
  static Future<List<UsageEvent>> queryEvents({
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final List<dynamic>? result = await _channel.invokeMethod<List<dynamic>>(
      'queryEvents',
      {
        'startTime': startTime.millisecondsSinceEpoch,
        'endTime': endTime.millisecondsSinceEpoch,
      },
    );

    if (result == null) return [];

    return result
        .map((e) => UsageEvent.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// 获取当前前台应用包名
  static Future<String?> getCurrentForegroundApp() async {
    return await _channel.invokeMethod<String?>('getCurrentForegroundApp');
  }

  /// 获取已安装应用列表
  static Future<List<AppInfo>> getInstalledApps() async {
    final List<dynamic>? result =
        await _channel.invokeMethod<List<dynamic>>('getInstalledApps');

    if (result == null) return [];

    return result
        .map((e) => AppInfo.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// 查询按时段统计的使用数据
  static Future<List<HourlyUsageData>> queryHourlyUsage({
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final List<dynamic>? result = await _channel.invokeMethod<List<dynamic>>(
      'queryHourlyUsage',
      {
        'startTime': startTime.millisecondsSinceEpoch,
        'endTime': endTime.millisecondsSinceEpoch,
      },
    );

    if (result == null) return [];

    return result
        .map((e) => HourlyUsageData.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }
}

/// 使用统计信息
class UsageStats {
  final String packageName;
  final String? appName;
  final int totalTimeInForeground;
  final int lastTimeUsed;
  final int firstTimeStamp;
  final int lastTimeStamp;
  final String? appIcon; // Base64编码的应用图标

  UsageStats({
    required this.packageName,
    this.appName,
    required this.totalTimeInForeground,
    required this.lastTimeUsed,
    required this.firstTimeStamp,
    required this.lastTimeStamp,
    this.appIcon,
  });

  factory UsageStats.fromMap(Map<String, dynamic> map) {
    return UsageStats(
      packageName: map['packageName'] as String,
      appName: map['appName'] as String?,
      totalTimeInForeground: map['totalTimeInForeground'] as int,
      lastTimeUsed: map['lastTimeUsed'] as int,
      firstTimeStamp: map['firstTimeStamp'] as int,
      lastTimeStamp: map['lastTimeStamp'] as int,
      appIcon: map['appIcon'] as String?,
    );
  }

  Duration get totalForegroundTime =>
      Duration(milliseconds: totalTimeInForeground);
  DateTime get lastUsedTime =>
      DateTime.fromMillisecondsSinceEpoch(lastTimeUsed);
  DateTime get firstTime =>
      DateTime.fromMillisecondsSinceEpoch(firstTimeStamp);
  DateTime get lastTime =>
      DateTime.fromMillisecondsSinceEpoch(lastTimeStamp);
}

/// 使用事件
class UsageEvent {
  final String packageName;
  final String? appName;
  final String eventType;
  final int timeStamp;

  UsageEvent({
    required this.packageName,
    this.appName,
    required this.eventType,
    required this.timeStamp,
  });

  factory UsageEvent.fromMap(Map<String, dynamic> map) {
    return UsageEvent(
      packageName: map['packageName'] as String,
      appName: map['appName'] as String?,
      eventType: map['eventType'] as String,
      timeStamp: map['timeStamp'] as int,
    );
  }

  DateTime get time => DateTime.fromMillisecondsSinceEpoch(timeStamp);

  bool get isResume => eventType == 'resume';
  bool get isPause => eventType == 'pause';
}

/// 应用信息
class AppInfo {
  final String packageName;
  final String appName;
  final bool isSystemApp;
  final String? appIcon; // Base64编码的应用图标

  AppInfo({
    required this.packageName,
    required this.appName,
    required this.isSystemApp,
    this.appIcon,
  });

  factory AppInfo.fromMap(Map<String, dynamic> map) {
    return AppInfo(
      packageName: map['packageName'] as String,
      appName: map['appName'] as String,
      isSystemApp: map['isSystemApp'] as bool? ?? false,
      appIcon: map['appIcon'] as String?,
    );
  }
}

/// 小时级使用数据（从原生通道返回）
class HourlyUsageData {
  final String date;
  final int hour;
  final String packageName;
  final String appName;
  final int durationSeconds;

  HourlyUsageData({
    required this.date,
    required this.hour,
    required this.packageName,
    required this.appName,
    required this.durationSeconds,
  });

  factory HourlyUsageData.fromMap(Map<String, dynamic> map) {
    return HourlyUsageData(
      date: map['date'] as String,
      hour: map['hour'] as int,
      packageName: map['packageName'] as String,
      appName: map['appName'] as String,
      durationSeconds: map['durationSeconds'] as int? ?? 0,
    );
  }

  Duration get duration => Duration(seconds: durationSeconds);
}
