import 'package:flutter/material.dart';
import 'package:qiaoqiao_companion/core/theme/app_theme.dart';
import 'package:qiaoqiao_companion/shared/models/models.dart';
import 'package:qiaoqiao_companion/shared/widgets/app_icon_widget.dart';
import 'package:qiaoqiao_companion/shared/widgets/design_system/app_button.dart';

class MonitoredAppCard extends StatelessWidget {
  final MonitoredApp app;
  final Function(MonitoredApp) onUpdate;
  final VoidCallback onDelete;

  const MonitoredAppCard({
    super.key,
    required this.app,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 应用名称和控制
            Row(
              children: [
                // 应用图标
                AppIconWidget(
                  packageName: app.packageName,
                  appName: app.appName,
                  size: 48,
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppDisplayName(
                        packageName: app.packageName,
                        appName: app.appName,
                        builder: (displayName) => Text(
                          displayName,
                          style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        app.packageName,
                        style: AppTextStyles.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: app.enabled,
                  onChanged: (value) => onUpdate(app.copyWith(enabled: value)),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onDelete,
                ),
              ],
            ),

            // 每日限制设置
            if (app.enabled) ...[
              SizedBox(height: AppSpacing.sm),
              const Divider(),
              SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('每日限制', style: AppTextStyles.body2),
                  _buildLimitSelector(),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLimitSelector() {
    return InkWell(
      onTap: () => _showLimitDialog(),
      borderRadius: BorderRadius.circular(AppBorderRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.timer_outlined,
              size: 18,
              color: AppColors.primary,
            ),
            SizedBox(width: AppSpacing.xs),
            Text(
              app.dailyLimitMinutes != null
                  ? '${app.dailyLimitMinutes} 分钟'
                  : '不限制',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(width: AppSpacing.xs),
            Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  void _showLimitDialog() {
    // 这个方法需要在有 context 的地方调用
    // 这里只是占位，实际使用时需要通过 callback 传递
  }
}

/// 带有 context 的 MonitoredAppCard
class MonitoredAppCardWithDialog extends StatelessWidget {
  final MonitoredApp app;
  final Function(MonitoredApp) onUpdate;
  final VoidCallback onDelete;

  const MonitoredAppCardWithDialog({
    super.key,
    required this.app,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 应用名称和控制
            Row(
              children: [
                // 应用图标
                AppIconWidget(
                  packageName: app.packageName,
                  appName: app.appName,
                  size: 48,
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppDisplayName(
                        packageName: app.packageName,
                        appName: app.appName,
                        builder: (displayName) => Text(
                          displayName,
                          style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        app.packageName,
                        style: AppTextStyles.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: app.enabled,
                  onChanged: (value) => onUpdate(app.copyWith(enabled: value)),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onDelete,
                ),
              ],
            ),

            // 每日限制设置
            if (app.enabled) ...[
              SizedBox(height: AppSpacing.sm),
              const Divider(),
              SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('每日限制', style: AppTextStyles.body2),
                  _buildLimitSelector(context),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLimitSelector(BuildContext context) {
    return InkWell(
      onTap: () => _showLimitDialog(context),
      borderRadius: BorderRadius.circular(AppBorderRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.timer_outlined,
              size: 18,
              color: AppColors.primary,
            ),
            SizedBox(width: AppSpacing.xs),
            Text(
              app.dailyLimitMinutes != null
                  ? '${app.dailyLimitMinutes} 分钟'
                  : '不限制',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(width: AppSpacing.xs),
            Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  void _showLimitDialog(BuildContext context) {
    final options = [null, 15, 30, 45, 60, 90, 120];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('设置每日限制'),
        content: SizedBox(
          width: double.minPositive,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: options.length,
            itemBuilder: (context, index) {
              final value = options[index];
              final isSelected = app.dailyLimitMinutes == value;
              return ListTile(
                title: Text(value == null ? '不限制' : '$value 分钟'),
                trailing: isSelected ? Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () {
                  Navigator.pop(context);
                  if (value == null) {
                    onUpdate(app.copyWith(clearDailyLimit: true));
                  } else {
                    onUpdate(app.copyWith(dailyLimitMinutes: value));
                  }
                },
              );
            },
          ),
        ),
        actions: [
          AppButtonGhost(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }
}
