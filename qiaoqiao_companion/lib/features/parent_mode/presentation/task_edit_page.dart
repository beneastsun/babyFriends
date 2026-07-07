import 'package:flutter/material.dart';
import 'package:qiaoqiao_companion/core/theme/app_theme.dart';
import 'package:qiaoqiao_companion/shared/models/task_definition.dart';
import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/database/daos/daos.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';

/// 家长端任务编辑页面
class TaskEditPage extends StatefulWidget {
  final TaskDefinition? task;

  const TaskEditPage({super.key, this.task});

  @override
  State<TaskEditPage> createState() => _TaskEditPageState();
}

class _TaskEditPageState extends State<TaskEditPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _emojiController;
  late TaskCategory _category;
  late CheckinMode _checkinMode;
  late int _basePoints;
  late int _penaltyMinutes;
  late int _minDailyCount;
  late int _maxDailyCount;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.task?.name ?? '');
    _emojiController = TextEditingController(text: widget.task?.emoji ?? '⭐');
    _category = widget.task?.category ?? TaskCategory.health;
    _checkinMode = widget.task?.checkinMode ?? CheckinMode.self;
    _basePoints = widget.task?.basePoints ?? 10;
    _penaltyMinutes = widget.task?.penaltyMinutes ?? 0;
    _minDailyCount = widget.task?.minDailyCount ?? 1;
    _maxDailyCount = widget.task?.maxDailyCount ?? 1;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emojiController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final db = AppDatabase.instance;
    final dao = TaskDefinitionDao(db);

    final task = TaskDefinition(
      id: widget.task?.id,
      name: _nameController.text,
      emoji: _emojiController.text,
      category: _category,
      basePoints: _basePoints,
      checkinMode: _checkinMode,
      penaltyMinutes: _penaltyMinutes,
      minDailyCount: _minDailyCount,
      maxDailyCount: _maxDailyCount,
    );

    if (widget.task?.id != null) {
      await dao.update(task);
    } else {
      await dao.insert(task);
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.task != null;

    return AlertDialog(
      title: Text(isEditing ? '编辑任务' : '添加任务'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 任务名称
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '任务名称',
                hintText: '例如：眼保健操',
              ),
            ),
            const SizedBox(height: 16),

            // Emoji
            TextField(
              controller: _emojiController,
              decoration: const InputDecoration(
                labelText: 'Emoji',
                hintText: '例如：👀',
              ),
            ),
            const SizedBox(height: 16),

            // 分类
            DropdownButtonFormField<TaskCategory>(
              value: _category,
              decoration: const InputDecoration(labelText: '分类'),
              items: TaskCategory.values.map((c) =>
                DropdownMenuItem(value: c, child: Text(c.label))
              ).toList(),
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 16),

            // 打卡方式（v2 只支持 self 和 parentConfirm）
            DropdownButtonFormField<CheckinMode>(
              value: _checkinMode,
              decoration: const InputDecoration(labelText: '打卡方式'),
              items: [
                DropdownMenuItem(value: CheckinMode.self, child: Text('自助打卡')),
                DropdownMenuItem(value: CheckinMode.parentConfirm, child: Text('需家长确认')),
              ],
              onChanged: (v) => setState(() => _checkinMode = v!),
            ),
            const SizedBox(height: 16),

            // 基础积分
            TextField(
              decoration: const InputDecoration(labelText: '基础积分'),
              keyboardType: TextInputType.number,
              controller: TextEditingController(text: _basePoints.toString()),
              onChanged: (v) => _basePoints = int.tryParse(v) ?? 10,
            ),
            const SizedBox(height: 16),

            // 惩罚分钟数
            TextField(
              decoration: const InputDecoration(
                labelText: '未完成惩罚（分钟）',
                hintText: '0 表示不惩罚',
              ),
              keyboardType: TextInputType.number,
              controller: TextEditingController(text: _penaltyMinutes.toString()),
              onChanged: (v) => _penaltyMinutes = int.tryParse(v) ?? 0,
            ),
            const SizedBox(height: 16),

            // 每日次数
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(labelText: '最低次数'),
                    keyboardType: TextInputType.number,
                    controller: TextEditingController(text: _minDailyCount.toString()),
                    onChanged: (v) => _minDailyCount = int.tryParse(v) ?? 1,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(labelText: '最高次数'),
                    keyboardType: TextInputType.number,
                    controller: TextEditingController(text: _maxDailyCount.toString()),
                    onChanged: (v) => _maxDailyCount = int.tryParse(v) ?? 1,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton.tonal(
          onPressed: _save,
          child: Text(isEditing ? '保存' : '添加'),
        ),
      ],
    );
  }
}
