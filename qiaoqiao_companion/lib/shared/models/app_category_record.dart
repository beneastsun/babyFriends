import 'package:qiaoqiao_companion/core/constants/database_constants.dart';

/// 应用分类记录模型
class AppCategoryRecord {
  final String packageName;
  final String? appName;
  final AppCategory category;
  final bool isCustom;
  final DateTime updatedAt;

  AppCategoryRecord({
    required this.packageName,
    this.appName,
    this.category = AppCategory.other,
    this.isCustom = false,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  factory AppCategoryRecord.fromMap(Map<String, dynamic> map) {
    return AppCategoryRecord(
      packageName: map['package_name'] as String,
      appName: map['app_name'] as String?,
      category: AppCategory.fromCode(map['category'] as String? ?? 'other'),
      isCustom: (map['custom'] as int?) == 1,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'package_name': packageName,
      'app_name': appName,
      'category': category.code,
      'custom': isCustom ? 1 : 0,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };
  }

  AppCategoryRecord copyWith({
    String? packageName,
    String? appName,
    AppCategory? category,
    bool? isCustom,
    DateTime? updatedAt,
  }) {
    return AppCategoryRecord(
      packageName: packageName ?? this.packageName,
      appName: appName ?? this.appName,
      category: category ?? this.category,
      isCustom: isCustom ?? this.isCustom,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'AppCategoryRecord(package: $packageName, category: $category, custom: $isCustom)';
  }
}
