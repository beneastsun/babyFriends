# 规则页面展示与禁用时段限制修复 实施计划

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复规则页面应用限制列表的图标展示问题，以及禁用时段不生效的问题

**Architecture:**
1. 在 `_MonitoredAppItem` 中使用 `installedAppsProvider` 获取真实应用图标和名称
2. 在应用初始化时加载 `monitoredAppsProvider` 和 `timePeriodsProvider`，确保监控服务启动前数据已就绪

**Tech Stack:** Flutter, Dart, Riverpod

---

## File Structure

| File | Type | Responsibility |
|------|------|----------------|
| `lib/features/rules/presentation/rules_page.dart` | Modify | `_MonitoredAppItem` 使用真实图标 |
| `lib/app/app_initializer.dart` | Modify | 初始化时加载必需的 provider |

---

### Task 1: 修复规则页面应用限制列表UI展示

**Files:**
- Modify: `lib/features/rules/presentation/rules_page.dart` (第297-381行 `_MonitoredAppItem` 类)

- [ ] **Step 1: 修改 `_MonitoredAppItem` 为 ConsumerWidget 并使用真实图标**

将 `_MonitoredAppItem` 从 `StatelessWidget` 改为 `ConsumerWidget`，使用 `installedAppsProvider` 获取真实图标和名称。

```dart
/// 被监控应用限制项
class _MonitoredAppItem extends ConsumerWidget {
  final MonitoredApp app;

  const _MonitoredAppItem({required this.app});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final installedAppsAsync = ref.watch(installedAppsProvider);
    final categoryColor = _getCategoryColor(app.category);
    final limitText = _formatLimit(app);

    return installedAppsAsync.when(
      data: (data) {
        final realIcon = data.getIcon(app.packageName);
        final realName = data.getName(app.packageName) ?? app.appName ?? app.packageName;
        return _buildItem(
          context: context,
          icon: realIcon,
          appName: realName,
          categoryColor: categoryColor,
          limitText: limitText,
        );
      },
      loading: () => _buildItem(
        context: context,
        icon: null,
        appName: app.appName ?? app.packageName,
        categoryColor: categoryColor,
        limitText: limitText,
      ),
      error: (_, __) => _buildItem(
        context: context,
        icon: null,
        appName: app.appName ?? app.packageName,
        categoryColor: categoryColor,
        limitText: limitText,
      ),
    );
  }

  Widget _buildItem({
    required BuildContext context,
    required String? icon,
    required String appName,
    required Color categoryColor,
    required String limitText,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          // 应用图标
          _buildAppIcon(icon, categoryColor),
          const SizedBox(width: AppSpacing.sm),
          // 应用名称
          Expanded(
            child: Text(
              appName,
              style: AppTextStyles.body1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // 限制标签
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: categoryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              limitText,
              style: AppTextStyles.caption.copyWith(color: categoryColor),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建应用图标
  Widget _buildAppIcon(String? icon, Color categoryColor) {
    // 如果有Base64编码的图标，显示真实图标
    if (icon != null && icon.isNotEmpty) {
      try {
        final bytes = base64Decode(icon);
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            bytes,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildFallbackIcon(categoryColor),
          ),
        );
      } catch (e) {
        return _buildFallbackIcon(categoryColor);
      }
    }
    return _buildFallbackIcon(categoryColor);
  }

  /// 构建备用图标（当无法获取真实图标时）
  Widget _buildFallbackIcon(Color categoryColor) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: categoryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          _getCategoryIcon(app.category),
          style: const TextStyle(fontSize: 20),
        ),
      ),
    );
  }

  String _getCategoryIcon(String? category) {
    switch (category) {
      case 'game':
        return '🎮';
      case 'video':
        return '📺';
      case 'study':
        return '📚';
      case 'reading':
        return '📖';
      default:
        return '📱';
    }
  }

  Color _getCategoryColor(String? category) {
    switch (category) {
      case 'game':
        return AppTheme.gameColor;
      case 'video':
        return AppTheme.videoColor;
      case 'study':
        return AppTheme.studyColor;
      case 'reading':
        return AppTheme.studyColor;
      default:
        return Colors.grey;
    }
  }

  String _formatLimit(MonitoredApp app) {
    if (app.dailyLimitMinutes == null) {
      return '无限制';
    }
    return '${app.dailyLimitMinutes}分钟/天';
  }
}
```

- [ ] **Step 2: 添加必需的 import**

在文件顶部添加 `dart:convert` import：

```dart
import 'dart:convert';
```

以及 `installedAppsProvider` 的 import（如果还没有）：

```dart
import 'package:qiaoqiao_companion/shared/providers/installed_apps_provider.dart';
```

- [ ] **Step 3: 验证编译通过**

Run: `cd qiaoqiao_companion && flutter analyze lib/features/rules/presentation/rules_page.dart`
Expected: No errors

---

### Task 2: 修复应用初始化时加载必需数据

**Files:**
- Modify: `lib/app/app_initializer.dart` (第59-64行)

- [ ] **Step 1: 在初始化时加载 monitoredAppsProvider 和 timePeriodsProvider**

修改 `initialize()` 方法中的 `Future.wait`，添加两个 provider 的加载：

```dart
// 2. 加载状态
await Future.wait([
  _ref.read(todayUsageProvider.notifier).loadToday(),
  _ref.read(pointsProvider.notifier).load(),
  _ref.read(rulesProvider.notifier).load(),
  _ref.read(couponsProvider.notifier).load(),
  // 新增：加载监控应用和时间段数据
  _ref.read(monitoredAppsProvider.notifier).load(),
  _ref.read(timePeriodsProvider.notifier).load(),
]);
```

- [ ] **Step 2: 添加必需的 import（如果需要）**

检查是否已导入 `monitoredAppsProvider` 和 `timePeriodsProvider`，如果没有则添加：

```dart
// 这些应该已经通过 providers.dart 导出了，检查一下
```

如果 `providers.dart` 没有导出这两个 provider，需要在 `lib/shared/providers/providers.dart` 中添加导出：

```dart
export 'monitored_apps_provider.dart';
export 'time_periods_provider.dart';
```

- [ ] **Step 3: 验证编译通过**

Run: `cd qiaoqiao_companion && flutter analyze lib/app/app_initializer.dart`
Expected: No errors

---

### Task 3: 整体验证

- [ ] **Step 1: 运行完整分析**

Run: `cd qiaoqiao_companion && flutter analyze`
Expected: No errors

- [ ] **Step 2: 运行测试（如果有相关测试）**

Run: `cd qiaoqiao_companion && flutter test`
Expected: All tests pass

---

## Verification Checklist

完成以上任务后，手动验证：

### UI展示验证
1. 运行应用：`cd qiaoqiao_companion && flutter run`
2. 打开"规则"页面
3. 检查"应用限制"列表中的图标是否为真实应用图标（而非分类emoji）
4. 检查应用名称是否正确显示

### 禁用时段验证
1. 进入家长模式
2. 添加一个应用到"应用限制"列表
3. 设置一个包含当前时间的"禁用时段"
4. 完全关闭应用，重新启动
5. 打开被监控的应用
6. 应该看到禁用提示弹窗
