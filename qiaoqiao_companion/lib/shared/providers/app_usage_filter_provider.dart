import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/shared/models/app_usage_filter.dart';

/// 应用明细筛选条件 Provider
final appUsageFilterProvider = StateProvider<AppUsageFilter>(
  (_) => const AppUsageFilter.todayAll(),
);
