/// 时间段模式
enum TimePeriodMode {
  blocked('blocked', '禁用时段'),
  allowed('allowed', '开放时段');

  final String code;
  final String label;
  const TimePeriodMode(this.code, this.label);

  static TimePeriodMode fromCode(String code) {
    return TimePeriodMode.values.firstWhere(
      (e) => e.code == code,
      orElse: () => TimePeriodMode.blocked,
    );
  }
}

/// 时间段
class TimePeriod {
  final int? id;
  final TimePeriodMode mode;
  final String timeStart; // "HH:mm"
  final String timeEnd; // "HH:mm"
  final List<int> days; // 1=周一, 7=周日
  final bool enabled;
  final DateTime createdAt;

  const TimePeriod({
    this.id,
    required this.mode,
    required this.timeStart,
    required this.timeEnd,
    required this.days,
    this.enabled = true,
    required this.createdAt,
  });

  factory TimePeriod.fromMap(Map<String, dynamic> map) {
    final daysStr = map['days'] as String? ?? '1,2,3,4,5,6,7';
    final daysList = _parseDays(daysStr);

    return TimePeriod(
      id: map['id'] as int?,
      mode: TimePeriodMode.fromCode(map['mode'] as String? ?? 'blocked'),
      timeStart: map['time_start'] as String,
      timeEnd: map['time_end'] as String,
      days: daysList,
      enabled: (map['enabled'] as int?) == 1,
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  static List<int> _parseDays(String daysStr) {
    try {
      return daysStr
          .split(',')
          .where((s) => s.isNotEmpty)
          .map(int.parse)
          .toList();
    } catch (e) {
      return [1, 2, 3, 4, 5, 6, 7]; // 默认全部
    }
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'mode': mode.code,
      'time_start': timeStart,
      'time_end': timeEnd,
      'days': days.join(','),
      'enabled': enabled ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  /// 检查是否跨天
  bool get isCrossDay => timeStart.compareTo(timeEnd) > 0;

  /// 检查指定时间是否在时间段内
  bool containsTime(String currentTime) {
    if (isCrossDay) {
      // 跨天：当前时间 >= start 或 < end
      return currentTime.compareTo(timeStart) >= 0 ||
          currentTime.compareTo(timeEnd) < 0;
    } else {
      // 同一天：当前时间 >= start 且 < end
      return currentTime.compareTo(timeStart) >= 0 &&
          currentTime.compareTo(timeEnd) < 0;
    }
  }

  /// 检查指定日期是否适用
  bool appliesToWeekday(int weekday) {
    return days.contains(weekday);
  }

  /// 获取显示文本
  String get displayText {
    final dayNames = ['一', '二', '三', '四', '五', '六', '日'];
    final daysText = days.map((d) => dayNames[d - 1]).join('');
    return '$timeStart - $timeEnd (周$daysText)';
  }

  TimePeriod copyWith({
    int? id,
    TimePeriodMode? mode,
    String? timeStart,
    String? timeEnd,
    List<int>? days,
    bool? enabled,
    DateTime? createdAt,
  }) {
    return TimePeriod(
      id: id ?? this.id,
      mode: mode ?? this.mode,
      timeStart: timeStart ?? this.timeStart,
      timeEnd: timeEnd ?? this.timeEnd,
      days: days ?? this.days,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'TimePeriod($timeStart-$timeEnd, mode: $mode, days: $days)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimePeriod &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
