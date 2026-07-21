import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/database/daos/daos.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';
import 'package:qiaoqiao_companion/shared/models/models.dart';
import 'package:qiaoqiao_companion/shared/providers/points_provider.dart';
import 'package:qiaoqiao_companion/shared/providers/today_usage_provider.dart';

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
  final DailyLimitAdjustmentDao _limitAdjustmentDao;
  final Ref _ref;

  CouponsNotifier(
    this._couponDao,
    this._limitAdjustmentDao,
    this._ref,
  ) : super(const CouponsState());

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

  /// 兑换加时券（10 积分 = 1 分钟）
  Future<bool> exchange(int minutes) async {
    if (minutes <= 0) return false;

    final cost = minutes * PointsConstants.exchangePointsPerMinute;
    final pointsNotifier = _ref.read(pointsProvider.notifier);
    final currentBalance = pointsNotifier.state.balance;

    if (currentBalance < cost) {
      return false;
    }

    // 扣除积分
    final deducted = await pointsNotifier.deductPoints(
      cost,
      '兑换$minutes分钟加时券',
      category: PointsCategory.couponExchange,
    );

    if (!deducted) return false;

    // 创建加时券
    final coupon = CouponFactory.createEarned(minutes);
    await _couponDao.insert(coupon);

    await load();
    return true;
  }

  /// 使用加时券
  Future<bool> use(int couponId) async {
    final success = await _couponDao.use(couponId);
    if (success) {
      // 读取券信息获取时长
      final coupon = await _couponDao.getById(couponId);
      if (coupon != null) {
        // 写入日限额调整记录
        final today = _formatDate(DateTime.now());
        final adjustment = DailyLimitAdjustment(
          adjustDate: today,
          adjustmentMinutes: coupon.durationMinutes,
          source: LimitAdjustmentSource.coupon,
          sourceId: couponId,
        );
        await _limitAdjustmentDao.insert(adjustment);
      }
      await load();
    }
    return success;
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// 家长发放加时券
  Future<void> parentGrant(int durationMinutes) async {
    final coupon = CouponFactory.createParentGiven(durationMinutes);
    await _couponDao.insert(coupon);
    await load();
  }

  /// 倒计时期间兑换并立即加时（不创建券，直接扣积分+写调整记录）
  /// 每日最多兑换一次，最多 10 分钟。返回兑换的分钟数（失败返回 0）
  Future<int> exchangeAndUseForCountdown(int minutes) async {
    if (minutes <= 0 || minutes > 10) return 0;

    final today = _formatDate(DateTime.now());

    // 检查今日是否已通过倒计时兑换过
    final alreadyExchanged = await _limitAdjustmentDao.existsByDateAndSource(
      today,
      LimitAdjustmentSource.countdownExchange,
    );
    if (alreadyExchanged) return 0;

    final cost = minutes * PointsConstants.exchangePointsPerMinute;
    final pointsNotifier = _ref.read(pointsProvider.notifier);
    if (pointsNotifier.state.balance < cost) return 0;

    final deducted = await pointsNotifier.deductPoints(
      cost,
      '倒计时兑换$minutes分钟',
      category: PointsCategory.couponExchange,
    );
    if (!deducted) return 0;

    // 直接写调整记录（不走 coupon 创建流程，避免重复加时）
    final adjustment = DailyLimitAdjustment(
      adjustDate: today,
      adjustmentMinutes: minutes,
      source: LimitAdjustmentSource.countdownExchange,
    );
    await _limitAdjustmentDao.insert(adjustment);

    // 立即刷新同步到 app_settings
    await _ref.read(todayUsageProvider.notifier).refresh();

    return minutes;
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
  return CouponsNotifier(
    CouponDao(db),
    DailyLimitAdjustmentDao(db),
    ref,
  );
});
