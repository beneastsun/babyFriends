import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/database/daos/daos.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';
import 'package:qiaoqiao_companion/core/platform/platform.dart';
import 'package:qiaoqiao_companion/shared/models/models.dart';
import 'package:qiaoqiao_companion/shared/providers/providers.dart';

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
      return OnboardingNotifier(ref);
    });

/// Onboarding Notifier
class OnboardingNotifier extends StateNotifier<OnboardingState> {
  static const _completedKey = 'onboarding_completed';

  final Ref _ref;

  OnboardingNotifier(this._ref) : super(const OnboardingState());

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
    final monitoredAppDao = MonitoredAppDao(db);
    final timePeriodDao = TimePeriodDao(db);

    final totalMinutes = state.data['total_minutes'] as int? ?? 180;
    final gameMinutes = state.data['game_minutes'] as int? ?? 60;
    final videoMinutes = state.data['video_minutes'] as int? ?? 90;

    final existingTotalRule = await ruleDao.getByTypeAndTarget(
      RuleType.totalTime,
      null,
    );
    final totalRule = Rule(
      id: existingTotalRule?.id,
      ruleType: RuleType.totalTime,
      weekdayLimitMinutes: totalMinutes,
      weekendLimitMinutes: (totalMinutes * 1.5).toInt(),
      enabled: true,
    );
    if (existingTotalRule == null) {
      await ruleDao.insert(totalRule);
    } else {
      await ruleDao.update(totalRule);
    }

    final now = DateTime.now();
    final installedApps = await UsageStatsService.getInstalledApps();
    final defaultApps = <String, ({String name, String category, int limit})>{
      'com.tencent.tmgp.sgame': (
        name: '王者荣耀',
        category: AppCategory.game.code,
        limit: gameMinutes,
      ),
      'com.tencent.tmgp.pubgmhd': (
        name: '和平精英',
        category: AppCategory.game.code,
        limit: gameMinutes,
      ),
      'com.netease.mc': (
        name: '我的世界',
        category: AppCategory.game.code,
        limit: gameMinutes,
      ),
      'com.ss.android.ugc.aweme': (
        name: '抖音',
        category: AppCategory.video.code,
        limit: videoMinutes,
      ),
      'tv.danmaku.bili': (
        name: '哔哩哔哩',
        category: AppCategory.video.code,
        limit: videoMinutes,
      ),
      'com.qiyi.video': (
        name: '爱奇艺',
        category: AppCategory.video.code,
        limit: videoMinutes,
      ),
    };

    for (final appInfo in installedApps) {
      final defaultApp = defaultApps[appInfo.packageName];
      if (defaultApp == null) continue;

      final existingApp = await monitoredAppDao.getByPackageName(
        appInfo.packageName,
      );
      final app = MonitoredApp(
        packageName: appInfo.packageName,
        appName: appInfo.appName.isNotEmpty ? appInfo.appName : defaultApp.name,
        dailyLimitMinutes: defaultApp.limit,
        category: defaultApp.category,
        enabled: true,
        createdAt: existingApp?.createdAt ?? now,
        updatedAt: now,
      );
      if (existingApp == null) {
        await monitoredAppDao.insert(app);
      } else {
        await monitoredAppDao.update(app);
      }
    }

    final existingPeriods = await timePeriodDao.getAll();
    if (existingPeriods.isEmpty) {
      await timePeriodDao.insert(
        TimePeriod(
          mode: TimePeriodMode.blocked,
          timeStart: '21:00',
          timeEnd: '07:00',
          days: const [1, 2, 3, 4, 5, 6, 7],
          enabled: true,
          createdAt: now,
        ),
      );
      await timePeriodDao.insert(
        TimePeriod(
          mode: TimePeriodMode.blocked,
          timeStart: '09:00',
          timeEnd: '12:00',
          days: const [1, 2, 3, 4, 5],
          enabled: true,
          createdAt: now,
        ),
      );
      await timePeriodDao.insert(
        TimePeriod(
          mode: TimePeriodMode.blocked,
          timeStart: '14:00',
          timeEnd: '17:00',
          days: const [1, 2, 3, 4, 5],
          enabled: true,
          createdAt: now,
        ),
      );
    }

    await Future.wait([
      _ref.read(rulesProvider.notifier).load(),
      _ref.read(monitoredAppsProvider.notifier).load(),
      _ref.read(timePeriodsProvider.notifier).load(),
    ]);
  }

  /// 检查是否已完成
  static Future<bool> isCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_completedKey) ?? false;
  }
}
