import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('egg_weekly_progress table exists after fresh creation', () async {
    final db = AppDatabase.instance;
    final database = await db.database;

    final tables = await database.query(
      'sqlite_master',
      where: 'type = ? AND name = ?',
      whereArgs: ['table', 'egg_weekly_progress'],
    );
    expect(tables, isNotEmpty);
    await db.close();
  });

  test('egg_weekly_progress columns match spec', () async {
    final db = AppDatabase.instance;
    final database = await db.database;

    final columns = await database.rawQuery('PRAGMA table_info(egg_weekly_progress)');
    final columnNames = columns.map((c) => c['name'] as String).toList();

    expect(columnNames, containsAll([
      'id', 'week_start', 'total_task_count',
      'completed_task_count', 'highest_stage', 'egg_style', 'updated_at',
    ]));
    await db.close();
  });
}
