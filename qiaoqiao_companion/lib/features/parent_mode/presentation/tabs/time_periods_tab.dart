import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/theme/app_theme.dart';
import 'package:qiaoqiao_companion/features/parent_mode/presentation/widgets/time_period_card.dart';
import 'package:qiaoqiao_companion/shared/models/models.dart';
import 'package:qiaoqiao_companion/shared/providers/time_periods_provider.dart';
import 'package:qiaoqiao_companion/shared/widgets/design_system/app_button.dart';

/// 时间段设置 Tab
class TimePeriodsTab extends ConsumerStatefulWidget {
  const TimePeriodsTab({super.key});

  @override
  ConsumerState<TimePeriodsTab> createState() => _TimePeriodsTabState();
}

class _TimePeriodsTabState extends ConsumerState<TimePeriodsTab> {
  @override
  void initState() {
    super.initState();
    // 加载数据
    Future.microtask(() => ref.read(timePeriodsProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final periodsState = ref.watch(timePeriodsProvider);

    return Column(
      children: [
        // 模式切换
        _buildModeSwitch(periodsState.currentMode),

        // 时间段列表
        Expanded(
          child: periodsState.allPeriods.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: periodsState.allPeriods.length,
                  itemBuilder: (context, index) {
                    final period = periodsState.allPeriods[index];
                    return TimePeriodCard(
                      period: period,
                      onEdit: () => _editPeriod(period),
                      onUpdate: (updated) => _updatePeriod(updated),
                      onDelete: () => _deletePeriod(period.id!),
                    );
                  },
                ),
        ),

        // 添加按钮
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: AppButtonPrimary(
            onPressed: _addPeriod,
            icon: const Icon(Icons.add),
            isFullWidth: true,
            child: const Text('添加时间段'),
          ),
        ),
      ],
    );
  }

  Widget _buildModeSwitch(TimePeriodMode currentMode) {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('时间段模式', style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w600)),
          SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _buildModeOption(
                  TimePeriodMode.blocked,
                  '禁用时段',
                  '在指定时间段内禁止使用',
                  Icons.block,
                  currentMode == TimePeriodMode.blocked,
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _buildModeOption(
                  TimePeriodMode.allowed,
                  '开放时段',
                  '仅在指定时间段内允许使用',
                  Icons.check_circle_outline,
                  currentMode == TimePeriodMode.allowed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeOption(
    TimePeriodMode mode,
    String title,
    String subtitle,
    IconData icon,
    bool isSelected,
  ) {
    return InkWell(
      onTap: () => _setMode(mode),
      borderRadius: BorderRadius.circular(AppBorderRadius.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : AppTheme.textSecondary,
            ),
            SizedBox(height: AppSpacing.xs),
            Text(
              title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? AppColors.primary : AppTheme.textPrimary,
              ),
            ),
            Text(
              subtitle,
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.schedule_outlined,
            size: 64,
            color: AppTheme.textHint,
          ),
          SizedBox(height: AppSpacing.md),
          Text(
            '还没有设置时间段',
            style: AppTextStyles.body1,
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            '点击下方按钮添加时间段规则',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }

  Future<void> _setMode(TimePeriodMode mode) async {
    await ref.read(timePeriodsProvider.notifier).setMode(mode);
  }

  Future<void> _updatePeriod(TimePeriod period) async {
    await ref.read(timePeriodsProvider.notifier).updatePeriod(period);
  }

  Future<void> _deletePeriod(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除时间段'),
        content: const Text('确定要删除这个时间段吗？'),
        actions: [
          AppButtonGhost(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          AppButton(
            onPressed: () => Navigator.of(context).pop(true),
            type: AppButtonType.danger,
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(timePeriodsProvider.notifier).removePeriod(id);
    }
  }

  Future<void> _addPeriod() async {
    final result = await showDialog<TimePeriod>(
      context: context,
      barrierColor: Colors.black26,
      builder: (context) => _TimePeriodDialog(
        currentMode: ref.read(timePeriodsProvider).currentMode,
      ),
    );

    if (result != null) {
      await ref.read(timePeriodsProvider.notifier).addPeriod(result);
    }
  }

  Future<void> _editPeriod(TimePeriod period) async {
    final result = await showDialog<TimePeriod>(
      context: context,
      barrierColor: Colors.black26,
      builder: (context) => _TimePeriodDialog(
        currentMode: ref.read(timePeriodsProvider).currentMode,
        existingPeriod: period,
      ),
    );

    if (result != null) {
      await ref.read(timePeriodsProvider.notifier).updatePeriod(result);
    }
  }
}

/// 时间段对话框 - 玻璃拟态风格（支持添加和编辑）
class _TimePeriodDialog extends StatefulWidget {
  final TimePeriodMode currentMode;
  final TimePeriod? existingPeriod;

  const _TimePeriodDialog({
    required this.currentMode,
    this.existingPeriod,
  });

  @override
  State<_TimePeriodDialog> createState() => _TimePeriodDialogState();
}

class _TimePeriodDialogState extends State<_TimePeriodDialog>
    with SingleTickerProviderStateMixin {
  late TimePeriodMode _selectedMode;
  TimeOfDay _startTime = const TimeOfDay(hour: 21, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 7, minute: 0);
  final Set<int> _selectedDays = {1, 2, 3, 4, 5, 6, 7};

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  // 时尚配色
  static const Color _softPink = Color(0xFFFFC0CB);
  static const Color _softPurple = Color(0xFFE1BEE7);
  static const Color _softPeach = Color(0xFFFFCCBC);
  static const Color _softBlue = Color(0xFFB3E5FC);
  static const Color _softMint = Color(0xFFB2DFDB);

  @override
  void initState() {
    super.initState();

    // 编辑模式：预填充现有数据
    if (widget.existingPeriod != null) {
      final period = widget.existingPeriod!;
      _selectedMode = period.mode;
      _startTime = _parseTimeOfDay(period.timeStart);
      _endTime = _parseTimeOfDay(period.timeEnd);
      _selectedDays.clear();
      _selectedDays.addAll(period.days);
    } else {
      _selectedMode = widget.currentMode;
    }

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  TimeOfDay _parseTimeOfDay(String time) {
    final parts = time.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  List<Color> _getGradientColors() {
    if (_selectedMode == TimePeriodMode.blocked) {
      return [_softPeach, _softPink];
    } else {
      return [_softMint, _softBlue];
    }
  }

  @override
  Widget build(BuildContext context) {
    final gradientColors = _getGradientColors();

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: child,
            ),
          );
        },
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors.map((c) => c.withOpacity(0.9)).toList(),
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: Colors.white.withOpacity(0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: gradientColors[0].withOpacity(0.4),
                  blurRadius: 30,
                  spreadRadius: 5,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: Stack(
                children: [
                  // 装饰性背景
                  Positioned(
                    right: -30,
                    top: -30,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.15),
                      ),
                    ),
                  ),
                  Positioned(
                    left: -20,
                    bottom: -20,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                  ),

                  // 主要内容
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 头部
                        _buildHeader(),

                        SizedBox(height: 24),

                        // 模式选择
                        _buildModeSelector(),

                        SizedBox(height: 20),

                        // 时间选择
                        _buildTimeSelector(),

                        SizedBox(height: 20),

                        // 适用日期
                        _buildDaysSelector(),

                        SizedBox(height: 28),

                        // 按钮
                        _buildButtons(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.6),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: _getGradientColors()),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.schedule_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          SizedBox(width: 14),
          Text(
            widget.existingPeriod != null ? '编辑时间段' : '添加时间段',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2D2D4A),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.6),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, size: 18, color: Color(0xFF2D2D4A)),
              SizedBox(width: 8),
              Text(
                '模式选择',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D2D4A),
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _GlassModeButton(
                  label: '禁用时段',
                  icon: Icons.block_rounded,
                  isSelected: _selectedMode == TimePeriodMode.blocked,
                  gradientColors: [_softPeach, _softPink],
                  onTap: () => setState(() => _selectedMode = TimePeriodMode.blocked),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _GlassModeButton(
                  label: '开放时段',
                  icon: Icons.check_circle_rounded,
                  isSelected: _selectedMode == TimePeriodMode.allowed,
                  gradientColors: [_softMint, _softBlue],
                  onTap: () => setState(() => _selectedMode = TimePeriodMode.allowed),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.6),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          _GlassTimeTile(
            label: '开始时间',
            time: _startTime.format(context),
            icon: Icons.play_arrow_rounded,
            gradientColors: [_softMint, _softBlue],
            onTap: () => _selectTime(true),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(color: Colors.white.withOpacity(0.5), height: 24),
          ),
          _GlassTimeTile(
            label: '结束时间',
            time: _endTime.format(context),
            icon: Icons.stop_rounded,
            gradientColors: [_softPink, _softPurple],
            onTap: () => _selectTime(false),
          ),
        ],
      ),
    );
  }

  Widget _buildDaysSelector() {
    const dayNames = ['一', '二', '三', '四', '五', '六', '日'];
    final gradientColors = _getGradientColors();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.6),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF2D2D4A)),
              SizedBox(width: 8),
              Text(
                '适用日期',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D2D4A),
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(7, (index) {
              final day = index + 1;
              final isSelected = _selectedDays.contains(day);
              return _GlassDayChip(
                label: dayNames[index],
                isSelected: isSelected,
                gradientColors: gradientColors,
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedDays.remove(day);
                    } else {
                      _selectedDays.add(day);
                    }
                  });
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildButtons() {
    return Row(
      children: [
        Expanded(
          child: AppButtonGhost(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
            isFullWidth: true,
            child: const Text('取消'),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: AppButtonPrimary(
            onPressed: _save,
            icon: const Icon(Icons.check_rounded),
            isFullWidth: true,
            child: const Text('保存'),
          ),
        ),
      ],
    );
  }

  Future<void> _selectTime(bool isStart) async {
    final time = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );

    if (time != null) {
      setState(() {
        if (isStart) {
          _startTime = time;
        } else {
          _endTime = time;
        }
      });
    }
  }

  void _save() {
    final period = TimePeriod(
      id: widget.existingPeriod?.id,
      mode: _selectedMode,
      timeStart:
          '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
      timeEnd:
          '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
      days: _selectedDays.toList()..sort(),
      enabled: widget.existingPeriod?.enabled ?? true,
      createdAt: widget.existingPeriod?.createdAt ?? DateTime.now(),
    );
    Navigator.pop(context, period);
  }
}

/// 玻璃风格模式按钮
class _GlassModeButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const _GlassModeButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  State<_GlassModeButton> createState() => _GlassModeButtonState();
}

class _GlassModeButtonState extends State<_GlassModeButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: widget.isSelected
              ? LinearGradient(colors: widget.gradientColors)
              : null,
          color: widget.isSelected
              ? null
              : Colors.white.withOpacity(_isPressed ? 0.7 : 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.isSelected
                ? Colors.transparent
                : Colors.white.withOpacity(0.6),
            width: 1.5,
          ),
          boxShadow: widget.isSelected
              ? [
                  BoxShadow(
                    color: widget.gradientColors[0].withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Column(
          children: [
            Icon(
              widget.icon,
              size: 24,
              color: widget.isSelected ? Colors.white : Color(0xFF2D2D4A),
            ),
            SizedBox(height: 6),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                color: widget.isSelected ? Colors.white : Color(0xFF2D2D4A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 玻璃风格时间选择行
class _GlassTimeTile extends StatefulWidget {
  final String label;
  final String time;
  final IconData icon;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const _GlassTimeTile({
    required this.label,
    required this.time,
    required this.icon,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  State<_GlassTimeTile> createState() => _GlassTimeTileState();
}

class _GlassTimeTileState extends State<_GlassTimeTile> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(_isPressed ? 0.7 : 0.4),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: widget.gradientColors),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(widget.icon, color: Colors.white, size: 20),
            ),
            SizedBox(width: 14),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF2D2D4A),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.time,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D2D4A),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 玻璃风格日期选择芯片
class _GlassDayChip extends StatefulWidget {
  final String label;
  final bool isSelected;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const _GlassDayChip({
    required this.label,
    required this.isSelected,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  State<_GlassDayChip> createState() => _GlassDayChipState();
}

class _GlassDayChipState extends State<_GlassDayChip> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          gradient: widget.isSelected
              ? LinearGradient(colors: widget.gradientColors)
              : null,
          color: widget.isSelected
              ? null
              : Colors.white.withOpacity(_isPressed ? 0.7 : 0.5),
          shape: BoxShape.circle,
          border: widget.isSelected
              ? null
              : Border.all(
                  color: Colors.white.withOpacity(0.6),
                  width: 1,
                ),
          boxShadow: widget.isSelected
              ? [
                  BoxShadow(
                    color: widget.gradientColors[0].withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Center(
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
              color: widget.isSelected ? Colors.white : Color(0xFF2D2D4A),
            ),
          ),
        ),
      ),
    );
  }
}

