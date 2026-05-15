import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

/// 连续使用设置
class ContinuousUsageSettings {
  final bool enabled;
  final int limitMinutes;
  final int restMinutes;
  final int resetAfterRestMinutes; // 休息后重置计时的时间（默认1分钟）

  const ContinuousUsageSettings({
    this.enabled = false,
    this.limitMinutes = 30,
    this.restMinutes = 10,
    this.resetAfterRestMinutes = 1, // 默认1分钟
  });

  ContinuousUsageSettings copyWith({
    bool? enabled,
    int? limitMinutes,
    int? restMinutes,
    int? resetAfterRestMinutes,
  }) {
    return ContinuousUsageSettings(
      enabled: enabled ?? this.enabled,
      limitMinutes: limitMinutes ?? this.limitMinutes,
      restMinutes: restMinutes ?? this.restMinutes,
      resetAfterRestMinutes: resetAfterRestMinutes ?? this.resetAfterRestMinutes,
    );
  }

  /// 限制时长（秒）
  int get limitSeconds => limitMinutes * 60;

  /// 休息时长（秒）
  int get restSeconds => restMinutes * 60;

  /// 休息后重置计时的时间（秒）
  int get resetAfterRestSeconds => resetAfterRestMinutes * 60;
}

/// 连续使用设置 Notifier
class ContinuousUsageSettingsNotifier
    extends StateNotifier<ContinuousUsageSettings> {
  static const _keyEnabled = 'continuous_usage_limit_enabled';
  static const _keyLimitMinutes = 'continuous_usage_limit_minutes';
  static const _keyRestMinutes = 'continuous_rest_minutes';
  static const _keyResetAfterRestMinutes = 'continuous_reset_after_rest_minutes';

  ContinuousUsageSettingsNotifier() : super(const ContinuousUsageSettings()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = ContinuousUsageSettings(
      enabled: prefs.getBool(_keyEnabled) ?? false,
      limitMinutes: prefs.getInt(_keyLimitMinutes) ?? 30,
      restMinutes: prefs.getInt(_keyRestMinutes) ?? 10,
      resetAfterRestMinutes: prefs.getInt(_keyResetAfterRestMinutes) ?? 1,
    );
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, enabled);
    state = state.copyWith(enabled: enabled);
  }

  Future<void> setLimitMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLimitMinutes, minutes);
    state = state.copyWith(limitMinutes: minutes);
  }

  Future<void> setRestMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyRestMinutes, minutes);
    state = state.copyWith(restMinutes: minutes);
  }

  Future<void> setResetAfterRestMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyResetAfterRestMinutes, minutes);
    state = state.copyWith(resetAfterRestMinutes: minutes);
  }
}

/// 连续使用设置 Provider
final continuousUsageSettingsProvider =
    StateNotifierProvider<ContinuousUsageSettingsNotifier, ContinuousUsageSettings>(
        (ref) {
  return ContinuousUsageSettingsNotifier();
});

/// 格式化日期辅助函数
String formatDate(DateTime date) {
  return DateFormat('yyyy-MM-dd').format(date);
}
