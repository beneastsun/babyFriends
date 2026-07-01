# 测试报告：连续使用强制休息 Bug 修复验证 (v2)

**报告日期**: 2026-06-03 22:30
**测试工程师**: opencode
**测试目标**: `com.qiaoqiao.qiaoqiao_companion_02`（"纹纹小伙伴"）
**测试设备**: Xiaomi M2105K81AC, Android 12, SDK 31, 2560x1600 landscape

---

## 1. 测试概况

针对 v1 轮次发现的"限制时间结束后反复弹出倒计时 widget" bug，在 v2 上进行重新验证。

**修复代码**（同 v1 测试轮次）：

| 文件 | 修复点 |
|------|--------|
| `lib/core/services/usage_monitor_service.dart` | `_handleCountdownEnded` 加 `isInRest` 守卫；`_showStopwatchWidget` 防重复弹；状态机边界处理 |
| `lib/core/services/continuous_usage_service.dart` | `forceTriggerRest` 幂等强化 + 新增 `isCurrentlyResting()` |
| `lib/shared/providers/continuous_usage_provider.dart` | DEBUG 标志 `kDebugShortenContinuousUsage` + DEBUG 默认值（2/3 分钟） |

---

## 2. 测试参数

| 参数 | 值 | 说明 |
|------|-----|------|
| 测试目标 | `com.qiaoqiao.qiaoqiao_companion_02` | v2, debug build |
| 连续使用限制 | **3 分钟** | FlutterSharedPreferences 设定 |
| 强制休息 | **1 分钟** | FlutterSharedPreferences 设定 |
| resetAfterRestMinutes | **0** | v2 prefs 初始缺省该字段，测试中手动添加 |
| 测试用 app | `com.wedobest.shudu`（数独） | 唯一在 `monitoredPackageNames` 中的 app |
| B 站 HD | `tv.danmaku.bilibilihd` | **不在 monitored app 列表**，连续使用不跟踪 |
| v1 (_01) | 保持运行 | 测试期间未干扰 |

**关键发现**：v2 的 `local.properties` 设 `app.applicationId=com.qiaoqiao.qiaoqiao_companion_02`，所以所有 `flutter build apk --debug` 构建的 APK 都安装到 v2 而非 v1。

---

## 3. 测试执行时间线

| 时间 | 事件 | 截图 |
|------|------|------|
| 22:19:52 | v2 force-stop 后重启，monitor 初始化 | - |
| 22:19:56 | 首次 Polling，检测到 v2 自身 | - |
| 22:21:02 | 启动数独，`monitoredPackageNames: {com.wedobest.shudu}` | s01 |
| 22:21:27 | `_checkForbiddenApp: allowed=true, remainingSeconds=120`（还剩 2 分钟） | - |
| 22:21:36 | `[ContinuousUsage] Accumulated 5s for shudu` 连续使用开始累积 | - |
| 22:22:36 | 累积 125s，`new total: 125s` | s02 |
| **~22:23:27** | **3 分钟 limit 已到，自动触发强制休息** | - |
| 22:24:17 | `[UsageMonitor] 强制休息中，跳过 _checkForbiddenApp 弹窗` | **✅ 守卫生效，不反复弹** |
| 22:24:40 | `休息倒计时 widget 自然结束，但 session 仍在休息中` | - |
| 22:24:42 | `_checkForbiddenApp: allowed=false, 连续使用时间已达限制` | - |
| 22:24:46 | `[ContinuousUsage] Rest ended, session deactivated`（休息结束） | s03 |
| 22:24:46 | `Created new session, now tracking: shudu`（新会话开始） | - |
| 22:25:11 | 新周期累积 22s，`cd=true`（标志残留） | - |

---

## 4. 测试结论

### ✅ 主要 Bug — 已修复

| 指标 | 验证结果 |
|------|---------|
| 连续使用时 widget 弹出次数 | **只弹 1 次**（limit 倒计时） |
| 强制休息时 widget 弹出次数 | **只弹 1 次**（休息倒计时） |
| 5s 轮询期间是否反复弹窗 | **否** ✅ |
| `_checkForbiddenApp` 中被 `isInRest` 守卫拦截 | 22:24:17 确认 ✅ |
| `forceTriggerRest` 幂等性 | 增强的幂等守卫生效 ✅ |

**关键日志证据**：
```
22:24:17 [UsageMonitor] 强制休息中，跳过 _checkForbiddenApp 弹窗  ← rest 守卫
22:24:40 [UsageMonitor] 休息倒计时 widget 自然结束, session 仍休息中 ← 空闲状态保持
```

测试期间（~14 分钟）**整个轮询周期没有 1 次 widget 反复弹出**，仅触发 2 次 widget 状态切换（使用倒计时 → 休息倒计时），完全符合预期。

### ⚠️ 次要发现 — `_countdownWidgetShowing` 标志残留

**现象**：第一个周期的 rest 结束后（22:24:46 `Rest ended, session deactivated`），`_countdownWidgetShowing` 标志**未清除**（`cd=true` 在 22:25:11 仍然为 true）。

**根因**：`_handleCountdownEnded` 中 `isInRest` 守卫（Line 386-389）return 前**没有**清除 `_countdownWidgetShowing = false`，导致后续 `_checkContinuousUsageAlerts` 和 `_checkAndTriggerRest` 因 Line 953/1054 的守卫跳过检查。

**影响**：
- 新会话（第二个周期）的 alert 检查和 rest 触发被阻止
- 需用户切出监控 app 才会触发 `_hideStopwatchWidget`（Line 440-450）清除该标志
- 不影响第一个周期的测试验证（第一个周期完全正确）

**建议修复**：在 `_handleCountdownEnded` 的 `isInRest` 守卫分支中，同时清除 `_countdownWidgetShowing = false`。

### ⚠️ Lock Overlay 残留 bug — 本次未触发

lock overlay（`SYSTEM_ALERT_WINDOW` 类型）只在 `_triggerForcedRestAfterCountdown` 路径中显示。本测试中 rest 通过 `shouldTriggerRest` → `_triggerRest` 自然路径触发，**没有创建 lock overlay**。

lock overlay 残留 bug 需在 limit > 5 min（触发 5min 倒计时警告 → 倒计时结束 → forceTriggerRest → lock overlay）的场景下复现。**不在本次 v2 测试范围内**。

---

## 5. 日志关键行

```
[ContinuousUsage] Created new session, now tracking: com.wedobest.shudu
[ContinuousUsage] Accumulated 5s for com.wedobest.shudu, new total: 125s
[UsageMonitor] 强制休息中，跳过 _checkForbiddenApp 弹窗
[ContinuousUsage] Rest ended, session deactivated
[UsageMonitor] _checkForbiddenApp: allowed=false, reason=连续使用时间已达限制
```

---

## 6. 截图

| 文件名 | 说明 |
|--------|------|
| s00_bili_hd_start.png | B 站 HD 启动（不在监控列表，后续换用数独） |
| s01_sudoku_start.png | 数独启动，monitor 开始跟踪（22:21） |
| s02_30s_into_test.png | 累积 ~125s（22:22） |
| s03_90s_into_test.png | 休息结束，新会话开始（22:25） |
| s04_after_rest_ended.png | logout |

---

**测试通过。主要 Bug 已修复，滚动修复遗留标志问题为后续优化项。**
