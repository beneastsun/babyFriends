# Findings & Decisions — Widget 倒计时混乱问题修复

<!--
  WHAT: 任务的知识库。存储所有发现和决策。
  WHY: 上下文窗口有限。此文件是"外部记忆" - 持久且无限。
  WHEN: 在任何发现后更新，特别是 2 次 view/browser/search 操作后（2-Action Rule）。
-->

## 问题描述

连续使用倒计时的 widget 倒计时有时候出现，有时候自己消失，倒计时还没结束就消失。
用户要求：在平板使用限制的 app 的时候，才进行 widget 倒计时，没使用就消失。

## 根因分析

### 确认存在两套逻辑控制 widget

**逻辑 A：Flutter 侧（UsageMonitorService）**
- `_handleContinuousUsageTransition()` → `_showStopwatchWidget()` → `_showCountdownFromRemaining()`
- `_hideStopwatchWidget()` / `_syncWidgetStateWithNative()` 控制隐藏
- 每 30 秒轮询 `_syncAndCheck()` 中调用

**逻辑 B：原生侧（MonitorForegroundService → NativeContinuousUsageTracker + NativeRuleChecker）**
- 每 5 秒 `monitorRunnable` 调用 `NativeContinuousUsageTracker.updateTracking()`
- 在 Flutter 死亡时接管倒计时显示（步骤 A + 步骤 B）
- `NativeRuleChecker.checkContinuousCountdown()` 也会判断需要倒计时

### 三个关键冲突点

#### 1. `_syncWidgetStateWithNative()` 误清除状态

位置：`usage_monitor_service.dart:489-507`

```
问题场景：原生 widget 被系统短暂移除（如 MIUI 内存回收）
→ isCountdownWidgetShowing() 返回 false
→ Flutter 误认为倒计时已结束
→ 清除所有标志 + 清空 DB 倒计时字段
→ widget 永远不再出现
```

根源：`_syncWidgetStateWithNative` 只检查"原生侧 widget 是否还在"，没有考虑 widget 可能被系统短暂回收后应该恢复的情况。

#### 2. 离开监控 app 时 widget 行为不符合预期

位置：`usage_monitor_service.dart:186-203`

```
当前逻辑：离开监控 app → 不立即隐藏 widget → 设置 _lastStopTime
→ 等 resetAfterRestSeconds (默认1分钟) 后才隐藏
→ 用户看起来就是"倒计时有时候自己消失"
```

根源：用户期望的是"不用限制 app 就消失"，但代码注释说"不立即隐藏 widget"，原因是担心用户短暂离开（下拉通知栏）后 widget 频繁出现/消失。这和用户需求冲突。

#### 3. 原生侧 NativeContinuousUsageTracker 和 Flutter 侧双重决策

位置：
- `NativeContinuousUsageTracker.handleMonitoredApp()` (L78-152)
- `NativeRuleChecker.checkContinuousCountdown()` (L141-242)

```
问题：即使 Flutter alive，NativeRuleChecker.checkApp() 中的
checkContinuousCountdown() 兜底路径会在 Flutter 死亡时写 DB，
而 Flutter alive 时跳过（L199: isFlutterAlive check）。
但 NativeContinuousUsageTracker.updateTracking() 不检查 isFlutterAlive，
它在 monitorRunnable 步骤 A 中有 isFlutterAlive 检查，
但在步骤 B 中 NativeContinuousUsageTracker 实际上不在使用！
步骤 B 只用了 NativeRuleChecker.checkApp()，不是 NativeContinuousUsageTracker。
```

不过这里的冲突更微妙：`NativeContinuousUsageTracker` 是有状态追踪（累加时间、维护会话），而 `NativeRuleChecker.checkContinuousCountdown` 是无状态检查（每次从 DB 读取）。两者可能产生不同的决策结果。

### 用户需求 vs 当前行为的差异

| 场景 | 用户期望 | 当前行为 | 问题 |
|------|----------|----------|------|
| 正在使用被监控 app | 显示倒计时 widget | 显示 | ✅ 一致 |
| 切换到非监控 app | widget 立即消失 | 等 1 分钟后才消失 | ❌ 不一致 |
| 下拉通知栏/锁屏 | widget 保持 | 保持但可能被系统回收 | ⚠️ 边缘情况 |
| 原生 widget 被系统回收 | Flutter 尝试恢复 | 清除所有状态 | ❌ 错误 |

## 修复方案

### 核心原则

**单一控制源**：Flutter alive 时由 Flutter 侧完全控制 widget 的显示/隐藏；原生侧只在 Flutter 死亡时接管。**即时响应前台应用变化**：用户不在使用被监控 app → widget 立即消失；用户回到被监控 app → widget 立即重新出现。

### 修复点 1：离开监控 app 时立即隐藏 widget

文件：`usage_monitor_service.dart`
位置：`_handleContinuousUsageTransition` (L186-203)

**改动**：
- 当 `shouldTrackCurrent = false` 时，立即隐藏 widget（调用 `_hideStopwatchWidget()`）
- 移除 `_lastStopTime` 延迟消失逻辑
- 保留 `_checkHideStopwatchAfterRest` 只用于重置连续使用会话（仍需要会话重置机制）

### 修复点 2：`_syncWidgetStateWithNative` 更健壮

文件：`usage_monitor_service.dart`
位置：`_syncWidgetStateWithNative` (L489-507)

**改动**：
- 如果原生 widget 不在显示但 Flutter 侧标志为 true → 不是清除状态，而是尝试重新显示 widget
- 只有在确认用户确实不在使用被监控 app 时才清除状态

### 修复点 3：回到监控 app 时立即恢复 widget

文件：`usage_monitor_service.dart`
位置：`_handleContinuousUsageTransition` (L167-183)

**改动**：
- 当 `shouldTrackCurrent = true` 且有活跃倒计时会话时 → 立即恢复显示 widget
- 不依赖 `_showStopwatchWidget` 的守卫逻辑（因为标志已重置，不会被阻挡）

### 修复点 5（新增）：禁用提示框关闭后 widget 不弹出

文件：`usage_monitor_service.dart`
位置：`_onLockOverlayDismissed` (L404-437)

**根因**：
- 倒计时结束后有两条路径显示 lock overlay
  - 路径 A：原生兜底 lock overlay（`_handleCountdownEnded` 中 `isOverlayShowing() == true`）
  - 路径 B：Flutter 侧 lock overlay（`_triggerForcedRestAfterCountdown`）
- 路径 A 中 `syncStateFromNativeFallback(OverlayState.showingLock)` 将 OverlayStateManager._state 设为 showingLock
- 用户关闭 lock overlay → `_onGlobalOverlayDismissed` → `_onLockOverlayDismissed`
- 但 `_onGlobalOverlayDismissed` 不会调用 `OverlayStateManager.onOverlayDismissed`
- 导致 `_state` 仍为 `showingLock` → `_showStopwatchWidget` 被守卫阻挡 → widget 不出现
- 在 MIUI 上更容易复现（原生侧 5 秒轮询比 Flutter 30 秒更快创建 lock overlay，更常走路径 A）

**改动**：
- 在 `_onLockOverlayDismissed` 中，关闭 lock overlay 后立即复位 OverlayStateManager 状态
- 调用 `_overlayManager.onOverlayDismissed('')` 将 `_state` 从 showingLock 复位为 idle
- 路径 B 中 `onOverlayDismissed` 已被 OverlayService 的回调调用，此处再设一次无害

### 修复点 6（新增）：2 分钟提醒关闭后 widget 消失

文件：`usage_monitor_service.dart`
位置：`_showStopwatchWidget` (L209-218)

**场景**：倒计时 widget 显示中，2 分钟提醒弹出，用户关闭提醒后 widget 消失。

**根因**：
- 2 分钟提醒是全屏 reminder overlay，可能覆盖 countdown widget
- 如果 MIUI 在 reminder 显示期间回收了 countdown widget 的 window
- `OverlayChannel.isCountdownWidgetShowing` 只是一个内存标志，不反映实际 window 状态
- MIUI 回收 window 后，标志仍为 true → `_countdownWidgetShowing = true`
- 所有恢复路径（`_showStopwatchWidget`、`_syncWidgetStateWithNative`）因守卫条件被跳过
- 用户关闭 reminder 后发现 widget 不在，但 Flutter 侧以为它还在

**修复**：
1. `_showStopwatchWidget` 中：如果 `_countdownWidgetShowing = true` 但原生侧 `isCountdownWidgetShowing()` 返回 false → 重置标志，允许重新显示
2. `_syncWidgetStateWithNative` 中：如果原生 widget 不在但 `_overlayManager.state == showingReminder/showingLock` → 不重置标志，defer 到下次轮询（防止恢复被守卫阻挡导致标志丢失）

## Technical Decisions

| Decision | Rationale |
|----------|-----------|
| 离开监控 app → 立即隐藏 widget | 符合用户明确需求："没使用就消失" |
| `_syncWidgetStateWithNative` → 尝试恢复而非清除 | 避免 MIUI 内存回收导致 widget 永远消失 |
| 保留会话重置机制 | `_checkAndResetSessionAfterRest` 仍用于重置连续使用会话，只是不再延迟隐藏 widget |
| 保留原生侧 Flutter 死亡时的接管逻辑 | 不改变原生侧逻辑，只在 Flutter alive 时确保单一控制源 |
| `_onLockOverlayDismissed` 中复位 OverlayStateManager | 路径 A（原生兜底）关闭回调不走 onOverlayDismissed，导致 _state 残留 showingLock |

---

## Resources

### 关键文件路径
- Flutter 侧核心文件：`qiaoqiao_companion/lib/core/services/usage_monitor_service.dart`
- Flutter 侧 Overlay 状态管理：`qiaoqiao_companion/lib/core/services/overlay_state_manager.dart`
- Flutter 侧平台通道：`qiaoqiao_companion/lib/core/platform/overlay_service.dart`
- 原生侧监控服务：`qiaoqiao_companion/android/app/src/main/kotlin/.../services/MonitorForegroundService.kt`
- 原生侧连续使用追踪器：`qiaoqiao_companion/android/app/src/main/kotlin/.../monitor/NativeContinuousUsageTracker.kt`
- 原生侧规则检查器：`qiaoqiao_companion/android/app/src/main/kotlin/.../monitor/NativeRuleChecker.kt`

---

<!--
  REMINDER: The 2-Action Rule
  After every 2 view/browser/search operations, you MUST update this file.
-->
*Update: 2026-06-09*