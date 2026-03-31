import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/main.dart';

void main() {
  testWidgets('App should build', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: QiaoqiaoApp(),
      ),
    );
    // 等待异步操作完成
    await tester.pumpAndSettle();
    // 验证应用已构建
    expect(find.byType(QiaoqiaoApp), findsOneWidget);
  });
}
