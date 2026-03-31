import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/database/daos/daos.dart';
import 'package:qiaoqiao_companion/shared/models/models.dart';

/// 今日小时级时间线 Provider
final todayHourlyTimelineProvider = FutureProvider<HourlyTimeline>((ref) async {
  final db = AppDatabase.instance;
  final hourlyDao = HourlyUsageDao(db);
  final today = DailyStats.formatDate(DateTime.now());

  return await hourlyDao.getTimelineByDate(today);
});

/// 指定日期的小时级时间线 Provider
final hourlyTimelineProvider =
    FutureProvider.family<HourlyTimeline, String>((ref, date) async {
  final db = AppDatabase.instance;
  final hourlyDao = HourlyUsageDao(db);

  return await hourlyDao.getTimelineByDate(date);
});

/// 小时级时间线 Notifier（支持刷新）
class HourlyTimelineNotifier extends StateNotifier<AsyncValue<HourlyTimeline>> {
  final HourlyUsageDao _hourlyDao;
  Timer? _refreshTimer;

  HourlyTimelineNotifier(this._hourlyDao)
      : super(const AsyncValue.loading()) {
    load();
  }

  /// 开始定时刷新（每30秒）
  void startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => load(),
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

  /// 加载数据（首次加载时如果为空，延迟重试）
  Future<void> load() async {
    try {
      // 动态获取当前日期，确保跨天后数据能自动更新
      final today = DailyStats.formatDate(DateTime.now());
      final timeline = await _hourlyDao.getTimelineByDate(today);

      // 首次加载且数据为空时，延迟2秒重试一次
      // 这是为了解决时序问题：UsageMonitorService 可能还未同步数据到数据库
      if (state.isLoading && timeline.hourlyTotals.isEmpty) {
        Future.delayed(const Duration(seconds: 2), () => load());
      }

      state = AsyncValue.data(timeline);
    } catch (e, stack) {
      // 只有在无数据时才显示错误，刷新失败保持旧数据
      if (state.isLoading || !state.hasValue) {
        state = AsyncValue.error(e, stack);
      }
      // 否则保持现有数据，不显示错误
    }
  }

  /// 刷新数据
  Future<void> refresh() async {
    await load();
  }
}

/// 今日时间线 Notifier Provider
final todayHourlyTimelineNotifierProvider =
    StateNotifierProvider<HourlyTimelineNotifier, AsyncValue<HourlyTimeline>>(
        (ref) {
  final db = AppDatabase.instance;
  final hourlyDao = HourlyUsageDao(db);

  final notifier = HourlyTimelineNotifier(hourlyDao);
  notifier.startAutoRefresh();
  return notifier;
});
