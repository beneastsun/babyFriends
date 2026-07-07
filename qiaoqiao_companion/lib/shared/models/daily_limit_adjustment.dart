import 'package:qiaoqiao_companion/core/constants/database_constants.dart';

/// 日限额调整模型
/// 记录每日使用时长的调整（正=加时，负=扣减）
class DailyLimitAdjustment {
  final int? id;
  final String adjustDate;
  final int adjustmentMinutes;
  final LimitAdjustmentSource source;
  final int? sourceId;
  final DateTime createdAt;

  DailyLimitAdjustment({
    this.id,
    required this.adjustDate,
    required this.adjustmentMinutes,
    required this.source,
    this.sourceId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory DailyLimitAdjustment.fromMap(Map<String, dynamic> map) {
    return DailyLimitAdjustment(
      id: map['id'] as int?,
      adjustDate: map['adjust_date'] as String,
      adjustmentMinutes: map['adjustment_minutes'] as int,
      source: LimitAdjustmentSource.fromCode(map['source'] as String),
      sourceId: map['source_id'] as int?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'adjust_date': adjustDate,
      'adjustment_minutes': adjustmentMinutes,
      'source': source.code,
      'source_id': sourceId,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  DailyLimitAdjustment copyWith({
    int? id,
    String? adjustDate,
    int? adjustmentMinutes,
    LimitAdjustmentSource? source,
    int? sourceId,
    DateTime? createdAt,
  }) {
    return DailyLimitAdjustment(
      id: id ?? this.id,
      adjustDate: adjustDate ?? this.adjustDate,
      adjustmentMinutes: adjustmentMinutes ?? this.adjustmentMinutes,
      source: source ?? this.source,
      sourceId: sourceId ?? this.sourceId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'DailyLimitAdjustment(id: $id, date: $adjustDate, minutes: $adjustmentMinutes, source: $source)';
  }
}
