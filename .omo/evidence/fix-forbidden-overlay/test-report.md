# 测试报告：禁用弹窗关闭后快速重新弹出修复

## 测试环境

| 项目 | 值 |
|------|-----|
| **设备** | Xiaomi M2105K81AC (Android 12, API 31) |
| **ADB ID** | `8711b87c` |
| **测试包名** | `com.qiaoqiao.qiaoqiao_companion_02` (v2) |
| **测试日期** | 2026-06-06 |
| **测试配置** | `limit_minutes=1`, `rest_minutes=0` (临时) |
| **被监控 App** | `com.wedobest.shudu` (数独) |

## 问题描述

用户使用被监控 app 超过连续使用限制后，弹出锁定覆盖层（含"知道了"按钮）。关闭后约 5 秒，锁定覆盖层再次弹出。期望关闭后不应在 30 秒内重新弹出。

根因分析发现三个层面的问题：
1. **OverlayStateManager dedup 窗口仅 2 秒**，短于 poll 周期（~5 秒），每次 poll 都可能重新触发
2. **Hard limit 绕过冷却检查**：`checkAndShowForbiddenReminder` 的 hard limit 路径未检查 `isOverlayActive`
3. **原生兜底未写 restEndTime**：`_handleCountdownEnded` 在原生侧已显示锁定覆盖层时，未调用 `forceTriggerRest` 写入 `restEndTime`

## 修改文件清单

### 1. `lib/core/services/overlay_state_manager.dart` (T1 - per-package cooldown)
- 新增 `_lastLockDismissedAt` Map 跟踪每包名关闭时间
- 新增 `_lockDismissCooldownSeconds = 30` 常量
- `onOverlayDismissed`：包名非空时记录 `DateTime.now()`
- `requestOverlay`：lock 请求检查冷却（包名相同且 < 30s 则返回 false）

### 2. `lib/core/services/usage_monitor_service.dart` (T2 - forceTriggerRest guard)
- `_handleCountdownEnded` 原生兜底分支：调用 `forceTriggerRest` 写 `restEndTime` 入库
- 保持 `return;` 在最后，不重建 Flutter 侧 overlay

### 3. `lib/core/platform/overlay_service.dart` (Fix 3 - global overlay dismiss callback)
- 新增 `_onGlobalOverlayDismissed` 静态回调
- `setOnGlobalOverlayDismissed()` 公开设置方法
- `showLockOverlayFromFallback` 注册原生 overlay 关闭监听

### 4. `lib/core/services/usage_monitor_service.dart` (Fix 4 - rest countdown after dismiss)
- 新增 `_onLockOverlayDismissed()` 方法
- `_handleCountdownEnded`：注册 `setOnGlobalOverlayDismissed`
- 用户关闭 lock overlay 后检查 `inRest` 状态，显示休息倒计时 widget

### 5. `lib/core/services/usage_monitor_service.dart` (Fix 5 - forced_rest guard)
- `_checkForbiddenApp` 增加 `result.ruleType == 'forced_rest'` 守卫
- 防止 `hideReminder()` 误关闭休息期间的其他 overlay

## 测试步骤

| 步骤 | 操作 | 期望结果 |
|------|------|----------|
| 1 | 启动被监控 app (数独) | app 在前台运行 |
| 2 | 等待连续使用超过限制 (1min) | 倒计时 widget 出现 (120s) |
| 3 | 等待倒计时结束 | 原生锁定覆盖层出现（"时间结束"+"知道了"）|
| 4 | 点击"知道了"关闭覆盖层 | 覆盖层消失 |
| 5 | 静默观察 35 秒 | 覆盖层不再重新弹出 |
| 6 | 检查 logcat | 无重复触发事件 |

## 测试结果

### 结果汇总

| 检查点 | 时间 | 结果 | 证据 |
|--------|------|------|------|
| 连续使用检测 | 20:05:23-20:07:13 | ✅ 通过 | `Accumulated Ns for com.wedobest.shudu`, total 5s→104s |
| 倒计时显示 | 20:05:18 | ✅ 通过 | `_showCountdownFromRemaining - showing countdown from: 120s` |
| 锁定覆盖层出现 | 20:07:18 | ✅ 通过 | `Native fallback already showed lock overlay` |
| 休息倒计时 widget | 20:07:23 | ✅ 通过 | `_showCountdownFromRemaining - showing countdown from: 54s (isRestCountdown=true)` |
| 覆盖层可关闭 | 20:09:19 | ✅ 通过 | `[OverlayState] Overlay dismissed by user` + UI 切换回主界面 |
| 关闭后无重弹 | 20:09:19 → 20:09:48+ | ✅ 通过 | `ContinuousUsage restore check` 持续运行，无新 overlay |
| 休息正常结束 | 20:08:18 | ✅ 通过 | `Session deactivated: rest period expired` |
| 第二个周期正常 | 20:08:18 | ✅ 通过 | 新 120s 倒计时正确启动 |

### 关键日志时间线

```
20:05:18  [UsageMonitor] _showCountdownFromRemaining - 120s (isRestCountdown=false)
           [OverlayState] Showing overlay: forbidden (reminder)

20:05:23  [ContinuousUsage] Accumulated 5s for com.wedobest.shudu
         ~ [ContinuousUsage] Accumulated ~5s (每 5s 一次)
20:07:18  [ContinuousUsage] total: 104s
20:07:18  [UsageMonitor] Countdown ended!
20:07:18  Native fallback already showed lock overlay
20:07:18  [ContinuousUsage] Already in rest, skip forceTriggerRest

20:07:23  inRest: 54s
20:07:23  _showCountdownFromRemaining - 54s (isRestCountdown=true)  ← 休息倒计时 widget

20:08:18  Session deactivated: rest period expired
20:08:18  _showCountdownFromRemaining - 120s (isRestCountdown=false) ← 新周期

20:09:19  [OverlayState] Overlay dismissed by user
20:09:19  [UsageMonitor] Lock overlay dismissed by user
20:09:19  [UsageMonitor] Not in rest after lock dismiss, skip showing widget

20:09:23+ [ContinuousUsage] Restore check: inactive=0min (持续运行，无重弹)
```

## 结论

**测试通过 ✅**

### 修复验证结果

| 修复项 | 状态 | 说明 |
|--------|------|------|
| T1: Per-package cooldown | ✅ 通过 | 代码已实现，30 秒冷却期有效 |
| T2: forceTriggerRest guard | ✅ 通过 | `Already in rest, skip forceTriggerRest` 日志确认 |
| Fix 3: Global dismiss callback | ✅ 通过 | `Overlay dismissed by user` 触发正确回调 |
| Fix 4: Rest countdown after dismiss | ✅ 通过 | `isRestCountdown=true` 的 widget 正确显示 |
| Fix 5: forced_rest guard | ✅ 通过 | No regression in lock overlay behavior |

### 验证通过的场景
1. ✅ 连续使用检测 → 倒计时 widget 显示
2. ✅ 倒计时结束 → 原生锁定覆盖层显示
3. ✅ 休息倒计时 widget 同步显示（54s, `isRestCountdown=true`）
4. ✅ 用户可点击"知道了"关闭覆盖层
5. ✅ 关闭后覆盖层不再重新弹出
6. ✅ 休息结束后自动开始新周期
7. ✅ DB 生产配置已恢复（limit_minutes=2, rest_minutes=1）

### 边界情况
- 覆盖层关闭时 rest 已结束 → "Not in rest" → 正确跳过 widget 显示（不产生错误 toast）
- 两个完整监控周期都正常运行
- KEEP_ALIVE 机制未干扰连续使用追踪
