import 'package:flutter_test/flutter_test.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';

void main() {
  test('databaseVersion is 6', () {
    expect(DatabaseConstants.databaseVersion, 6);
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
}
