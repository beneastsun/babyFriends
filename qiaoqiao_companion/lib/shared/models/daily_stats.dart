/// 每日统计模型
class DailyStats {
  final int? id;
  final String date;
  final int totalDurationSeconds;
  final int gameDurationSeconds;
  final int videoDurationSeconds;
  final int studyDurationSeconds;
  final int pointsEarned;
  final bool rulesFollowed;
  final DateTime createdAt;
  final DateTime updatedAt;

  DailyStats({
    this.id,
    required this.date,
    this.totalDurationSeconds = 0,
    this.gameDurationSeconds = 0,
    this.videoDurationSeconds = 0,
    this.studyDurationSeconds = 0,
    this.pointsEarned = 0,
    this.rulesFollowed = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory DailyStats.fromMap(Map<String, dynamic> map) {
    return DailyStats(
      id: map['id'] as int?,
      date: map['date'] as String,
      totalDurationSeconds: map['total_duration'] as int? ?? 0,
      gameDurationSeconds: map['game_duration'] as int? ?? 0,
      videoDurationSeconds: map['video_duration'] as int? ?? 0,
      studyDurationSeconds: map['study_duration'] as int? ?? 0,
      pointsEarned: map['points_earned'] as int? ?? 0,
      rulesFollowed: (map['rules_followed'] as int?) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'date': date,
      'total_duration': totalDurationSeconds,
      'game_duration': gameDurationSeconds,
      'video_duration': videoDurationSeconds,
      'study_duration': studyDurationSeconds,
      'points_earned': pointsEarned,
      'rules_followed': rulesFollowed ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };
  }

  Duration get totalDuration => Duration(seconds: totalDurationSeconds);
  Duration get gameDuration => Duration(seconds: gameDurationSeconds);
  Duration get videoDuration => Duration(seconds: videoDurationSeconds);
  Duration get studyDuration => Duration(seconds: studyDurationSeconds);

  /// 创建空的每日统计
  factory DailyStats.empty(String date) {
    return DailyStats(date: date);
  }

  /// 获取日期字符串 (YYYY-MM-DD)
  static String formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  DailyStats copyWith({
    int? id,
    String? date,
    int? totalDurationSeconds,
    int? gameDurationSeconds,
    int? videoDurationSeconds,
    int? studyDurationSeconds,
    int? pointsEarned,
    bool? rulesFollowed,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DailyStats(
      id: id ?? this.id,
      date: date ?? this.date,
      totalDurationSeconds: totalDurationSeconds ?? this.totalDurationSeconds,
      gameDurationSeconds: gameDurationSeconds ?? this.gameDurationSeconds,
      videoDurationSeconds: videoDurationSeconds ?? this.videoDurationSeconds,
      studyDurationSeconds: studyDurationSeconds ?? this.studyDurationSeconds,
      pointsEarned: pointsEarned ?? this.pointsEarned,
      rulesFollowed: rulesFollowed ?? this.rulesFollowed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'DailyStats(date: $date, total: ${totalDuration.inMinutes}m, points: $pointsEarned)';
  }
}
