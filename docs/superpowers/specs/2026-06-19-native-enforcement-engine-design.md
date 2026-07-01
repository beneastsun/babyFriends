# 原生监控引擎重构设计

> 日期：2026-06-19
> 状态：草稿
> 范围：核心链路（监控 + 限制 + 倒计时 + 弹窗），不涉及后台保活和数据同步

## 1. 背景与问题

### 1.1 当前架构

当前 App 限制功能由三层组成：

- **Flutter 层**：`UsageMonitorService`（1282 行）每 30 秒轮询前台 App，做规则判定，通过 MethodChannel 指令原生层显示/隐藏 UI
- **原生 Kotlin 层**：`OverlayChannel` / `NativeOverlayManager` 接收 Flutter 指令执行 UI 操作；`MonitorForegroundService` 在 Flutter 引擎死亡时独立运行原生监控
- **通信层**：MethodChannel 异步通信，有 100-500ms 延迟

### 1.2 核心问题

| # | 问题 | 根因 |
|---|------|------|
| 1 | Widget 弹出/消失时机混乱 | Flutter 30s 轮询 + 内存标志与原生侧状态不同步 |
| 2 | 倒计时不准确 | Flutter 挂钟 vs 原生挂钟 vs session 累加三条路径漂移 |
| 3 | 多程序控制冲突 | `_syncWidgetStateWithNative` 修复逻辑引入更多竞态 |
| 4 | 切换 App 时 Widget 闪退 | `shouldTrackCurrent=false` 立即隐藏，下次轮询才恢复 |
| 5 | 提醒弹窗覆盖 Widget | 全屏提醒弹窗和 countdown widget 互相抢占 |
| 6 | 删除纹纹后状态丢失 | Flutter 引擎死亡，原生侧恢复依赖 Flutter 同步 |

**核心矛盾**：Flutter 层做判定，原生层做执行，两者通过 MethodChannel 异步通信 → 状态永远不同步。

## 2. 设计目标

1. **准确**：倒计时使用唯一挂钟基准，消除三条计时路径漂移
2. **稳定**：Widget 显示/隐藏逻辑在原生进程内闭环，不依赖 Flutter 引擎
3. **及时**：轮询间隔从 30s 降至 5s，状态更新更及时
4. **不卡顿**：消除 Flutter↔原生跨进程通信延迟

## 3. 新架构

### 3.1 总体架构

```
┌─────────────────────────────────────────────────────┐
│  Flutter 层（配置面板 + 展示层）                       │
│                                                       │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────┐ │
│  │ 规则设置 UI   │  │ 使用报告 UI   │  │ 积分/成就  │ │
│  └──────┬───────┘  └──────────────┘  └────────────┘ │
│         │ 写入 DB                                     │
├─────────┼───────────────────────────────────────────┤
│         ▼                                             │
│  ┌─────────────────────────────────────────────┐     │
│  │  SQLite 数据库（共享状态层）                    │     │
│  │  rules / monitored_apps / daily_stats        │     │
│  │  continuous_usage_sessions / app_usage_records│     │
│  └─────────────────────┬───────────────────────┘     │
│                        │ 读取                          │
├────────────────────────┼─────────────────────────────┤
│  原生层（监控引擎）      ▼                             │
│  ┌─────────────────────────────────────────────┐     │
│  │  EnforcementEngine                           │     │
│  │  ┌─────────────┐ ┌──────────────────────┐   │     │
│  │  │ RuleEvaluator│ │ ContinuousUsageTracker│   │     │
│  │  └─────────────┘ └──────────────────────┘   │     │
│  │  ┌─────────────┐ ┌──────────────────────┐   │     │
│  │  │ WidgetManager│ │ OverlayManager       │   │     │
│  │  └─────────────┘ └──────────────────────┘   │     │
│  └─────────────────────────────────────────────┘     │
│         │ 5s 轮询 + 挂钟计时                           │
│         ▼                                             │
│  ┌─────────────────────────────────────────────┐     │
│  │  UI 执行（countdown widget / lock overlay）   │     │
│  └─────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────┘
```

### 3.2 关键设计决策

#### 决策 1：原生始终做判定和执行

当前：原生轮询 → 发 MethodChannel → Flutter 判定 → 发 MethodChannel → 原生显示
新：原生轮询 → 原生判定 → 原生显示（零 MethodChannel 延迟）

不再根据 `MainActivity.isFlutterAlive` 分支逻辑。Flutter 是否存活不影响监控引擎运行。

#### 决策 2：消除三条独立计时路径

当前：
- 路径 A：原生 countdown widget 的挂钟倒计时
- 路径 B：Flutter `_checkContinuousUsageAlerts` 的 session 累加
- 路径 C：原生 `checkActiveCountdown` 的 session 估算

新：**只有一条路径** — 原生 `ContinuousUsageTracker` 每 5 秒累加 session 时间；countdown widget 使用挂钟（从 DB 读取 `countdownStartedAt + countdownTotalSeconds` 计算）。

#### 决策 3：Widget 显示/隐藏规则简化

| 事件 | 旧逻辑 | 新逻辑 |
|------|--------|--------|
| 进入被监控 App | Flutter 轮询检测 → 显示 | 原生轮询检测 → 显示 |
| 离开被监控 App | 立即隐藏 → 等 30s 再恢复 | **延迟确认**：连续 2 次轮询（10s）确认不在监控 App → 才隐藏 |
| 短暂切换（Home 键） | 立即隐藏 → 闪退 | 延迟确认 → 不闪退 |
| Widget 被系统回收 | Flutter 标志仍 true → 死锁 | 原生 `View.OnAttachStateChangeListener` 检测 → 立即重建 |
| 倒计时结束 | 原生通知 Flutter → Flutter 显示 lock | 原生直接显示 lock overlay |

#### 决策 4：提醒弹窗不再覆盖 Widget

当前 3min/2min 提醒会显示全屏弹窗，覆盖 countdown widget。
新：**countdown widget 自身变色 + 振动提醒**，不再弹全屏覆盖。只有倒计时结束才弹 lock overlay。

| 阈值 | 旧行为 | 新行为 |
|------|--------|--------|
| 剩余 5 分钟 | 全屏温和提醒弹窗 | Widget 变黄色 + 振动 |
| 剩余 3 分钟 | 全屏提醒弹窗（覆盖 Widget） | Widget 变橙色 + 振动 |
| 剩余 2 分钟 | 全屏警告弹窗（覆盖 Widget） | Widget 变红色 + 振动 |
| 倒计时归零 | 原生通知 Flutter → Flutter 显示 lock | 原生直接显示 lock overlay |

## 4. EnforcementEngine 状态机

### 4.1 状态定义

```
┌───────┐  进入监控App   ┌───────────┐  剩余≤5min  ┌───────────┐
│ IDLE  │──────────────→│ MONITORING │──────────→│ COUNTDOWN │
└───┬───┘               └─────┬─────┘            └─────┬─────┘
    ↑                         │                        │
    │  离开监控App(确认)        │ 剩余≤0                 │ 倒计时归零
    │                         ▼                        ▼
    │                   ┌───────────┐            ┌───────────┐
    │                   │  AT_LIMIT │──────────→│   REST    │
    │                   └───────────┘            └─────┬─────┘
    │                                                  │
    │                  休息结束                          │
    └──────────────────────────────────────────────────┘
```

每个状态有明确职责：

| 状态 | 含义 | UI 表现 |
|------|------|---------|
| IDLE | 无监控 App 在前台 | 无 Widget、无 overlay |
| MONITORING | 监控 App 在前台，未到倒计时阈值 | 显示 stopwatch widget（已用时长） |
| COUNTDOWN | 剩余时间 ≤ 5 分钟 | 显示 countdown widget，随阈值变色 |
| AT_LIMIT | 时间到，准备强制休息 | 短暂停留，自动进入 REST |
| REST | 强制休息中 | 显示 lock overlay（带休息倒计时） |

### 4.2 状态转换规则

```
IDLE → MONITORING:  前台 App ∈ monitored_apps && 不在任何阻断规则中
MONITORING → COUNTDOWN:  continuousUsageTracker.remainingSeconds <= 5min
MONITORING → IDLE:  连续 2 次轮询确认前台 App 不在监控列表
COUNTDOWN → REST:  countdown 归零 (remainingSeconds <= 0)
COUNTDOWN → IDLE:  连续 2 次轮询确认前台 App 不在监控列表
REST → IDLE:  restEndTime <= now（休息结束）
AT_LIMIT → REST:  自动，无延迟
```

### 4.3 每次轮询的主循环

```kotlin
fun onPoll(now: Long, foregroundApp: String?) {
    // 0. 如果处于 REST 状态，只检查休息是否结束
    if (state == REST) {
        val remaining = session.restEndTime - now
        if (remaining <= 0) {
            endRest()
            state = IDLE
        } else {
            overlayManager.updateRestCountdown(remaining / 1000)
        }
        return
    }

    // 1. 检查前台 App 变化
    updateForegroundTracking(foregroundApp, now)

    // 2. 如果没有监控 App 在前台
    if (!isTrackingMonitoredApp) {
        handleAppLeft(now)
        return
    }

    // 3. 规则检查（时间段、总时间、单 App 限制）
    val ruleResult = ruleEvaluator.evaluate(foregroundApp, now)
    if (ruleResult.blocked) {
        showLockAndRest(ruleResult.reason, foregroundApp)
        state = REST
        return
    }

    // 4. 连续使用跟踪
    val usageResult = continuousUsageTracker.update(foregroundApp, now)

    when (state) {
        IDLE -> {
            if (usageResult.shouldShowStopwatch) {
                widgetManager.showStopwatch(usageResult.usedSeconds)
                state = MONITORING
            }
        }
        MONITORING -> {
            widgetManager.updateStopwatch(usageResult.usedSeconds)
            if (usageResult.shouldShowCountdown) {
                widgetManager.switchToCountdown(usageResult.remainingSeconds)
                state = COUNTDOWN
            }
        }
        COUNTDOWN -> {
            // 挂钟校准：从 DB 的 countdownStartedAt + countdownTotalSeconds 计算
            val remaining = calculateRemainingFromWallClock(now)
            widgetManager.updateCountdown(remaining)
            updateCountdownColor(remaining)
            if (remaining <= 0) {
                triggerRest(now)
            }
        }
    }

    // 5. AppLock 检查
    if (AppLockManager.shouldShowLock(context)) {
        AppLockOverlayActivity.start(context)
    }
}
```

## 5. Flutter 层简化

### 5.1 UsageMonitorService 简化为 ConfigSyncService

`UsageMonitorService`（1282 行）→ `ConfigSyncService`（~200 行）

| 旧职责 | 新归属 |
|--------|--------|
| 30s 轮询前台 App | **删除**（原生 5s 轮询） |
| 规则检查 → 提醒/锁定 | **删除**（原生 EnforcementEngine） |
| Widget 显示/隐藏 | **删除**（原生 WidgetManager） |
| 连续使用跟踪 | **删除**（原生 ContinuousUsageTracker） |
| `_syncWidgetStateWithNative` | **删除**（不再需要同步） |
| `_checkContinuousUsageAlerts` | **删除**（原生处理） |
| `_checkAndTriggerRest` | **删除**（原生处理） |
| `_switchToCountdownMode` | **删除**（原生处理） |
| `_handleCountdownEnded` | **删除**（原生处理） |
| DB 同步使用数据 | **保留**（5 分钟全量同步，用于报告展示） |
| Provider 刷新 | **保留**（从 DB 读取原生写入的数据） |
| AppLockProvider | **保留**（通过 MethodChannel 读写原生 SharedPreferences） |

### 5.2 保留的 Flutter 模块

1. **ConfigSyncService**：5 分钟全量同步 `UsageStatsManager` 数据 → DB（用于报告展示）
2. **规则/监控列表设置 UI**：写入 DB，原生侧缓存刷新
3. **使用报告 UI**：从 DB 读取原生写入的数据
4. **积分/成就系统**：不受本次重构影响
5. **Provider 层**：从 DB 读取数据供 UI 使用

### 5.3 删除的 Flutter 模块

1. `UsageMonitorService` 中的监控/规则/弹窗逻辑
2. `OverlayStateManager`（原生 `EnforcementEngine` 自带状态管理）
3. `ReminderService`（原生 Widget 变色替代提醒弹窗）
4. `RuleCheckerService`（原生 `RuleEvaluator` 替代）
5. `ContinuousUsageService`（原生 `ContinuousUsageTracker` 替代）
6. `OverlayService` 中与监控相关的 MethodChannel 方法

## 6. 原生 EnforcementEngine 组件设计

### 6.1 EnforcementEngine

位置：`android/.../monitor/EnforcementEngine.kt`

职责：状态机主控，协调各子模块

```kotlin
class EnforcementEngine(private val context: Context) {
    private val repository = NativeRuleRepository(context)
    private val ruleEvaluator = RuleEvaluator(repository)
    private val usageTracker = ContinuousUsageTracker(repository)
    private val widgetManager = WidgetManager(context)
    private val overlayManager = NativeOverlayManager(context)

    var state: EngineState = IDLE
        private set

    // 延迟确认：连续离开计数
    private var leaveConfirmCount = 0
    private val LEAVE_CONFIRM_THRESHOLD = 2  // 2 次 = 10 秒

    fun onPoll(now: Long, foregroundApp: String?) { /* 见 4.3 */ }

    fun restoreFromDB(now: Long) { /* 见 8.2 */ }

    fun persistStateBeforeDeath() { /* 见 8.1 */ }

    fun destroy() {
        widgetManager.destroy()
        overlayManager.destroy()
    }
}

enum class EngineState {
    IDLE, MONITORING, COUNTDOWN, AT_LIMIT, REST
}
```

### 6.2 RuleEvaluator

位置：`android/.../monitor/RuleEvaluator.kt`（基于现有 `NativeRuleChecker` 增强）

职责：纯函数式规则判定，无状态

```kotlin
class RuleEvaluator(private val repository: NativeRuleRepository) {
    data class EvalResult(
        val blocked: Boolean,
        val reason: String = "",
        val ruleType: String = ""
    )

    fun evaluate(packageName: String, now: Long): EvalResult {
        // 1. 强制休息检查
        val restRemaining = repository.getActiveRestRemainingSeconds()
        if (restRemaining > 0) return EvalResult(true, "正在休息中", "forced_rest")

        // 2. 是否在监控列表
        val monitoredApps = repository.getMonitoredApps()
        val app = monitoredApps.find { it.packageName == packageName }
            ?: return EvalResult(false)

        // 3. 时间段规则
        val timePeriodResult = checkTimePeriods(now)
        if (timePeriodResult.blocked) return timePeriodResult

        // 4. 总时间限制
        val totalTimeResult = checkTotalTime(monitoredApps.map { it.packageName }.toSet(), now)
        if (totalTimeResult.blocked) return totalTimeResult

        // 5. 单 App 每日限制
        if (app.dailyLimitMinutes != null && app.dailyLimitMinutes > 0) {
            val usedMinutes = repository.getTodayAppUsageMs(packageName) / 60_000
            if (usedMinutes >= app.dailyLimitMinutes) {
                return EvalResult(true, "今日使用已达上限", "app_daily_limit")
            }
        }

        return EvalResult(false)
    }
}
```

### 6.3 ContinuousUsageTracker

位置：`android/.../monitor/ContinuousUsageTracker.kt`（基于现有同名类增强）

职责：连续使用时间累加、倒计时阈值判断

保持现有 `NativeContinuousUsageTracker` 的核心逻辑，增加：

1. **挂钟持久化**：进入 COUNTDOWN 状态时写入 `countdownStartedAt` + `countdownTotalSeconds` 到 DB
2. **延迟确认离开**：不再在首次检测到非监控 App 时立即停用会话，改用 `leaveConfirmCount` 计数

### 6.4 WidgetManager

位置：`android/.../monitor/WidgetManager.kt`（新增）

职责：统一管理 countdown widget 和 stopwatch widget 的显示/隐藏/更新

```kotlin
class WidgetManager(private val context: Context) {
    private val overlayManager = NativeOverlayManager(context)

    fun showStopwatch(usedSeconds: Long) {
        overlayManager.showStopwatchWidget(usedSeconds)
    }

    fun updateStopwatch(usedSeconds: Long) {
        overlayManager.updateStopwatchTime(usedSeconds)
    }

    fun switchToCountdown(remainingSeconds: Long) {
        overlayManager.hideStopwatchWidget()
        overlayManager.showCountdownOverlayWithAlerts(remainingSeconds, ...)
    }

    fun updateCountdown(remainingSeconds: Long) {
        overlayManager.updateCountdownTime(remainingSeconds)
    }

    fun updateCountdownColor(remainingSeconds: Long) {
        // ≤5min 黄色, ≤3min 橙色, ≤2min 红色
        overlayManager.setCountdownColor(colorForRemaining(remainingSeconds))
    }

    fun hideAll() {
        overlayManager.hideCountdownOverlay()
        overlayManager.hideStopwatchWidget()
    }

    fun isCountdownShowing(): Boolean = overlayManager.isCountdownShowing()
    fun isStopwatchShowing(): Boolean = overlayManager.isStopwatchShowing()
}
```

**关键改进**：countdown widget 使用 `View.OnAttachStateChangeListener` 检测系统回收：

```kotlin
countdownWidgetView?.addOnAttachStateChangeListener(object : View.OnAttachStateChangeListener {
    override fun onViewDetachedFromWindow(v: View) {
        needsRebuild = true
    }
    override fun onViewAttachedToWindow(v: View) {}
})
```

每次 5s 轮询时检查：如果引擎状态是 COUNTDOWN 但 widget 不在显示，立即重建。

### 6.5 NativeOverlayManager 增强

在现有 `NativeOverlayManager` 基础上增加：

1. **Stopwatch widget**：显示已用时长（非倒计时状态下的悬浮窗）
2. **Countdown 颜色变更**：`setCountdownColor(color: Int)` 方法
3. **振动反馈**：阈值变化时振动提醒
4. **`OnAttachStateChangeListener`**：检测 View 被系统回收

## 7. 数据流

### 7.1 配置变更流程（Flutter → DB → 原生）

```
Flutter 规则设置 UI → 写入 SQLite → 原生 5s 轮询时缓存过期 → 重新读取
```

原生侧缓存刷新策略：`NativeRuleRepository` 的缓存 TTL 设为 30 秒。配置变更后最多 30 秒生效。

如果需要即时生效，Flutter 写入 DB 后可通过 MethodChannel 通知原生清除缓存：

```dart
// Flutter 侧
await ServiceChannel.updateNotification(title: 'CONFIG_CHANGED', message: '');
```

原生侧收到后清除 `NativeRuleRepository` 缓存。

### 7.2 监控数据流程（原生 → DB → Flutter）

```
原生 ContinuousUsageTracker 累加 → 写入 continuous_usage_sessions
原生 RuleEvaluator 判定 → 触发 Widget/Overlay
原生使用数据累加 → 写入 app_usage_records / daily_stats

Flutter Provider 定期读取 DB → 展示报告
```

### 7.3 挂钟时间基准

所有计时使用 `System.currentTimeMillis()`（挂钟），关键持久化字段：

| 字段 | 含义 | 用途 |
|------|------|------|
| `countdown_started_at` | 倒计时开始时的挂钟时间戳（ms） | 挂钟恢复倒计时 |
| `countdown_total_seconds` | 倒计时总秒数 | `remaining = total - (now - startedAt) / 1000` |
| `rest_end_time` | 休息结束的挂钟时间戳（ms） | `remaining = restEndTime - now` |
| `last_activity_time` | 最后活动挂钟时间戳（ms） | 会话恢复判定 |

## 8. 删除纹纹场景处理

### 8.1 onTaskRemoved 时持久化状态

```kotlin
override fun onTaskRemoved(rootIntent: Intent?) {
    // 1. 持久化当前监控状态到 DB
    engine.persistStateBeforeDeath()

    // 2. 弹 AppLock（趁进程还活着）
    if (AppLockManager.isLockEnabled(applicationContext)) {
        AppLockOverlayActivity.start(applicationContext)
    }

    // 3. 自重启 + 冗余闹钟（保持不变）
    scheduleRedundantAlarms(applicationContext)
    super.onTaskRemoved(rootIntent)
}
```

`persistStateBeforeDeath()` 确保当前倒计时进度、休息状态写入 DB。

### 8.2 服务重启后从 DB 恢复状态

```kotlin
fun restoreFromDB(now: Long) {
    val session = repository.getActiveContinuousSession()
    if (session == null) { state = IDLE; return }

    // 正在休息中？
    if (session.restEndTime != null && session.restEndTime > now) {
        state = REST
        val remaining = (session.restEndTime - now) / 1000
        overlayManager.showLockOverlay("正在休息中...", "", remaining.toInt())
        return
    }

    // 有倒计时？
    if (session.countdownStartedAt != null && session.countdownTotalSeconds != null) {
        val remaining = session.countdownTotalSeconds - (now - session.countdownStartedAt) / 1000
        if (remaining > 0) {
            state = COUNTDOWN
            widgetManager.switchToCountdown(remaining)
            return
        }
        // 倒计时已过期 → 触发强制休息
        triggerRest(now)
        return
    }

    // 正常监控中 → 等下一次轮询检测到前台 App
    state = IDLE
}
```

### 8.3 AppLock 检查融入轮询

每次 5 秒轮询末尾检查 `AppLockManager.shouldShowLock()`，与规则检查统一执行，不再只在 `onTaskRemoved` 和 `GuardService` 中检查。

### 8.4 保活链路（不重构）

以下保活机制保持不变：

- `MonitorForegroundService`（前台服务 + START_STICKY）
- `GuardService`（独立进程守护）
- `AlarmReceiver` + `AlarmProxyActivity`（闹钟唤醒）
- `KeepAliveWorker`（WorkManager 周期任务）
- `ServiceRestartReceiver`（广播重启）

## 9. MonitorForegroundService 简化

### 9.1 当前轮询逻辑（复杂）

当前 `monitorRunnable` 有两条分支：
- `isFlutterAlive = true`：原生只清理残留，所有 UI 由 Flutter 处理
- `isFlutterAlive = false`：原生接管所有 UI

还有步骤 A（倒计时恢复）和步骤 B（规则检查）的复杂交互。

### 9.2 新轮询逻辑（简化）

```kotlin
private val monitorRunnable = object : Runnable {
    override fun run() {
        try {
            val now = System.currentTimeMillis()
            val foregroundApp = UsageStatsHelper.getCurrentForegroundApp(
                applicationContext, packageName
            )

            // 单一入口，始终由 EnforcementEngine 处理
            engine.onPoll(now, foregroundApp)

            // AppLock 检查
            if (AppLockManager.shouldShowLock(applicationContext)) {
                AppLockOverlayActivity.start(applicationContext)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Monitoring error", e)
        }

        monitorHandler?.postDelayed(this, MONITOR_INTERVAL_MS)  // 5s
    }
}
```

不再需要 `isFlutterAlive` 分支判断。`EnforcementEngine.onPoll()` 内部状态机处理所有逻辑。

### 9.3 服务启动时恢复

```kotlin
private fun startNativeMonitoring() {
    if (engine != null) return

    engine = EnforcementEngine(applicationContext)

    // 从 DB 恢复状态（关键：处理进程被杀重启场景）
    engine!!.restoreFromDB(System.currentTimeMillis())

    monitorHandler = Handler(Looper.getMainLooper())
    monitorHandler?.postDelayed(monitorRunnable, INITIAL_DELAY_MS)
}
```

## 10. 改动范围

### 10.1 原生层改动

| 文件 | 改动类型 | 说明 |
|------|----------|------|
| `EnforcementEngine.kt` | **新增** | 状态机主控 |
| `RuleEvaluator.kt` | **新增** | 从 `NativeRuleChecker` 演化，纯判定 |
| `WidgetManager.kt` | **新增** | Widget 显示/隐藏/更新/颜色管理 |
| `ContinuousUsageTracker.kt` | **修改** | 增加挂钟持久化、延迟确认离开 |
| `NativeOverlayManager.kt` | **修改** | 增加 stopwatch widget、颜色变更、振动、OnAttachStateChangeListener |
| `NativeRuleRepository.kt` | **小改** | 缓存 TTL 调整、增加 stopwatch 相关查询 |
| `MonitorForegroundService.kt` | **简化** | 轮询逻辑简化为 `engine.onPoll()` |
| `OverlayChannel.kt` | **简化** | 删除 Flutter 侧调用的大部分方法，只保留 `isCountdownWidgetShowing` 等查询方法 |

### 10.2 Flutter 层改动

| 文件 | 改动类型 | 说明 |
|------|----------|------|
| `usage_monitor_service.dart` | **大幅简化** → `config_sync_service.dart` | 1282 行 → ~200 行，只保留数据同步 |
| `overlay_state_manager.dart` | **删除** | 原生 EnforcementEngine 自带状态管理 |
| `reminder_service.dart` | **删除** | Widget 变色替代提醒弹窗 |
| `rule_checker_service.dart` | **删除** | 原生 RuleEvaluator 替代 |
| `continuous_usage_service.dart` | **删除** | 原生 ContinuousUsageTracker 替代 |
| `overlay_service.dart` | **简化** | 只保留查询方法 |
| Provider 层 | **小改** | 从 DB 读取数据，不再触发监控逻辑 |

### 10.3 不改动的部分

- 后台保活机制（GuardService、AlarmReceiver、KeepAliveWorker、ServiceRestartReceiver）
- 数据库 Schema（表结构不变）
- 积分/成就系统
- 设置 UI、报告 UI
- AppLockOverlayActivity（密码锁屏 Activity）

## 11. 迁移策略

分三阶段逐步替换，每个阶段独立可测：

### 阶段 1：原生引擎搭建

1. 新增 `EnforcementEngine`、`RuleEvaluator`、`WidgetManager`
2. 修改 `NativeOverlayManager` 增加 stopwatch、颜色、振动
3. 修改 `MonitorForegroundService` 使用 `EnforcementEngine`
4. **此时 Flutter 层不动**，两套系统并存，通过 Feature Flag 切换

### 阶段 2：Flutter 层瘦身

1. 简化 `UsageMonitorService` → `ConfigSyncService`
2. 删除 `OverlayStateManager`、`ReminderService`、`RuleCheckerService`、`ContinuousUsageService`
3. 简化 `OverlayService` 的 MethodChannel 方法
4. 移除 Feature Flag，默认使用原生引擎

### 阶段 3：验证和清理

1. 全面功能测试（各场景：正常监控、倒计时、强制休息、删除纹纹、MIUI 回收）
2. 性能测试（5s 轮询的 CPU/电量影响）
3. 清理废弃代码和注释

## 12. 验证方案

### 12.1 功能验证

| 场景 | 验证方法 | 期望结果 |
|------|----------|----------|
| 打开被监控 App | 启动 App，观察 widget | 5s 内出现 stopwatch widget |
| 倒计时触发 | 连续使用到阈值 | 自动切换为 countdown widget，颜色随阈值变化 |
| 切换非监控 App | 按 Home 键 | Widget 保持显示 10s 后消失（延迟确认） |
| 短暂切换回来 | 按 Home 键后立即切回 | Widget 不消失 |
| 倒计时归零 | 等待倒计时结束 | 自动弹出 lock overlay |
| 强制休息中 | 倒计时归零后 | lock overlay 显示休息倒计时 |
| 休息结束 | 等待休息时间到期 | lock overlay 消失，回到 IDLE |
| 删除纹纹 | 最近应用中上滑删除 | AppLock 弹出，服务重启，监控恢复 |
| MIUI 回收 Widget | 使用中被系统回收 | 5s 内重建 widget，倒计时进度不丢失 |
| 时间段限制 | 在禁止时段使用 | 立即弹出 lock overlay |
| 总时间限制 | 今日时间用完 | 立即弹出 lock overlay |

### 12.2 性能验证

| 指标 | 当前 | 目标 |
|------|------|------|
| 轮询间隔 | 30s | 5s |
| Widget 出现延迟 | 0-30s | 0-5s |
| 倒计时精度 | ±10s 漂移 | ±1s（挂钟） |
| CPU 占用（每轮询） | ~2% | ~1%（原生直接执行，无 MethodChannel） |
| 内存泄漏 | 无检测 | 每次 Widget 重建后检查 View 是否释放 |

### 12.3 稳定性验证

- 连续运行 24 小时无崩溃
- 50 次 App 切换循环无状态异常
- 10 次删除纹纹循环监控正常恢复
- MIUI 一键清理后 30s 内监控恢复
