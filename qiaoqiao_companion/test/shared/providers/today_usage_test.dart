import 'package:flutter_test/flutter_test.dart';
import 'package:qiaoqiao_companion/shared/providers/today_usage_provider.dart';

void main() {
  test('TodayUsage effectiveTotalLimitMinutes = (totalLimit + adjustment).clamp(0, 480)', () {
    final usage = TodayUsage(
      totalLimitMinutes: 120,
      adjustmentMinutes: 15,
    );

    expect(usage.effectiveTotalLimitMinutes, 135);
  });

  test('TodayUsage effectiveTotalLimitMinutes clamps to 0 when penalty exceeds base', () {
    final usage = TodayUsage(
      totalLimitMinutes: 60,
      adjustmentMinutes: -90,
    );

    expect(usage.effectiveTotalLimitMinutes, 0);
  });

  test('TodayUsage effectiveTotalLimitMinutes clamps to 480 max', () {
    final usage = TodayUsage(
      totalLimitMinutes: 400,
      adjustmentMinutes: 200,
    );

    expect(usage.effectiveTotalLimitMinutes, 480);
  });

  test('TodayUsage totalRemaining uses effectiveTotalLimit', () {
    final usage = TodayUsage(
      totalDurationSeconds: 3600, // 60 min
      totalLimitMinutes: 120,
      adjustmentMinutes: 30, // effective = 150
    );

    expect(usage.totalRemaining.inMinutes, 90);
  });

  test('TodayUsage isTotalExceeded uses effectiveTotalLimit', () {
    final usage = TodayUsage(
      totalDurationSeconds: 7200, // 120 min
      totalLimitMinutes: 120,
      adjustmentMinutes: 30, // effective = 150, 120 < 150 so not exceeded
    );

    expect(usage.isTotalExceeded, false);
  });

  test('TodayUsage totalProgress uses effectiveTotalLimit', () {
    final usage = TodayUsage(
      totalDurationSeconds: 3600, // 60 min
      totalLimitMinutes: 120,
      adjustmentMinutes: 30, // effective = 150 min = 9000 sec
    );

    expect(usage.totalProgress, 3600 / 9000);
  });

  test('TodayUsage adjustmentMinutes defaults to 0', () {
    const usage = TodayUsage(
      totalLimitMinutes: 120,
    );

    expect(usage.adjustmentMinutes, 0);
    expect(usage.effectiveTotalLimitMinutes, 120);
  });
}
