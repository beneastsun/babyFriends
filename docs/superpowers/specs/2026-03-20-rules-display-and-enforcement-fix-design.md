# 规则页面展示与禁用时段限制修复设计

## 背景

用户反馈两个问题：
1. 规则页面"应用限制"列表展示与首页应用列表不一致（缺少真实图标和名称）
2. 设置了禁用时段后，打开被监控应用没有提示

## 问题分析

### 问题1：UI展示不一致

**现象**：
- 首页 `_AppUsageItem`：使用 base64 真实图标 + 真实应用名称
- 规则页面 `_MonitoredAppItem`：只显示分类emoji + `appName ?? packageName`

**根因**：
- `_MonitoredAppItem` 组件没有从 `installedAppsProvider` 获取真实图标和名称
- `MonitoredApp` 模型本身不存储 `appIcon` 字段

### 问题2：禁用时段不生效

**现象**：
- 用户已添加4个app到监控列表
- 已设置禁用时段（当前时间在时段内）
- 打开被监控app时没有任何提示

**根因**：
1. `UsageMonitorService` 在应用初始化时启动（`app_initializer.dart:84`）
2. `monitoredAppsProvider` 和 `timePeriodsProvider` **没有在应用初始化时加载**
3. 这两个 provider 只在 `RulesPage.initState()` 中加载
4. `RuleCheckerService` 使用 `_ref.read()` 读取数据，不会感知后续变化
5. 监控服务使用的是**空的旧数据**，导致所有检查都返回"允许"

## 解决方案

### 修复1：规则页面UI展示

**文件**：`lib/features/rules/presentation/rules_page.dart`

**修改内容**：
1. 在 `_MonitoredAppItem` 中添加 `ConsumerWidget` 支持
2. 使用 `installedAppsProvider` 获取真实图标和名称
3. 参考首页 `_AppUsageItem` 的实现方式

**代码变更**：
```dart
class _MonitoredAppItem extends ConsumerWidget {
  final MonitoredApp app;

  const _MonitoredAppItem({required this.app});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final installedAppsAsync = ref.watch(installedAppsProvider);

    return installedAppsAsync.when(
      data: (data) => _buildWithRealIcon(context, data),
      loading: () => _buildWithFallback(context),
      error: (_, __) => _buildWithFallback(context),
    );
  }

  Widget _buildWithRealIcon(BuildContext context, InstalledAppsData data) {
    final realIcon = data.getIcon(app.packageName);
    final realName = data.getName(app.packageName) ?? app.appName ?? app.packageName;
    // ... 使用真实图标渲染
  }
}
```

### 修复2：应用初始化时加载必需数据

**文件**：`lib/app/app_initializer.dart`

**修改内容**：
在 `initialize()` 方法的 `Future.wait` 中添加 `monitoredAppsProvider` 和 `timePeriodsProvider` 的加载

**代码变更**：
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

## 验证方法

### 修复1验证
1. 打开规则页面
2. 检查"应用限制"列表是否显示真实应用图标（与首页一致）
3. 检查应用名称是否正确显示（而非包名）

### 修复2验证
1. 设置禁用时段（包含当前时间）
2. 添加至少一个应用到"应用限制"列表
3. 完全关闭应用，重新启动
4. 打开被监控的应用
5. 应该看到禁用提示

## 文件变更清单

| 文件 | 变更类型 | 说明 |
|------|----------|------|
| `lib/features/rules/presentation/rules_page.dart` | 修改 | `_MonitoredAppItem` 组件使用真实图标 |
| `lib/app/app_initializer.dart` | 修改 | 初始化时加载 `monitoredAppsProvider` 和 `timePeriodsProvider` |

## 风险评估

- **风险等级**：低
- **影响范围**：仅影响规则页面UI展示和应用初始化流程
- **回滚方案**：还原两个文件的修改即可
