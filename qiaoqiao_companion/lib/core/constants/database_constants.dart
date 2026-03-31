/// 数据库常量配置
class DatabaseConstants {
  DatabaseConstants._();

  static const String databaseName = 'qiaoqiao_companion.db';
  static const int databaseVersion = 3;

  // 表名
  static const String tableAppUsageRecords = 'app_usage_records';
  static const String tableRules = 'rules';
  static const String tablePointsHistory = 'points_history';
  static const String tableCoupons = 'coupons';
  static const String tableDailyStats = 'daily_stats';
  static const String tableAppCategories = 'app_categories';
  static const String tableHourlyUsageStats = 'hourly_usage_stats';

  // v3 新增表
  static const String tableMonitoredApps = 'monitored_apps';
  static const String tableTimePeriods = 'time_periods';
  static const String tableContinuousSessions = 'continuous_usage_sessions';
}

/// 应用分类枚举
enum AppCategory {
  game('game', '🎮 游戏'),
  video('video', '📺 视频'),
  study('study', '📚 学习'),
  reading('reading', '📖 阅读'),
  other('other', '❓ 其他');

  const AppCategory(this.code, this.label);
  final String code;
  final String label;

  static AppCategory fromCode(String code) {
    return AppCategory.values.firstWhere(
      (e) => e.code == code,
      orElse: () => AppCategory.other,
    );
  }
}

/// 规则类型枚举
enum RuleType {
  totalTime('total_time', '总时间限制'),
  appCategory('app_category', '应用分类限制'),
  appSingle('app_single', '单个应用限制'),
  timeBlock('time_block', '禁止时段');

  const RuleType(this.code, this.label);
  final String code;
  final String label;

  static RuleType fromCode(String code) {
    return RuleType.values.firstWhere(
      (e) => e.code == code,
      orElse: () => RuleType.totalTime,
    );
  }
}

/// 加时券类型枚举
enum CouponType {
  small('small', 15, 30),
  medium('medium', 30, 50),
  large('large', 60, 80);

  const CouponType(this.code, this.durationMinutes, this.cost);
  final String code;
  final int durationMinutes;
  final int cost;

  static CouponType fromCode(String code) {
    return CouponType.values.firstWhere(
      (e) => e.code == code,
      orElse: () => CouponType.small,
    );
  }
}

/// 加时券状态枚举
enum CouponStatus {
  available('available', '可用'),
  used('used', '已使用'),
  expired('expired', '已过期');

  const CouponStatus(this.code, this.label);
  final String code;
  final String label;

  static CouponStatus fromCode(String code) {
    return CouponStatus.values.firstWhere(
      (e) => e.code == code,
      orElse: () => CouponStatus.available,
    );
  }
}

/// 加时券来源枚举
enum CouponSource {
  earned('earned', '积分兑换'),
  parentGiven('parent_given', '家长发放');

  const CouponSource(this.code, this.label);
  final String code;
  final String label;

  static CouponSource fromCode(String code) {
    return CouponSource.values.firstWhere(
      (e) => e.code == code,
      orElse: () => CouponSource.earned,
    );
  }
}

/// 积分交易类型
enum PointsTransactionType {
  earned,  // 获得
  spent,   // 消耗
}

/// 积分类别
enum PointsCategory {
  restReward,        // 按时休息奖励
  studyReward,       // 学习奖励
  exerciseReward,    // 运动奖励
  readingReward,     // 阅读奖励
  choreReward,       // 家务奖励
  couponExchange,    // 兑换加时券
  timePenalty,       // 超时惩罚
  ruleViolation,     // 违规惩罚
  dailyBonus,        // 每日签到
  achievementBonus,  // 成就奖励
  other,             // 其他
}

/// 积分边界常量
class PointsConstants {
  PointsConstants._();

  static const int maxPoints = 9999;
  static const int minPoints = 0;

  // 积分获取
  static const int pointsForEndingEarly = 10;
  static const int pointsForDailyLimit = 20;
  static const int pointsForForbiddenTime = 15;
  static const int pointsForStreak3Days = 30;

  // 分类奖励
  static const int restReward = 10;
  static const int studyReward = 20;
  static const int exerciseReward = 15;
  static const int readingReward = 15;
  static const int choreReward = 10;
  static const int dailyBonus = 5;
  static const int overtimePenalty = 20;
  static const int ruleViolationPenalty = 30;
}
