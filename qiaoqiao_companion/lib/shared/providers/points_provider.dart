import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/database/daos/daos.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';
import 'package:qiaoqiao_companion/shared/models/models.dart';

/// 积分状态
class PointsState {
  final int balance;
  final List<PointsHistory> recentHistory;
  final int todayEarned;

  const PointsState({
    this.balance = 0,
    this.recentHistory = const [],
    this.todayEarned = 0,
  });

  bool get canEarnMore => balance < PointsConstants.maxPoints;
  int get availableToEarn => PointsConstants.maxPoints - balance;

  PointsState copyWith({
    int? balance,
    List<PointsHistory>? recentHistory,
    int? todayEarned,
  }) {
    return PointsState(
      balance: balance ?? this.balance,
      recentHistory: recentHistory ?? this.recentHistory,
      todayEarned: todayEarned ?? this.todayEarned,
    );
  }
}

/// 积分状态 Notifier
class PointsNotifier extends StateNotifier<PointsState> {
  final PointsDao _pointsDao;

  PointsNotifier(this._pointsDao) : super(const PointsState());

  /// 加载积分数据
  Future<void> load() async {
    final balance = await _pointsDao.getCurrentBalance();
    final history = await _pointsDao.getAll(limit: 20);
    final today = DailyStats.formatDate(DateTime.now());
    final todayEarned = await _pointsDao.getPointsEarnedByDate(today);

    state = state.copyWith(
      balance: balance,
      recentHistory: history,
      todayEarned: todayEarned,
    );
  }

  /// 添加积分
  Future<bool> addPoints(int amount, String reason) async {
    final newBalance = await _pointsDao.addPoints(amount, reason);
    state = state.copyWith(
      balance: newBalance,
      todayEarned: state.todayEarned + amount,
    );
    return true;
  }

  /// 消耗积分
  Future<bool> deductPoints(int amount, String reason) async {
    final result = await _pointsDao.deductPoints(amount, reason);
    if (result != null) {
      state = state.copyWith(balance: result);
      return true;
    }
    return false;
  }

  /// 奖励按时结束
  Future<void> rewardEndingEarly() async {
    await addPoints(
      PointsConstants.pointsForEndingEarly,
      '按时主动结束使用',
    );
  }

  /// 奖励遵守每日限制
  Future<void> rewardDailyLimit() async {
    await addPoints(
      PointsConstants.pointsForDailyLimit,
      '遵守每日时间限制',
    );
  }

  /// 奖励遵守禁止时段
  Future<void> rewardForbiddenTime() async {
    await addPoints(
      PointsConstants.pointsForForbiddenTime,
      '遵守禁止时段规则',
    );
  }

  /// 奖励连续3天遵守规则
  Future<void> rewardStreak() async {
    await addPoints(
      PointsConstants.pointsForStreak3Days,
      '连续3天遵守规则',
    );
  }

  /// 刷新数据
  Future<void> refresh() async {
    await load();
  }
}

/// 积分状态 Provider
final pointsProvider =
    StateNotifierProvider<PointsNotifier, PointsState>((ref) {
  final db = AppDatabase.instance;
  return PointsNotifier(PointsDao(db));
});
