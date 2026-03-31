import 'package:qiaoqiao_companion/core/constants/database_constants.dart';

/// 应用使用记录模型
class AppUsageRecord {
  final int? id;
  final String packageName;
  final String? appName;
  final AppCategory category;
  final DateTime startTime;
  final DateTime endTime;
  final int durationSeconds;
  final String date;

  AppUsageRecord({
    this.id,
    required this.packageName,
    this.appName,
    this.category = AppCategory.other,
    required this.startTime,
    required this.endTime,
    required this.durationSeconds,
    required this.date,
  });

  factory AppUsageRecord.fromMap(Map<String, dynamic> map) {
    return AppUsageRecord(
      id: map['id'] as int?,
      packageName: map['package_name'] as String,
      appName: map['app_name'] as String?,
      category: AppCategory.fromCode(map['category'] as String? ?? 'other'),
      startTime: DateTime.fromMillisecondsSinceEpoch(map['start_time'] as int),
      endTime: DateTime.fromMillisecondsSinceEpoch(map['end_time'] as int),
      durationSeconds: map['duration'] as int,
      date: map['date'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'package_name': packageName,
      'app_name': appName,
      'category': category.code,
      'start_time': startTime.millisecondsSinceEpoch,
      'end_time': endTime.millisecondsSinceEpoch,
      'duration': durationSeconds,
      'date': date,
    };
  }

  Duration get duration => Duration(seconds: durationSeconds);

  AppUsageRecord copyWith({
    int? id,
    String? packageName,
    String? appName,
    AppCategory? category,
    DateTime? startTime,
    DateTime? endTime,
    int? durationSeconds,
    String? date,
  }) {
    return AppUsageRecord(
      id: id ?? this.id,
      packageName: packageName ?? this.packageName,
      appName: appName ?? this.appName,
      category: category ?? this.category,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      date: date ?? this.date,
    );
  }

  @override
  String toString() {
    return 'AppUsageRecord(id: $id, packageName: $packageName, duration: ${duration.inMinutes}m, date: $date)';
  }
}
