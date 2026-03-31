import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// 应用底部弹窗
class AppBottomSheet {
  AppBottomSheet._();

  /// 显示底部弹窗
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget Function(BuildContext) builder,
    bool isScrollControlled = true,
    bool enableDrag = true,
    double initialChildSize = 0.5,
    Color? backgroundColor,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      enableDrag: enableDrag,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: backgroundColor ??
                (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(DesignTokens.radius20),
            ),
          ),
          child: builder(context),
        );
      },
    );
  }

  /// 显示玻璃拟态底部弹窗
  static Future<T?> showGlass<T>({
    required BuildContext context,
    required Widget Function(BuildContext) builder,
  }) async {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.glassBackgroundLight,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(DesignTokens.radius20),
              ),
              border: Border.all(
                color: AppColors.glassBorderLight,
                width: 1,
              ),
            ),
            child: builder(context),
          ),
        );
      },
    );
  }
}

/// 底部弹窗容器
class BottomSheetContainer extends StatelessWidget {
  const BottomSheetContainer({
    super.key,
    required this.child,
    this.title,
    this.showHandle = true,
    this.showCloseButton = false,
    this.onClose,
  });

  final Widget child;
  final String? title;
  final bool showHandle;
  final bool showCloseButton;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖拽手柄
          if (showHandle)
            Padding(
              padding: const EdgeInsets.only(top: DesignTokens.space12),
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          // 标题栏
          if (title != null || showCloseButton)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DesignTokens.space16,
                DesignTokens.space8,
                DesignTokens.space16,
                DesignTokens.space16,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title ?? '',
                      style: AppTextStyles.heading3,
                    ),
                  ),
                  if (showCloseButton)
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: onClose ?? () => Navigator.of(context).pop(),
                    ),
                ],
              ),
            ),
          // 内容
          Flexible(child: child),
        ],
      ),
    );
  }
}

/// 选项列表底部弹窗
class OptionsBottomSheet extends StatelessWidget {
  const OptionsBottomSheet({
    super.key,
    required this.options,
    this.title,
  });

  final String? title;
  final List<BottomSheetOption> options;

  static Future<int?> show({
    required BuildContext context,
    required List<BottomSheetOption> options,
    String? title,
  }) {
    return AppBottomSheet.show<int>(
      context: context,
      builder: (context) => OptionsBottomSheet(
        title: title,
        options: options,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BottomSheetContainer(
      title: title,
      showCloseButton: false,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: options.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
        ),
        itemBuilder: (context, index) {
          final option = options[index];
          return ListTile(
            leading: option.icon != null
                ? Icon(
                    option.icon,
                    color: option.isDestructive
                        ? AppColors.error
                        : (isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight),
                  )
                : null,
            title: Text(
              option.label,
              style: AppTextStyles.bodyLarge.copyWith(
                color: option.isDestructive ? AppColors.error : null,
              ),
            ),
            subtitle: option.subtitle != null
                ? Text(
                    option.subtitle!,
                    style: AppTextStyles.bodySmall,
                  )
                : null,
            onTap: () {
              Navigator.of(context).pop(index);
            },
          );
        },
      ),
    );
  }
}

/// 底部弹窗选项
class BottomSheetOption {
  const BottomSheetOption({
    required this.label,
    this.icon,
    this.subtitle,
    this.isDestructive = false,
  });

  final String label;
  final IconData? icon;
  final String? subtitle;
  final bool isDestructive;
}

/// 密码输入底部弹窗
class PasswordInputSheet extends StatefulWidget {
  const PasswordInputSheet({
    super.key,
    required this.title,
    this.subtitle,
    this.confirmText = '确认',
    this.length = 4,
  });

  final String title;
  final String? subtitle;
  final String confirmText;
  final int length;

  static Future<String?> show({
    required BuildContext context,
    required String title,
    String? subtitle,
    String confirmText = '确认',
    int length = 4,
  }) {
    return AppBottomSheet.show<String>(
      context: context,
      isScrollControlled: false,
      builder: (context) => PasswordInputSheet(
        title: title,
        subtitle: subtitle,
        confirmText: confirmText,
        length: length,
      ),
    );
  }

  @override
  State<PasswordInputSheet> createState() => _PasswordInputSheetState();
}

class _PasswordInputSheetState extends State<PasswordInputSheet> {
  final List<String> _password = [];
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onKeyPressed(String value) {
    if (_password.length < widget.length) {
      setState(() {
        _password.add(value);
      });
    }
    if (_password.length == widget.length) {
      Navigator.of(context).pop(_password.join());
    }
  }

  void _onDelete() {
    if (_password.isNotEmpty) {
      setState(() {
        _password.removeLast();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BottomSheetContainer(
      title: widget.title,
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 副标题
            if (widget.subtitle != null)
              Text(
                widget.subtitle!,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            SizedBox(height: DesignTokens.space24),
            // 密码点显示
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.length, (index) {
                return Container(
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.symmetric(horizontal: DesignTokens.space8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index < _password.length
                        ? AppColors.primary
                        : (isDark
                            ? AppColors.borderDark
                            : AppColors.borderLight),
                  ),
                );
              }),
            ),
            SizedBox(height: DesignTokens.space24),
            // 数字键盘
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 3,
              mainAxisSpacing: DesignTokens.space8,
              crossAxisSpacing: DesignTokens.space8,
              childAspectRatio: 2,
              children: [
                ...List.generate(9, (index) {
                  final number = (index + 1).toString();
                  return _NumberButton(
                    number: number,
                    onTap: () => _onKeyPressed(number),
                  );
                }),
                _NumberButton(
                  number: '',
                  onTap: () {},
                  enabled: false,
                ),
                _NumberButton(
                  number: '0',
                  onTap: () => _onKeyPressed('0'),
                ),
                _NumberButton(
                  icon: Icons.backspace,
                  onTap: _onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberButton extends StatelessWidget {
  const _NumberButton({
    super.key,
    this.number,
    this.icon,
    required this.onTap,
    this.enabled = true,
  });

  final String? number;
  final IconData? icon;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(DesignTokens.radius8),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(DesignTokens.radius8),
        ),
        child: Center(
          child: icon != null
              ? Icon(
                  icon,
                  color: enabled
                      ? (isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight)
                      : (isDark
                          ? AppColors.textHintDark
                          : AppColors.textHintLight),
                )
              : Text(
                  number ?? '',
                  style: AppTextStyles.heading2.copyWith(
                    color: enabled
                        ? (isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight)
                        : (isDark
                            ? AppColors.textHintDark
                            : AppColors.textHintLight),
                  ),
                ),
        ),
      ),
    );
  }
}
