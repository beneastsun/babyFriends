import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/features/home/presentation/home_page.dart';
import 'package:qiaoqiao_companion/features/home/presentation/app_list_page.dart';
import 'package:qiaoqiao_companion/features/rules/presentation/rules_page.dart';
import 'package:qiaoqiao_companion/features/settings/presentation/settings_page.dart';
import 'package:qiaoqiao_companion/features/onboarding/presentation/onboarding_page.dart';
import 'package:qiaoqiao_companion/features/points/presentation/points_history_page.dart';
import 'package:qiaoqiao_companion/features/parent_mode/presentation/parent_mode_page.dart';
import 'package:qiaoqiao_companion/features/parent_mode/presentation/edit_rules_page.dart';
import 'package:qiaoqiao_companion/features/parent_mode/presentation/issue_coupon_page.dart';
import 'package:qiaoqiao_companion/features/parent_mode/presentation/adjust_points_page.dart';
import 'package:qiaoqiao_companion/features/parent_mode/presentation/pause_monitor_page.dart';
import 'package:qiaoqiao_companion/features/achievement/presentation/achievement_page.dart';
import 'package:qiaoqiao_companion/app/shell_page.dart';
import 'package:qiaoqiao_companion/app/app_initializer.dart';

/// 路由配置 Provider
final appRouterProvider = Provider<GoRouter>((ref) {
  final initState = ref.watch(appInitializationProvider);

  // 决定初始路由：统一使用 Onboarding 流程处理权限和引导
  String initialLocation;
  if (!initState.isDatabaseReady) {
    initialLocation = '/loading';
  } else if (!initState.isOnboardingCompleted) {
    initialLocation = '/onboarding';
  } else {
    initialLocation = '/home';
  }

  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      // 加载页面
      GoRoute(
        path: '/loading',
        name: 'loading',
        builder: (context, state) => const _LoadingPage(),
      ),
      // Onboarding页面（包含权限引导步骤）
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),
      // 主应用 Shell 路由
      ShellRoute(
        builder: (context, state, child) => ShellPage(child: child),
        routes: [
          GoRoute(
            path: '/home',
            name: 'home',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HomePage(),
            ),
          ),
          GoRoute(
            path: '/rules',
            name: 'rules',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: RulesPage(),
            ),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SettingsPage(),
            ),
          ),
        ],
      ),
      // 积分历史页面（不在 Shell 内）
      GoRoute(
        path: '/points/history',
        name: 'points_history',
        builder: (context, state) => const PointsHistoryPage(),
      ),
      // 应用列表页面
      GoRoute(
        path: '/app-list',
        name: 'app_list',
        builder: (context, state) => const AppListPage(),
      ),
      // 成就页面
      GoRoute(
        path: '/achievement',
        name: 'achievement',
        builder: (context, state) => const AchievementPage(),
      ),
      // 家长模式路由
      GoRoute(
        path: '/parent-mode',
        name: 'parent_mode',
        builder: (context, state) => const ParentModePage(),
        routes: [
          GoRoute(
            path: 'rules',
            name: 'parent_mode_rules',
            builder: (context, state) => const EditRulesPage(),
          ),
          GoRoute(
            path: 'coupon',
            name: 'parent_mode_coupon',
            builder: (context, state) => const IssueCouponPage(),
          ),
          GoRoute(
            path: 'points',
            name: 'parent_mode_points',
            builder: (context, state) => const AdjustPointsPage(),
          ),
          GoRoute(
            path: 'pause',
            name: 'parent_mode_pause',
            builder: (context, state) => const PauseMonitorPage(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('页面不存在: ${state.error}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/home'),
              child: const Text('返回首页'),
            ),
          ],
        ),
      ),
    ),
  );
});

/// 路由路径常量
class AppRoutes {
  AppRoutes._();

  static const String loading = '/loading';
  static const String onboarding = '/onboarding';
  static const String home = '/home';
  static const String rules = '/rules';
  static const String settings = '/settings';
  static const String pointsHistory = '/points/history';
  static const String appList = '/app-list';
  static const String parentMode = '/parent-mode';
}

/// 简单加载页面
class _LoadingPage extends StatelessWidget {
  const _LoadingPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
