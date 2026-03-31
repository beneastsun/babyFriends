/// 应用明细筛选类型
enum AppUsageFilterType {
  todayAll,    // 今日全天
  todayHour,   // 今日某小时
  weekAll,     // 本周汇总
  weekDay,     // 本周某天
}

/// 应用明细筛选条件
class AppUsageFilter {
  final AppUsageFilterType type;
  final int? hour;      // 0-23，用于 todayHour
  final String? date;   // YYYY-MM-DD，用于 weekDay

  const AppUsageFilter({
    required this.type,
    this.hour,
    this.date,
  });

  /// 今日全天
  const AppUsageFilter.todayAll() : type = AppUsageFilterType.todayAll, hour = null, date = null;

  /// 今日某小时
  const AppUsageFilter.todayHour(this.hour) : type = AppUsageFilterType.todayHour, date = null;

  /// 本周汇总
  const AppUsageFilter.weekAll() : type = AppUsageFilterType.weekAll, hour = null, date = null;

  /// 本周某天
  const AppUsageFilter.weekDay(this.date) : type = AppUsageFilterType.weekDay, hour = null;

  /// 是否是今日模式
  bool get isTodayMode => type == AppUsageFilterType.todayAll || type == AppUsageFilterType.todayHour;

  /// 是否是本周模式
  bool get isWeekMode => type == AppUsageFilterType.weekAll || type == AppUsageFilterType.weekDay;

  /// 获取显示标题
  String getDisplayTitle() {
    switch (type) {
      case AppUsageFilterType.todayAll:
        return '应用使用明细';
      case AppUsageFilterType.todayHour:
        return '$hour点应用明细';
      case AppUsageFilterType.weekAll:
        return '本周应用明细';
      case AppUsageFilterType.weekDay:
        if (date == null) return '应用明细';
        // 解析日期格式 YYYY-MM-DD
        final parts = date!.split('-');
        if (parts.length == 3) {
          final month = int.tryParse(parts[1]) ?? 1;
          final day = int.tryParse(parts[2]) ?? 1;
          return '$month月$day日应用明细';
        }
        return '应用明细';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppUsageFilter &&
        other.type == type &&
        other.hour == hour &&
        other.date == date;
  }

  @override
  int get hashCode => Object.hash(type, hour, date);

  @override
  String toString() {
    return 'AppUsageFilter(type: $type, hour: $hour, date: $date)';
  }
}
