import 'package:qiaoqiao_companion/core/constants/database_constants.dart';

/// 小时级使用统计模型
class HourlyUsageStats {
  final int? id;
  final String date;           // YYYY-MM-DD
  final int hour;              // 0-23
  final String packageName;
  final String? appName;
  final AppCategory category;
  final int durationSeconds;
  final DateTime updatedAt;

  HourlyUsageStats({
    this.id,
    required this.date,
    required this.hour,
    required this.packageName,
    this.appName,
    this.category = AppCategory.other,
    required this.durationSeconds,
    required this.updatedAt,
  });

  factory HourlyUsageStats.fromMap(Map<String, dynamic> map) {
    return HourlyUsageStats(
      id: map['id'] as int?,
      date: map['date'] as String,
      hour: map['hour'] as int,
      packageName: map['package_name'] as String,
      appName: map['app_name'] as String?,
      category: AppCategory.fromCode(map['category'] as String? ?? 'other'),
      durationSeconds: map['duration_seconds'] as int? ?? 0,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'date': date,
      'hour': hour,
      'package_name': packageName,
      'app_name': appName,
      'category': category.code,
      'duration_seconds': durationSeconds,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  Duration get duration => Duration(seconds: durationSeconds);

  HourlyUsageStats copyWith({
    int? id,
    String? date,
    int? hour,
    String? packageName,
    String? appName,
    AppCategory? category,
    int? durationSeconds,
    DateTime? updatedAt,
  }) {
    return HourlyUsageStats(
      id: id ?? this.id,
      date: date ?? this.date,
      hour: hour ?? this.hour,
      packageName: packageName ?? this.packageName,
      appName: appName ?? this.appName,
      category: category ?? this.category,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'HourlyUsageStats(date: $date, hour: $hour, package: $packageName, duration: ${duration.inMinutes}m)';
  }
}

/// 小时使用状态
enum HourUsageStatus {
  none,      // 未使用
  light,     // 轻度 (<5分钟)
  moderate,  // 中度 (<15分钟)
  heavy,     // 重度 (>=15分钟)
}

/// 小时级时间线数据
class HourlyTimeline {
  final String date;
  final Map<int, int> hourlyTotals;  // hour (0-23) -> seconds
  final List<HourlyUsageStats> allRecords;

  HourlyTimeline({
    required this.date,
    required this.hourlyTotals,
    required this.allRecords,
  });

  /// 获取指定小时的使用状态
  HourUsageStatus getStatusForHour(int hour) {
    final seconds = hourlyTotals[hour] ?? 0;
    if (seconds <= 0) return HourUsageStatus.none;
    if (seconds < 300) return HourUsageStatus.light;      // <5分钟
    if (seconds < 900) return HourUsageStatus.moderate;   // <15分钟
    return HourUsageStatus.heavy;
  }

  /// 获取总使用时长（秒）
  int get totalSeconds => hourlyTotals.values.fold(0, (a, b) => a + b);

  /// 获取总使用时长（Duration）
  Duration get totalDuration => Duration(seconds: totalSeconds);

  /// 获取活跃小时数（有使用的小时数）
  int get activeHours => hourlyTotals.entries.where((e) => e.value > 0).length;

  factory HourlyTimeline.empty(String date) {
    return HourlyTimeline(
      date: date,
      hourlyTotals: {},
      allRecords: [],
    );
  }
}
