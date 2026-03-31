import 'dart:convert';

/// 连续使用会话
class ContinuousSession {
  final int? id;
  final String sessionDate; // "YYYY-MM-DD"
  final DateTime startTime;
  final int totalDurationSeconds;
  final DateTime? lastActivityTime;
  final DateTime? restEndTime; // 强制休息结束时间
  final Set<String> alertsShown; // 已显示的提醒级别
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ContinuousSession({
    this.id,
    required this.sessionDate,
    required this.startTime,
    this.totalDurationSeconds = 0,
    this.lastActivityTime,
    this.restEndTime,
    this.alertsShown = const {},
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ContinuousSession.fromMap(Map<String, dynamic> map) {
    final alertsStr = map['alerts_shown'] as String?;
    Set<String> alerts = {};
    if (alertsStr != null && alertsStr.isNotEmpty) {
      try {
        final list = jsonDecode(alertsStr) as List;
        alerts = list.map((e) => e.toString()).toSet();
      } catch (e) {
        // 解析失败，使用空集合
      }
    }

    return ContinuousSession(
      id: map['id'] as int?,
      sessionDate: map['session_date'] as String,
      startTime:
          DateTime.fromMillisecondsSinceEpoch(map['start_time'] as int),
      totalDurationSeconds: map['total_duration_seconds'] as int? ?? 0,
      lastActivityTime: map['last_activity_time'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['last_activity_time'] as int)
          : null,
      restEndTime: map['rest_end_time'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['rest_end_time'] as int)
          : null,
      alertsShown: alerts,
      isActive: (map['is_active'] as int?) == 1,
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt:
          DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'session_date': sessionDate,
      'start_time': startTime.millisecondsSinceEpoch,
      'total_duration_seconds': totalDurationSeconds,
      'last_activity_time': lastActivityTime?.millisecondsSinceEpoch,
      'rest_end_time': restEndTime?.millisecondsSinceEpoch,
      'alerts_shown':
          alertsShown.isEmpty ? null : jsonEncode(alertsShown.toList()),
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  /// 是否处于强制休息中
  bool get isInRest {
    if (restEndTime == null) return false;
    return restEndTime!.isAfter(DateTime.now());
  }

  /// 剩余休息时间（秒）
  int? get remainingRestSeconds {
    if (restEndTime == null) return null;
    final remaining = restEndTime!.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  /// 累计使用时长（分钟）
  int get totalDurationMinutes => totalDurationSeconds ~/ 60;

  ContinuousSession copyWith({
    int? id,
    String? sessionDate,
    DateTime? startTime,
    int? totalDurationSeconds,
    DateTime? lastActivityTime,
    DateTime? restEndTime,
    bool? clearRestEndTime,
    Set<String>? alertsShown,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ContinuousSession(
      id: id ?? this.id,
      sessionDate: sessionDate ?? this.sessionDate,
      startTime: startTime ?? this.startTime,
      totalDurationSeconds:
          totalDurationSeconds ?? this.totalDurationSeconds,
      lastActivityTime: lastActivityTime ?? this.lastActivityTime,
      restEndTime:
          clearRestEndTime == true ? null : (restEndTime ?? this.restEndTime),
      alertsShown: alertsShown ?? this.alertsShown,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'ContinuousSession(date: $sessionDate, duration: ${totalDurationSeconds}s)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContinuousSession &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
