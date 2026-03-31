import 'package:qiaoqiao_companion/core/constants/database_constants.dart';

/// 积分流水记录模型
class PointsHistory {
  final int? id;
  final int points; // 积分变化量（正数为获得，负数为消耗）
  final PointsTransactionType type; // 交易类型
  final PointsCategory category; // 积分类别
  final String description; // 描述
  final int balanceAfter; // 变化后余额
  final DateTime createdAt;

  PointsHistory({
    this.id,
    required this.points,
    PointsTransactionType? type,
    this.category = PointsCategory.other,
    required this.description,
    required this.balanceAfter,
    DateTime? createdAt,
  })  : type = type ?? PointsTransactionType.earned,
        createdAt = createdAt ?? DateTime.now();

  factory PointsHistory.fromMap(Map<String, dynamic> map) {
    final changeValue = map['change'] as int;
    return PointsHistory(
      id: map['id'] as int?,
      points: changeValue.abs(),
      type: changeValue > 0
          ? PointsTransactionType.earned
          : PointsTransactionType.spent,
      category: _parseCategory(map['category'] as String?),
      description: map['reason'] as String? ?? '',
      balanceAfter: map['balance_after'] as int? ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['created_at'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  static PointsCategory _parseCategory(String? value) {
    if (value == null) return PointsCategory.other;
    return PointsCategory.values.firstWhere(
      (e) => e.name == value,
      orElse: () => PointsCategory.other,
    );
  }

  Map<String, dynamic> toMap() {
    final changeValue = type == PointsTransactionType.earned ? points : -points;
    return {
      if (id != null) 'id': id,
      'change': changeValue,
      'reason': description,
      'category': category.name,
      'balance_after': balanceAfter,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  bool get isEarned => type == PointsTransactionType.earned;

  /// 兼容旧代码
  int get change => type == PointsTransactionType.earned ? points : -points;
  String get reason => description;

  PointsHistory copyWith({
    int? id,
    int? points,
    PointsTransactionType? type,
    PointsCategory? category,
    String? description,
    int? balanceAfter,
    DateTime? createdAt,
  }) {
    return PointsHistory(
      id: id ?? this.id,
      points: points ?? this.points,
      type: type ?? this.type,
      category: category ?? this.category,
      description: description ?? this.description,
      balanceAfter: balanceAfter ?? this.balanceAfter,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'PointsHistory(id: $id, points: $points, type: $type, balanceAfter: $balanceAfter)';
  }
}
