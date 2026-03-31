import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';
import 'package:qiaoqiao_companion/shared/models/models.dart';

/// 加时券 DAO
class CouponDao {
  final AppDatabase _database;

  CouponDao(this._database);

  Future<int> insert(Coupon coupon) async {
    final db = await _database.database;
    return await db.insert(
      DatabaseConstants.tableCoupons,
      coupon.toMap(),
    );
  }

  Future<List<Coupon>> getAll() async {
    final db = await _database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseConstants.tableCoupons,
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => Coupon.fromMap(map)).toList();
  }

  Future<List<Coupon>> getAvailable() async {
    final db = await _database.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseConstants.tableCoupons,
      where: 'status = ? AND (expires_at IS NULL OR expires_at > ?)',
      whereArgs: [CouponStatus.available.code, now],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => Coupon.fromMap(map)).toList();
  }

  Future<List<Coupon>> getByStatus(CouponStatus status) async {
    final db = await _database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseConstants.tableCoupons,
      where: 'status = ?',
      whereArgs: [status.code],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => Coupon.fromMap(map)).toList();
  }

  Future<Coupon?> getById(int id) async {
    final db = await _database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseConstants.tableCoupons,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Coupon.fromMap(maps.first);
  }

  Future<int> update(Coupon coupon) async {
    final db = await _database.database;
    return await db.update(
      DatabaseConstants.tableCoupons,
      coupon.toMap(),
      where: 'id = ?',
      whereArgs: [coupon.id],
    );
  }

  /// 使用加时券
  Future<bool> use(int id) async {
    final coupon = await getById(id);
    if (coupon == null || !coupon.isAvailable) return false;

    final usedCoupon = coupon.copyWith(
      status: CouponStatus.used,
      usedAt: DateTime.now(),
    );
    await update(usedCoupon);
    return true;
  }

  /// 标记过期的加时券
  Future<int> markExpired() async {
    final db = await _database.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    return await db.update(
      DatabaseConstants.tableCoupons,
      {'status': CouponStatus.expired.code},
      where: 'status = ? AND expires_at IS NOT NULL AND expires_at <= ?',
      whereArgs: [CouponStatus.available.code, now],
    );
  }

  Future<int> delete(int id) async {
    final db = await _database.database;
    return await db.delete(
      DatabaseConstants.tableCoupons,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteAll() async {
    final db = await _database.database;
    return await db.delete(DatabaseConstants.tableCoupons);
  }
}
