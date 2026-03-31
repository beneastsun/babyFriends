import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/database/daos/time_period_dao.dart';
import 'package:qiaoqiao_companion/shared/models/models.dart';

/// 时间段状态
class TimePeriodsState {
  final List<TimePeriod> allPeriods;
  final List<TimePeriod> enabledPeriods;
  final TimePeriodMode currentMode;

  const TimePeriodsState({
    this.allPeriods = const [],
    this.enabledPeriods = const [],
    this.currentMode = TimePeriodMode.blocked,
  });

  TimePeriodsState copyWith({
    List<TimePeriod>? allPeriods,
    List<TimePeriod>? enabledPeriods,
    TimePeriodMode? currentMode,
  }) {
    final all = allPeriods ?? this.allPeriods;
    final enabled = enabledPeriods ?? all.where((p) => p.enabled).toList();
    return TimePeriodsState(
      allPeriods: all,
      enabledPeriods: enabled,
      currentMode: currentMode ?? this.currentMode,
    );
  }

  /// 获取当前模式的时间段
  List<TimePeriod> get periodsForCurrentMode =>
      enabledPeriods.where((p) => p.mode == currentMode).toList();

  /// 检查当前时间是否在禁止时段内
  TimePeriodStatus getCurrentTimeBlockStatus(DateTime dateTime) {
    final currentTime =
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    final weekday = dateTime.weekday;

    // 调试日志
    print('[TimePeriods] ========== getCurrentTimeBlockStatus =========');
    print('[TimePeriods] 检查时间: $currentTime, 星期: $weekday');
    print('[TimePeriods] enabledPeriods 数量: ${enabledPeriods.length}');

    // 只检查 blocked 模式
    print('[TimePeriods] --- 检查 blocked 模式 ---');
    for (final period in enabledPeriods) {
      if (period.mode != TimePeriodMode.blocked) continue;
      print('[TimePeriods] blocked 时段: ${period.timeStart}-${period.timeEnd}, days=${period.days}, appliesToWeekday=${period.appliesToWeekday(weekday)}');
      if (!period.appliesToWeekday(weekday)) continue;

      final contains = period.containsTime(currentTime);
      print('[TimePeriods] containsTime($currentTime) = $contains');
      if (contains) {
        print('[TimePeriods] => 在 blocked 时段内, 返回 blocked');
        return TimePeriodStatus(
          isBlocked: true,
          reason: period.displayText,
          period: period,
        );
      }
    }

    // 检查 allowed 模式
    print('[TimePeriods] --- 检查 allowed 模式 ---');
    final allowedPeriods = enabledPeriods.where((p) => p.mode == TimePeriodMode.allowed);
    print('[TimePeriods] allowedPeriods 数量: ${allowedPeriods.length}');
    if (allowedPeriods.isNotEmpty) {
      bool isInAllowedPeriod = false;
      for (final period in allowedPeriods) {
        print('[TimePeriods] allowed 时段: ${period.timeStart}-${period.timeEnd}, days=${period.days}, appliesToWeekday=${period.appliesToWeekday(weekday)}');
        if (!period.appliesToWeekday(weekday)) {
          print('[TimePeriods] => 不适用于当前星期, 跳过');
          continue;
        }
        final contains = period.containsTime(currentTime);
        print('[TimePeriods] containsTime($currentTime) = $contains');
        if (contains) {
          isInAllowedPeriod = true;
          print('[TimePeriods] => 在 allowed 时段内');
          break;
        }
      }
      print('[TimePeriods] isInAllowedPeriod = $isInAllowedPeriod');
      if (!isInAllowedPeriod) {
        print('[TimePeriods] => 不在任何 allowed 时段内, 返回 blocked');
        return TimePeriodStatus(
          isBlocked: true,
          reason: '当前不在允许使用时段内',
        );
      }
    }

    print('[TimePeriods] => 返回 allowed');
    return const TimePeriodStatus(isBlocked: false);
  }
}

/// 时间段状态
class TimePeriodStatus {
  final bool isBlocked;
  final String? reason;
  final TimePeriod? period;

  const TimePeriodStatus({
    required this.isBlocked,
    this.reason,
    this.period,
  });
}

/// 时间段状态 Notifier
class TimePeriodsNotifier extends StateNotifier<TimePeriodsState> {
  final TimePeriodDao _dao;

  TimePeriodsNotifier(this._dao) : super(const TimePeriodsState());

  /// 加载所有时间段
  Future<void> load() async {
    final allPeriods = await _dao.getAll();
    final mode = await _dao.getCurrentMode();
    state = state.copyWith(
      allPeriods: allPeriods,
      currentMode: mode ?? TimePeriodMode.blocked,
    );
  }

  /// 设置当前模式
  Future<void> setMode(TimePeriodMode mode) async {
    await _dao.updateAllMode(mode);
    state = state.copyWith(currentMode: mode);
    await load();
  }

  /// 添加时间段
  Future<void> addPeriod(TimePeriod period) async {
    await _dao.insert(period);
    await load();
  }

  /// 更新时间段
  Future<void> updatePeriod(TimePeriod period) async {
    await _dao.update(period);
    await load();
  }

  /// 删除时间段
  Future<void> removePeriod(int id) async {
    await _dao.delete(id);
    await load();
  }

  /// 切换时间段启用状态
  Future<void> toggleEnabled(int id) async {
    final period = await _dao.getById(id);
    if (period != null) {
      await _dao.update(period.copyWith(enabled: !period.enabled));
      await load();
    }
  }

  /// 刷新数据
  Future<void> refresh() async {
    await load();
  }
}

/// 时间段状态 Provider
final timePeriodsProvider =
    StateNotifierProvider<TimePeriodsNotifier, TimePeriodsState>((ref) {
  return TimePeriodsNotifier(TimePeriodDao(AppDatabase.instance));
});

/// 当前时间段状态 Provider
final currentTimePeriodStatusProvider = Provider<TimePeriodStatus>((ref) {
  final periods = ref.watch(timePeriodsProvider);
  return periods.getCurrentTimeBlockStatus(DateTime.now());
});
