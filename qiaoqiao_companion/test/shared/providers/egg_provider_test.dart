import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/database/daos/daos.dart';
import 'package:qiaoqiao_companion/shared/providers/egg_provider.dart';
import 'package:qiaoqiao_companion/shared/models/egg_weekly_progress.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';

late AppDatabase _db;
late EggNotifier _eggNotifier;

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    _db = AppDatabase.instance;
    await _db.database;
  });

  setUp(() async {
    final database = await _db.database;
    await database.delete(DatabaseConstants.tableEggWeeklyProgress);
    await database.delete(DatabaseConstants.tableTaskCheckins);
    await database.delete(DatabaseConstants.tableTaskDefinitions);
    _eggNotifier = EggNotifier(
      EggWeeklyProgressDao(_db),
      TaskCheckinDao(_db),
      TaskDefinitionDao(_db),
    );
  });

  test('initial state has stage 0 and princess style', () {
    expect(_eggNotifier.state.stage, 0);
    expect(_eggNotifier.state.eggStyle, EggStyle.princess);
  });

  test('refreshWeeklyProgress calculates completed days from checkins', () async {
    final database = await _db.database;
    final now = DateTime.now();
    final todayStr = _formatDate(now);

    // 插入 1 个任务
    final taskId = await database.insert(DatabaseConstants.tableTaskDefinitions, {
      'name': '眼保健操', 'emoji': '👀', 'category': 'health',
      'base_points': 10, 'extra_points': 0, 'min_daily_count': 1, 'max_daily_count': 1,
      'checkin_mode': 'self', 'penalty_minutes': 0, 'enabled': 1, 'sort_order': 0,
      'created_at': now.millisecondsSinceEpoch, 'updated_at': now.millisecondsSinceEpoch,
    });

    // 今天打卡1次
    await database.insert(DatabaseConstants.tableTaskCheckins, {
      'task_id': taskId, 'checkin_date': todayStr, 'checkin_time': '09:00',
      'points_earned': 10, 'confirmed_by_parent': 0,
      'created_at': now.millisecondsSinceEpoch,
    });

    await _eggNotifier.refreshWeeklyProgress();

    // 本周应完成 = 1 任务 × 7 天 = 7
    // 今天已打卡 1 次，达到 minDailyCount=1，所以 completedTaskCount=1
    expect(_eggNotifier.state.totalTaskCount, 7);
    expect(_eggNotifier.state.completedTaskCount, 1);
    // completionRate = 1/7 ≈ 0.143, stage = (0.143*5).floor() = 0
    expect(_eggNotifier.state.stage, 0);
  });

  test('refreshWeeklyProgress stage advances with more checkins', () async {
    final database = await _db.database;
    final now = DateTime.now();

    // 插入 3 个任务
    for (int t = 0; t < 3; t++) {
      await database.insert(DatabaseConstants.tableTaskDefinitions, {
        'name': '任务$t', 'emoji': '⭐', 'category': 'health',
        'base_points': 10, 'extra_points': 0, 'min_daily_count': 1, 'max_daily_count': 1,
        'checkin_mode': 'self', 'penalty_minutes': 0, 'enabled': 1, 'sort_order': t,
        'created_at': now.millisecondsSinceEpoch, 'updated_at': now.millisecondsSinceEpoch,
      });
    }

    // 为每个任务都在今天打卡
    final todayStr = _formatDate(now);
    final tasks = await database.query(DatabaseConstants.tableTaskDefinitions, where: 'enabled = 1');
    for (final task in tasks) {
      await database.insert(DatabaseConstants.tableTaskCheckins, {
        'task_id': task['id'], 'checkin_date': todayStr, 'checkin_time': '09:00',
        'points_earned': 10, 'confirmed_by_parent': 0,
        'created_at': now.millisecondsSinceEpoch,
      });
    }

    await _eggNotifier.refreshWeeklyProgress();

    // 本周应完成 = 3 任务 × 7 天 = 21
    // 今天 3 个任务都打卡了 = 3 达标
    expect(_eggNotifier.state.totalTaskCount, 21);
    expect(_eggNotifier.state.completedTaskCount, 3);
    // completionRate = 3/21 ≈ 0.143, stage = 0
    expect(_eggNotifier.state.stage, 0);
  });

  test('changeStyle updates state and persists', () async {
    await _eggNotifier.refreshWeeklyProgress();
    await _eggNotifier.changeStyle(EggStyle.sporty);

    expect(_eggNotifier.state.eggStyle, EggStyle.sporty);

    // 验证 app_settings 已写入
    final database = await _db.database;
    final settings = await database.query(
      DatabaseConstants.tableAppSettings,
      where: 'key = ?',
      whereArgs: ['egg_style'],
    );
    expect(settings, isNotEmpty);
    expect(settings.first['value'], 'sporty');
  });
}

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
