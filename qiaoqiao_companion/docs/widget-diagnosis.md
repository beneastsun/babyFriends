# Widget 显示混乱诊断报告

## 第1层：用户看到了什么？期望什么？

### 用户观察
1. **有时候 widget 没弹出来** — 打开被限制的 app 时，右上角倒计时 widget 不出现
2. **widget 在倒计时中突然消失** — 正在倒计时，突然不见了
3. **整体感觉混乱** — 行为不可预期

### 用户期望
- 打开被限制 app → 右上角立即出现倒计时 widget
- 倒计时持续显示直到归零 → 触发锁定弹窗
- 切换到非监控 app → widget 消失（"没使用就消失"）
- 回到被限制 app → widget 重新出现

## 第2层：产品逻辑诊断（核心问题）

### 问题1：三个独立的"倒计时"机制互相干扰

系统中有 **三条独立的计时路径**，它们的时序可能严重冲突：

| 路径 | 触发者 | 计时器 | 位置 |
|------|--------|--------|------|
| A. 原生 countdown widget | OverlayChannel.kt | 挂钟倒计时 `countdownWallClockStartMs` | 右上角小悬浮窗 |
| B. Flutter `_checkContinuousUsageAlerts` | 30s轮询 | ContinuousUsageService 中的 session 累加 | 右上角小悬浮窗 |
| C. `_checkAndTriggerRest` | 30s轮询 | `shouldTriggerRest()` 判断 | 全屏锁定弹窗 |

**关键冲突**：路径 B（5分钟提醒触发 countdown widget）和路径 C（强制休息）都由 30 秒轮询驱动，但它们的计时基准不同：
- 路径 B 使用 session 的 `totalDurationSeconds`（由 `onAppStopped` 累加）
- 路径 A 的 widget 倒计时使用挂钟时间
- 两者可能漂移几秒到几十秒

### 问题2：countdown widget 和提醒弹窗互相覆盖

当 countdown widget 正在倒计时，到 3 分钟/2 分钟阈值时，原生侧会通知 Flutter → Flutter 调用 `_handleCountdownAlert` → `_reminderService.checkAndShowForbiddenReminder` → 显示全屏提醒弹窗。

**但这个全屏弹窗会覆盖/遮挡 countdown widget！** 更严重的是：

```kotlin
// OverlayChannel.kt showOverlay()
if (isOverlayShowing) {
    hideOverlay()  // ← 这里会隐藏当前的 overlay
}
```

等等——这隐藏的是 overlay，不是 countdown widget。但实际上全屏提醒弹窗可能：
1. 在视觉上完全遮盖 countdown widget（MATCH_PARENT vs WRAP_CONTENT）
2. 用户点击"知道了"关闭提醒弹窗后，countdown widget 可能在弹窗显示期间被 MIUI 回收

### 问题3：`_syncWidgetStateWithNative` 的"修复"逻辑导致更多混乱

```dart
// _syncWidgetStateWithNative() 每次 30s 轮询都执行
if (!isNativeShowing && (_countdownWidgetShowing || _stopwatchWidgetShowing)) {
    if (isMonitored && !_forceRestInProgress) {
        // 尝试恢复 → 但先重置所有标志！
        _countdownWidgetShowing = false;
        _stopwatchWidgetShowing = false;
        _countdownTriggerApp = null;
        _countdownEnding = false;
        _overlayManager.onCountdownEnded();
        // 然后重新显示
        await _showStopwatchWidget(inRest: false);
    } else {
        // 重置标志
        _countdownWidgetShowing = false;
        _stopwatchWidgetShowing = false;
        // ...
    }
}
```

**这个逻辑有严重问题**：
1. 每次轮询都会检查原生侧状态，如果 widget 被系统短暂回收（MIUI 常见），会重置所有标志
2. `_showStopwatchWidget(inRest: false)` 会重新计算剩余时间，但可能和之前的倒计时不同步
3. `_overlayManager.onCountdownEnded()` 会把 OverlayStateManager 状态设为 idle，**打开了其他弹窗抢占的窗口**

### 问题4：widget 消失的根本原因 — MIUI/ROM 回收

MIUI 等国产 ROM 会主动回收 TYPE_APPLICATION_OVERLAY 窗口，特别是：
- 切换应用时
- 屏幕旋转时
- 系统内存紧张时

当原生 countdown widget 被回收后：
1. `isCountdownWidgetShowing`（Kotlin 侧标志）仍为 `true`（因为 `removeCountdownWidgetView` 没被调用）
2. **但是**，如果 `removeCountdownWidgetView` **确实被调了**（系统移除视图触发了某种回调），`isCountdownWidgetShowing` 会变为 `false`
3. Flutter 侧 `_countdownWidgetShowing` 仍为 `true`
4. 下次轮询 `_syncWidgetStateWithNative` 检测到不一致 → 尝试恢复

但恢复过程中有竞态：如果在恢复之前，`_checkContinuousUsageAlerts` 或 `_checkAndTriggerRest` 先执行了，它们看到 `_countdownWidgetShowing=true` 就直接跳过了。

### 问题5：_handleContinuousUsageTransition 中的"没使用就消失"导致 widget 闪退

```dart
if (!shouldTrackCurrent) {
    // 离开监控应用
    if (!_forceRestInProgress) {
        await _hideStopwatchWidget();  // ← 立即隐藏！
    }
}
```

如果 30 秒轮询时，用户刚好切换了应用（比如按 Home 键），前台 app 短暂变成 launcher：
1. `currentApp` 不是被监控 app
2. `shouldTrackCurrent = false`
3. widget 立即被隐藏
4. 下一秒用户又回到被监控 app
5. 但要等下一个 30 秒轮询才会重新显示 widget

**这就是"倒计时中突然消失"的主要原因！**

## 第3层：理解系统的所有层

### 原生层 (Kotlin OverlayChannel)
- countdown widget 使用 `FLAG_NOT_FOCUSABLE` → 不获取焦点，MIUI 更容易回收
- 倒计时使用挂钟（`System.currentTimeMillis()`），不受系统暂停影响
- 倒计时结束 → 自动显示 lock overlay（原生兜底）

### Flutter 层 (Dart)
- 30 秒轮询驱动所有逻辑
- 内存标志 (`_countdownWidgetShowing`, `_stopwatchWidgetShowing`) 可能与原生侧不同步
- `_syncWidgetStateWithNative` 试图修复不同步，但引入更多问题

### 通信层 (MethodChannel)
- `isCountdownWidgetShowing()` → 查询 Kotlin 侧布尔标志（不验证视图是否真的在屏幕上）
- `showCountdownWidget` / `hideCountdownWidget` → 异步调用，有延迟

## 第4层：防御级联故障

当前代码有多处级联故障风险：

1. **原生 widget 被回收** → Flutter 标志仍为 true → 所有恢复路径被跳过 → widget 永远不出现
2. **3min/2min 提醒弹窗覆盖 widget** → 用户关闭提醒 → widget 已被回收 → Flutter 标志仍为 true → 死锁
3. **切换 app 短暂失去前台** → widget 被隐藏 → 下次轮询才恢复 → 用户看到"突然消失"

## 第5层：修复建议（按优先级）

### P0：widget 被"没使用就消失"逻辑误杀

**根因**：`_handleContinuousUsageTransition` 中，当前台 app 不是被监控 app 时，立即隐藏 widget。但前台 app 检测有 30 秒延迟和噪声（launcher、系统 UI 短暂出现）。

**修复**：不要在 `shouldTrackCurrent=false` 时立即隐藏 widget，而是加一个延迟确认机制：
- 第一次检测到离开监控 app → 设置一个 `_lastSeenMonitoredApp` 时间戳，不立即隐藏
- 连续 2 次轮询（60 秒）都检测到不在监控 app → 才隐藏 widget
- 这样可以避免短暂的 app 切换导致 widget 闪退

### P1：原生 widget 被 MIUI 回收后恢复逻辑不稳定

**根因**：`_syncWidgetStateWithNative` 每次 30 秒轮询执行，恢复逻辑不稳定（重置所有标志再重新显示）。

**修复**：简化恢复逻辑 — 如果原生 widget 消失但 Flutter 认为应该显示，直接重新调用 `showCountdownWidget`，不重置 `_overlayManager` 状态。

### P2：3min/2min 提醒弹窗与 countdown widget 冲突

**根因**：提醒弹窗全屏显示时，视觉上完全遮盖 countdown widget，且可能导致 widget 被回收。

**修复**：当 countdown widget 正在显示时，3min/2min 提醒不应显示全屏弹窗，而应只更新 widget 的样式（如变色）或发送通知。

### P3：`isCountdownWidgetShowing` 标志不准确

**根因**：Kotlin 侧的 `isCountdownWidgetShowing` 是一个布尔标志，在 `addView` 后设为 true，但视图可能被系统移除而标志未更新。

**修复**：在 `removeCountdownWidgetView` 之外，增加视图存活检查。或者让 widget 使用 `View.OnAttachStateChangeListener` 来检测视图被系统移除。
