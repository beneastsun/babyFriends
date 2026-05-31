# 锁定弹窗"知道了"按钮不可点击 Bug 排查记录

## 基本信息

- **日期**: 2026-06-01
- **影响文件**: `android/../channels/OverlayChannel.kt`
- **复现条件**: 连续使用倒计时结束后，锁定弹窗出现，等待休息时长后点击"知道了"按钮无法关闭窗口
- **严重程度**: 高（用户永远无法关闭锁定弹窗，只能重启应用）

---

## 第一轮排查：`pendingCloseButton` 引用被覆盖

### 现象

锁定弹窗中"知道了"按钮始终处于禁用状态（灰色），无法点击。

### 初步分析

代码中锁定弹窗的关闭按钮由 `startCountdown` 的 `ValueAnimator.onAnimationEnd` 回调启用。该回调通过 `enablePendingCloseButton()` 方法访问类字段 `pendingCloseButton` 来启用按钮。

### 发现的时序问题

倒计时结束后有**两条路径同时显示锁定弹窗**：

1. **原生兜底路径**: `startCountdownWidgetAnimation.onAnimationEnd` →
   `showLockOverlayFromFallback()` → `showOverlay(type="lock")` → 创建覆盖层 #1 + `startCountdown #1`

2. **Flutter 路径**: `notifyCountdownEnded()` （通过 MethodChannel 异步通知 Flutter）→
   `_handleCountdownEnded()` → `_triggerForcedRestAfterCountdown()` →
   `checkAndShowForbiddenReminder()` → `showOverlay(type="lock")`

   Flutter 路径的 `showOverlay` 中 `isOverlayShowing = true`，所以先调用了 `hideOverlay()`——
   **这会把 `pendingCloseButton = null`**——然后再创建覆盖层 #2 + `startCountdown #2`

于是两条 `startCountdown` 同时运行，谁的 `onAnimationEnd` 先执行，谁就消费掉 `pendingCloseButton` 并置 `null`，另一条看到 `null` 就跳过——**按钮永远不可点击**。

### 修复方案 V1

铲除 `pendingCloseButton` 字段及所有依赖 `ValueAnimator.onAnimationEnd` 的按钮启用逻辑，改用**墙上时钟**控制：

- 按钮始终保持 `isEnabled = true`
- 点击时检查 `System.currentTimeMillis() >= lockOverlayRestEndTime`
- 按钮文本在 `startCountdown` 的 `addUpdateListener` 中实时更新

**提交**: 删除了 `pendingCloseButton`、`pendingCloseButtonAccent`、`enablePendingCloseButton()`，新增 `lockOverlayRestEndTime` 字段，修改 `startCountdown` 签名和 `hideOverlay`。

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
T0: 原生兜底路径 showLockOverlayFromFallback() → showOverlay()
    → overlayView = 覆盖层 A
T0+1ms: Flutter 路径 checkAndShowForbiddenReminder() → showOverlay()
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
    → overlayView = 覆盖层 B  ← 此时覆盖层 A 的动画还在跑
T0+200ms: 覆盖层 A 的淡出动画结束
    → onAnimationEnd 回调执行
    → overlayView = null    ← 错误！覆盖层 B 的引用被清掉了
T0+...: 用户点击"知道了"
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

## 经验总结

### 1. 异步动画与状态管理

`View.animate()` 的淡出动画是异步的（默认 200ms），**回调执行时调用栈早已不同**。任何在动画期间可能修改类字段的代码，都需要在回调中加入保护判断。

**不安全的模式**:
```kotlin
fun hide() {
    view?.animate()?.setListener(object : AnimatorListenerAdapter() {
        override fun onAnimationEnd(animation: Animator) {
            view = null  // 危险！view 可能已被重新赋值
        }
    })
}
```

**安全的模式**:
```kotlin
fun hide() {
    view?.let { v ->    // 先用局部变量捕获当前引用
        v.animate()?.setListener(object : AnimatorListenerAdapter() {
            override fun onAnimationEnd(animation: Animator) {
                if (view == v) {  // 确认还是同一个对象
                    view = null
                }
            }
        })
    }
}
```

### 2. 防御性编程：类字段 vs 局部变量

- `pendingCloseButton` 作为类字段在 `hideOverlay()` 中被置 null，导致 `startCountdown` 的 `onAnimationEnd` 回调无法找到按钮引用
- 修复方案改为将按钮引用作为参数传给 `startCountdown`（捕获到 ValueAnimator 的 lambda 中），不依赖类字段

**原则**: 如果值在创建时就能确定且后续不会变化，优先用局部变量或函数参数传递，而不是存为类字段。

### 3. 双重触发问题（UI 兜底的代价）

原生兜底 + Flutter 路径同时触发同一事件是这类 Bug 的常见来源。设计防御性代码时需要考虑：
- 如果两条路径同时触发，是否会有状态冲突？
- 是否可以统一入口，避免重复执行？

本例中无法简单统一入口（因为兜底路径就是为 Flutter 死亡场景设计的），所以需要确保类状态能正确处理重复调用。

### 4. 一个 Bug 可能掩盖另一个 Bug

第一轮修复后按钮变得可点击，但窗口仍然关不掉——说明问题不在按钮启用机制，而在 `hideOverlay()` 本身。花时间做完整的问题复现和端到端跟踪（从点击到窗口消失的完整链路）能更快定位真正的根因。
