# 单应用使用时长查看与规则设置

> 需求来源：2026-03-16 用户反馈
> 功能：实时查看每个 app 的使用时长，设置单个 app 的时间限制

## 1. 需求概述

### 1.1 背景

当前应用只能查看总时间和分类（游戏/视频）的使用情况，无法查看每个具体应用的使用时长，也无法对单个应用设置时间限制。

### 1.2 目标

1. **查看**：在首页展示每个应用的今日使用时长和汇总
2. **设置**：支持对单个应用设置工作日/节假日的时间限制
3. **位置**：首页快速设置 + 家长模式完整管理

### 1.3 范围

| 包含 | 不包含 |
|------|--------|
| 首页展示 app 使用列表 | 历史数据迁移 |
| 首页快速设置 app 限制 | 分类规则的移除（保留但不显示在首页） |
| 家长模式 app 规则管理 | 远程管理功能 |
| RuleCheckerService 支持单应用规则 | 自定义节假日配置 |

---

## 2. 界面设计

### 2.1 首页改造

**改造前**：显示"总时间/游戏/视频"三个进度条

**改造后**：显示总时间进度 + 应用使用列表

```
┌─────────────────────────────────────┐
│  今日使用情况                         │
│  ──────────────────────────────      │
│  总计：45分钟 / 2小时                 │
│  ████████░░░░  38%                   │
│                                      │
│  应用使用明细                         │
│  ┌─────────────────────────────┐    │
│  │ 📱 抖音        25分钟   >   │    │
│  │    已设置：30分钟/天         │    │
│  ├─────────────────────────────┤    │
│  │ 🎮 我的世界     15分钟   >   │    │
│  │    未设置限制               │    │
│  ├─────────────────────────────┤    │
│  │ 📚 作业帮       5分钟    >   │    │
│  │    学习类，无单独限制        │    │
│  └─────────────────────────────┘    │
│                                      │
│  [查看全部应用 ▼]                    │
└─────────────────────────────────────┘
```

**交互**：
- 点击应用行 → 弹出时间限制设置对话框
- 点击"查看全部应用" → 跳转到完整应用列表页面

**进度条显示规则**：
- 有单应用规则 → 显示进度条（使用量/单应用限额）
- 无单应用规则 → 不显示进度条（只显示使用时间）

**状态文案**：
| 情况 | 显示文案 |
|------|----------|
| 有单应用规则 | "已设置：30分钟/天" |
| 无单应用规则，有分类规则 | "受视频类限制（30分钟）" |
| 学习类，无单独限制 | "学习类，无单独限制" |

### 2.2 时间限制设置对话框

```
┌─────────────────────────────────────┐
│  设置「抖音」时间限制                 │
├─────────────────────────────────────┤
│                                      │
│  工作日限额                          │
│  ┌─────┬─────┬──────┬────────┐      │
│  │ 15分│ 30分│ 1小时│ 自定义  │      │
│  └─────┴─────┴──────┴────────┘      │
│                         [  30  ] 分  │
│                                      │
│  节假日限额                          │
│  ┌─────┬─────┬──────┬────────┐      │
│  │ 15分│ 30分│ 1小时│ 自定义  │      │
│  └─────┴─────┴──────┴────────┘      │
│                         [  60  ] 分  │
│                                      │
│  [清除限制]          [取消] [确定]   │
└─────────────────────────────────────┘
```

**交互**：
- 点击预设按钮 → 直接填入对应值
- 点击"自定义" → 启用数字输入框
- 数字输入框支持键盘输入和 +/- 按钮
- 点击"清除限制" → 显示确认对话框，说明将回退到分类规则

**清除限制确认对话框**：
```
┌─────────────────────────────────────┐
│  确认清除限制？                       │
├─────────────────────────────────────┤
│                                      │
│  清除后，该应用将受分类规则限制：      │
│  • 视频类：30分钟/天                  │
│                                      │
│  [取消]              [确认清除]       │
└─────────────────────────────────────┘
```

### 2.3 完整应用列表页面（新增）

从首页"查看全部应用"进入，展示所有已安装应用的使用情况。

```
┌─────────────────────────────────────┐
│  ← 应用使用情况                      │
├─────────────────────────────────────┤
│  今日总计：45分钟 / 2小时             │
│                                      │
│  [全部] [已设限制] [未设限制]         │
│                                      │
│  ┌─────────────────────────────┐    │
│  │ 📱 抖音        25分钟        │    │
│  │    限制：30分/天 (工作日)    │    │
│  │    ████████████░░  83%      │    │
│  ├─────────────────────────────┤    │
│  │ 🎮 我的世界     15分钟       │    │
│  │    未设限制                 │    │
│  ├─────────────────────────────┤    │
│  │ ...                         │    │
│  └─────────────────────────────┘    │
└─────────────────────────────────────┘
```

**筛选说明**：
- 首页和完整列表使用相同的筛选逻辑：[全部][已设限制][未设限制]
- 家长模式使用分类筛选：[全部][游戏][视频][学习][其他]

### 2.4 家长模式 - 应用规则管理

在家长模式中新增"应用规则"入口，提供完整的规则管理功能。

```
┌─────────────────────────────────────┐
│  家长模式                            │
├─────────────────────────────────────┤
│  📱 应用规则管理              >      │
│  📋 时间规则                          │
│  🎫 发放加时券                        │
│  ⭐ 调整积分                          │
│  ⏸️ 暂停监控                          │
└─────────────────────────────────────┘
```

**应用规则管理页面**：

```
┌─────────────────────────────────────┐
│  ← 应用规则管理                      │
├─────────────────────────────────────┤
│  [全部] [游戏] [视频] [学习] [其他]   │
│                                      │
│  已设限制的应用 (3)                   │
│  ┌─────────────────────────────┐    │
│  │ 📱 抖音                      │    │
│  │ 工作日: 30分  节假日: 60分   │    │
│  │ 今日: 25分/30分 (83%)        │    │
│  ├─────────────────────────────┤    │
│  │ 🎮 我的世界                   │    │
│  │ 工作日: 15分  节假日: 30分   │    │
│  │ 今日: 15分/15分 (100%) ⚠️    │    │
│  └─────────────────────────────┘    │
│                                      │
│  未设限制的应用 (12)                  │
│  ┌─────────────────────────────┐    │
│  │ 📺 哔哩哔哩            [设置] │    │
│  │ 🎮 王者荣耀            [设置] │    │
│  └─────────────────────────────┘    │
└─────────────────────────────────────┘
```

**警告图标显示条件**：
- ⚠️ 在使用量 ≥ 90% 时显示

---

## 3. 数据模型

### 3.1 复用现有模型

**Rule 模型**已支持单应用规则：

```dart
class Rule {
  final int? id;
  final RuleType ruleType;        // appSingle = 单应用限制
  final String? target;            // 应用包名
  final int? weekdayLimitMinutes;  // 工作日限额
  final int? weekendLimitMinutes;  // 节假日限额
  final bool enabled;
}
```

### 3.2 新增数据结构

**LimitSource 枚举** - 区分限制来源：

```dart
enum LimitSource {
  singleApp,   // 单应用规则
  category,    // 分类规则
  total,       // 总时间规则
  none,        // 无限制（学习类）
}
```

**AppUsageSummary** - 用于首页展示的应用使用汇总：

```dart
class AppUsageSummary {
  final String packageName;
  final String appName;
  final AppCategory category;
  final int todayDurationSeconds;
  final int? limitMinutes;        // 今日适用的限额
  final LimitSource limitSource;  // 限制来源
  final bool hasRule;             // 是否有单应用规则
}
```

### 3.3 Provider 扩展

**appUsageListProvider** - 提供今日应用使用列表：

```dart
final appUsageListProvider = FutureProvider<List<AppUsageSummary>>((ref) async {
  // 1. 获取今日所有应用使用记录，按使用时长排序
  // 2. 查询每个应用是否有单应用规则
  // 3. 如果没有单应用规则，查找分类规则
  // 4. 计算今日适用的限额和 LimitSource
  // 5. 返回汇总列表
});
```

---

## 4. 技术实现

### 4.1 数据库查询

**新增 DAO 方法**：

```dart
// AppUsageDao
Future<List<AppUsageAggregate>> getTodayAggregated(String date) async {
  final db = await _database.database;
  final results = await db.rawQuery('''
    SELECT
      package_name,
      app_name,
      category,
      SUM(duration) as total_duration
    FROM ${DatabaseConstants.tableAppUsageRecords}
    WHERE date = ?
    GROUP BY package_name
    ORDER BY total_duration DESC
  ''', [date]);

  return results.map((map) => AppUsageAggregate.fromMap(map)).toList();
}
```

**RuleDao 新增方法**：

```dart
// 删除指定类型和目标的规则
Future<int> deleteByTypeAndTarget(RuleType type, String? target) async {
  final db = await _database.database;
  if (target != null) {
    return await db.delete(
      DatabaseConstants.tableRules,
      where: 'rule_type = ? AND target = ?',
      whereArgs: [type.code, target],
    );
  } else {
    return await db.delete(
      DatabaseConstants.tableRules,
      where: 'rule_type = ? AND target IS NULL',
      whereArgs: [type.code],
    );
  }
}

// 获取单个应用的规则
Future<Rule?> getAppRule(String packageName) async {
  return await getByTypeAndTarget(RuleType.appSingle, packageName);
}
```

### 4.2 RuleCheckerService 修改

**修改 `checkAppUsage()` 方法**，添加单应用规则检查：

```dart
Future<AppUsageResult> checkAppUsage(String packageName) async {
  // 1. 优先检查单应用规则
  final appRule = await _ruleDao.getAppRule(packageName);
  if (appRule != null && appRule.enabled) {
    return await _checkSingleAppLimit(appRule, packageName);
  }

  // 2. 检查分类规则
  final category = await _getAppCategory(packageName);
  final categoryRule = await _getCategoryRule(category);
  if (categoryRule != null && categoryRule.enabled) {
    return await _checkCategoryLimit(categoryRule, packageName, category);
  }

  // 3. 检查总时间规则
  return await _checkTotalTimeLimit(packageName);
}

Future<AppUsageResult> _checkSingleAppLimit(Rule rule, String packageName) async {
  final limitMinutes = rule.getLimitForDate(DateTime.now());
  if (limitMinutes == null) {
    return AppUsageResult.allowed();
  }

  final todayUsage = await _getAppUsageToday(packageName);
  final remainingMinutes = limitMinutes - (todayUsage ~/ 60);

  if (remainingMinutes <= 0) {
    return AppUsageResult.locked(
      reason: '单应用时间已用完',
      packageName: packageName,
    );
  } else if (remainingMinutes <= 5) {
    return AppUsageResult.warning(
      remainingMinutes: remainingMinutes,
      reason: '单应用时间即将用完',
      packageName: packageName,
    );
  }

  return AppUsageResult.allowed();
}
```

### 4.3 组件结构

```
lib/
├── features/
│   ├── home/
│   │   └── presentation/
│   │       ├── home_page.dart           # 修改：使用新的 app 列表组件
│   │       └── widgets/
│   │           ├── app_usage_list.dart  # 新增：应用使用列表
│   │           └── app_limit_dialog.dart # 新增：时间限制设置对话框
│   │
│   ├── app_list/                         # 新增功能模块
│   │   └── presentation/
│   │       └── app_list_page.dart        # 完整应用列表页面
│   │
│   └── parent_mode/
│       └── presentation/
│           ├── app_rules_page.dart       # 新增：应用规则管理页面
│           └── edit_app_rule_page.dart   # 新增：编辑单个应用规则
│
└── shared/
    ├── models/
    │   ├── app_usage_summary.dart        # 新增：应用使用汇总模型
    │   └── limit_source.dart             # 新增：限制来源枚举
    └── providers/
        └── app_usage_list_provider.dart  # 新增：应用列表 Provider
```

### 4.4 路由更新

```dart
// router.dart
GoRoute(
  path: '/app-list',
  name: 'app_list',
  builder: (context, state) => const AppListPage(),
),
GoRoute(
  path: '/parent-mode/app-rules',
  name: 'parent_mode_app_rules',
  builder: (context, state) => const AppRulesPage(),
),
```

---

## 5. 业务规则

### 5.1 时间限制优先级

```
单应用规则 > 分类规则 > 总时间规则
```

示例：
- 抖音设置了单应用规则 30 分钟 → 使用抖音最多 30 分钟
- 未设置单应用规则，但属于视频类 → 使用视频类最多 30 分钟
- 未设置任何规则 → 受总时间 2 小时限制

**实现位置**：`RuleCheckerService.checkAppUsage()`

### 5.2 工作日/节假日判断

- 工作日：周一至周五
- 节假日：周六、周日
- 限额根据当天类型自动切换

**已知限制**：
- 暂不支持自定义节假日（如寒暑假、法定假日）
- 后续版本可扩展节假日配置功能

### 5.3 提醒逻辑

当单应用达到限制时：
1. 提前 5 分钟 → 温和提醒
2. 达到限制 → 强制锁定该应用

### 5.4 跨天边界处理

- 使用时间在 00:00 自动重置
- 跨天时（如 23:55 → 00:10）的使用会被拆分到两天
- 正在使用的应用不会被强制关闭，但新使用时间计入新的一天

### 5.5 应用安装/卸载处理

- **新安装应用**：自动出现在列表中，默认无规则
- **卸载应用**：规则保留，重新安装后自动恢复

---

## 6. 数据库迁移

### 6.1 版本变更

- 当前版本：1
- 新版本：2（如需新增字段则升级，否则保持 v1）

### 6.2 Schema 变更

**无需新增表**，复用现有 `rules` 表：
- `rule_type` 已支持 `appSingle`
- `target` 存储应用包名
- `weekday_limit` / `weekend_limit` 存储时间限制

### 6.3 迁移代码

```dart
// app_database.dart
Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 2) {
    // 当前无需 schema 变更
    // 版本号升级用于标记功能支持
  }
}
```

---

## 7. 实现计划

### Phase 1：首页应用列表展示
- 新增 `LimitSource` 枚举
- 新增 `AppUsageSummary` 模型
- 新增 `AppUsageDao.getTodayAggregated()` 方法
- 新增 `appUsageListProvider`
- 修改首页 `_UsageProgressCard` 为 `_AppUsageListCard`
- 新增 `AppUsageList` 组件

### Phase 2：快速设置对话框
- 新增 `AppLimitDialog` 组件
- 实现预设选项 + 自定义输入
- 新增 `RuleDao.deleteByTypeAndTarget()` 方法
- 连接 RuleDao 保存/删除规则

### Phase 3：完整应用列表页面
- 新增 `AppListPage` 页面
- 支持筛选（全部/已设限制/未设限制）

### Phase 4：家长模式应用规则管理
- 新增 `AppRulesPage` 页面
- 新增 `EditAppRulePage` 页面
- 更新家长模式入口

### Phase 5：RuleCheckerService 支持单应用规则
- 修改 `checkAppUsage()` 方法
- 新增 `_checkSingleAppLimit()` 方法
- 测试规则优先级

---

## 8. 测试要点

- [ ] 首页正确显示应用使用列表和汇总
- [ ] 快速设置对话框能正确保存工作日/节假日限额
- [ ] 预设选项和自定义输入都能正常工作
- [ ] 清除限制后显示确认对话框
- [ ] 规则优先级正确（单应用 > 分类 > 总时间）
- [ ] 家长模式能管理所有应用规则
- [ ] 删除规则后恢复正常分类规则限制
- [ ] 进度条仅在有单应用规则时显示
- [ ] 警告图标在 ≥90% 时显示
- [ ] RuleCheckerService 正确检查单应用规则

---

*文档版本：1.1*
*创建日期：2026-03-16*
*更新日期：2026-03-16*
*作者：Claude + 用户协作*
*更新说明：根据 code review 反馈修复 CRITICAL 和 HIGH 问题*
