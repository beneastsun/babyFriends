import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/features/report/domain/weekly_report.dart';
import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/database/daos/daos.dart';
import 'package:qiaoqiao_companion/shared/models/models.dart';

/// 周报服务
class WeeklyReportService {
  final DailyStatsDao _dailyStatsDao;
  final AppUsageDao _appUsageDao;

  WeeklyReportService(AppDatabase db)
      : _dailyStatsDao = DailyStatsDao(db),
        _appUsageDao = AppUsageDao(db);

  /// 生成周报
  Future<WeeklyReport> generateWeeklyReport({DateTime? endDate}) async {
    final now = endDate ?? DateTime.now();
    final startDate = now.subtract(const Duration(days: 6));

    // 获取每日统计数据
    final dailyStats = await _getDailyStats(startDate, now);

    // 获取应用使用排行
    final topApps = await _getTopApps(startDate, now);

    // 计算总时长
    final totalMinutes = dailyStats.fold<int>(
      0,
      (sum, stat) => sum + stat.totalMinutes,
    );

    // 计算分类时长
    final categoryMinutes = <String, int>{};
    for (final stat in dailyStats) {
      categoryMinutes['game'] = (categoryMinutes['game'] ?? 0) + stat.gameMinutes;
      categoryMinutes['video'] = (categoryMinutes['video'] ?? 0) + stat.videoMinutes;
      categoryMinutes['study'] = (categoryMinutes['study'] ?? 0) + stat.studyMinutes;
    }

    // 计算规则遵守率
    final compliedDays = dailyStats.where((s) => s.compliedWithRules).length;
    final complianceRate = dailyStats.isEmpty
        ? 0.0
        : compliedDays / dailyStats.length;

    // 计算星级（1-5星）
    final stars = _calculateStars(complianceRate, totalMinutes);

    // 生成评语
    final comment = _generateComment(stars, complianceRate, categoryMinutes);

    return WeeklyReport(
      startDate: startDate,
      endDate: now,
      dailyUsages: dailyStats,
      topApps: topApps,
      totalMinutes: totalMinutes,
      categoryMinutes: categoryMinutes,
      complianceRate: complianceRate,
      stars: stars,
      comment: comment,
    );
  }

  /// 获取每日统计
  Future<List<DailyUsage>> _getDailyStats(DateTime start, DateTime end) async {
    final startDateStr = DailyStats.formatDate(start);
    final endDateStr = DailyStats.formatDate(end);

    // 从数据库获取真实数据
    final dailyStatsList = await _dailyStatsDao.getByDateRange(startDateStr, endDateStr);

    // 创建日期到统计的映射
    final statsMap = <String, DailyStats>{};
    for (final stats in dailyStatsList) {
      statsMap[stats.date] = stats;
    }

    // 生成7天的数据
    final List<DailyUsage> result = [];
    for (var i = 0; i < 7; i++) {
      final date = start.add(Duration(days: i));
      final dateStr = DailyStats.formatDate(date);
      final stats = statsMap[dateStr];

      result.add(DailyUsage(
        date: date,
        totalMinutes: (stats?.totalDurationSeconds ?? 0) ~/ 60,
        gameMinutes: (stats?.gameDurationSeconds ?? 0) ~/ 60,
        videoMinutes: (stats?.videoDurationSeconds ?? 0) ~/ 60,
        studyMinutes: (stats?.studyDurationSeconds ?? 0) ~/ 60,
        compliedWithRules: stats?.rulesFollowed ?? true,
      ));
    }
    return result;
  }

  /// 获取应用使用排行
  Future<List<AppUsageRanking>> _getTopApps(DateTime start, DateTime end) async {
    final startDateStr = DailyStats.formatDate(start);
    final endDateStr = DailyStats.formatDate(end);

    // 从数据库获取指定日期范围内的使用记录
    final records = await _appUsageDao.getByDateRange(startDateStr, endDateStr);

    if (records.isEmpty) {
      return [];
    }

    // 按应用聚合使用时间
    final appUsageMap = <String, int>{};
    final appNameMap = <String, String>{};
    final appCategoryMap = <String, String>{};
    var totalSeconds = 0;

    for (final record in records) {
      final packageName = record.packageName;
      appUsageMap[packageName] = (appUsageMap[packageName] ?? 0) + record.durationSeconds;
      if (record.appName != null) {
        appNameMap[packageName] = record.appName!;
      }
      appCategoryMap[packageName] = record.category.code;
      totalSeconds += record.durationSeconds;
    }

    // 排序并取前5个
    final sortedApps = appUsageMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topApps = sortedApps.take(5).toList();

    return topApps.map((entry) {
      final packageName = entry.key;
      final seconds = entry.value;
      final percentage = totalSeconds > 0 ? seconds / totalSeconds : 0.0;

      return AppUsageRanking(
        appName: appNameMap[packageName] ?? packageName,
        packageName: packageName,
        category: appCategoryMap[packageName] ?? 'other',
        minutes: seconds ~/ 60,
        percentage: percentage,
      );
    }).toList();
  }

  /// 计算星级
  int _calculateStars(double complianceRate, int totalMinutes) {
    // 基于规则遵守率和使用时长计算星级
    if (complianceRate >= 0.9 && totalMinutes <= 14 * 60) {
      return 5;
    } else if (complianceRate >= 0.8 && totalMinutes <= 18 * 60) {
      return 4;
    } else if (complianceRate >= 0.6 && totalMinutes <= 21 * 60) {
      return 3;
    } else if (complianceRate >= 0.4 && totalMinutes <= 25 * 60) {
      return 2;
    } else {
      return 1;
    }
  }

  /// 生成评语
  String _generateComment(
    int stars,
    double complianceRate,
    Map<String, int> categoryMinutes,
  ) {
    if (stars >= 4) {
      return '太棒了！这一周表现非常出色，继续保持！';
    } else if (stars >= 3) {
      return '这一周表现不错，再努力一下会更好！';
    } else if (stars >= 2) {
      return '这一周有些松懈了，下周要加油哦！';
    } else {
      return '这周的使用习惯需要改进，让我们一起努力！';
    }
  }
}

/// 周报服务 Provider
final weeklyReportServiceProvider = Provider<WeeklyReportService>((ref) {
  final db = AppDatabase.instance;
  return WeeklyReportService(db);
});

/// 周报数据 Provider - 直接提供周报数据
final weeklyReportProvider = FutureProvider<WeeklyReport>((ref) async {
  final service = ref.watch(weeklyReportServiceProvider);
  return service.generateWeeklyReport();
});
