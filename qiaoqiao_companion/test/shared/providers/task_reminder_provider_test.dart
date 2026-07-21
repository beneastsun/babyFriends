import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/database/daos/daos.dart';
import 'package:qiaoqiao_companion/shared/providers/task_reminder_provider.dart';
import 'package:qiaoqiao_companion/shared/models/task_definition.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

late AppDatabase _db;
late TaskReminderNotifier _notifier;

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // 初始化 timezone（NotificationService.scheduleTaskReminder 需要）
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));
    _db = AppDatabase.instance;
    await _db.database;
    _notifier = TaskReminderNotifier(
      TaskDefinitionDao(_db),
      _db,
    );
  });

  setUp(() async {
    final database = await _db.database;
    await database.delete(DatabaseConstants.tableTaskDefinitions);
    await database.delete(DatabaseConstants.tableTaskCheckins);
  });

  test('registerDailyReminders skips tasks without reminderTime', () async {
    final database = await _db.database;
    await database.insert(DatabaseConstants.tableTaskDefinitions, {
      'name': '无提醒任务', 'emoji': '⭐', 'category': 'health',
      'base_points': 10, 'extra_points': 0, 'min_daily_count': 1, 'max_daily_count': 1,
      'checkin_mode': 'self', 'penalty_minutes': 0, 'enabled': 1, 'sort_order': 0,
      'reminder_time': null,
      'reminder_repeat_interval': 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    });

    final count = await _notifier.registerDailyReminders();
    expect(count, 0);
  });

  test('registerDailyReminders registers tasks with reminderTime', () async {
    final database = await _db.database;
    await database.insert(DatabaseConstants.tableTaskDefinitions, {
      'name': '眼保健操', 'emoji': '👀', 'category': 'health',
      'base_points': 10, 'extra_points': 0, 'min_daily_count': 1, 'max_daily_count': 1,
      'checkin_mode': 'self', 'penalty_minutes': 5, 'enabled': 1, 'sort_order': 0,
      'reminder_time': '10:00',
      'reminder_repeat_interval': 30,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    });

    final count = await _notifier.registerDailyReminders();
    expect(count, 1);
  });

  test('getPendingReminders returns tasks with reminderTime not yet checked in', () async {
    final database = await _db.database;
    final taskId = await database.insert(DatabaseConstants.tableTaskDefinitions, {
      'name': '阅读', 'emoji': '📚', 'category': 'study',
      'base_points': 10, 'extra_points': 0, 'min_daily_count': 1, 'max_daily_count': 1,
      'checkin_mode': 'self', 'penalty_minutes': 0, 'enabled': 1, 'sort_order': 0,
      'reminder_time': '20:00',
      'reminder_repeat_interval': 15,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    });

    final pending = await _notifier.getPendingReminders();
    expect(pending.length, 1);
    expect(pending.first.id, taskId);
    expect(pending.first.reminderTime, '20:00');
  });
}
