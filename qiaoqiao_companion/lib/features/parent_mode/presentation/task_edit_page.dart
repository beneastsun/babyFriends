import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qiaoqiao_companion/core/theme/app_theme.dart';
import 'package:qiaoqiao_companion/shared/models/task_definition.dart';
import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/database/daos/daos.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';

/// 家长端任务编辑页面（BottomSheet 形式）
class TaskEditPage extends StatefulWidget {
  final TaskDefinition? task;

  const TaskEditPage({super.key, this.task});

  @override
  State<TaskEditPage> createState() => _TaskEditPageState();
}

class _TaskEditPageState extends State<TaskEditPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _emojiController;
  late final TextEditingController _pointsController;
  late final TextEditingController _penaltyController;
  late final TextEditingController _minCountController;
  late final TextEditingController _maxCountController;
  late TaskCategory _category;
  late CheckinMode _checkinMode;
  String? _reminderTime;
  int _reminderRepeatInterval = 0;

  // 各分类对应emoji和颜色
  static const Map<TaskCategory, (String emoji, Color color)> _categoryMeta = {
    TaskCategory.health: ('💪', Colors.green),
    TaskCategory.study: ('📚', Colors.blue),
    TaskCategory.chore: ('🧹', Colors.orange),
    TaskCategory.discipline: ('⭐', Colors.purple),
  };

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.task?.name ?? '');
    _emojiController = TextEditingController(text: widget.task?.emoji ?? '⭐');
    _pointsController = TextEditingController(text: (widget.task?.basePoints ?? 10).toString());
    _penaltyController = TextEditingController(text: (widget.task?.penaltyMinutes ?? 0).toString());
    _minCountController = TextEditingController(text: (widget.task?.minDailyCount ?? 1).toString());
    _maxCountController = TextEditingController(text: (widget.task?.maxDailyCount ?? 1).toString());
    _category = widget.task?.category ?? TaskCategory.health;
    _checkinMode = widget.task?.checkinMode ?? CheckinMode.self;
    _reminderTime = widget.task?.reminderTime;
    _reminderRepeatInterval = widget.task?.reminderRepeatInterval ?? 0;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emojiController.dispose();
    _pointsController.dispose();
    _penaltyController.dispose();
    _minCountController.dispose();
    _maxCountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // 校验
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入任务名称'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    final basePoints = int.tryParse(_pointsController.text) ?? 10;
    final penaltyMinutes = int.tryParse(_penaltyController.text) ?? 0;
    final minDailyCount = int.tryParse(_minCountController.text) ?? 1;
    final maxDailyCount = int.tryParse(_maxCountController.text) ?? 1;

    if (maxDailyCount < minDailyCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('最高次数不能小于最低次数'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    final db = AppDatabase.instance;
    final dao = TaskDefinitionDao(db);

    final task = TaskDefinition(
      id: widget.task?.id,
      name: name,
      emoji: _emojiController.text.isEmpty ? '⭐' : _emojiController.text,
      category: _category,
      basePoints: basePoints,
      checkinMode: _checkinMode,
      penaltyMinutes: penaltyMinutes,
      minDailyCount: minDailyCount,
      maxDailyCount: maxDailyCount,
      reminderTime: _reminderTime,
      reminderRepeatInterval: _reminderRepeatInterval,
    );

    if (widget.task?.id != null) {
      await dao.update(task);
    } else {
      await dao.insert(task);
    }

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  void _adjustValue(TextEditingController controller, int delta, int min, int max) {
    final current = int.tryParse(controller.text) ?? min;
    final newValue = (current + delta).clamp(min, max);
    controller.text = newValue.toString();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEditing = widget.task != null;
    final categoryColor = _categoryMeta[_category]!.$2;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(DesignTokens.radius24),
            ),
          ),
          child: Column(
            children: [
              // 拖拽手柄
              Container(
                margin: const EdgeInsets.only(top: DesignTokens.space12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // 渐变头部
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      categoryColor,
                      categoryColor.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          _emojiController.text.isEmpty ? '⭐' : _emojiController.text,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing ? '编辑任务' : '添加新任务',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isEditing ? '修改任务的详细设置' : '为孩子设置一个新任务',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),

              // 表单内容
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    MediaQuery.of(context).viewInsets.bottom + 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. 任务名称和Emoji
                      _buildSectionLabel(theme, '任务信息'),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 76,
                            child: _buildTextField(
                              controller: _emojiController,
                              labelText: '图标',
                              textAlign: TextAlign.center,
                              fontSize: 24,
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildTextField(
                              controller: _nameController,
                              labelText: '任务名称',
                              hintText: '例如：眼保健操',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 2. 分类选择 - 改为卡片式选择
                      _buildSectionLabel(theme, '任务分类'),
                      Row(
                        children: TaskCategory.values.map((c) {
                          final meta = _categoryMeta[c]!;
                          final isSelected = _category == c;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _category = c),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: EdgeInsets.only(
                                  right: c != TaskCategory.values.last ? 8 : 0,
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? meta.$2.withOpacity(0.12)
                                      : theme.colorScheme.surfaceVariant.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected ? meta.$2 : Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(meta.$1, style: const TextStyle(fontSize: 22)),
                                    const SizedBox(height: 4),
                                    Text(
                                      c.label,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                        color: isSelected ? meta.$2 : theme.colorScheme.outline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // 3. 打卡方式 - 分段选择
                      _buildSectionLabel(theme, '打卡方式'),
                      Row(
                        children: [
                          Expanded(
                            child: _buildOptionCard(
                              theme: theme,
                              icon: Icons.touch_app_rounded,
                              label: '自助打卡',
                              subtitle: '孩子自己完成',
                              isSelected: _checkinMode == CheckinMode.self,
                              color: Colors.blue,
                              onTap: () => setState(() => _checkinMode = CheckinMode.self),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildOptionCard(
                              theme: theme,
                              icon: Icons.verified_user_rounded,
                              label: '家长确认',
                              subtitle: '需家长审核',
                              isSelected: _checkinMode == CheckinMode.parentConfirm,
                              color: Colors.purple,
                              onTap: () => setState(() => _checkinMode = CheckinMode.parentConfirm),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 4. 积分和惩罚
                      _buildSectionLabel(theme, '积分与惩罚'),
                      Row(
                        children: [
                          Expanded(
                            child: _buildNumberField(
                              controller: _pointsController,
                              labelText: '基础积分',
                              icon: Icons.stars_rounded,
                              iconColor: Colors.amber,
                              min: 1,
                              max: 100,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildNumberField(
                              controller: _penaltyController,
                              labelText: '未完成惩罚(分)',
                              icon: Icons.warning_amber_rounded,
                              iconColor: Colors.red,
                              min: 0,
                              max: 120,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 5. 打卡次数
                      _buildSectionLabel(theme, '打卡次数'),
                      Row(
                        children: [
                          Expanded(
                            child: _buildNumberField(
                              controller: _minCountController,
                              labelText: '最低次数',
                              icon: Icons.flag_rounded,
                              iconColor: Colors.green,
                              min: 1,
                              max: 20,
                              subtitle: '完成即达标',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildNumberField(
                              controller: _maxCountController,
                              labelText: '最高次数',
                              icon: Icons.add_circle_outline_rounded,
                              iconColor: Colors.blue,
                              min: 1,
                              max: 20,
                              subtitle: '超额仍可打卡',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 6. 提醒设置
                      _buildSectionLabel(theme, '提醒设置'),
                      _buildReminderCard(theme),
                      if (_reminderTime != null) ...[
                        const SizedBox(height: 10),
                        _buildRepeatSelector(theme),
                      ],
                    ],
                  ),
                ),
              ),

              // 底部操作按钮
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            side: BorderSide(color: theme.colorScheme.outlineVariant),
                          ),
                          child: const Text('取消', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: _save,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            backgroundColor: categoryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(isEditing ? Icons.save_rounded : Icons.add_circle_rounded, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                isEditing ? '保存修改' : '添加任务',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionLabel(ThemeData theme, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        label,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface.withOpacity(0.7),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    String? hintText,
    TextAlign textAlign = TextAlign.left,
    double fontSize = 14,
    ValueChanged<String>? onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: controller,
      textAlign: textAlign,
      style: TextStyle(fontSize: fontSize),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        filled: true,
        fillColor: isDark ? AppColors.surfaceDark : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    required Color iconColor,
    required int min,
    required int max,
    String? subtitle,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  labelText,
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _buildStepButton(
                icon: Icons.remove_rounded,
                onTap: () => _adjustValue(controller, -1, min, max),
                color: theme.colorScheme.surfaceVariant,
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              _buildStepButton(
                icon: Icons.add_rounded,
                onTap: () => _adjustValue(controller, 1, min, max),
                color: theme.colorScheme.primary.withOpacity(0.1),
                iconColor: theme.colorScheme.primary,
              ),
            ],
          ),
          if (subtitle != null)
            Text(
              subtitle,
              style: TextStyle(fontSize: 10, color: theme.colorScheme.outline),
            ),
        ],
      ),
    );
  }

  Widget _buildStepButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
    Color? iconColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: iconColor ?? Theme.of(context).colorScheme.onSurface),
      ),
    );
  }

  Widget _buildOptionCard({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required String subtitle,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : theme.colorScheme.surfaceVariant.withOpacity(0.4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected ? color.withOpacity(0.15) : theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: isSelected ? color : theme.colorScheme.outline),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? color : theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 10, color: theme.colorScheme.outline),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, size: 18, color: color),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderCard(ThemeData theme) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final time = await showTimePicker(
            context: context,
            initialTime: _reminderTime != null
                ? TimeOfDay(
                    hour: int.parse(_reminderTime!.split(':')[0]),
                    minute: int.parse(_reminderTime!.split(':')[1]),
                  )
                : TimeOfDay.now(),
          );
          if (time != null) {
            setState(() {
              _reminderTime = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
              _reminderRepeatInterval = 0;
            });
          }
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
            borderRadius: BorderRadius.circular(14),
            border: _reminderTime != null
                ? Border.all(color: theme.colorScheme.primary.withOpacity(0.3), width: 1.5)
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _reminderTime != null
                      ? theme.colorScheme.primary.withOpacity(0.1)
                      : theme.colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _reminderTime != null
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_none_rounded,
                  size: 20,
                  color: _reminderTime != null ? theme.colorScheme.primary : theme.colorScheme.outline,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _reminderTime != null ? '提醒时间' : '设置提醒',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _reminderTime != null
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _reminderTime != null ? _reminderTime! : '点击选择提醒时间',
                      style: TextStyle(
                        fontSize: 12,
                        color: _reminderTime != null ? theme.colorScheme.primary : theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              if (_reminderTime != null)
                GestureDetector(
                  onTap: () => setState(() {
                    _reminderTime = null;
                    _reminderRepeatInterval = 0;
                  }),
                  child: Icon(Icons.cancel, size: 18, color: theme.colorScheme.outline),
                )
              else
                Icon(Icons.chevron_right_rounded, color: theme.colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRepeatSelector(ThemeData theme) {
    final options = [
      (0, '不重复'),
      (15, '15分钟'),
      (30, '30分钟'),
      (60, '60分钟'),
    ];

    return Wrap(
      spacing: 8,
      children: options.map((o) {
        final isSelected = _reminderRepeatInterval == o.$1;
        return GestureDetector(
          onTap: () => setState(() => _reminderRepeatInterval = o.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.surfaceVariant.withOpacity(0.4),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              o.$2,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? Colors.white : theme.colorScheme.onSurface,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
