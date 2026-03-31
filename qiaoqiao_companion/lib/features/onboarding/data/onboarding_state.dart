import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/database/daos/daos.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';
import 'package:qiaoqiao_companion/shared/models/models.dart';

/// Onboarding状态
class OnboardingState {
  final int currentStep;
  final bool isCompleted;
  final Map<String, dynamic> data;

  const OnboardingState({
    this.currentStep = 0,
    this.isCompleted = false,
    this.data = const {},
  });

  OnboardingState copyWith({
    int? currentStep,
    bool? isCompleted,
    Map<String, dynamic>? data,
  }) {
    return OnboardingState(
      currentStep: currentStep ?? this.currentStep,
      isCompleted: isCompleted ?? this.isCompleted,
      data: data ?? this.data,
    );
  }
}

/// Onboarding Provider
final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>((ref) {
  return OnboardingNotifier();
});

/// Onboarding Notifier
class OnboardingNotifier extends StateNotifier<OnboardingState> {
  static const _completedKey = 'onboarding_completed';

  OnboardingNotifier() : super(const OnboardingState());

  /// 下一步
  void nextStep() {
    state = state.copyWith(currentStep: state.currentStep + 1);
  }

  /// 上一步
  void previousStep() {
    if (state.currentStep > 0) {
      state = state.copyWith(currentStep: state.currentStep - 1);
    }
  }

  /// 跳转到指定步骤
  void goToStep(int step) {
    state = state.copyWith(currentStep: step);
  }

  /// 更新数据
  void updateData(Map<String, dynamic> newData) {
    state = state.copyWith(data: {...state.data, ...newData});
  }

  /// 完成Onboarding
  Future<void> complete() async {
    // 1. 保存规则到数据库
    await _saveRulesToDatabase();

    // 2. 标记完成
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_completedKey, true);
    state = state.copyWith(isCompleted: true);
  }

  /// 保存规则到数据库
  Future<void> _saveRulesToDatabase() async {
    final db = AppDatabase.instance;
    final ruleDao = RuleDao(db);

    // 从 state.data 获取用户设置的规则
    final totalMinutes = state.data['total_minutes'] as int? ?? 180;
    final gameMinutes = state.data['game_minutes'] as int? ?? 60;
    final videoMinutes = state.data['video_minutes'] as int? ?? 90;

    // 清除旧规则
    await ruleDao.deleteAll();

    // 保存总时间规则
    await ruleDao.insert(Rule(
      ruleType: RuleType.totalTime,
      weekdayLimitMinutes: totalMinutes,
      weekendLimitMinutes: (totalMinutes * 1.5).toInt(), // 周末多50%
      enabled: true,
    ));

    // 保存游戏时间规则
    await ruleDao.insert(Rule(
      ruleType: RuleType.appCategory,
      target: AppCategory.game.code,
      weekdayLimitMinutes: gameMinutes,
      weekendLimitMinutes: (gameMinutes * 1.5).toInt(),
      enabled: true,
    ));

    // 保存视频时间规则
    await ruleDao.insert(Rule(
      ruleType: RuleType.appCategory,
      target: AppCategory.video.code,
      weekdayLimitMinutes: videoMinutes,
      weekendLimitMinutes: (videoMinutes * 1.5).toInt(),
      enabled: true,
    ));

    // 保存默认的禁止时段规则
    // 睡觉时间：21:00-07:00
    await ruleDao.insert(Rule(
      ruleType: RuleType.timeBlock,
      timeStart: '21:00',
      timeEnd: '07:00',
      enabled: true,
    ));

    // 工作日上课时间：上午 9:00-12:00
    await ruleDao.insert(Rule(
      ruleType: RuleType.timeBlock,
      target: 'weekday',
      timeStart: '09:00',
      timeEnd: '12:00',
      enabled: true,
    ));

    // 工作日上课时间：下午 14:00-17:00
    await ruleDao.insert(Rule(
      ruleType: RuleType.timeBlock,
      target: 'weekday',
      timeStart: '14:00',
      timeEnd: '17:00',
      enabled: true,
    ));
  }

  /// 检查是否已完成
  static Future<bool> isCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_completedKey) ?? false;
  }
}
