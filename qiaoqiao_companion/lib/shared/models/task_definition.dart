import 'package:qiaoqiao_companion/core/constants/database_constants.dart';

/// 任务定义模型
class TaskDefinition {
  final int? id;
  final String name;
  final String emoji;
  final TaskCategory category;
  final int basePoints;
  final int extraPoints;
  final int minDailyCount;
  final int maxDailyCount;
  final int? dailyPointsCap;
  final CheckinMode checkinMode;
  final int penaltyMinutes;
  final String? reminderTime;           // 提醒时间 HH:MM
  final int reminderRepeatInterval;     // 重复间隔分钟（0=不重复）
  final bool enabled;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  TaskDefinition({
    this.id,
    required this.name,
    this.emoji = '⭐',
    required this.category,
    this.basePoints = 10,
    this.extraPoints = 0,
    this.minDailyCount = 1,
    this.maxDailyCount = 1,
    this.dailyPointsCap,
    this.checkinMode = CheckinMode.self,
    this.penaltyMinutes = 0,
    this.reminderTime,
    this.reminderRepeatInterval = 0,
    this.enabled = true,
    this.sortOrder = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// 积分类别映射
  PointsCategory get pointsCategory => switch (category) {
        TaskCategory.health => PointsCategory.exerciseReward,
        TaskCategory.study => PointsCategory.studyReward,
        TaskCategory.chore => PointsCategory.choreReward,
        TaskCategory.discipline => PointsCategory.restReward,
      };

  factory TaskDefinition.fromMap(Map<String, dynamic> map) {
    return TaskDefinition(
      id: map['id'] as int?,
      name: map['name'] as String,
      emoji: map['emoji'] as String? ?? '⭐',
      category: TaskCategory.fromCode(map['category'] as String),
      basePoints: map['base_points'] as int? ?? 10,
      extraPoints: map['extra_points'] as int? ?? 0,
      minDailyCount: map['min_daily_count'] as int? ?? 1,
      maxDailyCount: map['max_daily_count'] as int? ?? 1,
      dailyPointsCap: map['daily_points_cap'] as int?,
      checkinMode: CheckinMode.fromCode(map['checkin_mode'] as String? ?? 'self'),
      penaltyMinutes: map['penalty_minutes'] as int? ?? 0,
      reminderTime: map['reminder_time'] as String?,
      reminderRepeatInterval: (map['reminder_repeat_interval'] as int?) ?? 0,
      enabled: (map['enabled'] as int? ?? 1) == 1,
      sortOrder: map['sort_order'] as int? ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'emoji': emoji,
      'category': category.code,
      'base_points': basePoints,
      'extra_points': extraPoints,
      'min_daily_count': minDailyCount,
      'max_daily_count': maxDailyCount,
      'daily_points_cap': dailyPointsCap,
      'checkin_mode': checkinMode.code,
      'penalty_minutes': penaltyMinutes,
      if (reminderTime != null) 'reminder_time': reminderTime,
      'reminder_repeat_interval': reminderRepeatInterval,
      'enabled': enabled ? 1 : 0,
      'sort_order': sortOrder,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  TaskDefinition copyWith({
    int? id,
    String? name,
    String? emoji,
    TaskCategory? category,
    int? basePoints,
    int? extraPoints,
    int? minDailyCount,
    int? maxDailyCount,
    int? dailyPointsCap,
    CheckinMode? checkinMode,
    int? penaltyMinutes,
    String? reminderTime,
    int? reminderRepeatInterval,
    bool? enabled,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TaskDefinition(
      id: id ?? this.id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      category: category ?? this.category,
      basePoints: basePoints ?? this.basePoints,
      extraPoints: extraPoints ?? this.extraPoints,
      minDailyCount: minDailyCount ?? this.minDailyCount,
      maxDailyCount: maxDailyCount ?? this.maxDailyCount,
      dailyPointsCap: dailyPointsCap ?? this.dailyPointsCap,
      checkinMode: checkinMode ?? this.checkinMode,
      penaltyMinutes: penaltyMinutes ?? this.penaltyMinutes,
      reminderTime: reminderTime ?? this.reminderTime,
      reminderRepeatInterval: reminderRepeatInterval ?? this.reminderRepeatInterval,
      enabled: enabled ?? this.enabled,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'TaskDefinition(id: $id, name: $name, category: $category, checkinMode: $checkinMode)';
  }
}
