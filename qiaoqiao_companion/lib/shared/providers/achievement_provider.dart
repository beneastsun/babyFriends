import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/database/daos/achievement_dao.dart';
import 'package:qiaoqiao_companion/shared/models/achievement.dart';

/// 成就状态
class AchievementState {
  final List<UserAchievement> achievements;
  final int totalUnlocked;
  final bool isLoading;

  const AchievementState({
    this.achievements = const [],
    this.totalUnlocked = 0,
    this.isLoading = true,
  });

  double get overallProgress {
    if (achievements.isEmpty) return 0;
    final unlocked = achievements.where((a) => a.isUnlocked).length;
    return unlocked / AchievementDefinition.all.length;
  }

  List<UserAchievement> get unlockedAchievements =>
      achievements.where((a) => a.isUnlocked).toList();

  List<UserAchievement> get inProgressAchievements =>
      achievements.where((a) => !a.isUnlocked && a.progress > 0).toList();

  UserAchievement? getAchievement(String id) {
    try {
      return achievements.firstWhere((a) => a.achievementId == id);
    } catch (_) {
      return null;
    }
  }

  AchievementState copyWith({
    List<UserAchievement>? achievements,
    int? totalUnlocked,
    bool? isLoading,
  }) {
    return AchievementState(
      achievements: achievements ?? this.achievements,
      totalUnlocked: totalUnlocked ?? this.totalUnlocked,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// 成就管理 Notifier
class AchievementNotifier extends StateNotifier<AchievementState> {
  final AchievementDao _dao;

  AchievementNotifier(this._dao) : super(const AchievementState());

  /// 加载成就数据
  Future<void> load() async {
    final unlocked = await _dao.getUnlocked();
    final totalUnlocked = await _dao.countUnlocked();

    // 合并所有定义的成就和用户成就
    final List<UserAchievement> allAchievements = [];

    for (final def in AchievementDefinition.all) {
      final existing = unlocked.firstWhere(
        (a) => a.achievementId == def.id,
        orElse: () => UserAchievement(achievementId: def.id),
      );
      allAchievements.add(existing);
    }

    state = state.copyWith(
      achievements: allAchievements,
      totalUnlocked: totalUnlocked,
      isLoading: false,
    );
  }

  /// 更新成就进度
  Future<bool> updateProgress(String achievementId, int progress) async {
    final achievement = state.getAchievement(achievementId);
    if (achievement == null) return false;

    final def = achievement.definition;
    if (def == null) return false;

    // 如果已解锁，不再更新
    if (achievement.isUnlocked) return false;

    final newProgress = progress.clamp(0, def.requirement);
    final isNowUnlocked = newProgress >= def.requirement;

    final updated = achievement.copyWith(
      progress: newProgress,
      isUnlocked: isNowUnlocked,
    );

    await _dao.insert(updated);

    state = state.copyWith(
      achievements: state.achievements.map((a) {
        return a.achievementId == achievementId ? updated : a;
      }).toList(),
      totalUnlocked: isNowUnlocked ? state.totalUnlocked + 1 : state.totalUnlocked,
    );

    return isNowUnlocked;
  }

  /// 增加进度
  Future<bool> incrementProgress(String achievementId, {int amount = 1}) async {
    final achievement = state.getAchievement(achievementId);
    if (achievement == null) return false;
    return updateProgress(achievementId, achievement.progress + amount);
  }

  /// 检查并更新连续天数成就
  Future<void> checkStreakAchievements(int currentStreak) async {
    for (final def in AchievementDefinition.all) {
      if (def.type == AchievementType.streak) {
        await updateProgress(def.id, currentStreak);
      }
    }
  }

  /// 检查并更新总积分成就
  Future<void> checkTotalPointsAchievements(int totalPoints) async {
    for (final def in AchievementDefinition.all) {
      if (def.type == AchievementType.totalPoints) {
        await updateProgress(def.id, totalPoints);
      }
    }
  }

  /// 检查并更新按时休息成就
  Future<void> checkRestOnTimeAchievements(int totalRestCount) async {
    for (final def in AchievementDefinition.all) {
      if (def.type == AchievementType.restOnTime) {
        await updateProgress(def.id, totalRestCount);
      }
    }
  }

  /// 刷新数据
  Future<void> refresh() async {
    await load();
  }
}

/// 成就状态 Provider
final achievementProvider =
    StateNotifierProvider<AchievementNotifier, AchievementState>((ref) {
  final db = AppDatabase.instance;
  return AchievementNotifier(AchievementDao(db));
});
