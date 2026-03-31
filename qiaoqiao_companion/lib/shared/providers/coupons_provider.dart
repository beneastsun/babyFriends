import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/database/daos/daos.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';
import 'package:qiaoqiao_companion/shared/models/models.dart';
import 'package:qiaoqiao_companion/shared/providers/points_provider.dart';

/// 加时券状态
class CouponsState {
  final List<Coupon> availableCoupons;
  final List<Coupon> usedCoupons;
  final List<Coupon> expiredCoupons;

  const CouponsState({
    this.availableCoupons = const [],
    this.usedCoupons = const [],
    this.expiredCoupons = const [],
  });

  int get availableCount => availableCoupons.length;
  int get totalDurationMinutes =>
      availableCoupons.fold(0, (sum, c) => sum + c.durationMinutes);

  CouponsState copyWith({
    List<Coupon>? availableCoupons,
    List<Coupon>? usedCoupons,
    List<Coupon>? expiredCoupons,
  }) {
    return CouponsState(
      availableCoupons: availableCoupons ?? this.availableCoupons,
      usedCoupons: usedCoupons ?? this.usedCoupons,
      expiredCoupons: expiredCoupons ?? this.expiredCoupons,
    );
  }
}

/// 加时券状态 Notifier
class CouponsNotifier extends StateNotifier<CouponsState> {
  final CouponDao _couponDao;
  final Ref _ref;

  CouponsNotifier(this._couponDao, this._ref)
      : super(const CouponsState());

  /// 加载加时券数据
  Future<void> load() async {
    // 先标记过期的加时券
    await _couponDao.markExpired();

    final allCoupons = await _couponDao.getAll();
    final availableCoupons = allCoupons.where((c) => c.isAvailable).toList();
    final usedCoupons = allCoupons.where((c) => c.status == CouponStatus.used).toList();
    final expiredCoupons = allCoupons.where((c) => c.status == CouponStatus.expired).toList();

    state = state.copyWith(
      availableCoupons: availableCoupons,
      usedCoupons: usedCoupons,
      expiredCoupons: expiredCoupons,
    );
  }

  /// 兑换加时券
  Future<bool> exchange(CouponType type) async {
    final cost = type.cost;
    final pointsNotifier = _ref.read(pointsProvider.notifier);
    final currentBalance = pointsNotifier.state.balance;

    if (currentBalance < cost) {
      return false;
    }

    // 扣除积分
    final deducted = await pointsNotifier.deductPoints(
      cost,
      '兑换${type.durationMinutes}分钟加时券',
    );

    if (!deducted) return false;

    // 创建加时券
    final coupon = CouponFactory.createEarned(type);
    await _couponDao.insert(coupon);

    await load();
    return true;
  }

  /// 使用加时券
  Future<bool> use(int couponId) async {
    final success = await _couponDao.use(couponId);
    if (success) {
      await load();
    }
    return success;
  }

  /// 家长发放加时券
  Future<void> parentGrant(int durationMinutes) async {
    final coupon = CouponFactory.createParentGiven(durationMinutes);
    await _couponDao.insert(coupon);
    await load();
  }

  /// 刷新数据
  Future<void> refresh() async {
    await load();
  }
}

/// 加时券状态 Provider
final couponsProvider =
    StateNotifierProvider<CouponsNotifier, CouponsState>((ref) {
  final db = AppDatabase.instance;
  return CouponsNotifier(CouponDao(db), ref);
});
