import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<void> _deleteExistingDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, DatabaseConstants.databaseName);
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  test('daily_limit_adjustments table exists after fresh creation', () async {
    await _deleteExistingDb();
    final db = AppDatabase.instance;
    final database = await db.database;

    final tables = await database.query(
      'sqlite_master',
      where: 'type = ? AND name = ?',
      whereArgs: ['table', 'daily_limit_adjustments'],
    );
    expect(tables, isNotEmpty);
    await db.close();
  });

  test('task_checkins has unique index on (task_id, checkin_date, checkin_time)', () async {
    await _deleteExistingDb();
    final db = AppDatabase.instance;
    final database = await db.database;

    final indexes = await database.query(
      'sqlite_master',
      where: 'type = ? AND name = ?',
      whereArgs: ['index', 'idx_checkins_unique'],
    );
    expect(indexes, isNotEmpty);
    await db.close();
  });

  test('daily_limit_adjustments has index on adjust_date', () async {
    await _deleteExistingDb();
    final db = AppDatabase.instance;
    final database = await db.database;

    final indexes = await database.query(
      'sqlite_master',
      where: 'type = ? AND name = ?',
      whereArgs: ['index', 'idx_adjustments_date'],
    );
    expect(indexes, isNotEmpty);
    await db.close();
  });
}
