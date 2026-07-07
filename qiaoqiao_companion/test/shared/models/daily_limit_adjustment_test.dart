import 'package:flutter_test/flutter_test.dart';
import 'package:qiaoqiao_companion/shared/models/daily_limit_adjustment.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';

void main() {
  test('DailyLimitAdjustment fromMap parses all fields correctly', () {
    final map = {
      'id': 1,
      'adjust_date': '2026-07-07',
      'adjustment_minutes': 15,
      'source': 'coupon',
      'source_id': 42,
      'created_at': 1720000000000,
    };

    final adjustment = DailyLimitAdjustment.fromMap(map);

    expect(adjustment.id, 1);
    expect(adjustment.adjustDate, '2026-07-07');
    expect(adjustment.adjustmentMinutes, 15);
    expect(adjustment.source, LimitAdjustmentSource.coupon);
    expect(adjustment.sourceId, 42);
  });

  test('DailyLimitAdjustment fromMap handles negative minutes and null source_id', () {
    final map = {
      'id': 2,
      'adjust_date': '2026-07-08',
      'adjustment_minutes': -10,
      'source': 'task_penalty',
      'source_id': null,
      'created_at': 1720000000000,
    };

    final adjustment = DailyLimitAdjustment.fromMap(map);

    expect(adjustment.adjustmentMinutes, -10);
    expect(adjustment.source, LimitAdjustmentSource.taskPenalty);
    expect(adjustment.sourceId, isNull);
  });

  test('DailyLimitAdjustment toMap produces correct map', () {
    final adjustment = DailyLimitAdjustment(
      id: 3,
      adjustDate: '2026-07-09',
      adjustmentMinutes: 30,
      source: LimitAdjustmentSource.parentGrant,
      sourceId: null,
    );

    final map = adjustment.toMap();

    expect(map['id'], 3);
    expect(map['adjust_date'], '2026-07-09');
    expect(map['adjustment_minutes'], 30);
    expect(map['source'], 'parent_grant');
    expect(map['source_id'], isNull);
    expect(map['created_at'], isNotNull);
  });

  test('DailyLimitAdjustment copyWith works correctly', () {
    final original = DailyLimitAdjustment(
      adjustDate: '2026-07-07',
      adjustmentMinutes: 15,
      source: LimitAdjustmentSource.coupon,
    );

    final copied = original.copyWith(adjustmentMinutes: 30);

    expect(copied.adjustDate, '2026-07-07');
    expect(copied.adjustmentMinutes, 30);
    expect(copied.source, LimitAdjustmentSource.coupon);
  });
}
