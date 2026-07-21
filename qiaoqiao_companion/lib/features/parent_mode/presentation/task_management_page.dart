import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qiaoqiao_companion/core/theme/app_theme.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';
import 'package:qiaoqiao_companion/shared/models/task_definition.dart';
import 'package:qiaoqiao_companion/shared/providers/task_provider.dart';
import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/database/daos/daos.dart';
import 'package:qiaoqiao_companion/features/parent_mode/presentation/task_edit_page.dart';

/// 家长端任务管理页面
class TaskManagementPage extends ConsumerStatefulWidget {
  const TaskManagementPage({super.key});

  @override
  ConsumerState<TaskManagementPage> createState() => _TaskManagementPageState();
}

class _TaskManagementPageState extends ConsumerState<TaskManagementPage> {
  List<TaskDefinition> _tasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    final db = AppDatabase.instance;
    final dao = TaskDefinitionDao(db);
    _tasks = await dao.getAll();
    if (mounted) {
      setState(() => _isLoading = false);
    }
    // 刷新全局任务状态，让首页和任务页实时更新
    ref.read(taskProvider.notifier).refresh();
  }

  Future<void> _deleteTask(int id) async {
    final db = AppDatabase.instance;
    final dao = TaskDefinitionDao(db);
    await dao.delete(id);
    await _loadTasks();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('任务已删除'), duration: Duration(seconds: 1)),
      );
    }
  }

  Future<void> _toggleEnabled(TaskDefinition task) async {
    final db = AppDatabase.instance;
    final dao = TaskDefinitionDao(db);
    final updated = task.copyWith(enabled: !task.enabled);
    await dao.update(updated);
    await _loadTasks();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('管理任务'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: '添加任务',
            onPressed: () => _showEditDialog(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tasks.isEmpty
              ? _buildEmptyState(theme)
              : _buildTaskList(theme),
      floatingActionButton: _tasks.isNotEmpty ? FloatingActionButton.extended(
        onPressed: () => _showEditDialog(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('添加任务'),
      ) : null,
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.task_alt_rounded,
                size: 48,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '还没有任务',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '添加任务帮助孩子养成好习惯',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _showEditDialog(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('添加第一个任务'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskList(ThemeData theme) {
    // 按分类分组
    final groupedTasks = <TaskCategory, List<TaskDefinition>>{};
    for (final task in _tasks) {
      groupedTasks.putIfAbsent(task.category, () => []).add(task);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 统计卡片
        _buildStatsCard(theme),
        const SizedBox(height: 16),
        // 分类任务列表
        ...TaskCategory.values.expand((category) {
          final tasks = groupedTasks[category];
          if (tasks == null || tasks.isEmpty) return [];
          return [
            Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 8),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      color: _getCategoryColor(category),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    category.label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${tasks.length}个',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ...tasks.map((task) => _buildTaskCard(task, theme)),
          ];
        }),
        const SizedBox(height: 80), // 为FAB留空间
      ],
    );
  }

  Widget _buildStatsCard(ThemeData theme) {
    final enabledCount = _tasks.where((t) => t.enabled).length;
    final totalPoints = _tasks.fold<int>(0, (sum, t) => sum + (t.enabled ? t.basePoints : 0));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatItem(
              icon: Icons.assignment_turned_in_rounded,
              label: '已启用',
              value: '$enabledCount',
              unit: '个任务',
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.white24,
          ),
          Expanded(
            child: _StatItem(
              icon: Icons.stars_rounded,
              label: '完成可获',
              value: '$totalPoints',
              unit: '积分',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(TaskDefinition task, ThemeData theme) {
    final isEnabled = task.enabled;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isEnabled ? theme.colorScheme.surface : theme.colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEnabled ? Colors.transparent : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _getCategoryColor(task.category).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(task.emoji, style: const TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      decoration: isEnabled ? null : TextDecoration.lineThrough,
                      color: isEnabled ? null : theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildInfoChip(
                        icon: Icons.stars_rounded,
                        label: '${task.basePoints}分',
                        color: Colors.amber,
                      ),
                      _buildInfoChip(
                        icon: Icons.repeat_rounded,
                        label: '${task.minDailyCount}-${task.maxDailyCount}次/天',
                        color: Colors.blue,
                      ),
                      if (task.penaltyMinutes > 0)
                        _buildInfoChip(
                          icon: Icons.warning_amber_rounded,
                          label: '未完成扣${task.penaltyMinutes}分',
                          color: Colors.red,
                        ),
                      if (task.checkinMode == CheckinMode.parentConfirm)
                        _buildInfoChip(
                          icon: Icons.verified_user_rounded,
                          label: '家长确认',
                          color: Colors.purple,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Switch(
                  value: task.enabled,
                  onChanged: (_) => _toggleEnabled(task),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit_rounded, size: 20, color: theme.colorScheme.primary),
                      tooltip: '编辑',
                      onPressed: () => _showEditDialog(task: task),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline_rounded, size: 20, color: theme.colorScheme.error),
                      tooltip: '删除',
                      onPressed: () => _showDeleteConfirm(task),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip({required IconData icon, required String label, required Color color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 2),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: color),
        ),
      ],
    );
  }

  Color _getCategoryColor(TaskCategory category) {
    return switch (category) {
      TaskCategory.health => Colors.green,
      TaskCategory.study => Colors.blue,
      TaskCategory.chore => Colors.orange,
      TaskCategory.discipline => Colors.purple,
    };
  }

  void _showEditDialog({TaskDefinition? task}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TaskEditPage(task: task),
    ).then((_) => _loadTasks());
  }

  void _showDeleteConfirm(TaskDefinition task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除任务"${task.name}"吗？删除后相关的打卡记录也会保留，但该任务不会再出现在任务列表中。'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              Navigator.pop(context);
              if (task.id != null) _deleteTask(task.id!);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 2),
            Text(
              unit,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }
}
