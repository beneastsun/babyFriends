import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/theme/app_theme.dart';
import 'package:qiaoqiao_companion/core/services/backup_service.dart';
import 'package:qiaoqiao_companion/shared/widgets/design_system/app_button.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

/// 备份恢复页面
class BackupRestorePage extends ConsumerStatefulWidget {
  const BackupRestorePage({super.key});

  @override
  ConsumerState<BackupRestorePage> createState() => _BackupRestorePageState();
}

class _BackupRestorePageState extends ConsumerState<BackupRestorePage> {
  final _backupService = BackupService();
  final _csvExportService = CsvExportService();
  List<BackupInfo> _backups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  Future<void> _loadBackups() async {
    setState(() => _isLoading = true);
    final backups = await _backupService.getBackups();
    setState(() {
      _backups = backups;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('备份与恢复'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 备份操作
                  _buildBackupSection(),
                  SizedBox(height: AppSpacing.lg),

                  // 备份列表
                  _buildBackupList(),
                  SizedBox(height: AppSpacing.lg),

                  // 导出功能
                  _buildExportSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildBackupSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('数据备份', style: AppTextStyles.heading3),
            SizedBox(height: AppSpacing.md),
            Text(
              '自动备份：每天凌晨3点自动创建备份',
              style: AppTextStyles.body2,
            ),
            Text(
              '备份保留：最近7天的备份',
              style: AppTextStyles.body2,
            ),
            SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: AppButtonPrimary(
                onPressed: _createManualBackup,
                icon: const Icon(Icons.backup, size: 18),
                child: const Text('立即创建备份'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupList() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('备份列表', style: AppTextStyles.heading3),
                if (_backups.isNotEmpty)
                  TextButton(
                    onPressed: _deleteAllBackups,
                    child: Text(
                      '删除全部',
                      style: TextStyle(color: AppColors.error),
                    ),
                  ),
              ],
            ),
            SizedBox(height: AppSpacing.md),
            if (_backups.isEmpty)
              Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Text('暂无备份', style: AppTextStyles.body2),
                ),
              )
            else
              ...(_backups.map((backup) => _buildBackupItem(backup))),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupItem(BackupInfo backup) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.info.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.archive, color: AppColors.info),
      ),
      title: Text(backup.formattedDate),
      subtitle: Text('版本 ${backup.version}'),
      trailing: PopupMenuButton<String>(
        onSelected: (value) => _handleBackupAction(backup, value),
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'restore', child: Text('恢复')),
          const PopupMenuItem(value: 'share', child: Text('分享')),
          const PopupMenuItem(
            value: 'delete',
            child: Text('删除', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Widget _buildExportSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('数据导出', style: AppTextStyles.heading3),
            SizedBox(height: AppSpacing.md),
            Text(
              '将使用记录导出为CSV格式，方便在其他应用中查看',
              style: AppTextStyles.body2,
            ),
            SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: AppButtonSecondary(
                    onPressed: _exportUsageRecords,
                    icon: const Icon(Icons.file_download, size: 18),
                    child: const Text('导出使用记录'),
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppButtonSecondary(
                    onPressed: _exportPointsRecords,
                    icon: const Icon(Icons.file_download, size: 18),
                    child: const Text('导出积分记录'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createManualBackup() async {
    try {
      // TODO: 收集所有需要备份的数据
      final data = <String, dynamic>{
        'rules': [],
        'coupons': [],
        'points_history': [],
        'app_categories': [],
      };

      await _backupService.createBackup(data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('备份创建成功')),
        );
      }

      _loadBackups();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('备份失败: $e')),
        );
      }
    }
  }

  Future<void> _handleBackupAction(BackupInfo backup, String action) async {
    switch (action) {
      case 'restore':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('确认恢复'),
            content: const Text('恢复备份将覆盖当前数据，是否继续？'),
            actions: [
              AppButtonGhost(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              AppButtonPrimary(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('确认'),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          final data = await _backupService.restoreBackup(backup.file);
          if (data != null && mounted) {
            // TODO: 恢复数据到数据库
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('数据恢复成功')),
            );
          }
        }
        break;

      case 'share':
        await Share.shareXFiles([XFile(backup.file.path)]);
        break;

      case 'delete':
        await backup.file.delete();
        _loadBackups();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('备份已删除')),
          );
        }
        break;
    }
  }

  Future<void> _deleteAllBackups() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除所有备份吗？此操作不可恢复。'),
        actions: [
          AppButtonGhost(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          AppButtonDanger(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _backupService.deleteAllBackups();
      _loadBackups();
    }
  }

  Future<void> _exportUsageRecords() async {
    try {
      // TODO: 从数据库获取使用记录
      final records = <Map<String, dynamic>>[];
      final file = await _csvExportService.exportUsageRecords(records);
      await Share.shareXFiles([XFile(file.path)]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
  }

  Future<void> _exportPointsRecords() async {
    try {
      // TODO: 从数据库获取积分记录
      final records = <Map<String, dynamic>>[];
      final file = await _csvExportService.exportPointsRecords(records);
      await Share.shareXFiles([XFile(file.path)]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
  }
}
