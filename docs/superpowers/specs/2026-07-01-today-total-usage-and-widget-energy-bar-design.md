# 今日总时长展示与连续使用 widget 能量条改造设计

**日期**: 2026-07-01
**状态**: 已认可，待实现

## 背景与目标

qiaoqiao_companion 是一款帮助学龄前/低年级儿童管理 app 使用时长、培养自觉、避免沉迷的应用。

当前存在两个展示问题：

1. **全日总时长未展示**：首页 [_QiaoqiaoCard](../../../qiaoqiao_companion/lib/features/home/presentation/home_page.dart) 硬编码 `remainingTime: Duration.zero`，规则页 [_TimeRulesCard](../../../qiaoqiao_companion/lib/features/rules/presentation/rules_page.dart) 只显示限额不显示已用。数据其实已由 [todayUsageProvider](../../../qiaoqiao_companion/lib/shared/providers/today_usage_provider.dart) 计算，只是没接线到 UI。
2. **连续使用 widget 是强展示**：原生右上角圆形 widget 始终显示 MM:SS 倒计时，对学龄前儿童是焦虑源（秒级跳动）和"凑满"诱惑。

### 设计理念

基于"低龄儿童应弱化数字、强化情境"的原则，采取**混合方案**：
- **全日层（长时域）**：透明展示已用时长（数字不跳，诱惑弱），让家长和小孩都能看到累积情况
- **连续层（短时域）**：弱化为视觉化能量条，仅在临界点（剩余 ≤5 分钟）才显示数字倒计时

### 统计口径（已确认）

**全日总时长 = 今日"添加了规则的应用"（restrictedPackages）的使用时长之和**。

不统计未加监控的 app。这与当前限额执行逻辑的口径一致，由 [TodayUsageNotifier.loadToday()](../../../qiaoqiao_companion/lib/shared/providers/today_usage_provider.dart) 的 `getTotalDurationByPackageNamesAndDate(restrictedPackages, today)` 实现。

注：系统中还存在 [ConfigSyncService._syncTodayUsageFromSystem()](../../../qiaoqiao_companion/lib/core/services/config_sync_service.dart) 写入 `daily_stats.totalSeconds`（全量所有 app），但该数据不用于限额判定，本设计也不使用它。

## 架构总览

两个独立但风格统一的改动：

| 改动 | 层 | 对象 | 说明 |
|------|----|------|------|
| A. 全日已用时长 | Flutter | [rules_page.dart](../../../qiaoqiao_companion/lib/features/rules/presentation/rules_page.dart) _TimeRulesCard | 限额旁新增"今日已用"区块（进度条+文字） |
| B. 连续使用 widget | 原生 Kotlin | [OverlayChannel.kt](../../../qiaoqiao_companion/android/app/src/main/kotlin/com/qiaoqiao/qiaoqiao_companion/channels/OverlayChannel.kt) createCountdownWidgetView + startCountdownWidgetAnimation | 圆形+外环能量条，≤5 分钟叠加 MM:SS |

**关键边界**：B 的 5 分钟以下逻辑（3min/2min 提醒、到 0 锁定、lock overlay、MethodChannel 协议、widget 出现/消失时机）**全部保持不变**。

## A. 全日已用时长（Flutter 侧）

### 数据流（全部复用现有链路，无新增 provider）

```
ConfigSyncService.refreshTodayUsage()  (每5分钟同步系统数据)
  └─ _syncTodayUsageFromSystem()
       └─ daily_stats 表写入 totalSeconds（全量，已存在）
       └─ app_usage_records 表写入各 app 记录（已存在）
  └─ todayUsageProvider.notifier.loadToday()
       └─ AppUsageDao.getTotalDurationByPackageNamesAndDate(restrictedPackages, today)
            → 返回"仅监控应用"的总秒数（口径已确认）
       └─ state.totalDurationSeconds 更新
            → _TimeRulesCard 消费 state 展示
```

### 展示改造

改造 [_TimeRulesCard](../../../qiaoqiao_companion/lib/features/rules/presentation/rules_page.dart)。

**现状结构**：
```
时间限制
  [☀] 工作日每日限额          2小时
  ─────────────────────
  [📅] 周末每日限额            3小时
```

**改造后**：
```
时间限制
  [☀] 工作日每日限额          2小时
  ─────────────────────
  [📅] 周末每日限额            3小时
  ─────────────────────
  今日已用          45 / 120 分钟
  [████████░░░░░░░░░░] 37%
```

### 具体改动点

1. `_TimeRulesCard` 从 `ConsumerWidget` 读 `todayUsageProvider`（已有 provider，30 秒自动刷新）
2. 在两个限额项之后，新增"今日已用"区块：
   - 文字行：`今日已用` + `{已用分钟} / {当前生效限额分钟} 分钟`
   - 进度条：使用项目现有 [gradient_progress.dart](../../../qiaoqiao_companion/lib/shared/widgets/design_system/gradient_progress.dart) 组件，填充比例 = 已用/限额（clamp 0~1）
3. **限额取值**：根据今天是否周末，取 `weekdayLimitMinutes` 或 `weekendLimitMinutes`（与执行逻辑一致）
4. **进度条配色（百分比阈值）**：
   - <80%：主题色
   - ≥80%：警告色
   - ≥100%：错误色（进度条 clamp 到 100%）
   - 与 hourly timeline 的三档配色风格一致
5. **限额未启用时**：若 `totalRule?.enabled != true`，**隐藏整个"今日已用"区块**（没有限额就没参照意义）

### 不改的部分

- 首页巧巧卡 `remainingTime: Duration.zero` 保持不动（首页保留纯角色化体验，不显示数字）
- `todayUsageProvider` 的统计逻辑不动（口径已确认正确）
- 不新增 provider，直接复用 `todayUsageProvider`

### 错误处理

- `todayUsageProvider` 是 `StateNotifierProvider`（同步），不会有 async 错误态，无需新增错误处理
- `restrictedPackages` 为空时：`totalDurationSeconds = 0`，进度条显示 0%，文字"0 / 120 分钟"——正常展示，不特殊处理
- 加载失败时：保持现状（异常冒泡到 provider），不阻塞限额项展示（限额项数据来自独立的 `rulesProvider`）

## B. 连续使用 widget（原生 Kotlin 侧）

### 改造对象

[OverlayChannel.kt](../../../qiaoqiao_companion/android/app/src/main/kotlin/com/qiaoqiao/qiaoqiao_companion/channels/OverlayChannel.kt) 的：
- `createCountdownWidgetView`（L720）
- `startCountdownWidgetAnimation`（L794）

### 视觉形态

替换现有"🐻 + MM:SS"横条，改为圆形 widget + 外环能量条。

**剩余 >5 分钟**：
```
    ╭─────────╮
   ╱  ●●●●●●  ╲     ← 外环：渐变能量条（递增填充）
  │  ●●●●●●●●  │
  │     🐻      │     ← 中央：小熊头像（不变）
  │  ●●●●●●●●  │
   ╲  ●●●●●●  ╱
    ╰─────────╯
```

**剩余 ≤5 分钟**：
```
    ╭─────────╮
   ╱  ●●●●●●  ╲
  │  ●●●●●●●●  │
  │  🐻 04:32  │     ← 中央叠加 MM:SS
  │  ●●●●●●●●  │
   ╲  ●●●●●●  ╱
    ╰─────────╯
```

### 能量条逻辑（递增型，使用强度增加）

| 已用比例 | 能量条填充 | 颜色 | 中央内容 |
|---------|-----------|------|---------|
| 0%–50% | 0%–50% | 绿 `#4CAF50` | 🐻 |
| 50%–80% | 50%–80% | 黄 `#FFC107` | 🐻 |
| 80%–100% | 80%–100% | 红 `#F44336` | 🐻 |
| 剩余 ≤5分钟（即已用 ≥83.3%，以30分钟限额为例） | 继续递增至100% | 红 | 🐻 + MM:SS |

能量条始终**递增**（已用比例增加→填充越多），即使在 ≤5分钟阶段也继续向 100% 填充，不递减。只有中央叠加的 MM:SS 倒计时是递减的。

**颜色过渡**：段内用 `ArgbEvaluator` 平滑过渡（绿渐变到黄渐变到红），不做硬切。

### 实现要点

1. **视图改造**：`createCountdownWidgetView` 用自定义 `View` 绘制圆形 + 外环（`SweepGradient` 或 `Canvas.drawArc`），中央保留 🐻 emoji `TextView`
2. **倒计时文字**：新增 `countdownTextView`，默认 `GONE`；剩余 ≤300 秒时设为 `VISIBLE` 并显示 `formatCountdownTime(remainingSec)`
3. **动画 ticker 改造**（[startCountdownWidgetAnimation L811-845](../../../qiaoqiao_companion/android/app/src/main/kotlin/com/qiaoqiao/qiaoqiao_companion/channels/OverlayChannel.kt)）：
   - 每个 tick 计算 `progress = elapsed / total`（clamp 0~1）
   - `invalidate()` 触发外环重绘（颜色用 `ArgbEvaluator` 平滑过渡）
   - `if (remainingSec <= 300 && remainingSec > 0)` → 显示倒计时文字
   - **3min/2min 提醒、到 0 锁定、`showLockOverlayFromFallback()`、`notifyCountdownEnded()` 全部不动**
4. **能量条更新频率**：外环每秒重绘一次（跟 ticker 对齐），无需 60fps 动画，避免性能开销
5. **尺寸**：圆形直径约 56dp，位置 `Gravity.TOP or Gravity.END, x=32, y=100` 不变

### 保持不变的部分（边界）

- `showCountdownWidget` / `hideCountdownWidget` 的调用时机、MethodChannel 协议
- `notified3min` / `notified2min` 标志和触发逻辑
- `showLockOverlayFromFallback()` 锁定弹窗
- Widget 的拖动监听 `setupDragListener`
- Widget 出现/消失时机（由 EnforcementEngine 控制）

### 错误处理

- 自定义 View 绘制异常：在 `onDraw` 外层加 try-catch，失败时回退到只显示 🐻 + MM:SS（退化成类似现状的展示），保证锁定逻辑不受影响
- `ArgbEvaluator` / `SweepGradient` 从 API 1 起支持，无兼容问题
- Widget 已隐藏但 ticker 仍在跑：现有 `countdownCancelled` 标志已处理，不动

## 测试策略

### A. 全日已用时长（Flutter widget 测试）

参考现有 [widget_test.dart](../../../qiaoqiao_companion/test/widget_test.dart) 风格，mock `todayUsageProvider` 和 `rulesProvider`：

| 用例 | 输入 | 期望 |
|------|------|------|
| 1 | 限额启用，已用 45min/限额 120min | 显示"45 / 120 分钟"，进度条 37.5%，主题色 |
| 2 | 已用 100min/限额 120min（83%） | 进度条警告色 |
| 3 | 已用 130min/限额 120min（108%） | 进度条错误色，clamp 到 100% |
| 4 | 限额未启用 | "今日已用"区块不渲染 |
| 5 | 周末 | 限额取 `weekendLimitMinutes` |

### B. 连续使用 widget（原生单元测试）

扩展 [WidgetManagerTest.kt](../../../qiaoqiao_companion/android/app/src/test/java/com/qiaoqiao/qiaoqiao_companion/monitor/WidgetManagerTest.kt)。建议把颜色计算抽成纯函数便于测试：

| 用例 | 输入 | 期望 |
|------|------|------|
| 1 | total=30min, elapsed=15min | progress=0.5，颜色≈黄色，无倒计时文字 |
| 2 | remaining=4min | 显示"04:00"，颜色红色 |
| 3 | remaining=3min | `notifyCountdownAlert("3min")` 被调用（验证现有逻辑未被破坏） |
| 4 | remaining=0 | `showLockOverlayFromFallback()` 被调用 |
| 5 | progress=0.65 | 颜色介于黄和红之间（验证 `ArgbEvaluator` 生效） |

### 手动验证（平板 8711b87c）

- **A**：打开规则页，确认"今日已用"区块出现，进度条与实际使用时长一致；等待 30 秒看是否自动刷新
- **B**：打开监控 app，观察 widget 外环颜色随时间从绿→黄→红平滑过渡；剩余 5 分钟时确认 MM:SS 出现；剩余 3/2 分钟确认提醒弹出；到 0 确认锁定

## 范围外（YAGNI）

- 不改首页巧巧卡的 `remainingTime` 接线（保持硬编码 `Duration.zero`）
- 不改 `todayUsageProvider` 的统计口径
- 不改 daily_stats 表的 totalSeconds 用途
- 不改连续使用的设置项（limitMinutes/restMinutes/resetAfterRestMinutes）
- 不改 lock overlay 的视觉与逻辑
- 不新增"角色精力"角色化反馈系统（本次只做能量条，不做巧巧表情变化）
