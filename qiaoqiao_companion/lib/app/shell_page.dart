import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qiaoqiao_companion/app/router.dart';
import 'package:qiaoqiao_companion/core/theme/app_theme.dart';
import 'package:qiaoqiao_companion/core/theme/app_solid_colors.dart';
import 'package:qiaoqiao_companion/shared/providers/theme_provider.dart';
import 'package:qiaoqiao_companion/core/platform/monitor_service.dart';

/// 带浮动导航栏的 Shell 页面
class ShellPage extends StatefulWidget {
  final Widget child;

  const ShellPage({super.key, required this.child});

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  int _currentIndex = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateIndex();
  }

  void _updateIndex() {
    final location = GoRouterState.of(context).uri.toString();
    setState(() {
      switch (location) {
        case AppRoutes.home:
          _currentIndex = 0;
          break;
        case AppRoutes.rules:
          _currentIndex = 1;
          break;
        case AppRoutes.settings:
          _currentIndex = 2;
          break;
      }
    });
  }

  void _onItemTapped(int index) {
    if (_currentIndex == index) return;

    setState(() {
      _currentIndex = index;
    });
    switch (index) {
      case 0:
        context.go(AppRoutes.home);
        break;
      case 1:
        context.go(AppRoutes.rules);
        break;
      case 2:
        context.go(AppRoutes.settings);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // 确保前台服务在运行
        await MonitorService.startForegroundService();

        // 将应用移动到后台（不退出）
        await MonitorService.moveToBackground();
      },
      child: Scaffold(
        body: widget.child,
        bottomNavigationBar: _buildFloatingNavBar(isDark),
      ),
    );
  }

  Widget _buildFloatingNavBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.only(
        left: DesignTokens.space16,
        right: DesignTokens.space16,
        bottom: DesignTokens.space16,
        top: DesignTokens.space8,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(DesignTokens.radius20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.glassBackgroundDark
                  : AppColors.glassBackgroundLight,
              borderRadius: BorderRadius.circular(DesignTokens.radius20),
              border: Border.all(
                color: isDark
                    ? AppColors.glassBorderDark
                    : AppColors.glassBorderLight,
                width: 1,
              ),
              boxShadow: AppShadows.floatingNav,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _NavItem(
                  icon: Icons.home_rounded,
                  label: '首页',
                  isSelected: _currentIndex == 0,
                  onTap: () => _onItemTapped(0),
                ),
                _NavItem(
                  icon: Icons.rule_rounded,
                  label: '规则',
                  isSelected: _currentIndex == 1,
                  onTap: () => _onItemTapped(1),
                ),
                _NavItem(
                  icon: Icons.person_rounded,
                  label: '我的',
                  isSelected: _currentIndex == 2,
                  onTap: () => _onItemTapped(2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 导航项组件
class _NavItem extends ConsumerStatefulWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  ConsumerState<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends ConsumerState<_NavItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: DesignTokens.animationQuick,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeType = ref.watch(themeTypeProvider);
    final colors = ref.watch(colorSchemeProvider);

    return Expanded(
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: child,
            );
          },
          child: Container(
            color: Colors.transparent,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 图标
                AnimatedContainer(
                  duration: DesignTokens.animationNormal,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: widget.isSelected ? AppSolidColors.getPrimaryColor(themeType, isDark) : Colors.transparent,
                    borderRadius: BorderRadius.circular(DesignTokens.radius12),
                  ),
                  child: Icon(
                    widget.icon,
                    size: 24,
                    color: widget.isSelected
                        ? Colors.white
                        : (isDark
                            ? AppColors.textHintDark
                            : AppColors.textHintLight),
                  ),
                ),
                const SizedBox(height: 4),
                // 标签
                AnimatedDefaultTextStyle(
                  duration: DesignTokens.animationNormal,
                  style: AppTextStyles.navLabel.copyWith(
                    color: widget.isSelected
                        ? (isDark
                            ? colors.primaryDark
                            : colors.primary)
                        : (isDark
                            ? AppColors.textHintDark
                            : AppColors.textHintLight),
                    fontWeight:
                        widget.isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  child: Text(widget.label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
