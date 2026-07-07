import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/database/daos/egg_weekly_progress_dao.dart';
import 'package:qiaoqiao_companion/shared/models/egg_weekly_progress.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';

void main() {
  late AppDatabase db;
  late EggWeeklyProgressDao dao;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    db = AppDatabase.instance;
    await db.database;
    dao = EggWeeklyProgressDao(db);
  });

  tearDownAll(() async {
    await db.close();
  });

  setUp(() async {
    final database = await db.database;
    await database.delete(DatabaseConstants.tableEggWeeklyProgress);
  });

  test('upsert inserts new record', () async {
    final progress = EggWeeklyProgress(
      weekStart: '2026-07-07',
      totalTaskCount: 10,
      completedTaskCount: 5,
      highestStage: 2,
      eggStyle: EggStyle.princess,
    );

    await dao.upsert(progress);
    final result = await dao.getByWeekStart('2026-07-07');

    expect(result, isNotNull);
    expect(result!.totalTaskCount, 10);
    expect(result.completedTaskCount, 5);
  });

  test('upsert updates existing record', () async {
    await dao.upsert(EggWeeklyProgress(
      weekStart: '2026-07-07',
      totalTaskCount: 10,
      completedTaskCount: 3,
      highestStage: 1,
      eggStyle: EggStyle.princess,
    ));

    await dao.upsert(EggWeeklyProgress(
      weekStart: '2026-07-07',
      totalTaskCount: 10,
      completedTaskCount: 7,
      highestStage: 3,
      eggStyle: EggStyle.sporty,
    ));

    final result = await dao.getByWeekStart('2026-07-07');
    expect(result!.completedTaskCount, 7);
    expect(result.highestStage, 3);
    expect(result.eggStyle, EggStyle.sporty);
  });

  test('getByWeekStart returns null when not found', () async {
    final result = await dao.getByWeekStart('2026-01-01');
    expect(result, isNull);
  });

  test('updateStyle changes egg_style for a week', () async {
    await dao.upsert(EggWeeklyProgress(
      weekStart: '2026-07-07',
      totalTaskCount: 10,
      completedTaskCount: 5,
      highestStage: 2,
      eggStyle: EggStyle.princess,
    ));

    await dao.updateStyle('2026-07-07', EggStyle.fairy);

    final result = await dao.getByWeekStart('2026-07-07');
    expect(result!.eggStyle, EggStyle.fairy);
  });

  test('getLatest returns most recent week', () async {
    await dao.upsert(EggWeeklyProgress(
      weekStart: '2026-06-30',
      totalTaskCount: 10,
      completedTaskCount: 8,
      highestStage: 4,
      eggStyle: EggStyle.princess,
    ));
    await dao.upsert(EggWeeklyProgress(
      weekStart: '2026-07-07',
      totalTaskCount: 10,
      completedTaskCount: 5,
      highestStage: 2,
      eggStyle: EggStyle.princess,
    ));

    final result = await dao.getLatest();

    expect(result, isNotNull);
    expect(result!.weekStart, '2026-07-07');
  });
}
