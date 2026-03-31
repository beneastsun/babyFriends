import 'package:qiaoqiao_companion/core/constants/database_constants.dart';
import 'package:qiaoqiao_companion/shared/models/limit_source.dart';

/// 应用使用汇总模型
class AppUsageSummary {
  final String packageName;
  final String appName;
  final AppCategory category;
  final int todayDurationSeconds;
  final int? limitMinutes;
  final LimitSource limitSource;
  final bool hasRule;
  final String? appIcon; // Base64编码的应用图标
  final double usagePercentage; // 使用时长占总时长的百分比 (0.0 - 1.0)

  const AppUsageSummary({
    required this.packageName,
    required this.appName,
    required this.category,
    required this.todayDurationSeconds,
    this.limitMinutes,
    required this.limitSource,
    required this.hasRule,
    this.appIcon,
    this.usagePercentage = 0.0,
  });

  /// 使用时长（Duration）
  Duration get todayDuration => Duration(seconds: todayDurationSeconds);

  /// 使用进度 (0.0 - 1.0)，仅当有规则时返回
  double? get progress {
    if (limitMinutes == null || limitMinutes! <= 0) return null;
    return (todayDurationSeconds / (limitMinutes! * 60)).clamp(0.0, 1.0);
  }

  /// 是否接近限制 (>= 90%)
  bool get isNearLimit {
    final p = progress;
    return p != null && p >= 0.9;
  }

  /// 是否已超限
  bool get isExceeded {
    final p = progress;
    return p != null && p >= 1.0;
  }

  /// 剩余时间（分钟）
  int? get remainingMinutes {
    if (limitMinutes == null) return null;
    final usedMinutes = (todayDurationSeconds / 60).ceil();
    final remaining = limitMinutes! - usedMinutes;
    return remaining > 0 ? remaining : 0;
  }

  /// 状态文案
  String get statusText {
    if (hasRule) {
      return '已设置：$limitMinutes分钟/天';
    }
    switch (limitSource) {
      case LimitSource.category:
        return '受${category.label}限制（$limitMinutes分钟）';
      case LimitSource.total:
        return '受总时间限制';
      case LimitSource.none:
        if (category == AppCategory.study) {
          return '学习类，无单独限制';
        }
        return '未设置限制';
      case LimitSource.singleApp:
        return '已设置：$limitMinutes分钟/天';
    }
  }

  AppUsageSummary copyWith({
    String? packageName,
    String? appName,
    AppCategory? category,
    int? todayDurationSeconds,
    int? limitMinutes,
    LimitSource? limitSource,
    bool? hasRule,
    String? appIcon,
    double? usagePercentage,
  }) {
    return AppUsageSummary(
      packageName: packageName ?? this.packageName,
      appName: appName ?? this.appName,
      category: category ?? this.category,
      todayDurationSeconds: todayDurationSeconds ?? this.todayDurationSeconds,
      limitMinutes: limitMinutes ?? this.limitMinutes,
      limitSource: limitSource ?? this.limitSource,
      hasRule: hasRule ?? this.hasRule,
      appIcon: appIcon ?? this.appIcon,
      usagePercentage: usagePercentage ?? this.usagePercentage,
    );
  }

  @override
  String toString() {
    return 'AppUsageSummary($packageName, ${todayDuration.inMinutes}min, limit: $limitMinutes min, source: $limitSource)';
  }
}
