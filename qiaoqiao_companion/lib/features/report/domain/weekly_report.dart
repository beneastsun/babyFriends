/// 周报数据模型
class WeeklyReport {
  final DateTime startDate;
  final DateTime endDate;
  final List<DailyUsage> dailyUsages;
  final List<AppUsageRanking> topApps;
  final int totalMinutes;
  final Map<String, int> categoryMinutes;
  final double complianceRate;
  final int stars;
  final String comment;

  const WeeklyReport({
    required this.startDate,
    required this.endDate,
    required this.dailyUsages,
    required this.topApps,
    required this.totalMinutes,
    required this.categoryMinutes,
    required this.complianceRate,
    required this.stars,
    required this.comment,
  });

  /// 总使用时长（格式化）
  String get formattedTotalTime {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours > 0) {
      return '$hours小时$minutes分钟';
    }
    return '$minutes分钟';
  }

  /// 平均每日使用时长
  int get averageDailyMinutes {
    if (dailyUsages.isEmpty) return 0;
    return totalMinutes ~/ dailyUsages.length;
  }
}

/// 每日使用数据
class DailyUsage {
  final DateTime date;
  final int totalMinutes;
  final int gameMinutes;
  final int videoMinutes;
  final int studyMinutes;
  final bool compliedWithRules;

  const DailyUsage({
    required this.date,
    required this.totalMinutes,
    required this.gameMinutes,
    required this.videoMinutes,
    required this.studyMinutes,
    required this.compliedWithRules,
  });

  /// 星期几
  String get weekdayName {
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return weekdays[date.weekday - 1];
  }
}

/// 应用使用排行
class AppUsageRanking {
  final String appName;
  final String packageName;
  final String category;
  final int minutes;
  final double percentage;

  const AppUsageRanking({
    required this.appName,
    required this.packageName,
    required this.category,
    required this.minutes,
    required this.percentage,
  });
}
