# 修复强制休息弹窗倒计时与双弹窗竞争问题

## TL;DR
> **Summary**: 修复强制休息弹窗（"使用时间到啦！"）在停止纹纹小伙伴后台进程后出现两个弹窗循环切换、按钮在倒计时内可点击的问题。需要修改 NativeOverlayManager.kt 和 OverlayChannel.kt，确保倒计时结束前按钮禁用、弹窗不自动消失。
> **Deliverables**: 1 个 Kotlin 文件修改 + 验证方法
> **Effort**: Short
> **Parallel**: NO
> **Critical Path**: NativeOverlayManager.kt 修改 → OverlayChannel.kt 修改 → 验证

## Context
### Original Request
用户反馈：在最近使用 App 中划掉纹纹小伙伴后，连续使用倒计时到限时弹出的强制休息弹窗可以随意点击关闭（按钮"回到纹纹小伙伴"在倒计时期间可点）。需要改为等倒计时结束才能关闭。

### 用户二次反馈（关键）
用户测试后发现有两个弹窗在循环切换：
1. **新弹窗**（禁用"回到纹纹小伙伴"按钮）——来自我之前的临时修改
2. **旧弹窗**（按钮一直可点击）——原始弹窗

用户要求：只保留新弹窗（禁用按钮），弹窗一直不自动消失，按钮倒计时结束才可点击，点击关闭。

### 根因分析

**根因 1 — 双弹窗竞争**：
存在两套独立的覆盖层系统：
- `NativeOverlayManager.kt` — 原生强制休息覆盖层（🔒图标）
- `OverlayChannel.kt` — Flutter 侧覆盖层，倒计时结束后调用 `showLockOverlayFromFallback()` 显示弹窗

当 `triggerNativeForcedRest()` 通过 `NativeOverlayManager` 显示强制休息覆盖层后，`OverlayChannel` 的独立倒计时（在 Flutter 死亡前启动）也可能到达 0，调用 `showLockOverlayFromFallback()` 在**同一 WindowManager 栈顶**再创建一个覆盖层（按钮可点击）。两者交替显示 → 用户看到循环切换。

**根因 2 — 按钮在倒计时内可点击**：
`showLockOverlay()` 的 `durationSeconds` 参数控制按钮是否禁用（>0 禁用），但监控循环调用 `showLockOverlay(reason, foregroundApp)` 时**未传递 durationSeconds**（默认 0），导致覆盖层重建后按钮立即可点击。

**根因 3 — 弹窗自动消失**：
监控循环的 `needsCountdown` 和 `else` 分支会在强制休息结束后调用 `hideOverlay()`，使弹窗自动关闭，违背"弹窗一直不消失直到用户点击"的需求。

## Work Objectives
### Core Objective
确保强制休息弹窗：
1. 倒计时期间按钮禁用（灰色不可点）
2. 弹窗不会自动消失（需要用户主动点击按钮）
3. 按钮在倒计时结束后变为可点击
4. 点击按钮关闭弹窗并回到 App
5. 只有一个弹窗显示（无 OverlayChannel 竞争）

### Must Have
- `NativeOverlayManager.kt`：添加 `isUserDismissRequired` 标志防止自动隐藏
- `NativeOverlayManager.kt`：添加 `isForceRestActive` 静态标志供 OverlayChannel 检查
- `NativeOverlayManager.kt`：`hideOverlay()` 和 `hideOverlayImmediate()` 增加 `force` 参数
- `OverlayChannel.kt`：`showLockOverlayFromFallback()` 检查 `isForceRestActive` 标志并跳过

### Must NOT Have
- 不修改覆盖层 UI 样式和文字
- 不改变倒计时悬浮窗（countdown widget）的行为
- 不影响 Flutter 正常运行时（引擎存活）的弹窗行为

## Verification Strategy
### 验证方式（需在物理设备或模拟器上执行）
1. 运行 App → 设置连续使用限制（如 2 分钟）
2. 使用被监控 App 到时间限制触发
3. **测试 1**：弹窗显示后检查"回到纹纹小伙伴"按钮为灰色禁用
4. **测试 2**：等待倒计时结束，检查按钮变为红色可点击
5. **测试 3**：倒计时期间点击按钮 → 无反应
6. **测试 4**：倒计时结束后点击按钮 → 弹窗关闭，App 回到前台
7. **测试 5**：弹窗显示期间从最近应用划掉纹纹小伙伴 → 弹窗不应消失，仍在前台
8. **测试 6**：弹窗显示期间等待 → 不应有两个弹窗循环切换

## TODOs

- [ ] 1. 修改 NativeOverlayManager.kt — 添加标志和防自动隐藏逻辑

  **What to do**:
  1. 在 `companion object` 中添加 `@JvmStatic var isForceRestActive = false`
  2. 添加实例标志 `private var isUserDismissRequired = false`
  3. 在 `showLockOverlay()` 中：
     - 将已有的 `isLockOverlayWithCountdown` 检查替换为 `isUserDismissRequired` 检查
     - 当 `durationSeconds > 0` 时：`isUserDismissRequired = true; isForceRestActive = true`
  4. 修改 `hideOverlay()`：增加 `force: Boolean = false` 参数，当 `isUserDismissRequired && !force` 时返回
  5. 修改 `hideOverlayImmediate()`：增加 `force: Boolean = false` 参数，同上逻辑
  6. 在按钮 `setOnClickListener` 中：`hideOverlay(force = true)`
  7. 在 `destroy()` 中：重置标志，调用 `hideOverlayImmediate(force = true)`
  8. 在所有隐藏路径重置 `isUserDismissRequired` 和 `isForceRestActive`

  **Must NOT do**: 不修改 UI 布局、按钮样式、动画等

  **Parallelization**: Wave 1

  **References**:
  - `NativeOverlayManager.kt` lines 29-31: companion object
  - `NativeOverlayManager.kt` lines 83-155: `showLockOverlay()`
  - `NativeOverlayManager.kt` lines 160-184: `hideOverlay()`
  - `NativeOverlayManager.kt` lines 189-199: `hideOverlayImmediate()`
  - `NativeOverlayManager.kt` lines 396-402: button click listener

  **Acceptance Criteria**:
  - [ ] Kotlin 编译通过，无语法错误
  - [ ] 强制休息弹窗的按钮在倒计时期间不可点击
  - [ ] hideOverlay() 不加 force=true 不会隐藏强制休息弹窗

  **QA Scenarios**:
  ```
  Scenario: 强制休息弹窗按钮在倒计时期间禁用
    Tool: mobile_ui (Android设备测试)
    Steps: 触发强制休息弹窗，检查"回到纹纹小伙伴"按钮
    Expected: 按钮灰色(isEnabled=false)，点击无反应
    Evidence: 屏幕截图

  Scenario: 强制休息弹窗按钮倒计时结束可点击
    Tool: mobile_ui (Android设备测试)
    Steps: 等待倒计时结束，检查按钮变为红色可点击
    Expected: 按钮红色(isEnabled=true)，点击关闭弹窗回到App
    Evidence: 屏幕截图

  Scenario: 监控循环不自动关闭强制休息弹窗
    Tool: logcat
    Steps: 观察日志，确认无意外的 hideOverlay 调用
    Expected: 弹窗持续显示直到用户点击按钮
    Evidence: logcat 输出
  ```

  **Commit**: YES | Message: `fix(android): prevent lock overlay auto-dismiss and suppress competing overlay` | Files: `NativeOverlayManager.kt`

- [ ] 2. 验证 OverlayChannel.kt 在强制休息时不显示竞争弹窗

  **What to do**:
  确认 `OverlayChannel.kt` 的 `showLockOverlayFromFallback()` 方法（约第 951 行）增加检查：
  ```kotlin
  if (NativeOverlayManager.isForceRestActive) return
  ```

  **Must NOT do**: 不修改 OverlayChannel 的其他逻辑

  **Parallelization**: Wave 1 (与任务 1 并行)

  **References**:
  - `OverlayChannel.kt` lines 951-975: `showLockOverlayFromFallback()`

  **Acceptance Criteria**:
  - [ ] OverlayChannel 在强制休息期间不显示竞争覆盖层
  - [ ] 只有一个弹窗出现在屏幕上

  **QA Scenarios**:
  ```
  Scenario: 强制休息期间仅有一个覆盖层
    Tool: logcat / 屏幕观察
    Steps: 触发强制休息弹窗后，检查 WindowManager 覆盖层数
    Expected: 只有 NativeOverlayManager 的覆盖层，无 OverlayChannel 覆盖层
    Evidence: logcat 日志确认无 "showLockOverlayFromFallback" 执行
  ```

  **Commit**: YES | Message: `fix(android): skip OverlayChannel fallback when forced rest active` | Files: `OverlayChannel.kt`

## Commit Strategy
| # | Message | Scope |
|---|---------|-------|
| 1 | `fix(android): prevent lock overlay auto-dismiss and suppress competing overlay` | NativeOverlayManager.kt, OverlayChannel.kt |

## Success Criteria
1. 强制休息弹窗倒计时期间按钮禁用 ✓
2. 弹窗不自动消失（直到用户点击按钮） ✓
3. 一个弹窗（无竞争切换） ✓
4. 点击按钮关闭弹窗回到 App ✓
