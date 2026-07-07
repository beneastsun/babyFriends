import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/database/daos/daos.dart';
import 'package:qiaoqiao_companion/shared/providers/task_provider.dart';
import 'package:qiaoqiao_companion/shared/models/models.dart';
import 'package:qiaoqiao_companion/shared/models/task_definition.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';
import 'package:qiaoqiao_companion/core/database/daos/task_checkin_dao.dart';
import 'package:qiaoqiao_companion/core/database/daos/task_penalty_dao.dart';

late AppDatabase _db;
late TaskNotifier _taskNotifier;

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    _db = AppDatabase.instance;
    await _db.database;
    _taskNotifier = TaskNotifier(
      TaskDefinitionDao(_db),
      TaskCheckinDao(_db),
      TaskPenaltyDao(_db),
      DailyLimitAdjustmentDao(_db),
      PointsDao(_db),
    );
  });

  tearDownAll(() async {
    await _db.close();
  });

  test('generatePenalties creates daily_limit_adjustments with negative minutes', () async {
    final database = await _db.database;
    final today = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';

    // 清空测试数据
    await database.delete(DatabaseConstants.tableTaskDefinitions);
    await database.delete(DatabaseConstants.tableTaskCheckins);
    await database.delete(DatabaseConstants.tableTaskPenalties);
    await database.delete(DatabaseConstants.tableDailyLimitAdjustments);

    // 插入一个有惩罚的任务
    final taskId = await database.insert(DatabaseConstants.tableTaskDefinitions, {
      'name': '眼保健操',
      'emoji': '👀',
      'category': 'health',
      'base_points': 10,
      'extra_points': 0,
      'min_daily_count': 1,
      'max_daily_count': 1,
      'checkin_mode': 'self',
      'penalty_minutes': 10,
      'enabled': 1,
      'sort_order': 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    });

    // 不插入昨天的打卡记录（模拟未完成）

    // 执行 generatePenalties
    await _taskNotifier.generatePenalties();

    // 验证 task_penalties 表有记录
    final penalties = await database.query(DatabaseConstants.tableTaskPenalties);
    expect(penalties.length, 1);
    expect(penalties.first['penalty_minutes'], 10);
    expect(penalties.first['applied'], 1);

    // 验证 daily_limit_adjustments 表有负数记录
    final adjustments = await database.query(
      DatabaseConstants.tableDailyLimitAdjustments,
      where: 'adjust_date = ? AND source = ?',
      whereArgs: [today, 'task_penalty'],
    );
    expect(adjustments.length, 1);
    expect(adjustments.first['adjustment_minutes'], -10);
    expect(adjustments.first['source_id'], penalties.first['id']);
  });

  test('generatePenalties is idempotent - does not duplicate', () async {
    // 再次执行 generatePenalties
    await _taskNotifier.generatePenalties();

    final database = await _db.database;
    final penalties = await database.query(DatabaseConstants.tableTaskPenalties);
    expect(penalties.length, 1); // 仍然只有 1 条
  });
}
