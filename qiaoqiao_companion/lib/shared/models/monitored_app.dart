/// 被监控的应用
class MonitoredApp {
  final String packageName;
  final String? appName;
  final int? dailyLimitMinutes;  // NULL 表示无限制
  final String? category;
  final bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MonitoredApp({
    required this.packageName,
    this.appName,
    this.dailyLimitMinutes,
    this.category,
    this.enabled = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MonitoredApp.fromMap(Map<String, dynamic> map) {
    return MonitoredApp(
      packageName: map['package_name'] as String,
      appName: map['app_name'] as String?,
      dailyLimitMinutes: map['daily_limit_minutes'] as int?,
      category: map['category'] as String?,
      enabled: (map['enabled'] as int?) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'package_name': packageName,
      'app_name': appName,
      'daily_limit_minutes': dailyLimitMinutes,
      'category': category,
      'enabled': enabled ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  MonitoredApp copyWith({
    String? packageName,
    String? appName,
    int? dailyLimitMinutes,
    bool? clearDailyLimit,
    String? category,
    bool? enabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MonitoredApp(
      packageName: packageName ?? this.packageName,
      appName: appName ?? this.appName,
      dailyLimitMinutes: clearDailyLimit == true
          ? null
          : (dailyLimitMinutes ?? this.dailyLimitMinutes),
      category: category ?? this.category,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'MonitoredApp($packageName, limit: $dailyLimitMinutes min)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MonitoredApp &&
          runtimeType == other.runtimeType &&
          packageName == other.packageName;

  @override
  int get hashCode => packageName.hashCode;
}
