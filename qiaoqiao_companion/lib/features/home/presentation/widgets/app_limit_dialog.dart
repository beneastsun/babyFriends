import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/database/daos/daos.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';
import 'package:qiaoqiao_companion/shared/models/models.dart';
import 'package:qiaoqiao_companion/shared/models/app_usage_summary.dart';
import 'package:qiaoqiao_companion/shared/providers/app_usage_list_provider.dart';
import 'package:qiaoqiao_companion/shared/providers/theme_provider.dart';

/// 时间限制设置对话框 - 时尚玻璃拟态风格
class AppLimitDialog extends ConsumerStatefulWidget {
  final AppUsageSummary summary;

  const AppLimitDialog({
    super.key,
    required this.summary,
  });

  @override
  ConsumerState<AppLimitDialog> createState() => _AppLimitDialogState();
}

class _AppLimitDialogState extends ConsumerState<AppLimitDialog>
    with TickerProviderStateMixin {
  late TextEditingController _weekdayController;
  late TextEditingController _weekendController;
  int? _selectedWeekdayMinutes;
  int? _selectedWeekendMinutes;
  bool _weekdayCustom = false;
  bool _weekendCustom = false;
  bool _isLoading = false;

  final List<int> _presetMinutes = [15, 30, 60, 120];

  // 时尚配色
  static const Color _softPink = Color(0xFFFFC0CB);
  static const Color _softPurple = Color(0xFFE1BEE7);
  static const Color _softPeach = Color(0xFFFFCCBC);
  static const Color _softBlue = Color(0xFFB3E5FC);

  late AnimationController _mainController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _weekdayController = TextEditingController();
    _weekendController = TextEditingController();

    // 入场动画
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: Curves.easeOut),
    );

    _mainController.forward();
    _loadExistingRule();
  }

  Future<void> _loadExistingRule() async {
    final db = AppDatabase.instance;
    final ruleDao = RuleDao(db);
    final rule = await ruleDao.getAppRule(widget.summary.packageName);

    if (rule != null && mounted) {
      setState(() {
        if (rule.weekdayLimitMinutes != null) {
          _weekdayController.text = rule.weekdayLimitMinutes.toString();
          _selectedWeekdayMinutes = rule.weekdayLimitMinutes;
          if (!_presetMinutes.contains(rule.weekdayLimitMinutes)) {
            _weekdayCustom = true;
          }
        }
        if (rule.weekendLimitMinutes != null) {
          _weekendController.text = rule.weekendLimitMinutes.toString();
          _selectedWeekendMinutes = rule.weekendLimitMinutes;
          if (!_presetMinutes.contains(rule.weekendLimitMinutes)) {
            _weekendCustom = true;
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _weekdayController.dispose();
    _weekendController.dispose();
    _mainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _mainController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: child,
          ),
        );
      },
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            constraints: const BoxConstraints(maxWidth: 380),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _softPeach.withOpacity(0.9),
                  _softPink.withOpacity(0.85),
                ],
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: Colors.white.withOpacity(0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: _softPeach.withOpacity(0.4),
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
                  _buildDecorations(),

                  // 主要内容
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 头部
                        _buildHeader(),

                        SizedBox(height: 24),

                        // 工作日限额
                        _buildLimitSection(
                          label: '工作日限额',
                          icon: Icons.wb_sunny_rounded,
                          gradientColors: [_softBlue, _softPurple],
                          selectedMinutes: _selectedWeekdayMinutes,
                          isCustom: _weekdayCustom,
                          controller: _weekdayController,
                          onPresetSelected: (minutes) {
                            setState(() {
                              _selectedWeekdayMinutes = minutes;
                              _weekdayController.text = minutes.toString();
                              _weekdayCustom = false;
                            });
                          },
                          onCustomToggled: (isCustom) {
                            setState(() {
                              _weekdayCustom = isCustom;
                              if (isCustom && _weekdayController.text.isEmpty) {
                                _weekdayController.text = '30';
                                _selectedWeekdayMinutes = 30;
                              }
                            });
                          },
                          onCustomChanged: (value) {
                            final minutes = int.tryParse(value);
                            if (minutes != null && minutes > 0) {
                              setState(() {
                                _selectedWeekdayMinutes = minutes;
                              });
                            }
                          },
                        ),

                        SizedBox(height: 20),

                        // 节假日限额
                        _buildLimitSection(
                          label: '节假日限额',
                          icon: Icons.weekend_rounded,
                          gradientColors: [_softPink, _softPurple],
                          selectedMinutes: _selectedWeekendMinutes,
                          isCustom: _weekendCustom,
                          controller: _weekendController,
                          onPresetSelected: (minutes) {
                            setState(() {
                              _selectedWeekendMinutes = minutes;
                              _weekendController.text = minutes.toString();
                              _weekendCustom = false;
                            });
                          },
                          onCustomToggled: (isCustom) {
                            setState(() {
                              _weekendCustom = isCustom;
                              if (isCustom && _weekendController.text.isEmpty) {
                                _weekendController.text = '60';
                                _selectedWeekendMinutes = 60;
                              }
                            });
                          },
                          onCustomChanged: (value) {
                            final minutes = int.tryParse(value);
                            if (minutes != null && minutes > 0) {
                              setState(() {
                                _selectedWeekendMinutes = minutes;
                              });
                            }
                          },
                        ),

                        SizedBox(height: 28),

                        // 按钮区域
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

  /// 装饰性背景元素
  Widget _buildDecorations() {
    return Positioned(
      right: -40,
      top: -40,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.15),
        ),
      ),
    );
  }

  /// 构建头部
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_softPink, _softPurple],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.timer_outlined,
              color: Colors.white,
              size: 22,
            ),
          ),
          SizedBox(width: 14),
          Flexible(
            child: Text(
              '设置「${widget.summary.appName}」时间限制',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF4A4A6A),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建限额设置区块
  Widget _buildLimitSection({
    required String label,
    required IconData icon,
    required List<Color> gradientColors,
    required int? selectedMinutes,
    required bool isCustom,
    required TextEditingController controller,
    required Function(int) onPresetSelected,
    required Function(bool) onCustomToggled,
    required Function(String) onCustomChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.4),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withOpacity(0.6),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标签行
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradientColors),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4A4A6A),
                ),
              ),
            ],
          ),

          SizedBox(height: 16),

          // 预设按钮
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ..._presetMinutes.map((minutes) => _GlassPresetButton(
                    label: minutes < 60 ? '${minutes}分' : '${minutes ~/ 60}小时',
                    isSelected: !isCustom && selectedMinutes == minutes,
                    gradientColors: gradientColors,
                    onTap: () => onPresetSelected(minutes),
                  )),
              _GlassPresetButton(
                label: '自定义',
                isSelected: isCustom,
                gradientColors: gradientColors,
                isOutlined: true,
                onTap: () => onCustomToggled(true),
              ),
            ],
          ),

          // 自定义输入框
          if (isCustom) ...[
            SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: gradientColors[0].withOpacity(0.5),
                  width: 1.5,
                ),
              ),
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                onChanged: onCustomChanged,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4A4A6A),
                ),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: InputBorder.none,
                  suffixText: '分钟',
                  suffixStyle: TextStyle(
                    color: Color(0xFF8A8AAA),
                    fontSize: 14,
                  ),
                  hintText: '输入分钟数',
                  hintStyle: TextStyle(
                    color: Color(0xFFB0B0C0),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 构建按钮区域
  Widget _buildButtons() {
    final colorScheme = ref.watch(colorSchemeProvider);
    final isDark = ref.watch(isDarkModeProvider);

    return Row(
      children: [
        // 清除限制按钮
        if (widget.summary.hasRule)
          Expanded(
            child: _GlassActionButton(
              label: '清除限制',
              icon: Icons.delete_outline_rounded,
              isDestructive: true,
              primaryColor: colorScheme.primary,
              onTap: _isLoading ? null : _showClearConfirmDialog,
            ),
          ),
        if (widget.summary.hasRule) SizedBox(width: 12),

        // 取消按钮
        Expanded(
          child: _GlassActionButton(
            label: '取消',
            icon: Icons.close_rounded,
            isSecondary: true,
            primaryColor: isDark ? colorScheme.textPrimaryDark : colorScheme.textSecondaryLight,
            onTap: _isLoading ? null : () => Navigator.of(context).pop(),
          ),
        ),
        SizedBox(width: 12),

        // 确定按钮
        Expanded(
          flex: 2,
          child: _GlassActionButton(
            label: '确定',
            icon: Icons.check_rounded,
            isLoading: _isLoading,
            primaryColor: isDark ? colorScheme.secondaryDarkMode : colorScheme.secondary,
            secondaryColor: isDark
                ? colorScheme.secondaryLightDarkMode
                : colorScheme.secondaryLight,
            onTap: _isLoading ? null : _saveRule,
          ),
        ),
      ],
    );
  }

  Future<void> _saveRule() async {
    final weekdayLimit = int.tryParse(_weekdayController.text);
    final weekendLimit = int.tryParse(_weekendController.text);

    if (weekdayLimit == null ||
        weekendLimit == null ||
        weekdayLimit <= 0 ||
        weekendLimit <= 0) {
      _showToast('请输入有效的时间');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final db = AppDatabase.instance;
      final ruleDao = RuleDao(db);

      final existingRule = await ruleDao.getAppRule(widget.summary.packageName);

      final rule = Rule(
        id: existingRule?.id,
        ruleType: RuleType.appSingle,
        target: widget.summary.packageName,
        weekdayLimitMinutes: weekdayLimit,
        weekendLimitMinutes: weekendLimit,
        enabled: true,
      );

      if (existingRule != null) {
        await ruleDao.update(rule);
      } else {
        await ruleDao.insert(rule);
      }

      ref.invalidate(appUsageListProvider);

      if (mounted) {
        Navigator.of(context).pop();
        _showToast('设置成功 ✨');
      }
    } catch (e) {
      if (mounted) {
        _showToast('保存失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showClearConfirmDialog() {
    final colorScheme = ref.read(colorSchemeProvider);
    final isDark = ref.read(isDarkModeProvider);

    showDialog(
      context: context,
      builder: (context) => _GlassConfirmDialog(
        title: '确认清除限制？',
        message:
            '清除后，该应用将受分类规则限制：\n• ${widget.summary.category.label}：${widget.summary.limitMinutes ?? '无'}分钟/天',
        confirmLabel: '确认清除',
        isDestructive: true,
        primaryColor: colorScheme.primary,
        secondaryColor: isDark
            ? colorScheme.secondaryDarkMode
            : colorScheme.secondary,
        onConfirm: () async {
          Navigator.of(context).pop();
          await _clearRule();
        },
      ),
    );
  }

  Future<void> _clearRule() async {
    setState(() => _isLoading = true);

    try {
      final db = AppDatabase.instance;
      final ruleDao = RuleDao(db);

      await ruleDao.deleteByTypeAndTarget(
        RuleType.appSingle,
        widget.summary.packageName,
      );

      ref.invalidate(appUsageListProvider);

      if (mounted) {
        Navigator.of(context).pop();
        _showToast('限制已清除');
      }
    } catch (e) {
      if (mounted) {
        _showToast('清除失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

/// 玻璃风格预设按钮
class _GlassPresetButton extends StatefulWidget {
  final String label;
  final bool isSelected;
  final List<Color> gradientColors;
  final bool isOutlined;
  final VoidCallback onTap;

  const _GlassPresetButton({
    required this.label,
    required this.isSelected,
    required this.gradientColors,
    this.isOutlined = false,
    required this.onTap,
  });

  @override
  State<_GlassPresetButton> createState() => _GlassPresetButtonState();
}

class _GlassPresetButtonState extends State<_GlassPresetButton> {
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: widget.isSelected && !widget.isOutlined
              ? LinearGradient(colors: widget.gradientColors)
              : null,
          color: widget.isSelected && widget.isOutlined
              ? widget.gradientColors[0].withOpacity(0.2)
              : widget.isOutlined
                  ? Colors.white.withOpacity(_isPressed ? 0.7 : 0.5)
                  : widget.isSelected
                      ? null
                      : Colors.white.withOpacity(_isPressed ? 0.7 : 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: widget.isSelected
                ? Colors.transparent
                : Colors.white.withOpacity(0.6),
            width: 1.5,
          ),
          boxShadow: widget.isSelected && !widget.isOutlined
              ? [
                  BoxShadow(
                    color: widget.gradientColors[0].withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Text(
          widget.label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
            color: widget.isSelected
                ? Colors.white
                : const Color(0xFF4A4A6A),
          ),
        ),
      ),
    );
  }
}

/// 玻璃风格操作按钮
class _GlassActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isSecondary;
  final bool isDestructive;
  final bool isLoading;
  final Color primaryColor;
  final Color? secondaryColor;
  final VoidCallback? onTap;

  const _GlassActionButton({
    required this.label,
    required this.icon,
    this.isSecondary = false,
    this.isDestructive = false,
    this.isLoading = false,
    required this.primaryColor,
    this.secondaryColor,
    this.onTap,
  });

  @override
  State<_GlassActionButton> createState() => _GlassActionButtonState();
}

class _GlassActionButtonState extends State<_GlassActionButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap != null ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: !widget.isSecondary && !widget.isDestructive && widget.secondaryColor != null
              ? LinearGradient(
                  colors: [widget.primaryColor, widget.secondaryColor!],
                )
              : null,
          color: widget.isSecondary || widget.isDestructive
              ? widget.primaryColor.withValues(alpha: _isPressed ? 0.3 : 0.15)
              : null,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: widget.isSecondary || widget.isDestructive
                ? widget.primaryColor.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: !widget.isSecondary && !widget.isDestructive
              ? [
                  BoxShadow(
                    color: widget.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.isLoading)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            else ...[
              Icon(
                widget.icon,
                size: 16,
                color: widget.isSecondary || widget.isDestructive
                    ? widget.primaryColor
                    : Colors.white,
              ),
              SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: widget.isSecondary || widget.isDestructive
                      ? widget.primaryColor
                      : Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 玻璃风格确认对话框
class _GlassConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final bool isDestructive;
  final Color primaryColor;
  final Color secondaryColor;
  final VoidCallback onConfirm;

  const _GlassConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.isDestructive = false,
    required this.primaryColor,
    required this.secondaryColor,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                primaryColor.withValues(alpha: 0.9),
                secondaryColor.withValues(alpha: 0.85),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.4),
                blurRadius: 25,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 图标
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isDestructive
                      ? Icons.warning_amber_rounded
                      : Icons.help_outline_rounded,
                  color: primaryColor,
                  size: 28,
                ),
              ),

              SizedBox(height: 18),

              // 标题
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4A4A6A),
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: 12),

              // 消息
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6A6A8A),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              SizedBox(height: 24),

              // 按钮
              Row(
                children: [
                  Expanded(
                    child: _GlassActionButton(
                      label: '取消',
                      icon: Icons.close_rounded,
                      isSecondary: true,
                      primaryColor: Color(0xFF8A8AAA),
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _GlassActionButton(
                      label: confirmLabel,
                      icon: Icons.check_rounded,
                      isDestructive: true,
                      primaryColor: primaryColor,
                      onTap: onConfirm,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
