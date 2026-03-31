import 'package:qiaoqiao_companion/core/constants/database_constants.dart';

/// 规则模型
class Rule {
  final int? id;
  final RuleType ruleType;
  final String? target;
  final int? weekdayLimitMinutes;
  final int? weekendLimitMinutes;
  final String? timeStart;
  final String? timeEnd;
  final bool enabled;

  Rule({
    this.id,
    required this.ruleType,
    this.target,
    this.weekdayLimitMinutes,
    this.weekendLimitMinutes,
    this.timeStart,
    this.timeEnd,
    this.enabled = true,
  });

  factory Rule.fromMap(Map<String, dynamic> map) {
    final rule = Rule(
      id: map['id'] as int?,
      ruleType: RuleType.fromCode(map['rule_type'] as String? ?? 'total_time'),
      target: map['target'] as String?,
      weekdayLimitMinutes: map['weekday_limit'] as int?,
      weekendLimitMinutes: map['weekend_limit'] as int?,
      timeStart: map['time_start'] as String?,
      timeEnd: map['time_end'] as String?,
      enabled: (map['enabled'] as int?) == 1,
    );
    print('[Rule.fromMap] map=$map => rule.id=${rule.id}, enabled=${rule.enabled}');
    return rule;
  }

  Map<String, dynamic> toMap() {
    final map = {
      if (id != null) 'id': id,
      'rule_type': ruleType.code,
      'target': target,
      'weekday_limit': weekdayLimitMinutes,
      'weekend_limit': weekendLimitMinutes,
      'time_start': timeStart,
      'time_end': timeEnd,
      'enabled': enabled ? 1 : 0,
    };
    print('[Rule.toMap] id=$id, rule_type=${ruleType.code}, enabled=$enabled, map=$map');
    return map;
  }

  /// 获取今日限额（分钟）
  int? getLimitForDate(DateTime date) {
    final weekday = date.weekday;
    final isWeekend = weekday == DateTime.saturday || weekday == DateTime.sunday;

    if (isWeekend) {
      return weekendLimitMinutes ?? weekdayLimitMinutes;
    }
    return weekdayLimitMinutes;
  }

  Rule copyWith({
    int? id,
    RuleType? ruleType,
    String? target,
    int? weekdayLimitMinutes,
    int? weekendLimitMinutes,
    String? timeStart,
    String? timeEnd,
    bool? enabled,
  }) {
    return Rule(
      id: id ?? this.id,
      ruleType: ruleType ?? this.ruleType,
      target: target ?? this.target,
      weekdayLimitMinutes: weekdayLimitMinutes ?? this.weekdayLimitMinutes,
      weekendLimitMinutes: weekendLimitMinutes ?? this.weekendLimitMinutes,
      timeStart: timeStart ?? this.timeStart,
      timeEnd: timeEnd ?? this.timeEnd,
      enabled: enabled ?? this.enabled,
    );
  }

  @override
  String toString() {
    return 'Rule(id: $id, type: $ruleType, target: $target, enabled: $enabled)';
  }
}

/// 默认规则工厂
class DefaultRules {
  static List<Rule> createDefaultRules() {
    // v1.1: 默认不创建任何规则，完全不做限制
    // 家长可以在家长模式中自行添加规则（指定app限制、总时间限制等）
    return [];
  }
}
