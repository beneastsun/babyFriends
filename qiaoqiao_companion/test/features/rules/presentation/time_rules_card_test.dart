import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/features/rules/presentation/rules_page.dart';
import 'package:qiaoqiao_companion/shared/widgets/design_system/gradient_progress.dart';

/// "今日已用"区块的 widget 测试
///
/// 采用简化策略：直接测纯展示 widget [TodayUsedSection]，
/// 它只接收 `usedSeconds` 和 `limitMinutes` 两个参数，不依赖任何 provider/DB，
/// 测试稳定且能覆盖核心展示逻辑（文字格式、进度条渲染、超限 clamp）。
void main() {
  group('TodayUsedSection', () {
    testWidgets('限额启用时显示"今日已用"文字、分钟数与进度条', (tester) async {
      // 45 分钟 / 120 分钟限额 = 37.5%
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: TodayUsedSection(
                usedSeconds: 45 * 60,
                limitMinutes: 120,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('今日已用'), findsOneWidget);
      expect(find.textContaining('45 / 120 分钟'), findsOneWidget);
      expect(find.byType(UsageProgress), findsOneWidget);
    });

    testWidgets('超限时进度条 clamp 到 100% 但文字仍显示真实已用值', (tester) async {
      // 130 分钟 / 120 分钟限额 = 108% → clamp 到 100%
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: TodayUsedSection(
                usedSeconds: 130 * 60,
                limitMinutes: 120,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('今日已用'), findsOneWidget);
      // 文字仍显示真实已用值（不 clamp），方便家长看到实际超出多少
      expect(find.textContaining('130 / 120 分钟'), findsOneWidget);
      expect(find.byType(UsageProgress), findsOneWidget);

      final usageProgress = tester.widget<UsageProgress>(find.byType(UsageProgress));
      expect(usageProgress.percentage, 1.0);
    });

    testWidgets('已用 0 分钟时显示 0 / 限额 分钟', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: TodayUsedSection(
                usedSeconds: 0,
                limitMinutes: 90,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('0 / 90 分钟'), findsOneWidget);
      final usageProgress = tester.widget<UsageProgress>(find.byType(UsageProgress));
      expect(usageProgress.percentage, 0.0);
    });
  });
}
