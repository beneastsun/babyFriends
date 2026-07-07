import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/database/daos/daos.dart';
import 'package:qiaoqiao_companion/shared/providers/coupons_provider.dart';
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
      'type': 'small',
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
}
