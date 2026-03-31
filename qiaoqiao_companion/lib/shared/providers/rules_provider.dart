import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/database/daos/daos.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';
import 'package:qiaoqiao_companion/shared/models/models.dart';

/// 规则状态
class RulesState {
  final List<Rule> allRules;
  final List<Rule> enabledRules;
  final Rule? totalTimeRule;
  final List<Rule> timeBlockRules;
  final List<Rule> categoryRules;

  const RulesState({
    this.allRules = const [],
    this.enabledRules = const [],
    this.totalTimeRule,
    this.timeBlockRules = const [],
    this.categoryRules = const [],
  });

  /// 获取分类限制
  int? getCategoryLimit(AppCategory category, DateTime date) {
    final rule = categoryRules.firstWhere(
      (r) => r.target == category.code,
      orElse: () => Rule(
        ruleType: RuleType.appCategory,
        target: category.code,
      ),
    );
    return rule.getLimitForDate(date);
  }

  /// 检查当前是否在禁止时段
  TimeBlockStatus getCurrentTimeBlockStatus(DateTime dateTime) {
    final currentTime =
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';

    for (final rule in timeBlockRules) {
      if (!rule.enabled) continue;

      final start = rule.timeStart ?? '00:00';
      final end = rule.timeEnd ?? '00:00';

      // 检查是否在工作日禁止时段
      if (rule.target == 'weekday') {
        final weekday = dateTime.weekday;
        if (weekday == DateTime.saturday || weekday == DateTime.sunday) {
          continue;
        }
      }

      // 处理跨天情况（如 21:00-07:00）
      if (start.compareTo(end) > 0) {
        // 跨天（如 21:00-07:00）
        if (currentTime.compareTo(start) >= 0 || currentTime.compareTo(end) < 0) {
          return TimeBlockStatus(
            isBlocked: true,
            reason: '$start - $end',
            rule: rule,
          );
        }
      } else {
        // 同一天（如 09:00-12:00）
        if (currentTime.compareTo(start) >= 0 && currentTime.compareTo(end) < 0) {
          return TimeBlockStatus(
            isBlocked: true,
            reason: '$start - $end',
            rule: rule,
          );
        }
      }
    }

    return const TimeBlockStatus(isBlocked: false);
  }

  RulesState copyWith({
    List<Rule>? allRules,
    List<Rule>? enabledRules,
    Rule? totalTimeRule,
    List<Rule>? timeBlockRules,
    List<Rule>? categoryRules,
  }) {
    return RulesState(
      allRules: allRules ?? this.allRules,
      enabledRules: enabledRules ?? this.enabledRules,
      totalTimeRule: totalTimeRule ?? this.totalTimeRule,
      timeBlockRules: timeBlockRules ?? this.timeBlockRules,
      categoryRules: categoryRules ?? this.categoryRules,
    );
  }
}

/// 禁止时段状态
class TimeBlockStatus {
  final bool isBlocked;
  final String? reason;
  final Rule? rule;

  const TimeBlockStatus({
    required this.isBlocked,
    this.reason,
    this.rule,
  });
}

/// 规则状态 Notifier
class RulesNotifier extends StateNotifier<RulesState> {
  final RuleDao _ruleDao;

  RulesNotifier(this._ruleDao) : super(const RulesState());

  /// 加载所有规则
  Future<void> load() async {
    final allRules = await _ruleDao.getAll();
    final enabledRules = allRules.where((r) => r.enabled).toList();
    print('[RulesNotifier] load: allRules=${allRules.length}, enabledRules=${enabledRules.length}');
    for (final r in allRules) {
      print('[RulesNotifier] 规则: id=${r.id}, type=${r.ruleType.code}, enabled=${r.enabled}');
    }

    // 从 allRules 中查找 totalTimeRule（即使被禁用也能找到，保留 id）
    final totalTimeRule = allRules.firstWhere(
      (r) => r.ruleType == RuleType.totalTime,
      orElse: () => Rule(ruleType: RuleType.totalTime),
    );
    print('[RulesNotifier] totalTimeRule: id=${totalTimeRule.id}, enabled=${totalTimeRule.enabled}');

    final timeBlockRules =
        enabledRules.where((r) => r.ruleType == RuleType.timeBlock).toList();

    final categoryRules = enabledRules
        .where((r) => r.ruleType == RuleType.appCategory)
        .toList();

    state = state.copyWith(
      allRules: allRules,
      enabledRules: enabledRules,
      totalTimeRule: totalTimeRule,
      timeBlockRules: timeBlockRules,
      categoryRules: categoryRules,
    );
  }

  /// 更新规则
  Future<void> updateRule(Rule rule) async {
    print('[RulesNotifier] updateRule: id=${rule.id}, type=${rule.ruleType.code}, enabled=${rule.enabled}');
    await _ruleDao.update(rule);
    await load();
    print('[RulesNotifier] updateRule 完成: allRules=${state.allRules.length}, enabledRules=${state.enabledRules.length}');
  }

  /// 添加规则
  Future<void> addRule(Rule rule) async {
    print('[RulesNotifier] addRule: type=${rule.ruleType.code}, enabled=${rule.enabled}');
    final id = await _ruleDao.insert(rule);
    print('[RulesNotifier] addRule 返回 id: $id');
    await load();
    print('[RulesNotifier] addRule 完成: allRules=${state.allRules.length}, enabledRules=${state.enabledRules.length}');
  }

  /// 删除规则
  Future<void> deleteRule(int id) async {
    await _ruleDao.delete(id);
    await load();
  }

  /// 启用/禁用规则
  Future<void> toggleRule(int id) async {
    final rule = state.allRules.firstWhere((r) => r.id == id);
    final updated = rule.copyWith(enabled: !rule.enabled);
    await updateRule(updated);
  }

  /// 刷新数据
  Future<void> refresh() async {
    await load();
  }
}

/// 规则状态 Provider
final rulesProvider =
    StateNotifierProvider<RulesNotifier, RulesState>((ref) {
  final db = AppDatabase.instance;
  return RulesNotifier(RuleDao(db));
});

/// 当前是否在禁止时段 Provider
final currentTimeBlockStatusProvider = Provider<TimeBlockStatus>((ref) {
  final rules = ref.watch(rulesProvider);
  return rules.getCurrentTimeBlockStatus(DateTime.now());
});
