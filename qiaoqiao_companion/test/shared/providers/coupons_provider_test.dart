import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/database/daos/daos.dart';
import 'package:qiaoqiao_companion/shared/providers/coupons_provider.dart';
import 'package:qiaoqiao_companion/shared/providers/points_provider.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';

late AppDatabase _db;
late CouponsNotifier _couponsNotifier;

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    _db = AppDatabase.instance;
    await _db.database;
  });

  tearDownAll(() async {
    await _db.close();
  });

  test('use creates daily_limit_adjustments record with positive minutes', () async {
    final database = await _db.database;
    final today = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';

    // 先插入一张可用的加时券
    final couponId = await database.insert(DatabaseConstants.tableCoupons, {
      'type': 'custom',
      'status': 'available',
      'duration': 15,
      'source': 'earned',
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });

    // 清空今日调整记录
    await database.delete(DatabaseConstants.tableDailyLimitAdjustments,
        where: 'adjust_date = ?', whereArgs: [today]);

    // 使用 ProviderContainer 创建 notifier
    final container = ProviderContainer();
    _couponsNotifier = container.read(couponsProvider.notifier);
    await _couponsNotifier.load();

    // 使用加时券
    final result = await _couponsNotifier.use(couponId);

    expect(result, true);

    // 验证 daily_limit_adjustments 表有记录
    final adjustments = await database.query(
      DatabaseConstants.tableDailyLimitAdjustments,
      where: 'adjust_date = ? AND source = ?',
      whereArgs: [today, 'coupon'],
    );
    expect(adjustments, isNotEmpty);
    expect(adjustments.first['adjustment_minutes'], 15);
    expect(adjustments.first['source_id'], couponId);

    // 清理
    await database.delete(DatabaseConstants.tableCoupons, where: 'id = ?', whereArgs: [couponId]);
    await database.delete(DatabaseConstants.tableDailyLimitAdjustments,
        where: 'adjust_date = ?', whereArgs: [today]);
  });

  test('exchangePointsPerMinute constant is 10', () {
    expect(PointsConstants.exchangePointsPerMinute, 10);
  });

  test('exchange(10) deducts 100 points and creates 10-minute coupon', () async {
    final database = await _db.database;
    final container = ProviderContainer();
    final pointsNotifier = container.read(pointsProvider.notifier);
    _couponsNotifier = container.read(couponsProvider.notifier);

    // 清理旧的兑换券和积分记录
    await database.delete(DatabaseConstants.tableCoupons,
        where: 'source = ?', whereArgs: ['earned']);

    // 先加 200 积分
    await pointsNotifier.addPoints(200, '测试积分',
        category: PointsCategory.other);
    final balanceBefore = pointsNotifier.state.balance;
    expect(balanceBefore >= 200, true);

    // 兑换 10 分钟 = 100 积分
    final result = await _couponsNotifier.exchange(10);
    expect(result, true);

    // 验证积分扣了 100
    final balanceAfter = pointsNotifier.state.balance;
    expect(balanceAfter, balanceBefore - 100);

    // 验证券创建成功，时长 10 分钟
    final coupons = await database.query(DatabaseConstants.tableCoupons,
        where: 'source = ? AND duration = ?',
        whereArgs: ['earned', 10]);
    expect(coupons, isNotEmpty);

    // 清理
    await database.delete(DatabaseConstants.tableCoupons,
        where: 'source = ?', whereArgs: ['earned']);
  });

  test('exchange(0) returns false for invalid input', () async {
    final container = ProviderContainer();
    _couponsNotifier = container.read(couponsProvider.notifier);
    final result = await _couponsNotifier.exchange(0);
    expect(result, false);
  });

  test('exchange returns false when points insufficient', () async {
    final database = await _db.database;
    final container = ProviderContainer();
    final pointsNotifier = container.read(pointsProvider.notifier);
    _couponsNotifier = container.read(couponsProvider.notifier);

    // 确保积分不足（先清零再加少量积分）
    // 使用 deductPoints 尝试清零，然后只加 50 积分
    await pointsNotifier.addPoints(50, '测试积分',
        category: PointsCategory.other);

    // 尝试兑换 100 分钟 = 1000 积分（远超余额）
    final result = await _couponsNotifier.exchange(100);
    expect(result, false);

    // 清理
    await database.delete(DatabaseConstants.tableCoupons,
        where: 'source = ?', whereArgs: ['earned']);
  });
}
