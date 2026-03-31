import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';
import 'package:qiaoqiao_companion/shared/models/models.dart';

/// 积分流水 DAO
class PointsDao {
  final AppDatabase _database;

  PointsDao(this._database);

  Future<int> insert(PointsHistory history) async {
    final db = await _database.database;
    return await db.insert(
      DatabaseConstants.tablePointsHistory,
      history.toMap(),
    );
  }

  Future<List<PointsHistory>> getAll({
    int? limit,
    int? offset,
  }) async {
    final db = await _database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseConstants.tablePointsHistory,
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );
    return maps.map((map) => PointsHistory.fromMap(map)).toList();
  }

  Future<List<PointsHistory>> getByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await _database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseConstants.tablePointsHistory,
      where: 'created_at >= ? AND created_at <= ?',
      whereArgs: [
        startDate.millisecondsSinceEpoch,
        endDate.millisecondsSinceEpoch,
      ],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => PointsHistory.fromMap(map)).toList();
  }

  /// 获取当前积分余额
  Future<int> getCurrentBalance() async {
    final db = await _database.database;
    final result = await db.rawQuery(
      'SELECT balance_after FROM ${DatabaseConstants.tablePointsHistory} '
      'ORDER BY created_at DESC LIMIT 1',
    );
    if (result.isEmpty) return 0;
    return result.first['balance_after'] as int;
  }

  /// 添加积分
  Future<int> addPoints(int amount, String reason, {PointsCategory category = PointsCategory.other}) async {
    final currentBalance = await getCurrentBalance();
    final newBalance = (currentBalance + amount).clamp(
      PointsConstants.minPoints,
      PointsConstants.maxPoints,
    );

    final history = PointsHistory(
      points: amount,
      type: PointsTransactionType.earned,
      category: category,
      description: reason,
      balanceAfter: newBalance,
    );

    await insert(history);
    return newBalance;
  }

  /// 扣减积分
  Future<int?> deductPoints(int amount, String reason, {PointsCategory category = PointsCategory.other}) async {
    final currentBalance = await getCurrentBalance();
    if (currentBalance < amount) return null;

    final newBalance = currentBalance - amount;
    final history = PointsHistory(
      points: amount,
      type: PointsTransactionType.spent,
      category: category,
      description: reason,
      balanceAfter: newBalance,
    );

    await insert(history);
    return newBalance;
  }

  /// 获取指定日期获得的积分
  Future<int> getPointsEarnedByDate(String date) async {
    final db = await _database.database;
    final startOfDay = DateTime.parse(date);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final result = await db.rawQuery(
      'SELECT SUM(change) as total FROM ${DatabaseConstants.tablePointsHistory} '
      'WHERE change > 0 AND created_at >= ? AND created_at < ?',
      [startOfDay.millisecondsSinceEpoch, endOfDay.millisecondsSinceEpoch],
    );
    return (result.first['total'] as int?) ?? 0;
  }

  Future<int> deleteAll() async {
    final db = await _database.database;
    return await db.delete(DatabaseConstants.tablePointsHistory);
  }
}
