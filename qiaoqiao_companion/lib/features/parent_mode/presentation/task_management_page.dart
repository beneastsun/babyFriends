import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qiaoqiao_companion/core/theme/app_theme.dart';
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
    setState(() => _isLoading = false);
  }

  Future<void> _deleteTask(int id) async {
    final db = AppDatabase.instance;
    final dao = TaskDefinitionDao(db);
    await dao.delete(id);
    await _loadTasks();
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
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showEditDialog(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tasks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.task_alt, size: 64, color: theme.colorScheme.outline),
                      const SizedBox(height: 16),
                      Text('还没有任务', style: theme.textTheme.bodyLarge),
                      const SizedBox(height: 8),
                      FilledButton.tonal(
                        onPressed: () => _showEditDialog(),
                        child: const Text('添加任务'),
                      ),
                    ],
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _tasks.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex--;
                      final item = _tasks.removeAt(oldIndex);
                      _tasks.insert(newIndex, item);
                    });
                  },
                  itemBuilder: (context, index) {
                    final task = _tasks[index];
                    return Card(
                      key: ValueKey(task.id),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Text(task.emoji, style: const TextStyle(fontSize: 28)),
                        title: Text(task.name),
                        subtitle: Text('${task.category.label} · ${task.basePoints}积分 · ${task.checkinMode.label}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: task.enabled,
                              onChanged: (_) => _toggleEnabled(task),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showEditDialog(task: task),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _showDeleteConfirm(task),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  void _showEditDialog({TaskDefinition? task}) {
    showDialog(
      context: context,
      builder: (context) => TaskEditPage(task: task),
    ).then((_) => _loadTasks());
  }

  void _showDeleteConfirm(TaskDefinition task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除任务"${task.name}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton.tonal(
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
