import 'package:qiaoqiao_companion/core/constants/database_constants.dart';

/// 蛋仔周进度模型
class EggWeeklyProgress {
  final int? id;
  final String weekStart;           // 周一日期 YYYY-MM-DD
  final int totalTaskCount;         // 本周应完成任务总天数
  final int completedTaskCount;     // 本周已达标任务天数
  final int highestStage;           // 本周达到过的最高阶段
  final EggStyle eggStyle;          // 当前蛋仔风格
  final DateTime updatedAt;

  EggWeeklyProgress({
    this.id,
    required this.weekStart,
    required this.totalTaskCount,
    required this.completedTaskCount,
    required this.highestStage,
    required this.eggStyle,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  factory EggWeeklyProgress.fromMap(Map<String, dynamic> map) {
    return EggWeeklyProgress(
      id: map['id'] as int?,
      weekStart: map['week_start'] as String,
      totalTaskCount: map['total_task_count'] as int,
      completedTaskCount: map['completed_task_count'] as int,
      highestStage: map['highest_stage'] as int,
      eggStyle: EggStyle.fromCode(map['egg_style'] as String),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'week_start': weekStart,
      'total_task_count': totalTaskCount,
      'completed_task_count': completedTaskCount,
      'highest_stage': highestStage,
      'egg_style': eggStyle.code,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  /// 周完成率 (0.0 ~ 1.0)
  double get completionRate =>
      totalTaskCount == 0 ? 0.0 : completedTaskCount / totalTaskCount;

  /// 当前阶段 (0~4)
  /// stage = (completionRate * 5).floor().clamp(0, 4)
  int get stage => (completionRate * 5).floor().clamp(0, 4);

  EggWeeklyProgress copyWith({
    int? id,
    String? weekStart,
    int? totalTaskCount,
    int? completedTaskCount,
    int? highestStage,
    EggStyle? eggStyle,
    DateTime? updatedAt,
  }) {
    return EggWeeklyProgress(
      id: id ?? this.id,
      weekStart: weekStart ?? this.weekStart,
      totalTaskCount: totalTaskCount ?? this.totalTaskCount,
      completedTaskCount: completedTaskCount ?? this.completedTaskCount,
      highestStage: highestStage ?? this.highestStage,
      eggStyle: eggStyle ?? this.eggStyle,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'EggWeeklyProgress(week: $weekStart, completed: $completedTaskCount/$totalTaskCount, stage: $stage, style: $eggStyle)';
  }
}
