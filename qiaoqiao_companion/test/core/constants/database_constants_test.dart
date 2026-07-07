import 'package:flutter_test/flutter_test.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';

void main() {
  test('databaseVersion is 7', () {
    expect(DatabaseConstants.databaseVersion, 7);
  });

  test('tableDailyLimitAdjustments constant exists', () {
    expect(DatabaseConstants.tableDailyLimitAdjustments, 'daily_limit_adjustments');
  });

  test('LimitAdjustmentSource enum has coupon, taskPenalty, parentGrant', () {
    expect(LimitAdjustmentSource.values.length, 3);
    expect(LimitAdjustmentSource.coupon.code, 'coupon');
    expect(LimitAdjustmentSource.taskPenalty.code, 'task_penalty');
    expect(LimitAdjustmentSource.parentGrant.code, 'parent_grant');
  });

  test('CheckinMode does not have scheduled value', () {
    expect(
      CheckinMode.values.where((m) => m.code == 'scheduled'),
      isEmpty,
    );
  });

  test('tableEggWeeklyProgress constant exists', () {
    expect(DatabaseConstants.tableEggWeeklyProgress, 'egg_weekly_progress');
  });

  test('EggStyle enum has princess, sporty, fairy, school', () {
    expect(EggStyle.values.length, 4);
    expect(EggStyle.princess.code, 'princess');
    expect(EggStyle.sporty.code, 'sporty');
    expect(EggStyle.fairy.code, 'fairy');
    expect(EggStyle.school.code, 'school');
  });
}
