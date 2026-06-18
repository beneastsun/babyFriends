# Draft: 修复连续使用限时Widget未弹出 + 倒计时残留

## 原始需求（用户原话）
> 设备上安装了两个app,需要测试这个v2的app  app.applicationId=com.qiaoqiao.qiaoqiao_companion_02
> 目前app在打开限制的app，连续使用限时结束后，弹出禁用的弹窗（进行倒计时），此时wedgit没有弹出
> 倒计时结束后，我点击关闭了这个弹窗，之后很快又弹出这个禁用弹窗
> 感觉wedgit虽然没有弹出，实际是时间是一直在倒计时计算的，所以才会很快弹出禁用的弹窗
> 帮我修复次问题，并通过真实设备进行测试验证，关键的点进行截图并生成最终测试报告
> 必须是验证通过才结束

## 探索结果（待回填）

### Task bg_6b8a8862 — continuous usage session 逻辑
（等待回填）

### Task bg_b88264bb — Widget 实现
（等待回填）

### Task bg_49a0e79e — 锁定弹窗流程
（等待回填）

### Task bg_9233a500 — 设备/构建状态
（等待回填）

## 关键假设（已探索验证）
- 倒计时在原生 Android 侧（OverlayChannel.showCountdownWidget）由 ValueAnimator 驱动
- 5秒轮询在 Flutter UsageMonitorService（Timer.periodic 5s）→ 触发 Dart 端逻辑
- Flutter 弹窗关闭只调 `hideOverlay()`，**未**通知 Dart 端 `recordDismissal`（仅在原生 setOnClickListener 调 notifyDismissed→onOverlayDismissed 回调）
- 数据库会话（ContinuousSession）的 `restEndTime` 设置后从未清零
- `_checkAndTriggerRest` 5秒一次 + `isOverlayShowing` 检测只能防"重复创建弹窗"，无法防"用户关闭后下一轮再弹"

## Root Cause (已定位)

### Bug: 关闭禁用弹窗后立刻再弹

**链路**:
1. 5min widget 倒计时结束 → `onEnded` 回调 → `_triggerForcedRestAfterCountdown`
2. → `shouldTriggerRest()` → `getStatus()` 返回 `atLimit` (因为 restEndTime 还没设) → `_triggerRest()` 设置 `restEndTime` → 返回 `atLimit`
3. → `checkAndShowForbiddenReminder` 弹出禁用弹窗（10min 倒计时）
4. 用户关闭弹窗 → 原生 `notifyDismissed` → Dart `onOverlayDismissed` 回调 → `_forbiddenAppTracker.recordDismissal(pkg)` 
5. **但** `_forbiddenAppTracker` 只是 `forbidden_app_tracker.dart` 里的内存 Map，**与 `restEndTime` 完全无关**！
6. 5秒后下次轮询 → `_checkRules` → `_checkAndTriggerRest` → `shouldTriggerRest()` → `getStatus()` 返回 `inRest` (因为 restEndTime 还有效) → 返回 true → 再次显示禁用弹窗
7. 循环：用户关闭 → 5秒后 → 再次弹 → 关闭 → 5秒后 → 再弹...

**根因**:
- `recordDismissal` 只更新 `forbiddenAppTracker.reminderCount`，**没有调用 `clearRestEndTime` 或结束休息**
- 用户在休息期间被弹窗持续骚扰（即使禁用的 app 已退出）
- 设计上没有"用户主动提前结束休息"的概念

### 关于"5min widget 倒计时结束后 widget 没有切换为休息倒计时" — 用户已确认本次**不在修复范围**

## 修复方案

### 主修复 (方向A: 范围小)
**目标**: 用户关闭禁用弹窗后，本会话**不再被强制骚扰**。可选项：
- **A1**: 用户关闭 = 提前结束本轮休息 → 清空 `restEndTime` → 会话从 `inRest` 变回 `atLimit` → 但下次进入监控 app 仍会被 `_checkForcedRest` 拦截（因为总时长仍超额）→ 仍可能弹
- **A2**: 用户关闭 = 接受"我需要继续休息" → 记录 `userAcceptedRestAt = now` → `checkAndShowForbiddenReminder` 检查"若 X 秒内刚被关闭过则不重弹" → 10分钟 `restEndTime` 后才允许重弹
- **A3 (推荐)**: A1+A2 混合 — 关闭即结束本轮强制休息 + 加入"刚被关闭 N 秒内不重弹"的双重保险

### 推荐实现路径 (A3)
1. **`lib/core/services/continuous_usage_service.dart`**: 新增 `endRest()` 方法，调用 `clearRestEndTime` 更新数据库
2. **`lib/core/services/forbidden_app_tracker.dart`**: 新增 `recordDismissalAndEndRest(packageName, endRest: bool)` — 当 `bypassCooldown` 规则（如 continuous_usage_limit/forced_rest）下，关闭时调用 `endRest()`
3. **`lib/core/services/reminder_service.dart`** (`checkAndShowForbiddenReminder`): 对 `bypassCooldown` 类规则，关闭时调用新方法结束休息
4. **新增防重弹冷却** (Dart 端 + 原生端 都要): 
   - 原生 `OverlayChannel.kt`: 新增 `lastDismissTimes: Map<String, Long>`，每次 `notifyDismissed` 时记录
   - 原生 `showOverlay`: 对 `forbidden_dismissible/forbidden_locked/lock` 类型，若 `now - lastDismissTimes[pkg] < cooldownMs` (默认 30s) 则拒绝创建弹窗
   - 同步给 Dart 端 (`isOverlayShowing` + 新增 `getLastDismissTime`)
5. **用户主动结束休息时的处理**: 
   - 关闭禁用弹窗 → 调用 `endRest()` → `restEndTime` 清空
   - 关闭后用户停留在 launcher，不应再弹
   - 用户再次进入监控 app → 仍会触发 atLimit 状态 → 弹禁用弹窗（这是正常行为，不是 bug）

### 不修复的部分 (用户已确认)
- 5min widget 倒计时结束后未切换为休息倒计时显示 — 保持当前行为
- 用户体验优化 (如 widget 持续显示) — 不在范围

## 验证策略 (必须在真实设备上)
- 设备：M2105K81AC (id: 8711b87c)
- 包名：v2 = `com.qiaoqiao.qiaoqiao_companion_02` (待用户告知切包名方法)
- 测试方法：临时把 `continuous_usage` 的 `limitMinutes` 设为 1 分钟 → 打开监控 app → 等 1 分钟 → 5min widget 弹出 → 等 5min 倒计时结束 → 禁用弹窗弹出 (10min 倒计时) → 点击关闭 → **验证 60 秒内不再弹** → 验证 60 秒后允许重弹 (如果用户再次进入监控 app)
- 截图：每个关键节点截图存到 `.omo/evidence/`
- 报告：`.omo/plans/fix-continuous-usage-widget-countdown.md` 包含完整测试结果

## 待澄清（Open Questions）
- [ ] Widget 应在何时展示？是"启动时存在"还是"超时时也更新内容"？
- [ ] 关闭弹窗后预期行为是：A) 立即允许使用；B) 启动一个冷却期；C) 仅清除当前弹窗，下次启动再判断？
- [ ] 修复方向：只修"关闭后不再立刻弹"，还是同时修"widget 显示"？

## 范围
- INCLUDE: 修复弹窗残留逻辑 + 确保 widget 渲染链路 + 真机回归测试 + 关键截图 + 报告
- EXCLUDE: 重新设计整套时长/限制规则系统（除非是阻塞 root cause）
- EXCLUDE: 第一次集成 widget 的全新引导流程（仅验证现有 widget 链路能正常更新）

## 验证策略
- 设备：已连接的真实 Android 设备
- 包名：com.qiaoqiao.qiaoqiao_companion_02（v2）
- 测试场景：
  1. 设置一个非常短的连续使用限时（便于测试），例如 1 分钟
  2. 打开被限制的 app，等待限制触发
  3. 观察 widget 是否出现
  4. 倒计时结束后关闭弹窗
  5. 等待 5+ 秒验证弹窗是否再次出现
  6. 重复关闭 2-3 次确认不会反复触发
- 截图：触发时、widget 状态、关闭后、关闭后 10s、再触发（如有）
- 报告：.omo/evidence/ 目录归档截图与日志，.omo/plans/ 目录下放最终测试报告
