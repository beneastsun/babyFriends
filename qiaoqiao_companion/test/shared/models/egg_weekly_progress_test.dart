import 'package:flutter_test/flutter_test.dart';
import 'package:qiaoqiao_companion/shared/models/egg_weekly_progress.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';

void main() {
  test('EggWeeklyProgress fromMap parses all fields correctly', () {
    final map = {
      'id': 1,
      'week_start': '2026-07-07',
      'total_task_count': 10,
      'completed_task_count': 6,
      'highest_stage': 3,
      'egg_style': 'sporty',
      'updated_at': 1720000000000,
    };

    final progress = EggWeeklyProgress.fromMap(map);

    expect(progress.id, 1);
    expect(progress.weekStart, '2026-07-07');
    expect(progress.totalTaskCount, 10);
    expect(progress.completedTaskCount, 6);
    expect(progress.highestStage, 3);
    expect(progress.eggStyle, EggStyle.sporty);
  });

  test('EggWeeklyProgress fromMap handles default princess style', () {
    final map = {
      'id': 2,
      'week_start': '2026-07-14',
      'total_task_count': 0,
      'completed_task_count': 0,
      'highest_stage': 0,
      'egg_style': 'princess',
      'updated_at': 1720000000000,
    };

    final progress = EggWeeklyProgress.fromMap(map);

    expect(progress.eggStyle, EggStyle.princess);
    expect(progress.completionRate, 0.0);
  });

  test('EggWeeklyProgress completionRate calculates correctly', () {
    final progress = EggWeeklyProgress(
      weekStart: '2026-07-07',
      totalTaskCount: 10,
      completedTaskCount: 6,
      highestStage: 2,
      eggStyle: EggStyle.princess,
    );

    expect(progress.completionRate, 0.6);
  });

  test('EggWeeklyProgress completionRate returns 0 when totalTaskCount is 0', () {
    final progress = EggWeeklyProgress(
      weekStart: '2026-07-07',
      totalTaskCount: 0,
      completedTaskCount: 0,
      highestStage: 0,
      eggStyle: EggStyle.princess,
    );

    expect(progress.completionRate, 0.0);
  });

  test('EggWeeklyProgress stage calculates from completionRate', () {
    // 0% -> stage 0
    expect(
      EggWeeklyProgress(weekStart: '', totalTaskCount: 10, completedTaskCount: 0, highestStage: 0, eggStyle: EggStyle.princess).stage,
      0,
    );
    // 10% -> stage 0 (10/100*5 = 0.5 -> floor 0)
    expect(
      EggWeeklyProgress(weekStart: '', totalTaskCount: 10, completedTaskCount: 1, highestStage: 0, eggStyle: EggStyle.princess).stage,
      0,
    );
    // 20% -> stage 1
    expect(
      EggWeeklyProgress(weekStart: '', totalTaskCount: 10, completedTaskCount: 2, highestStage: 0, eggStyle: EggStyle.princess).stage,
      1,
    );
    // 60% -> stage 3
    expect(
      EggWeeklyProgress(weekStart: '', totalTaskCount: 10, completedTaskCount: 6, highestStage: 0, eggStyle: EggStyle.princess).stage,
      3,
    );
    // 100% -> stage 4 (500/100*5=5 -> clamp 4)
    expect(
      EggWeeklyProgress(weekStart: '', totalTaskCount: 10, completedTaskCount: 10, highestStage: 0, eggStyle: EggStyle.princess).stage,
      4,
    );
  });

  test('EggWeeklyProgress toMap produces correct map', () {
    final progress = EggWeeklyProgress(
      id: 3,
      weekStart: '2026-07-09',
      totalTaskCount: 5,
      completedTaskCount: 3,
      highestStage: 1,
      eggStyle: EggStyle.fairy,
    );

    final map = progress.toMap();

    expect(map['id'], 3);
    expect(map['week_start'], '2026-07-09');
    expect(map['total_task_count'], 5);
    expect(map['completed_task_count'], 3);
    expect(map['highest_stage'], 1);
    expect(map['egg_style'], 'fairy');
    expect(map['updated_at'], isNotNull);
  });

  test('EggWeeklyProgress copyWith works correctly', () {
    final original = EggWeeklyProgress(
      weekStart: '2026-07-07',
      totalTaskCount: 10,
      completedTaskCount: 5,
      highestStage: 2,
      eggStyle: EggStyle.princess,
    );

    final copied = original.copyWith(
      completedTaskCount: 8,
      highestStage: 3,
    );

    expect(copied.weekStart, '2026-07-07');
    expect(copied.completedTaskCount, 8);
    expect(copied.highestStage, 3);
    expect(copied.totalTaskCount, 10);
    expect(copied.eggStyle, EggStyle.princess);
  });
}
