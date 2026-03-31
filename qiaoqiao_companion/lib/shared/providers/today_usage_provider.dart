import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/database/database_service.dart';
import 'package:qiaoqiao_companion/core/database/daos/daos.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';
import 'package:qiaoqiao_companion/shared/models/models.dart';

/// 今日使用状态
class TodayUsage {
  final int totalDurationSeconds;
  final int gameDurationSeconds;
  final int videoDurationSeconds;
  final int studyDurationSeconds;
  final int totalLimitMinutes;
  final int gameLimitMinutes;
  final int videoLimitMinutes;
  final List<AppUsageRecord> recentRecords;

  const TodayUsage({
    this.totalDurationSeconds = 0,
    this.gameDurationSeconds = 0,
    this.videoDurationSeconds = 0,
    this.studyDurationSeconds = 0,
    this.totalLimitMinutes = 120,
    this.gameLimitMinutes = 30,
    this.videoLimitMinutes = 30,
    this.recentRecords = const [],
  });

  Duration get totalDuration => Duration(seconds: totalDurationSeconds);
  Duration get gameDuration => Duration(seconds: gameDurationSeconds);
  Duration get videoDuration => Duration(seconds: videoDurationSeconds);
  Duration get studyDuration => Duration(seconds: studyDurationSeconds);

  Duration get totalLimit => Duration(minutes: totalLimitMinutes);
  Duration get gameLimit => Duration(minutes: gameLimitMinutes);
  Duration get videoLimit => Duration(minutes: videoLimitMinutes);

  Duration get totalRemaining => totalLimit - totalDuration;
  Duration get gameRemaining => gameLimit - gameDuration;
  Duration get videoRemaining => videoLimit - videoDuration;

  double get totalProgress =>
      (totalDurationSeconds / (totalLimitMinutes * 60)).clamp(0.0, 1.0);
  double get gameProgress =>
      (gameDurationSeconds / (gameLimitMinutes * 60)).clamp(0.0, 1.0);
  double get videoProgress =>
      (videoDurationSeconds / (videoLimitMinutes * 60)).clamp(0.0, 1.0);

  bool get isTotalExceeded => totalDuration >= totalLimit;
  bool get isGameExceeded => gameDuration >= gameLimit;
  bool get isVideoExceeded => videoDuration >= videoLimit;

  bool get isNearTotalLimit => totalRemaining.inMinutes <= 5;
  bool get isNearGameLimit => gameRemaining.inMinutes <= 5;
  bool get isNearVideoLimit => videoRemaining.inMinutes <= 5;

  TodayUsage copyWith({
    int? totalDurationSeconds,
    int? gameDurationSeconds,
    int? videoDurationSeconds,
    int? studyDurationSeconds,
    int? totalLimitMinutes,
    int? gameLimitMinutes,
    int? videoLimitMinutes,
    List<AppUsageRecord>? recentRecords,
  }) {
    return TodayUsage(
      totalDurationSeconds:
          totalDurationSeconds ?? this.totalDurationSeconds,
      gameDurationSeconds: gameDurationSeconds ?? this.gameDurationSeconds,
      videoDurationSeconds: videoDurationSeconds ?? this.videoDurationSeconds,
      studyDurationSeconds: studyDurationSeconds ?? this.studyDurationSeconds,
      totalLimitMinutes: totalLimitMinutes ?? this.totalLimitMinutes,
      gameLimitMinutes: gameLimitMinutes ?? this.gameLimitMinutes,
      videoLimitMinutes: videoLimitMinutes ?? this.videoLimitMinutes,
      recentRecords: recentRecords ?? this.recentRecords,
    );
  }
}

/// 今日使用状态 Notifier
class TodayUsageNotifier extends StateNotifier<TodayUsage> {
  final DailyStatsDao _dailyStatsDao;
  final AppUsageDao _appUsageDao;
  final RuleDao _ruleDao;
  Timer? _refreshTimer;

  TodayUsageNotifier(this._dailyStatsDao, this._appUsageDao, this._ruleDao)
      : super(const TodayUsage());

  /// 开始定时刷新（每30秒）
  void startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => refresh(),
    );
  }

  /// 停止定时刷新
  void stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// 加载今日数据
  Future<void> loadToday() async {
    final today = DailyStats.formatDate(DateTime.now());

    // 获取有限制规则的应用包名列表
    final restrictedPackages = await _ruleDao.getRestrictedPackageNames();

    // 获取规则限制
    final rules = await _ruleDao.getEnabled();
    final totalRule = rules.firstWhere(
      (r) => r.ruleType == RuleType.totalTime,
      orElse: () => Rule(
        ruleType: RuleType.totalTime,
        weekdayLimitMinutes: 120,
        weekendLimitMinutes: 180,
      ),
    );
    final gameRule = rules.firstWhere(
      (r) => r.ruleType == RuleType.appCategory && r.target == 'game',
      orElse: () => Rule(
        ruleType: RuleType.appCategory,
        target: 'game',
        weekdayLimitMinutes: 30,
        weekendLimitMinutes: 30,
      ),
    );
    final videoRule = rules.firstWhere(
      (r) => r.ruleType == RuleType.appCategory && r.target == 'video',
      orElse: () => Rule(
        ruleType: RuleType.appCategory,
        target: 'video',
        weekdayLimitMinutes: 30,
        weekendLimitMinutes: 30,
      ),
    );

    // 只统计有限制规则的app使用时间
    int totalDuration = 0;
    int gameDuration = 0;
    int videoDuration = 0;

    if (restrictedPackages.isNotEmpty) {
      totalDuration = await _appUsageDao.getTotalDurationByPackageNamesAndDate(
        restrictedPackages,
        today,
      );
      gameDuration = await _appUsageDao.getTotalDurationByPackageNamesAndCategoryAndDate(
        restrictedPackages,
        AppCategory.game,
        today,
      );
      videoDuration = await _appUsageDao.getTotalDurationByPackageNamesAndCategoryAndDate(
        restrictedPackages,
        AppCategory.video,
        today,
      );
    }

    // 获取最近使用记录（只返回有限制规则的app）
    final allRecords = await _appUsageDao.getByDate(today);
    final filteredRecords = allRecords
        .where((r) => restrictedPackages.contains(r.packageName))
        .toList();

    state = state.copyWith(
      totalDurationSeconds: totalDuration,
      gameDurationSeconds: gameDuration,
      videoDurationSeconds: videoDuration,
      studyDurationSeconds: 0, // 暂不统计学习类
      totalLimitMinutes: totalRule.getLimitForDate(DateTime.now()) ?? 120,
      gameLimitMinutes: gameRule.getLimitForDate(DateTime.now()) ?? 30,
      videoLimitMinutes: videoRule.getLimitForDate(DateTime.now()) ?? 30,
      recentRecords: filteredRecords,
    );
  }

  /// 更新使用时间
  void updateUsage({
    int? totalDelta,
    int? gameDelta,
    int? videoDelta,
    int? studyDelta,
  }) {
    state = state.copyWith(
      totalDurationSeconds:
          totalDelta != null ? state.totalDurationSeconds + totalDelta : null,
      gameDurationSeconds:
          gameDelta != null ? state.gameDurationSeconds + gameDelta : null,
      videoDurationSeconds:
          videoDelta != null ? state.videoDurationSeconds + videoDelta : null,
      studyDurationSeconds:
          studyDelta != null ? state.studyDurationSeconds + studyDelta : null,
    );
  }

  /// 刷新数据
  Future<void> refresh() async {
    await loadToday();
  }
}

/// 数据库服务 Provider
final databaseServiceProvider = FutureProvider<DatabaseService>((ref) async {
  return await DatabaseService.getInstance();
});

/// 今日使用状态 Provider
final todayUsageProvider =
    StateNotifierProvider<TodayUsageNotifier, TodayUsage>((ref) {
  final db = AppDatabase.instance;
  final notifier = TodayUsageNotifier(
    DailyStatsDao(db),
    AppUsageDao(db),
    RuleDao(db),
  );
  // Start auto-refresh and initial load
  notifier.startAutoRefresh();
  notifier.loadToday();
  return notifier;
});

/// 剩余时间 Provider（自动计算）
final remainingTimeProvider = Provider<Duration>((ref) {
  final usage = ref.watch(todayUsageProvider);
  return usage.totalRemaining;
});
