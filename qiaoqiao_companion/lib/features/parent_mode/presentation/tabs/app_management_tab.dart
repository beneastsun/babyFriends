import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/theme/app_theme.dart';
import 'package:qiaoqiao_companion/features/parent_mode/presentation/app_selection_page.dart';
import 'package:qiaoqiao_companion/features/parent_mode/presentation/widgets/monitored_app_card.dart';
import 'package:qiaoqiao_companion/shared/models/models.dart';
import 'package:qiaoqiao_companion/shared/providers/monitored_apps_provider.dart';
import 'package:qiaoqiao_companion/shared/widgets/design_system/app_button.dart';

/// 应用管理 Tab
class AppManagementTab extends ConsumerStatefulWidget {
  const AppManagementTab({super.key});

  @override
  ConsumerState<AppManagementTab> createState() => _AppManagementTabState();
}

class _AppManagementTabState extends ConsumerState<AppManagementTab> {
  @override
  void initState() {
    super.initState();
    // 加载数据
    Future.microtask(() => ref.read(monitoredAppsProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final appsState = ref.watch(monitoredAppsProvider);

    return Column(
      children: [
        // 说明卡片
        Container(
          margin: const EdgeInsets.all(AppSpacing.md),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.info),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '只有添加到这里的应用才会被监控和限制，其他应用不受限制。',
                  style: AppTextStyles.body2,
                ),
              ),
            ],
          ),
        ),

        // 应用列表
        Expanded(
          child: appsState.allApps.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  itemCount: appsState.allApps.length,
                  itemBuilder: (context, index) {
                    final app = appsState.allApps[index];
                    return MonitoredAppCardWithDialog(
                      app: app,
                      onUpdate: _updateApp,
                      onDelete: () => _deleteApp(app.packageName),
                    );
                  },
                ),
        ),

        // 添加应用按钮
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: AppButtonPrimary(
            onPressed: _addApps,
            icon: const Icon(Icons.add),
            isFullWidth: true,
            child: const Text('添加应用'),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.apps_outlined,
            size: 64,
            color: AppTheme.textHint,
          ),
          SizedBox(height: AppSpacing.md),
          Text(
            '还没有添加监控应用',
            style: AppTextStyles.body1,
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            '点击下方按钮选择要监控的应用',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }

  Future<void> _updateApp(MonitoredApp app) async {
    await ref.read(monitoredAppsProvider.notifier).updateApp(app);
  }

  Future<void> _deleteApp(String packageName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移除应用'),
        content: const Text('确定要移除该应用的监控吗？'),
        actions: [
          AppButtonGhost(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          AppButtonGhost(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('移除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(monitoredAppsProvider.notifier).removeApp(packageName);
    }
  }

  Future<void> _addApps() async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (context) => const AppSelectionPage(),
        fullscreenDialog: true,
      ),
    );

    if (result != null && result.isNotEmpty) {
      // 批量添加选中的应用
      final apps = result.entries.map((entry) {
        return MonitoredApp(
          packageName: entry.key,
          appName: entry.value, // 使用真实的应用名称
          enabled: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }).toList();

      await ref.read(monitoredAppsProvider.notifier).addApps(apps);
    }
  }
}
