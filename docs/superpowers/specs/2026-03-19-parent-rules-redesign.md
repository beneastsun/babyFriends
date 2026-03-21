# 家长管理规则界面功能修改设计文档

**日期**: 2026-03-19
**状态**: 待实现
**版本**: v1.0

---

## 1. 需求概述

### 1.1 背景

当前规则系统存在以下问题：
- 规则模型不够灵活，难以支持多个时间段
- 缺乏对单个 app 的精细化管理
- 缺少连续使用时长限制功能

### 1.2 核心需求

1. **基础规则变更**：限制功能只针对设定的 app，未设置的 app 不在限制范围内，也不计入总时间统计
2. **时间段设置**：支持禁用时段/开放时段两种模式，可设置多个时间段
3. **单独 app 设置**：从已安装应用列表选择要限制的 app，为每个 app 设置单独的使用时长
4. **连续使用时长限制**：
   - 默认 30 分钟
   - 有开关控制，默认关闭
   - 触发机制：
     - 前 5 分钟：倒计时提示（半透明可拖动）
     - 前 2 分钟：再提醒
     - 到时间：再提醒
     - 超时后：禁用限制的 app，强制休息 10 分钟

5. **界面布局**：分 Tab 展示（时间段设置 / 应用管理 / 连续使用限制）

---

## 2. 数据模型设计

### 2.1 新增 `monitored_apps` 表

存储被监控的 app 列表及其限制配置。

```sql
CREATE TABLE monitored_apps (
  package_name TEXT PRIMARY KEY,   -- app 包名
  app_name TEXT,                   -- app 显示名称
  daily_limit_minutes INTEGER,     -- 每日时间限制（分钟），NULL 表示无限制
  category TEXT,                   -- 分类（game/video/other）
  enabled INTEGER DEFAULT 1,       -- 是否启用监控
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE INDEX idx_monitored_apps_enabled ON monitored_apps(enabled);
```

### 2.2 新增 `time_periods` 表

存储禁用/开放时间段配置。

```sql
CREATE TABLE time_periods (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  mode TEXT NOT NULL,              -- 'blocked' 禁用时段 / 'allowed' 开放时段
  time_start TEXT NOT NULL,        -- 开始时间 "HH:mm"
  time_end TEXT NOT NULL,          -- 结束时间 "HH:mm"
  days TEXT NOT NULL,              -- 适用日期 "1,2,3,4,5" (1=周一, 7=周日)
  enabled INTEGER DEFAULT 1,
  created_at INTEGER NOT NULL
);

CREATE INDEX idx_time_periods_mode ON time_periods(mode);
CREATE INDEX idx_time_periods_enabled ON time_periods(enabled);
```

### 2.3 连续使用限制配置

使用 settings 表存储全局设置：

| 键名 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `continuous_usage_limit_minutes` | int | 30 | 连续使用限制时长（分钟） |
| `continuous_usage_limit_enabled` | bool | false | 是否启用连续使用限制 |
| `continuous_rest_minutes` | int | 10 | 强制休息时长（分钟） |

### 2.4 新增 `continuous_usage_sessions` 表

存储连续使用会话状态（支持跨重启恢复）：

```sql
CREATE TABLE continuous_usage_sessions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  session_date TEXT NOT NULL,       -- 会话日期 "YYYY-MM-DD"
  start_time INTEGER NOT NULL,      -- 会话开始时间戳
  total_duration_seconds INTEGER DEFAULT 0, -- 累计连续使用时长
  last_activity_time INTEGER,       -- 最后活动时间戳
  rest_end_time INTEGER,            -- 强制休息结束时间（NULL 表示未在休息）
  alerts_shown TEXT,                -- 已显示的提醒级别 JSON: ["5min", "2min"]
  is_active INTEGER DEFAULT 1,      -- 会话是否活跃
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE INDEX idx_continuous_session_date ON continuous_usage_sessions(session_date);
CREATE INDEX idx_continuous_session_active ON continuous_usage_sessions(is_active);
```

**会话重置条件**：
- 切换到非监控 app 超过 2 分钟
- 屏幕关闭超过 5 分钟
- 一天结束（次日 00:00 自动重置）

### 2.4 保留并简化 `rules` 表

- 保留用于存储全局总时间限制（可选功能）
- 移除 `appCategory` 类型（改用 monitored_apps）
- 移除 `appSingle` 类型（改用 monitored_apps）
- 移除 `timeBlock` 类型（改用 time_periods）

---

## 3. 界面设计

### 3.1 页面结构

```
EditRulesPage
├─ TabBar
│  ├─ 时间段设置
│  ├─ 应用管理
│  └─ 连续使用
│
├─ Tab: 时间段设置
│  ├─ 模式切换开关（禁用时段 / 开放时段）
│  ├─ 时段列表
│  │  └─ TimePeriodCard
│  │     ├─ 时间选择器（开始-结束）
│  │     ├─ 适用日期选择（周一到周日）
│  │     └─ 删除按钮
│  └─ 添加时段按钮
│
├─ Tab: 应用管理
│  ├─ 已监控应用列表
│  │  └─ MonitoredAppCard
│  │     ├─ App 图标和名称
│  │     ├─ 每日时间限制设置
│  │     ├─ 启用/禁用开关
│  │     └─ 移除按钮
│  └─ 添加应用按钮 → 跳转到应用选择页面
│
└─ Tab: 连续使用
   ├─ 启用开关（默认关闭）
   ├─ 连续使用时长设置（分钟，默认30）
   └─ 强制休息时长设置（分钟，默认10）
```

### 3.2 应用选择页面 (AppSelectionPage)

- 显示设备已安装应用列表
- **过滤规则**：
  - 排除系统应用（包名以 `com.android.`, `android.` 开头）
  - 排除本应用自身 (`com.qiaoqiao.qiaoqiao_companion`)
  - 保留第三方应用和游戏
- 支持搜索过滤（按应用名称）
- 勾选要监控的应用
- 批量添加到监控列表
- 显示每个应用的分类标签（游戏/视频/其他）

### 3.3 连续使用提醒弹窗 (ContinuousUsageReminder)

```
┌─────────────────────────────────┐
│  半透明背景，可拖动位置          │
│  ┌───────────────────────────┐  │
│  │   👁️ 保护眼睛              │  │
│  │                           │  │
│  │   连续使用已 25 分钟       │  │
│  │                           │  │
│  │      00:05:00             │  │
│  │    （大字体倒计时）        │  │
│  │                           │  │
│  │   建议休息 10 分钟         │  │
│  │                           │  │
│  │ [继续使用]  [现在休息]     │  │
│  └───────────────────────────┘  │
└─────────────────────────────────┘
```

---

## 4. 规则检查逻辑

### 4.0 规则优先级（从高到低）

```
1. 强制休息（连续使用超时）  ← 最高优先级，覆盖其他所有规则
2. 时间段规则（禁用/开放时段）
3. 单个 app 每日时间限制    ← 最低优先级
```

**冲突处理示例**：
- 当前在"开放时段"内，但处于"强制休息"状态 → **禁止使用**
- 当前在"禁用时段"内，但单个 app 时间未超限 → **禁止使用**（时间段规则优先）

### 4.1 检查流程

```
当用户打开某个 app 时：

1. 检查该 app 是否在 monitored_apps 列表中
   ├─ 不在列表 → 允许使用，不记录时间，结束
   └─ 在列表 → 继续

2. 检查是否处于强制休息状态
   ├─ 查询 continuous_usage_sessions 表
   ├─ rest_end_time != NULL 且 < 当前时间 → 禁止使用，显示休息倒计时
   └─ 否则 → 继续

3. 检查时间段规则 (time_periods)
   ├─ 模式=禁用时段 → 当前时间在任何禁用时段内？
   │   └─ 是 → 禁止使用
   ├─ 模式=开放时段 → 当前时间在任何开放时段内？
   │   └─ 否 → 禁止使用
   └─ 通过 → 继续

4. 检查连续使用限制
   ├─ 未启用 → 跳过
   └─ 已启用 → 检查本次连续使用时长
       ├─ 前5分钟 → 弹出倒计时提醒
       ├─ 前2分钟 → 再次提醒
       ├─ 到时间 → 最后提醒
       └─ 超时 → 进入强制休息状态

5. 检查单个 app 的每日时间限制
   └─ 超限 → 禁止使用
```

### 4.2 连续使用会话定义

**会话开始**：用户打开任意被监控的 app

**会话保持**（以下情况会话**不中断**）：
- 在被监控 app 之间切换
- 短暂切换到非监控 app（≤ 2 分钟）
- 屏幕短暂关闭（≤ 5 分钟）

**会话中断**（累计时间清零）：
- 切换到非监控 app 超过 2 分钟
- 屏幕关闭超过 5 分钟
- 进入强制休息状态
- 一天结束（00:00 重置）

**跨天处理**：
- 时间段如 "22:00-06:00" 自动处理跨天
- 检查逻辑：`start > end ? (now >= start || now < end) : (now >= start && now < end)`

### 4.3 连续使用监控状态机

```
┌─────────┐  开始使用  ┌──────────┐
│  空闲   │ ────────→ │  使用中  │
└─────────┘           └──────────┘
     ↑                     │
     │                     │ 切换app/停止
     │                     ↓
     │              ┌──────────┐
     │   休息结束   │  休息中  │
     └──────────────│          │
                    └──────────┘
                          ↑
                          │ 超时强制休息
                    ┌──────────┐
                    │  警告中  │
                    └──────────┘
```

### 4.3 强制休息机制

**触发条件**：连续使用时间超过限制

**实现方式**：

1. **数据层**：在 `continuous_usage_sessions` 表设置 `rest_end_time = 当前时间 + 休息时长`
2. **检查层**：在 `RuleCheckerService` 中优先检查 `rest_end_time`（不修改 `monitored_apps.enabled` 字段）
3. **UI 层**：触发时调用 `OverlayChannel.showRestOverlay()` 显示全屏休息提示

```dart
// 在 RuleCheckerService 中的实现
Future<RuleCheckResult> checkAppUsage(String packageName) async {
  // 1. 检查是否在 monitored_apps 中
  // ...

  // 2. 检查强制休息状态（最高优先级）
  final session = await _continuousSessionDao.getActiveSession(today);
  if (session?.restEndTime != null && session!.restEndTime! > now) {
    final remainingRest = session.restEndTime! - now;
    // 通过 OverlayChannel 显示休息界面
    await _overlayChannel.showRestOverlay(remainingRest);
    return RuleCheckResult.blocked(
      reason: '请休息 ${remainingRest ~/ 60} 分钟',
      ruleType: RuleType.continuousRest,
    );
  }

  // 3. 继续其他检查...
}
```

**休息期间行为**：
- 所有 `monitored_apps` 被禁止使用
- 显示全屏休息提示，包含剩余时间倒计时
- 休息结束后自动清除 `rest_end_time`，恢复正常使用

### 4.4 会话恢复逻辑

应用重启时的会话状态恢复：

```dart
Future<void> restoreSession() async {
  final today = formatDate(DateTime.now());
  final activeSession = await dao.getActiveSession(today);

  if (activeSession == null) {
    // 无活跃会话，创建新会话
    return;
  }

  // 检查会话是否仍然有效
  // 注意：阈值 30 分钟 > 2 分钟（切换非监控 app 中断阈值），
  // 因为应用重启可能已过较长时间，给更宽松的恢复条件
  final lastActivity = activeSession.lastActivityTime;
  final now = DateTime.now().millisecondsSinceEpoch;

  // 如果距离最后活动时间超过 30 分钟，认为会话已失效
  if (now - lastActivity > 30 * 60 * 1000) {
    await dao.deactivateSession(activeSession.id);
    return;
  }

  // 检查是否在强制休息中
  if (activeSession.restEndTime != null && activeSession.restEndTime! > now) {
    // 仍在休息中，保持休息状态
    return;
  }

  // 会话有效，继续使用
}
```

**阈值说明**：
- 切换到非监控 app 中断：2 分钟（实时监控）
- 屏幕关闭中断：5 分钟（实时监控）
- 应用重启恢复阈值：30 分钟（较宽松，因为无法确定重启前状态）

### 4.5 时间段跨天处理示例

```dart
/// 检查当前时间是否在时间段内
bool isTimeInPeriod(String currentTime, String startTime, String endTime) {
  // start > end 表示跨天（如 22:00-06:00）
  if (startTime.compareTo(endTime) > 0) {
    // 跨天：当前时间 >= start 或 < end
    return currentTime.compareTo(startTime) >= 0 ||
           currentTime.compareTo(endTime) < 0;
  } else {
    // 同一天：当前时间 >= start 且 < end
    return currentTime.compareTo(startTime) >= 0 &&
           currentTime.compareTo(endTime) < 0;
  }
}

// 示例 1：检查 23:00 是否在 "22:00-06:00" 时段内
// start = "22:00", end = "06:00", current = "23:00"
// start > end 为 true
// current >= start (23:00 >= 22:00) = true
// 结果：true → 在时段内 ✓

// 示例 2：检查 03:00 是否在 "22:00-06:00" 时段内
// start = "22:00", end = "06:00", current = "03:00"
// start > end 为 true
// current >= start (03:00 >= 22:00) = false
// current < end (03:00 < 06:00) = true
// 结果：true → 在时段内 ✓

// 示例 3：检查 08:00 是否在 "22:00-06:00" 时段内
// start = "22:00", end = "06:00", current = "08:00"
// start > end 为 true
// current >= start (08:00 >= 22:00) = false
// current < end (08:00 < 06:00) = false
// 结果：false → 不在时段内 ✓
```

---

## 5. 文件结构

### 5.1 新增/修改文件

```
lib/
├─ core/
│  ├─ database/
│  │  ├─ app_database.dart          # 修改：新增表、升级版本
│  │  └─ daos/
│  │     ├─ monitored_app_dao.dart  # 新增
│  │     ├─ time_period_dao.dart    # 新增
│  │     └─ continuous_session_dao.dart # 新增
│  └─ services/
│     ├─ rule_checker_service.dart  # 修改：新检查逻辑
│     ├─ continuous_usage_service.dart # 新增：连续使用监控
│     └─ app_discovery_service.dart    # 新增：发现已安装应用
│
├─ shared/
│  ├─ models/
│  │  ├─ monitored_app.dart         # 新增
│  │  ├─ time_period.dart           # 新增
│  │  └─ continuous_session.dart    # 新增
│  └─ providers/
│     ├─ monitored_apps_provider.dart # 新增
│     ├─ time_periods_provider.dart   # 新增
│     └─ continuous_usage_provider.dart # 新增
│
└─ features/
   └─ parent_mode/
      └─ presentation/
         ├─ edit_rules_page.dart      # 重构：Tab 布局
         ├─ time_periods_tab.dart     # 新增
         ├─ app_management_tab.dart   # 新增
         ├─ continuous_usage_tab.dart # 新增
         ├─ app_selection_page.dart   # 新增
         └─ widgets/
            ├─ time_period_card.dart           # 新增
            ├─ monitored_app_card.dart         # 新增
            └─ continuous_usage_reminder.dart  # 新增
```

---

## 6. 数据库迁移计划

### 6.1 版本升级

当前版本: v2 → 新版本: v3

### 6.2 迁移步骤

```dart
Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 3) {
    // v2 -> v3: 重构规则系统
    // 使用事务确保迁移原子性
    await db.transaction(() async {
      // 1. 创建新表
      await db.execute('''
        CREATE TABLE monitored_apps (
          package_name TEXT PRIMARY KEY,
          app_name TEXT,
          daily_limit_minutes INTEGER,
          category TEXT,
          enabled INTEGER DEFAULT 1,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        );
      ''');

      await db.execute('''
        CREATE TABLE time_periods (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          mode TEXT NOT NULL,
          time_start TEXT NOT NULL,
          time_end TEXT NOT NULL,
          days TEXT NOT NULL,
          enabled INTEGER DEFAULT 1,
          created_at INTEGER NOT NULL
        );
      ''');

      await db.execute('''
        CREATE TABLE continuous_usage_sessions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          session_date TEXT NOT NULL,
          start_time INTEGER NOT NULL,
          total_duration_seconds INTEGER DEFAULT 0,
          last_activity_time INTEGER,
          rest_end_time INTEGER,
          alerts_shown TEXT,
          is_active INTEGER DEFAULT 1,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        );
      ''');

      // 2. 迁移现有 rules 数据
      final now = DateTime.now().millisecondsSinceEpoch;

      // 2.1 timeBlock 规则 → time_periods 表
      final timeBlockRules = await db.query(
        'rules',
        where: 'rule_type = ?',
        whereArgs: ['time_block'],
      );
      for (final rule in timeBlockRules) {
        final timeStart = rule['time_start'] as String?;
        final timeEnd = rule['time_end'] as String?;
        if (timeStart == null || timeEnd == null) continue; // 跳过无效数据

        await db.insert('time_periods', {
          'mode': 'blocked',
          'time_start': timeStart,
          'time_end': timeEnd,
          'days': rule['target'] == 'weekday' ? '1,2,3,4,5' : '1,2,3,4,5,6,7',
          'enabled': rule['enabled'] ?? 1,
          'created_at': now,
        });
      }

      // 2.2 appSingle 规则 → monitored_apps 表
      final appSingleRules = await db.query(
        'rules',
        where: 'rule_type = ?',
        whereArgs: ['app_single'],
      );
      for (final rule in appSingleRules) {
        final packageName = rule['target'] as String?;
        if (packageName == null) continue; // 跳过无效数据

        final limitMinutes = rule['weekday_limit'] as int?; // NULL 表示无限制

        // 尝试从 app_categories 表获取 app_name
        String? appName;
        final categoryInfo = await db.query(
          'app_categories',
          where: 'package_name = ?',
          whereArgs: [packageName],
          limit: 1,
        );
        if (categoryInfo.isNotEmpty) {
          appName = categoryInfo.first['app_name'] as String?;
        }

        await db.insert('monitored_apps', {
          'package_name': packageName,
          'app_name': appName ?? packageName, // 无名称时使用包名
          'daily_limit_minutes': limitMinutes, // 允许 NULL
          'enabled': rule['enabled'] ?? 1,
          'created_at': now,
          'updated_at': now,
        });
      }

      // 2.3 appCategory 规则 → 迁移该分类下所有 app 到 monitored_apps
      // 先检查 app_categories 表是否存在
      final tableCheck = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='app_categories'",
      );
      if (tableCheck.isNotEmpty) {
        final categoryRules = await db.query(
          'rules',
          where: 'rule_type = ?',
          whereArgs: ['app_category'],
        );
        for (final rule in categoryRules) {
          final category = rule['target'] as String?;
          if (category == null) continue;

          // 查找该分类下的所有 app
          final appsInCategory = await db.query(
            'app_categories',
            where: 'category = ?',
            whereArgs: [category],
          );

          for (final app in appsInCategory) {
            final packageName = app['package_name'] as String?;
            if (packageName == null) continue;

            // 检查是否已存在（避免重复）
            final existing = await db.query(
              'monitored_apps',
              where: 'package_name = ?',
              whereArgs: [packageName],
            );
            if (existing.isNotEmpty) continue;

            final limitMinutes = rule['weekday_limit'] as int?;

            await db.insert('monitored_apps', {
              'package_name': packageName,
              'app_name': app['app_name'],
              'daily_limit_minutes': limitMinutes,
              'category': category,
              'enabled': rule['enabled'] ?? 1,
              'created_at': now,
              'updated_at': now,
            });
          }
        }
      }

      // 3. 清理旧的规则类型（保留 totalTime）
      await db.delete(
        'rules',
        where: 'rule_type IN (?, ?, ?)',
        whereArgs: ['time_block', 'app_single', 'app_category'],
      );

      // 4. 创建索引
      await db.execute('CREATE INDEX idx_monitored_apps_enabled ON monitored_apps(enabled);');
      await db.execute('CREATE INDEX idx_time_periods_mode ON time_periods(mode);');
      await db.execute('CREATE INDEX idx_time_periods_enabled ON time_periods(enabled);');
      await db.execute('CREATE INDEX idx_continuous_session_date ON continuous_usage_sessions(session_date);');
      await db.execute('CREATE INDEX idx_continuous_session_active ON continuous_usage_sessions(is_active);');
    });
  }
}
```

### 6.3 回滚策略

如果 v3 版本出现严重问题，用户可以：
1. 卸载重装应用（清空所有数据）
2. 使用设置中的"重置所有规则"功能
3. 从备份恢复（如之前导出过 CSV）
```

---

## 7. 实现计划

### Phase 1: 数据层（预计 2-3 小时）

1. 定义数据模型 (`monitored_app.dart`, `time_period.dart`)
2. 实现 DAO (`monitored_app_dao.dart`, `time_period_dao.dart`)
3. 实现数据库迁移
4. 定义 Provider

### Phase 2: 服务层（预计 2-3 小时）

5. 实现连续使用监控服务
6. 重构规则检查服务

### Phase 3: UI 层（预计 4-5 小时）

7. 实现时间段设置 Tab
8. 实现应用管理 Tab + 应用选择页面
9. 实现连续使用 Tab
10. 重构主页面为 Tab 布局

### Phase 4: 集成测试（预计 1-2 小时）

11. 端到端测试
12. 边界情况处理

---

## 8. 验收标准

### 8.1 功能验收

- [ ] 未设置的 app 不受任何限制，不计入时间统计
- [ ] 可以添加/编辑/删除时间段规则
- [ ] 时间段支持跨天（如 22:00-06:00）
- [ ] 可以添加/编辑/删除被监控的 app
- [ ] 可以设置单个 app 的每日时间限制
- [ ] 连续使用限制开关和时长设置正常工作
- [ ] 连续使用提醒弹窗可拖动
- [ ] 强制休息机制正常工作
- [ ] 强制休息优先级高于时间段规则

### 8.2 数据迁移验收

- [ ] 现有 timeBlock 规则正确迁移到 time_periods
- [ ] 现有 appSingle 规则正确迁移到 monitored_apps
- [ ] 现有 appCategory 规则正确迁移（该分类下所有 app 被监控）
- [ ] 无效数据（NULL 字段）被正确跳过
- [ ] 迁移后数据完整性

### 8.3 连续使用会话验收

- [ ] 会话在被监控 app 间切换时保持
- [ ] 会话在切换到非监控 app 超过 2 分钟后中断
- [ ] 会话在屏幕关闭超过 5 分钟后中断
- [ ] 会话在 00:00 自动重置
- [ ] 应用重启后会话状态正确恢复

### 8.4 UI 验收

- [ ] 三个 Tab 切换流畅
- [ ] 时间段设置界面直观易用
- [ ] 应用选择界面正确过滤系统应用
- [ ] 应用选择界面搜索功能正常
- [ ] 连续使用设置界面简洁明了
- [ ] 提醒弹窗显示正确的时间倒计时
