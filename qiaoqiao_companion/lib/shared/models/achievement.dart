import 'package:qiaoqiao_companion/core/constants/database_constants.dart';

/// 成就类型
enum AchievementType {
  streak,       // 连续天数
  totalPoints,  // 累计积分
  restOnTime,   // 按时休息次数
  study,        // 学习相关
  exercise,     // 运动相关
  reading,      // 阅读相关
  special,      // 特殊成就
}

/// 成就定义
class AchievementDefinition {
  final String id;
  final String name;
  final String description;
  final AchievementType type;
  final int requirement;      // 达成条件数值
  final int rewardPoints;     // 奖励积分
  final String emoji;         // 成就图标
  final int tier;             // 等级 (1=铜, 2=银, 3=金)

  const AchievementDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.requirement,
    required this.rewardPoints,
    required this.emoji,
    this.tier = 1,
  });

  /// 所有成就定义
  static const List<AchievementDefinition> all = [
    // 连续天数成就
    AchievementDefinition(
      id: 'streak_3',
      name: '初露锋芒',
      description: '连续3天遵守规则',
      type: AchievementType.streak,
      requirement: 3,
      rewardPoints: 30,
      emoji: '🌱',
      tier: 1,
    ),
    AchievementDefinition(
      id: 'streak_7',
      name: '坚持不懈',
      description: '连续7天遵守规则',
      type: AchievementType.streak,
      requirement: 7,
      rewardPoints: 50,
      emoji: '🌿',
      tier: 2,
    ),
    AchievementDefinition(
      id: 'streak_14',
      name: '习惯养成',
      description: '连续14天遵守规则',
      type: AchievementType.streak,
      requirement: 14,
      rewardPoints: 80,
      emoji: '🌳',
      tier: 2,
    ),
    AchievementDefinition(
      id: 'streak_30',
      name: '自律达人',
      description: '连续30天遵守规则',
      type: AchievementType.streak,
      requirement: 30,
      rewardPoints: 150,
      emoji: '🏆',
      tier: 3,
    ),

    // 累计积分成就
    AchievementDefinition(
      id: 'points_100',
      name: '小小积累',
      description: '累计获得100积分',
      type: AchievementType.totalPoints,
      requirement: 100,
      rewardPoints: 20,
      emoji: '⭐',
      tier: 1,
    ),
    AchievementDefinition(
      id: 'points_500',
      name: '积少成多',
      description: '累计获得500积分',
      type: AchievementType.totalPoints,
      requirement: 500,
      rewardPoints: 50,
      emoji: '🌟',
      tier: 2,
    ),
    AchievementDefinition(
      id: 'points_1000',
      name: '积分大师',
      description: '累计获得1000积分',
      type: AchievementType.totalPoints,
      requirement: 1000,
      rewardPoints: 100,
      emoji: '💫',
      tier: 3,
    ),

    // 按时休息成就
    AchievementDefinition(
      id: 'rest_10',
      name: '休息小能手',
      description: '按时休息10次',
      type: AchievementType.restOnTime,
      requirement: 10,
      rewardPoints: 30,
      emoji: '😴',
      tier: 1,
    ),
    AchievementDefinition(
      id: 'rest_50',
      name: '健康达人',
      description: '按时休息50次',
      type: AchievementType.restOnTime,
      requirement: 50,
      rewardPoints: 80,
      emoji: '💪',
      tier: 2,
    ),
    AchievementDefinition(
      id: 'rest_100',
      name: '护眼卫士',
      description: '按时休息100次',
      type: AchievementType.restOnTime,
      requirement: 100,
      rewardPoints: 150,
      emoji: '👁️',
      tier: 3,
    ),

    // 学习成就
    AchievementDefinition(
      id: 'study_first',
      name: '学海初探',
      description: '首次完成学习任务',
      type: AchievementType.study,
      requirement: 1,
      rewardPoints: 20,
      emoji: '📚',
      tier: 1,
    ),
    AchievementDefinition(
      id: 'study_20',
      name: '勤奋学子',
      description: '完成20次学习任务',
      type: AchievementType.study,
      requirement: 20,
      rewardPoints: 60,
      emoji: '🎓',
      tier: 2,
    ),

    // 运动成就
    AchievementDefinition(
      id: 'exercise_first',
      name: '运动起步',
      description: '首次完成运动目标',
      type: AchievementType.exercise,
      requirement: 1,
      rewardPoints: 20,
      emoji: '🏃',
      tier: 1,
    ),
    AchievementDefinition(
      id: 'exercise_20',
      name: '活力少年',
      description: '完成20次运动目标',
      type: AchievementType.exercise,
      requirement: 20,
      rewardPoints: 60,
      emoji: '🏅',
      tier: 2,
    ),

    // 阅读成就
    AchievementDefinition(
      id: 'reading_first',
      name: '书虫初生',
      description: '首次完成阅读目标',
      type: AchievementType.reading,
      requirement: 1,
      rewardPoints: 20,
      emoji: '📖',
      tier: 1,
    ),
    AchievementDefinition(
      id: 'reading_20',
      name: '博览群书',
      description: '完成20次阅读目标',
      type: AchievementType.reading,
      requirement: 20,
      rewardPoints: 60,
      emoji: '🏅',
      tier: 2,
    ),

    // 特殊成就
    AchievementDefinition(
      id: 'early_bird',
      name: '早起鸟儿',
      description: '连续7天早起',
      type: AchievementType.special,
      requirement: 7,
      rewardPoints: 50,
      emoji: '🐦',
      tier: 2,
    ),
    AchievementDefinition(
      id: 'perfect_week',
      name: '完美一周',
      description: '一周内无任何违规',
      type: AchievementType.special,
      requirement: 7,
      rewardPoints: 100,
      emoji: '👑',
      tier: 3,
    ),
  ];

  static AchievementDefinition? getById(String id) {
    try {
      return all.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }
}

/// 用户成就记录
class UserAchievement {
  final String achievementId;
  final DateTime unlockedAt;
  final int progress;           // 当前进度
  final bool isUnlocked;

  UserAchievement({
    required this.achievementId,
    DateTime? unlockedAt,
    this.progress = 0,
    this.isUnlocked = false,
  }) : unlockedAt = unlockedAt ?? DateTime.now();

  factory UserAchievement.fromMap(Map<String, dynamic> map) {
    return UserAchievement(
      achievementId: map['achievement_id'] as String,
      unlockedAt: map['unlocked_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['unlocked_at'] as int)
          : DateTime.now(),
      progress: map['progress'] as int? ?? 0,
      isUnlocked: (map['is_unlocked'] as int?) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'achievement_id': achievementId,
      'unlocked_at': unlockedAt.millisecondsSinceEpoch,
      'progress': progress,
      'is_unlocked': isUnlocked ? 1 : 0,
    };
  }

  AchievementDefinition? get definition => AchievementDefinition.getById(achievementId);

  double get progressPercent {
    final def = definition;
    if (def == null || def.requirement == 0) return 0;
    return (progress / def.requirement).clamp(0.0, 1.0);
  }

  UserAchievement copyWith({
    String? achievementId,
    DateTime? unlockedAt,
    int? progress,
    bool? isUnlocked,
  }) {
    return UserAchievement(
      achievementId: achievementId ?? this.achievementId,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      progress: progress ?? this.progress,
      isUnlocked: isUnlocked ?? this.isUnlocked,
    );
  }
}
