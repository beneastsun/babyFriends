import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/database/daos/daos.dart';
import 'package:qiaoqiao_companion/shared/providers/points_provider.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';

late AppDatabase _db;
late PointsNotifier _pointsNotifier;

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    _db = AppDatabase.instance;
    await _db.database;
    _pointsNotifier = PointsNotifier(PointsDao(_db));
    await _pointsNotifier.load();
  });

  tearDownAll(() async {
    await _db.close();
  });

  test('addPoints accepts category parameter and stores it', () async {
    final balanceBefore = _pointsNotifier.state.balance;
    await _pointsNotifier.addPoints(
      10,
      '完成任务测试',
      category: PointsCategory.exerciseReward,
    );
    expect(_pointsNotifier.state.balance, balanceBefore + 10);

    // 验证 category 被正确写入数据库
    final database = await _db.database;
    final records = await database.query(
      DatabaseConstants.tablePointsHistory,
      where: 'reason = ?',
      whereArgs: ['完成任务测试'],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    expect(records, isNotEmpty);
    expect(records.first['category'], 'exerciseReward');
  });

  test('deductPoints accepts category parameter', () async {
    final balanceBefore = _pointsNotifier.state.balance;
    if (balanceBefore >= 5) {
      await _pointsNotifier.deductPoints(
        5,
        '惩罚扣分测试',
        category: PointsCategory.timePenalty,
      );
      expect(_pointsNotifier.state.balance, balanceBefore - 5);

      final database = await _db.database;
      final records = await database.query(
        DatabaseConstants.tablePointsHistory,
        where: 'reason = ?',
        whereArgs: ['惩罚扣分测试'],
        orderBy: 'created_at DESC',
        limit: 1,
      );
      expect(records, isNotEmpty);
      expect(records.first['category'], 'timePenalty');
    }
  });
}
