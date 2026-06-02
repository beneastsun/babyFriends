# 锁定弹窗"知道了"按钮不可点击 Bug 排查记录

## TL;DR

| 项目 | 内容 |
|---|---|
| **症状** | 连续使用倒计时结束后，锁定弹窗出现，等完休息时长后"知道了"按钮无法点击（或点击后窗口不消失） |
| **根因** | 同一个 `showOverlay()` 被**原生兜底**和 **Flutter 路径**在 ≤1ms 内重复触发，导致两条异步回调（`ValueAnimator.onAnimationEnd` / `View.animate()` 淡出回调）在共享的类字段（`pendingCloseButton` / `overlayView`）上发生竞态 |
| **最终修复** | 1) 铲除基于 `ValueAnimator.onAnimationEnd` 的按钮启用机制，改用挂钟 `System.currentTimeMillis() >= lockOverlayRestEndTime` 控制按钮可用性；2) 淡出回调加 `if (overlayView == view)` 保护判断 |
| **影响文件** | `android/app/src/main/kotlin/.../channels/OverlayChannel.kt` |
| **状态** | ✅ 已修复并提交 |

---

## 基本信息

- **日期**: 2026-06-01
- **影响文件**: `android/app/src/main/kotlin/com/qiaoqiao/qiaoqiao_companion/channels/OverlayChannel.kt`
- **复现路径**: 使用受监控 App → 连续使用倒计时（最后 5 分钟）出现 → 倒计时归零 → 锁定弹窗出现 → 等完配置的休息时长 → 点击"知道了"
- **严重程度**: 高（用户永远无法关闭锁定弹窗，只能重启应用）

---

## 第一轮排查：`pendingCloseButton` 引用被覆盖

### 现象

锁定弹窗中"知道了"按钮始终处于禁用状态（灰色），无论等多久都不可点击。

### 初步分析

代码中锁定弹窗的关闭按钮由 `startCountdown` 的 `ValueAnimator.onAnimationEnd` 回调启用。该回调通过 `enablePendingCloseButton()` 方法访问类字段 `pendingCloseButton` 来启用按钮。

### 发现的时序问题

倒计时结束后**两条路径几乎同时显示锁定弹窗**：

1. **原生兜底路径**：`startCountdownWidgetAnimation.onAnimationEnd`
   → `showLockOverlayFromFallback()` → `showOverlay(type="lock")`
   → 创建覆盖层 #1 + `startCountdown #1`

2. **Flutter 路径**：`notifyCountdownEnded()`（通过 MethodChannel 异步通知 Flutter）
   → `_handleCountdownEnded()` → `_triggerForcedRestAfterCountdown()`
   → `checkAndShowForbiddenReminder()` → `showOverlay(type="lock")`

   Flutter 路径进入时 `isOverlayShowing = true`，所以先调用 `hideOverlay()`——
   **这会把 `pendingCloseButton = null`**——然后再创建覆盖层 #2 + `startCountdown #2`

于是两条 `startCountdown` 同时运行，谁的 `onAnimationEnd` 先执行，谁就消费掉 `pendingCloseButton` 并置 `null`，另一条看到 `null` 就跳过——**按钮永远不可点击**。

### 修复方案 V1

铲除 `pendingCloseButton` 字段及所有依赖 `ValueAnimator.onAnimationEnd` 的按钮启用逻辑，改用**挂钟**控制：

- 按钮始终保持 `isEnabled = true`
- 点击时检查 `System.currentTimeMillis() >= lockOverlayRestEndTime`
- 按钮文本在 `startCountdown` 的 `addUpdateListener` 中实时更新（每秒刷新一次剩余时间文本）

**提交**：删除了 `pendingCloseButton`、`pendingCloseButtonAccent`、`enablePendingCloseButton()`，新增 `lockOverlayRestEndTime` 字段，修改 `startCountdown` 签名和 `hideOverlay`。

### 结果

按钮可以点击了，**但点击后窗口无法关闭**——一个问题掩盖了另一个问题。

---

## 第二轮排查：`hideOverlay()` 中的引用竞态

### 现象

按钮变成可点击状态，点击后 `notifyDismissed()` 和 `hideOverlay()` 都执行了，但窗口仍然留在屏幕上。

### 分析

追踪 `hideOverlay()` 的执行路径：

```
时间线:
T0       原生兜底路径 showLockOverlayFromFallback() → showOverlay()
         → overlayView = 覆盖层 A
T0+1ms   Flutter 路径 checkAndShowForbiddenReminder() → showOverlay()
         → hideOverlay():
             overlayView?.let { view ->
                 view.animate().alpha(0f).setDuration(200).setListener {
                     onAnimationEnd {
                         removeView(view)
                         overlayView = null     ← 注意！
                         isOverlayShowing = false
                     }
                 }
             }
         → overlayView = 覆盖层 B  ← 此时覆盖层 A 的淡出动画还在跑
T0+200ms 覆盖层 A 的淡出动画结束
         → onAnimationEnd 回调执行
         → overlayView = null    ← 错误！覆盖层 B 的引用被清掉了
T0+...   用户点击"知道了"
         → hideOverlay()
         → overlayView 是 null
         → 什么都不做
         → 覆盖层 B 永远留在屏幕上
```

### 根因

`hideOverlay()` 使用 `View.animate()` 启动异步动画，动画回调中无条件设置 `overlayView = null`。如果在这 200ms 动画期间另一个 `showOverlay()` 调用重新赋值了 `overlayView`，回调就会错误地清除新覆盖层的引用。

这个 Bug 在 `pendingCloseButton` 修复之前就已经存在，只是被"按钮不可点击"的问题掩盖了。

### 修复方案 V2

在动画回调中加保护判断：只当 `overlayView` 仍然指向被移除的 view 时才置 null。

```kotlin
override fun onAnimationEnd(animation: Animator) {
    try {
        windowManager?.removeView(view)
    } catch (e: Exception) { }
    if (overlayView == view) {   // 新增保护
        overlayView = null
        isOverlayShowing = false
    }
}
```

---

## 最终修复对照表

| 位置 | 修复前 | 修复后 |
|---|---|---|
| 按钮启用时机 | `ValueAnimator.onAnimationEnd` 调用 `enablePendingCloseButton()`（依赖类字段 `pendingCloseButton`） | 按钮始终 `isEnabled = true`，点击时校验 `System.currentTimeMillis() >= lockOverlayRestEndTime` |
| 按钮文本更新 | 一次性静态文本 | `startCountdown` 的 `addUpdateListener` 每秒刷新 |
| 淡出回调 | 无条件 `overlayView = null` | 加 `if (overlayView == view)` 保护判断 |
| 共享类字段 | `pendingCloseButton` / `pendingCloseButtonAccent` | 删除；仅保留 `lockOverlayRestEndTime`（时间戳，无对象引用问题） |

---

## 经验总结

### 原则 1：异步回调中访问类字段 = 危险信号

`View.animate()` / `ValueAnimator` 的回调是异步执行的（回调触发时调用栈早已不同）。任何在回调中读写类字段的代码，都必须考虑**回调触发时字段可能已被其他调用修改**。

**不安全**：
```kotlin
fun hide() {
    view?.animate()?.setListener(object : AnimatorListenerAdapter() {
        override fun onAnimationEnd(animation: Animator) {
            view = null  // ❌ view 可能已被重新赋值
        }
    })
}
```

**安全**：
```kotlin
fun hide() {
    view?.let { v ->    // 用局部变量捕获当前引用
        v.animate()?.setListener(object : AnimatorListenerAdapter() {
            override fun onAnimationEnd(animation: Animator) {
                if (view == v) {  // ✅ 身份确认
                    view = null
                }
            }
        })
    }
}
```

### 原则 2：能用"墙钟 + 值对象"就不用"对象引用 + 回调"

`pendingCloseButton` 是一个 `View` 引用字段——任何持有该引用的异步任务都可能在错误的时间点访问已失效的对象。改为记录 `lockOverlayRestEndTime: Long`（时间戳是值对象），让"是否可点击"变成一个**纯计算**而非**状态同步**问题，从根本上消除了竞态。

**适用场景**：
- 按钮"在 X 秒后可点击"
- 弹窗"在 X 秒后自动关闭"
- 提示"在 X 秒内不重复显示"

**反例**：不要为这些场景创建 `Timer` / `Animator` / `Handler.postDelayed` 回调去修改某个 `isEnabled` 字段——直接用挂钟判断。

### 原则 3：类字段 vs 局部变量

- 如果值在创建时就能确定且后续不会变化，优先用**局部变量或函数参数**传递，而不是存为类字段。
- 本例中 `pendingCloseButton` 原本应该作为参数传给 `startCountdown`，让 `ValueAnimator` 的 lambda 直接捕获它，而不是通过类字段间接访问。

### 原则 4：双路径触发的防御设计

原生兜底 + Flutter 路径同时触发同一事件是这类 Bug 的常见来源。设计时自问：

1. 两条路径同时触发时，状态会不会冲突？
2. 能否在入口加 `isDoingX` 标志做去重？
3. 如果无法统一入口，共享状态（字段、WindowManager 中的 view、SharedPreferences）是否都做了幂等处理？

本例兜底路径是专门为 Flutter 死亡场景设计的，无法与 Flutter 路径合并，所以**只能**通过"让共享状态在重复调用下仍然正确"来防御。

### 原则 5：一个 Bug 掩盖另一个 Bug

第一轮修复后按钮变得可点击，但窗口仍然关不掉——说明问题不止一个。

**做法**：修完一个 Bug 后，**重头走一遍完整用户路径**（点击 → 状态变更 → 窗口消失 → 资源回收），而不是只验证"按钮可点了"就结束。端到端跟踪能更快暴露深层问题。

---

## 关联改动

本次排查暴露的"异步回调 + 类字段"反模式在仓库中可能还存在于：

- `NativeOverlayManager.kt` 中的 `lockCountdownAnimator` / `countdownAnimator` 回调（已用 `lockCountdownCancelled` / `countdownCancelled` 标志做基本保护）
- 其他使用 `View.animate().withEndAction { ... }` 的地方

**建议**：日后修改任何涉及异步动画回调的代码时，对照原则 1 和 2 检查一遍。
