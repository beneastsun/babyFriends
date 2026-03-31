import 'package:qiaoqiao_companion/core/constants/database_constants.dart';

/// 加时券模型
class Coupon {
  final int? id;
  final CouponType type;
  final int durationMinutes;
  final CouponSource source;
  final CouponStatus status;
  final DateTime? expiresAt;
  final DateTime? usedAt;
  final DateTime createdAt;

  Coupon({
    this.id,
    required this.type,
    required this.durationMinutes,
    required this.source,
    this.status = CouponStatus.available,
    this.expiresAt,
    this.usedAt,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Coupon.fromMap(Map<String, dynamic> map) {
    return Coupon(
      id: map['id'] as int?,
      type: CouponType.fromCode(map['type'] as String? ?? 'small'),
      durationMinutes: map['duration'] as int,
      source: CouponSource.fromCode(map['source'] as String? ?? 'earned'),
      status: CouponStatus.fromCode(map['status'] as String? ?? 'available'),
      expiresAt: map['expires_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['expires_at'] as int)
          : null,
      usedAt: map['used_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['used_at'] as int)
          : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'type': type.code,
      'duration': durationMinutes,
      'source': source.code,
      'status': status.code,
      'expires_at': expiresAt?.millisecondsSinceEpoch,
      'used_at': usedAt?.millisecondsSinceEpoch,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  /// 是否可用
  bool get isAvailable {
    if (status != CouponStatus.available) return false;
    if (expiresAt != null && DateTime.now().isAfter(expiresAt!)) return false;
    return true;
  }

  /// 是否永久有效
  bool get isPermanent => expiresAt == null;

  /// 是否已过期
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  Coupon copyWith({
    int? id,
    CouponType? type,
    int? durationMinutes,
    CouponSource? source,
    CouponStatus? status,
    DateTime? expiresAt,
    DateTime? usedAt,
    DateTime? createdAt,
  }) {
    return Coupon(
      id: id ?? this.id,
      type: type ?? this.type,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      source: source ?? this.source,
      status: status ?? this.status,
      expiresAt: expiresAt ?? this.expiresAt,
      usedAt: usedAt ?? this.usedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'Coupon(id: $id, type: $type, status: $status, duration: ${durationMinutes}m)';
  }
}

/// 加时券工厂
class CouponFactory {
  /// 创建积分兑换的加时券
  static Coupon createEarned(CouponType type) {
    return Coupon(
      type: type,
      durationMinutes: type.durationMinutes,
      source: CouponSource.earned,
      // 积分兑换的永久有效
      expiresAt: null,
    );
  }

  /// 创建家长发放的加时券
  static Coupon createParentGiven(int durationMinutes) {
    return Coupon(
      type: CouponType.small, // 类型不重要，用 durationMinutes 指定
      durationMinutes: durationMinutes,
      source: CouponSource.parentGiven,
      // 家长发放的 7 天有效
      expiresAt: DateTime.now().add(const Duration(days: 7)),
    );
  }
}
