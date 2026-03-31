import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/theme/app_theme.dart';
import 'package:qiaoqiao_companion/features/home/presentation/widgets/app_usage_list.dart';

/// 应用列表页面 - 显示所有应用的完整列表
class AppListPage extends ConsumerWidget {
  const AppListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text('应用使用明细'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: const AppUsageList(
          maxItems: 100, // 显示所有应用
          showViewAll: false, // 不显示"查看全部"按钮
        ),
      ),
    );
  }
}
