import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/theme/app_theme.dart';
import 'package:qiaoqiao_companion/app/router.dart';
import 'package:qiaoqiao_companion/app/app_initializer.dart';
import 'package:qiaoqiao_companion/shared/providers/theme_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    const ProviderScope(
      child: QiaoqiaoApp(),
    ),
  );
}

/// 巧巧小伙伴应用
class QiaoqiaoApp extends ConsumerStatefulWidget {
  const QiaoqiaoApp({super.key});

  @override
  ConsumerState<QiaoqiaoApp> createState() => _QiaoqiaoAppState();
}

class _QiaoqiaoAppState extends ConsumerState<QiaoqiaoApp> {
  @override
  void initState() {
    super.initState();
    // 启动初始化
    Future.microtask(() {
      ref.read(appInitializationProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final initState = ref.watch(appInitializationProvider);

    // 监听主题状态
    final themeState = ref.watch(themeProvider);
    final themeData = AppTheme.getTheme(
      themeState.themeType,
      isDark: themeState.isDarkMode,
    );

    return MaterialApp.router(
      title: '纹纹小伙伴',
      debugShowCheckedModeBanner: false,
      theme: themeData,
      routerConfig: router,
      builder: (context, child) {
        // 显示启动画面
        if (!initState.isDatabaseReady) {
          return _LoadingScreen(
            error: initState.error,
            themeType: themeState.themeType,
          );
        }
        return child ?? _LoadingScreen(
          error: initState.error,
          themeType: themeState.themeType,
        );
      },
    );
  }
}

/// 加载画面
class _LoadingScreen extends StatelessWidget {
  final String? error;
  final AppThemeType themeType;

  const _LoadingScreen({
    this.error,
    required this.themeType,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColorSchemes.getScheme(themeType);

    return Scaffold(
      backgroundColor: colors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 巧巧形象占位
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(60),
              ),
              child: const Center(
                child: Text(
                  '🌤️',
                  style: TextStyle(fontSize: 60),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '纹纹小伙伴',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            if (error != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  '加载失败: $error',
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ),
            ] else ...[
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              const SizedBox(height: 16),
              const Text(
                '正在加载...',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
