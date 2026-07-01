# 修复禁用弹窗关闭后立刻又弹出（基于正确代码 v2 重写版）

## TL;DR
> **Summary**: 修复连续使用限时结束→禁用弹窗弹出后，用户关闭弹窗，5 秒后又被弹出的 bug。根因不是"倒计时在后台继续"，而是 5 秒轮询（`UsageMonitorService._syncAndCheck`）每次都重新触发 `_checkForbiddenApp`/`_checkAndTriggerRest` → `checkAndShowForbiddenReminder`，而 `checkAndShowForbiddenReminder` 对 `continuous_usage_limit`（hard limit）**同时绕过** `isOverlayActive` 检查和 `_forbiddenAppTracker.shouldShowReminder` 冷却检查；`OverlayStateManager` 仅有 2 秒 dedup 窗口（短于 5 秒轮询周期）；且 `_handleCountdownEnded` 在原生兜底路径已显示锁定弹窗时**未调用 `forceTriggerRest`**——下次轮询 `getStatus()` 仍返回 `atLimit`，触发新循环。
>
> **Deliverables**:
> - 修复 1：`lib/core/services/overlay_state_manager.dart` 新增"每包名锁定弹窗关闭冷却"机制（30s 拒绝同包名 lock overlay 重弹）
> - 修复 2：`lib/core/services/usage_monitor_service.dart` 的 `_handleCountdownEnded` 在原生兜底显示锁定弹窗时**也**调用 `forceTriggerRest`（写 `restEndTime` 入库），防止下一轮询重新触发
> - 真机回归测试（v2 包名 `com.qiaoqiao.qiaoqiao_companion_02`，设备 `M2105K81AC`）+ 关键节点截图 + 测试报告
> **Effort**: Short
> **Parallel**: NO（5 秒测试用例是串行的，但代码修改可同时进行；构建→安装→测试必须串行）
> **Critical Path**: T1 修 OverlayStateManager → T2 修 _handleCountdownEnded → T3 编译 v2 → T4 安装 v2 → T5 配置测试参数 → T6 真机回归测试 → T7 恢复参数 → T8 测试报告

## Context

### Original Request
> 目前已经连接上了真实的设备。目前设备上安装了两个 app，需要测试这个 v2 的 app，app.applicationId=com.qiaoqiao.qiaoqiao_companion_02，目前 app 在打开限制的 app，连续使用限时结束后，弹出禁用的弹窗（进行倒计时），此时 widget 没有弹出，倒计时结束后，我点击关闭了这个弹窗，之后很快又弹出这个禁用弹窗，感觉 widget 虽然没有弹出，实际是时间是一直在倒计时计算的，所以才会很快弹出禁用的弹窗，帮我修复次问题，并通过真实设备进行测试验证，关键的点进行截图并生成最终测试报告。必须是验证通过才结束。

### Interview Summary
- 修复范围：**仅修"关闭后立刻再弹"**（用户明确）
- **不在范围**：5min widget 倒计时结束后未切换为休息倒计时显示（用户：超出本次任务）
- 目标包名：`com.qiaoqiao.qiaoqiao_companion_02`（v2）
- 项目根目录：**`D:\Developfile\baby-friends`**（用户修正：之前误用了 `baby-friends-main`）
- 真实设备：`M2105K81AC`（xiaomi, Android 12, API 31, id `8711b87c`）
- 必须真机测试 + 截图 + 报告，且**必须通过**

### 关键重新发现（基于正确项目代码的根因重分析）

**正确项目（`D:\Developfile\baby-friends\qiaoqiao_companion`）相比旧 `baby-friends-main` 已有大量重构：**
- 新增 `lib/core/services/overlay_state_manager.dart`：集中式弹窗状态管理器，含优先级队列、`_acquireLock` 串行化、2 秒 `_dedupWindowMs` 去重、hard limit 抢占
- `usage_monitor_service.dart` 已引入：`_lastRestCountdownShownAt`（10s dedup）、`_forceRestInProgress`、`_countdownEnding`、`_countdownWidgetShowing`、`_stopwatchWidgetShowing` 标志；`forceTriggerRest`（幂等守卫）、`checkRestEnded`（会话结束自动 deactivate）；`isCurrentlyResting()` / `getActiveSession()` / `updateSession()` 公共方法
- `continuous_usage_service.dart`：`getStatus()` 在 `session.isInRest` 时直接返回 `inRest`（不再计算 remaining）
- `reminder_service.dart` 构造签名改为 `ReminderService(this._ref, this._overlayManager)`，所有弹窗都走 `_overlayManager.requestOverlay()`
- `OverlayChannel.kt` 原生侧：倒计时 widget 改用挂钟（`countdownWallClockStartMs`+`countdownTotalMs`）、倒计时结束**原生侧直接显示 lock overlay 兜底**、lock overlay 按钮可点击性由挂钟控制（`lockOverlayRestEndTime`）、`lastFallbackLockTimeMs` 2 秒窗口去重

### Metis Review (self-derived since background task 未返回结果)
- **CRITICAL — A1 方案失败**：单纯清空 `restEndTime` 不够，会形成新循环（用户已明确范围外，未采用）
- **CRITICAL — 通知回调 vs 轮询竞态**：5 秒轮询同步运行；必须在 Dart 侧（per-package cooldown）设防，原生侧 2 秒 `lastFallbackLockTimeMs` 仅对原生兜底路径有效
- **HIGH — 测试设置**：`limitMinutes` 需临时改为 1，测试完成后恢复原值（30 分钟）
- **HIGH — 测试期间 rest 配置**：必须 `restMinutes=0` 让 lock overlay 按钮**立即可关闭**（否则 `lockOverlayRestEndTime=now+restSeconds` 用户关闭按钮被原生忽略）
- **HIGH — 修改入口**：通过修改 DB 中 `continuous_usage_settings` 表（不要走家长模式 UI，避免家长密码未知阻塞测试）
- **MEDIUM — `_checkForbiddenApp` + `_checkAndTriggerRest` 双触发**：T1 修复 `OverlayStateManager.requestOverlay` 内部冷却，两条路径都受益
- **MEDIUM — `_handleCountdownEnded` 修复是 T2 配套**：用户说 widget 不显示，但 T2 修复可堵住"未来 widget 显示 + 原生兜底"的边缘路径
- **LOW — 5min widget 不显示**：本计划**不修**（用户明确范围外），仅在 plan 内记录为"已知未修复"

## Work Objectives

### Core Objective
修复禁用弹窗关闭后 5 秒内再次弹出的 bug，保持其他现有逻辑（5min widget 逻辑、强制休息机制、`OverlayStateManager` 优先级、native 兜底机制）不变。

### Deliverables
1. `lib/core/services/overlay_state_manager.dart`：新增 `_lastLockDismissedAt` Map + `_lockDismissCooldownSeconds=30` 常量 + `onOverlayDismissed` 记录时间戳 + `requestOverlay` 入口冷却检查
2. `lib/core/services/usage_monitor_service.dart`：`_handleCountdownEnded` 在原生兜底分支也调用 `forceTriggerRest` 写 `restEndTime` 入库
3. APK 构建产物 `build/app/outputs/flutter-apk/app-debug.apk`
4. 真机测试截图（关键节点）保存至 `.omo/evidence/fix-forbidden-overlay/`
5. 测试报告 `.omo/evidence/fix-forbidden-overlay/test-report.md`

### Definition of Done (verifiable conditions)
- [ ] `cd D:\Developfile\baby-friends\qiaoqiao_companion && flutter build apk --debug` 成功生成 APK
- [ ] `adb -s 8711b87c install -r build/app/outputs/flutter-apk/app-debug.apk` 安装成功
- [ ] 设备上 v2 包名仍是 `com.qiaoqiao.qiaoqiao_companion_02`（`adb shell pm list packages | grep qiaoqiao` 验证）
- [ ] 临时配置 `continuous_usage_settings.limitMinutes=1, restMinutes=0`（DB 直写，不走家长模式 UI）
- [ ] 添加一个测试用被监控 app（如果当前没有）
- [ ] 打开被监控 app 等待 ~65 秒，锁定弹窗出现
- [ ] 点击"知道了"按钮关闭弹窗（**restMinutes=0 时按钮立即可点**）
- [ ] 关闭后静默 ≥ 35 秒（覆盖 5s 轮询 + 30s 冷却），**弹窗不重弹**
- [ ] 截图保存：测试前 / 弹窗出现 / 用户关闭弹窗 / 关闭后 30s 无重弹
- [ ] 测试完成后 `continuous_usage_settings` 恢复 `limitMinutes=30, restMinutes=5`（生产默认）
- [ ] 测试报告 `.omo/evidence/fix-forbidden-overlay/test-report.md` 包含：问题描述、根因、修改文件清单（含行号 diff 摘要）、测试步骤、截图引用、结论

### Must Have
- 修改 2 个 Dart 源文件（`overlay_state_manager.dart` + `usage_monitor_service.dart`）
- 真机测试通过（v2 包名，`M2105K81AC`）
- 至少 4 张关键截图（前置状态 / 弹窗 / 关闭 / 30s 后无重弹）
- 测试报告含根因 + 修改清单 + 测试结果

### Must NOT Have (guardrails)
- **不要修改 5min widget 显示逻辑**（用户明确范围外）
- **不要清空 `restEndTime` 数据库字段**（会触发新循环，Metis CRITICAL-1）
- **不要修改 `getStatus()` 状态机逻辑**（影响面太大）
- **不要修改 `_checkAndTriggerRest` / `_checkForbiddenApp` 触发逻辑**（不是问题源头）
- **不要修改 `forbidden_app_tracker.dart` 现有递进式提醒逻辑**（前 3 次 2min/1min/30s 间隔是有意设计）
- **不要触碰 v1 包名（`_01`）的任何代码路径**
- **不要新增桌面 AppWidgetProvider**（项目中不存在，超范围）
- **不要修改数据库 schema**（migrations 风险高）
- **不要删除现有打印日志**（测试时需要日志辅助定位）
- **不要禁用打印日志**
- **不要硬编码家长密码**（测试配置走 DB 直写，绕过家长模式 UI）
- **不要修改 `OverlayChannel.kt`**（Dart 侧修复已足够；原生 2s `lastFallbackLockTimeMs` 不动）
- **不要修改 v1 路径或 `app.applicationId` 切换配置**（`local.properties` 与 `build.gradle.kts` 已正确指向 v2，不需要改动）

## Verification Strategy
> **ZERO HUMAN INTERVENTION** - 所有验证 agent 自动执行。

- **Test decision**: 设备驱动端到端测试（Dart 端逻辑变更不做单元测试，agent 实机回归足够）
- **QA policy**: 每个任务含 agent-executable 场景（happy + failure 路径）
- **Evidence**: `.omo/evidence/fix-forbidden-overlay/` 目录
  - `task-{N}-{slug}.{ext}` 按任务名
  - `screenshot-{timestamp}.png` 真机截图
  - `test-report.md` 最终报告

## Execution Strategy

### Parallel Execution Waves
> 单文件修改可并行；构建/安装/测试/报告严格串行（依赖前序产出）。

Wave 1: 代码修改（可并行）
- T1: OverlayStateManager per-package dismiss cooldown
- T2: _handleCountdownEnded forceTriggerRest guard

Wave 2: 构建 + 安装（串行）
- T3: 构建 debug APK
- T4: 安装 v2 到设备

Wave 3: 测试配置 + 设备测试（串行，强依赖 T4）
- T5: 临时 DB 写入 limitMinutes=1, restMinutes=0 + 添加被监控 app
- T6: 端到端真机回归测试（等待 65s → 弹窗 → 关闭 → 等待 35s → 验证无重弹 → 截图）

Wave 4: 恢复 + 报告（串行，强依赖 T6 通过）
- T7: 恢复生产配置（limitMinutes=30, restMinutes=5）+ 移除测试用被监控 app
- T8: 编写测试报告

### Dependency Matrix
| Task | Blocks | Blocked By |
|------|--------|------------|
| T1 | T3 | - |
| T2 | T3 | - |
| T3 | T4 | T1, T2 |
| T4 | T5, T6 | T3 |
| T5 | T6 | T4 |
| T6 | T7, T8 | T5 |
| T7 | T8 | T6 |
| T8 | F1-F4 | T6, T7 |

### Agent Dispatch Summary
- Wave 1: 2 tasks, category=`unspecified-high` (Dart 修改，需阅读相关方法)
- Wave 2-4: 1 task at a time, category=`unspecified-high` (实机操作 + 截图)

## TODOs

### Wave 1: 代码修改

- [x] T1. OverlayStateManager 添加每包名锁定弹窗关闭冷却

  **What to do**:
  1. 在 `lib/core/services/overlay_state_manager.dart` 中：
     - 类顶部新增字段 `final Map<String, DateTime> _lastLockDismissedAt = {};`
     - 类顶部新增常量 `static const int _lockDismissCooldownSeconds = 30;`
     - 修改 `onOverlayDismissed(String packageName)` 方法，在原有 `_state=idle; _currentRequest=null;` 之后增加：
       ```dart
       if (packageName.isNotEmpty) {
         _lastLockDismissedAt[packageName] = DateTime.now();
       }
       ```
     - 在 `requestOverlay(OverlayRequest request)` 方法的**最开头**（在 `await _acquireLock();` 之后、`try` 块内、原有去重检查 `_isDuplicate(request)` 之前）增加：
       ```dart
       // 每包名锁定弹窗关闭冷却：用户刚关闭 lock 弹窗后 N 秒内，
       // 同包名的 lock overlay 重新请求被丢弃，避免 5s 轮询重弹
       if (request.type == OverlayType.lock &&
           request.packageName != null &&
           request.packageName!.isNotEmpty) {
         final lastDismissed = _lastLockDismissedAt[request.packageName];
         if (lastDismissed != null &&
             DateTime.now().difference(lastDismissed).inSeconds <
                 _lockDismissCooldownSeconds) {
           print('[OverlayState] Lock dismiss cooldown active for '
               '${request.packageName}, '
               'elapsed=${DateTime.now().difference(lastDismissed).inSeconds}s');
           return false;
         }
       }
       ```

  **Must NOT do**:
  - 不要修改 `_isDuplicate`、`_isHardLimit`、`_acquireLock`/`_releaseLock` 逻辑
  - 不要修改 `requestOverlay` 其他分支（优先级判断、`_dismissCurrentInternal`、`_showOverlay`）
  - 不要在冷却期内影响 `OverlayType.reminder` 或 `OverlayType.countdown` 类型（只阻断 `lock`）
  - 不要修改 `dismissCurrent`/`onCountdownEnded`/`dismissCountdown` 方法

  **Recommended Agent Profile**:
  - Category: `unspecified-high` - Reason: 需精确理解 OverlayStateManager 现有锁定语义，插入位置不能破坏优先级/抢占逻辑
  - Skills: [] - 无需特殊 skill，dart 修改 + flutter analyze
  - Omitted: `visual-engineering` - 无 UI 修改

  **Parallelization**: Can Parallel: YES | Wave 1 | Blocks: T3 | Blocked By: -

  **References**:
  - Pattern: `D:\Developfile\baby-friends\qiaoqiao_companion\lib\core\services\overlay_state_manager.dart:60-110` (`requestOverlay` 现有去重/优先级判断)
  - Pattern: `D:\Developfile\baby-friends\qiaoqiao_companion\lib\core\services\overlay_state_manager.dart:131-135` (`onOverlayDismissed` 现有实现)
  - Caller: `D:\Developfile\baby-friends\qiaoqiao_companion\lib\core\services\reminder_service.dart:178-235` (`checkAndShowForbiddenReminder` 调用 `requestOverlay`)
  - Type: `OverlayType` enum in same file: `lock`/`reminder`/`countdown` 三选一

  **Acceptance Criteria**:
  - [ ] `flutter analyze lib/core/services/overlay_state_manager.dart` 无新增 error
  - [ ] 新增字段 `_lastLockDismissedAt` 和常量 `_lockDismissCooldownSeconds` 已添加
  - [ ] `onOverlayDismissed` 在包名非空时写入时间戳
  - [ ] `requestOverlay` 在冷却检查点返回 `false`（不抛错）
  - [ ] 冷却**仅**对 `OverlayType.lock` 生效

  **QA Scenarios**:
  ```
  Scenario: 关闭锁定弹窗后 30s 内同包名 lock 请求被拒
    Tool: Bash + adb logcat
    Steps:
      1. 触发 lock overlay（被监控 app 超时）→ `requestOverlay(OverlayType.lock, packageName=X)` 返回 true
      2. 用户关闭 → `onOverlayDismissed(X)` 记录 `_lastLockDismissedAt[X]=now`
      3. 5s 后再调 `requestOverlay(OverlayType.lock, packageName=X)`
      4. 期望：返回 false，日志 `[OverlayState] Lock dismiss cooldown active for X, elapsed=5s`
    Expected: 第二次请求被丢弃，无新 overlay 出现
    Evidence: .omo/evidence/fix-forbidden-overlay/task-T1-cooldown-log.txt

  Scenario: 30s 后冷却解除，重新允许 lock 弹窗
    Tool: Bash
    Steps:
      1. 同上 1-2 步
      2. sleep 31s
      3. 再调 `requestOverlay(OverlayType.lock, packageName=X)`
      4. 期望：返回 true（超过 30s 冷却）
    Expected: 第三次请求通过，overlay 正常显示
    Evidence: .omo/evidence/fix-forbidden-overlay/task-T1-cooldown-expire-log.txt

  Scenario: 冷却不影响 reminder/countdown 类型
    Tool: Bash
    Steps:
      1. 触发 lock overlay → 关闭 → `_lastLockDismissedAt[X]=now`
      2. 5s 后调 `requestOverlay(OverlayType.reminder, packageName=X)` 或 `OverlayType.countdown`
      3. 期望：正常显示（不受冷却影响）
    Expected: reminder/countdown 正常显示
    Evidence: .omo/evidence/fix-forbidden-overlay/task-T1-other-types-ok-log.txt

  Scenario: 不同包名不受彼此冷却影响
    Tool: Bash
    Steps:
      1. 包 X 关闭 lock → `_lastLockDismissedAt[X]=now`
      2. 5s 后包 Y（不同包名）调 `requestOverlay(OverlayType.lock, packageName=Y)`
      3. 期望：正常显示
    Expected: 包 Y 不受包 X 冷却影响
    Evidence: .omo/evidence/fix-forbidden-overlay/task-T1-different-pkg-log.txt
  ```

  **Commit**: YES | Message: `fix(overlay): per-package lock dismiss cooldown to prevent 5s polling re-pop` | Files: `qiaoqiao_companion/lib/core/services/overlay_state_manager.dart`

- [x] T2. _handleCountdownEnded 在原生兜底分支也调用 forceTriggerRest

  **What to do**:
  1. 在 `lib/core/services/usage_monitor_service.dart` 中定位 `_handleCountdownEnded` 方法（位于该文件中段，紧接 `_showCountdownFromRemaining` 之后）
  2. 找到以下分支：
     ```dart
     // 去重：如果原生兜底路径已经显示了锁定弹窗，不再重复创建
     if (await OverlayService.isOverlayShowing()) {
       print('[UsageMonitor] Native fallback already showed lock overlay,'
           ' 保持 widget 状态标志，�?rest 结束时统一清除');
       // 不清�?_countdownWidgetShowing / _stopwatchWidgetShowing�?
       // 否则下一个轮询会重建 widget（此时原生侧正在处理 rest�?
       return;
     }
     ```
  3. 将该分支内的 `return;` 之前增加：
     ```dart
     // 即使原生侧已显示锁定弹窗，仍需写 restEndTime 入库，否则
     // 下一轮询 getStatus() 仍返回 atLimit，触发新的 checkAndShowForbiddenReminder
     final settingsForRest = _ref.read(continuousUsageSettingsProvider);
     await _continuousUsageService.forceTriggerRest(
       minTotalDurationSeconds: settingsForRest.limitMinutes * 60,
     );
     ```
  4. 保持 `return;` 在最后（不再重复创建 Flutter 侧 overlay，仅写 rest 状态）

  **Must NOT do**:
  - 不要修改 `_handleCountdownEnded` 中其他逻辑（`isInRest` 检查、`_overlayManager.onCountdownEnded()` 调用、`hideCountdownWidget`、`_clearCountdownState`）
  - 不要修改 `_triggerForcedRestAfterCountdown` 方法（该方法本身就是正确路径，不需要改）
  - 不要修改 `forceTriggerRest` 内部（已有幂等守卫，再调一次不会出错）
  - 不要修改 `_countdownWidgetShowing`/`_stopwatchWidgetShowing` 标志的清空逻辑

  **Recommended Agent Profile**:
  - Category: `unspecified-high` - Reason: 涉及会话状态机修复，需精确定位 `return;` 位置
  - Skills: []
  - Omitted: `visual-engineering` - 无 UI 修改

  **Parallelization**: Can Parallel: YES | Wave 1 | Blocks: T3 | Blocked By: -

  **References**:
  - Pattern: `D:\Developfile\baby-friends\qiaoqiao_companion\lib\core\services\usage_monitor_service.dart` 中 `_handleCountdownEnded` 方法（搜索 `Native fallback already showed lock overlay`）
  - Method: `forceTriggerRest({int? minTotalDurationSeconds})` in `D:\Developfile\baby-friends\qiaoqiao_companion\lib\core\services\continuous_usage_service.dart`（已有幂等守卫，再调安全）
  - Provider: `continuousUsageSettingsProvider` in `D:\Developfile\baby-friends\qiaoqiao_companion\lib\shared\providers\continuous_usage_provider.dart`（提供 `limitMinutes`）

  **Acceptance Criteria**:
  - [ ] `flutter analyze lib/core/services/usage_monitor_service.dart` 无新增 error
  - [ ] 原生兜底分支（`isOverlayShowing()` 为 true）内 `forceTriggerRest` 被调用
  - [ ] `return;` 仍在最后
  - [ ] 不影响 widget 标志的保留逻辑

  **QA Scenarios**:
  ```
  Scenario: 原生兜底显示锁定弹窗后，restEndTime 被写入 DB
    Tool: Bash + adb shell sqlite3
    Steps:
      1. 制造场景：widget 显示 → 倒计时结束 → 原生 showLockOverlayFromFallback() 触发
      2. 等待 _handleCountdownEnded 的 isOverlayShowing() 分支执行
      3. 查 DB：adb shell run-as com.qiaoqiao.qiaoqiao_companion_02 sqlite3 databases/qiaoqiao.db "SELECT rest_end_time FROM continuous_sessions WHERE is_active=1"
      4. 期望：rest_end_time 不为空（已写入未来时间戳）
    Expected: restEndTime 写入成功
    Evidence: .omo/evidence/fix-forbidden-overlay/task-T2-rest-written-db.txt

  Scenario: 写入 restEndTime 后下一轮询不再触发新弹窗
    Tool: Bash + adb logcat
    Steps:
      1. 同上场景
      2. 等 10s（2 个轮询周期）
      3. 检查 logcat 中是否还有 [UsageMonitor] 触发强制休息 / 检查 _checkForbiddenApp 输出
      4. 期望：_checkForbiddenApp 早期 return (inRest)，_checkAndTriggerRest 返回 false
    Expected: 无新 lock 弹窗
    Evidence: .omo/evidence/fix-forbidden-overlay/task-T2-no-repop-log.txt
  ```

  **Commit**: YES | Message: `fix(usage_monitor): also write restEndTime when native fallback shows lock overlay` | Files: `qiaoqiao_companion/lib/core/services/usage_monitor_service.dart`

### Wave 2: 构建 + 安装

- [x] T3. 构建 v2 debug APK

  **What to do**:
  1. 打开 PowerShell 终端，`workdir=D:\Developfile\baby-friends\qiaoqiao_companion`
  2. 执行：`flutter clean`（确保无旧构建产物干扰）
  3. 执行：`flutter pub get`（拉取最新依赖）
  4. 执行：`flutter analyze`（必须无 error，允许现有 warning）
  5. 执行：`flutter build apk --debug`（构建 debug APK，~2-3 分钟）
  6. 验证产物：`Test-Path 'D:\Developfile\baby-friends\qiaoqiao_companion\build\app\outputs\flutter-apk\app-debug.apk'` 返回 True
  7. 验证包名：使用 aapt 或 unzip + aapt 验证包名为 `com.qiaoqiao.qiaoqiao_companion_02`

  **Must NOT do**:
  - 不要构建 release APK（签名问题）
  - 不要修改 pubspec.yaml 版本号
  - 不要运行 `build_runner`（AGENTS.md 明示无 `.g.dart` 文件）

  **Recommended Agent Profile**:
  - Category: `quick` - Reason: 标准 flutter build 命令
  - Skills: []
  - Omitted: 所有领域 skill

  **Parallelization**: Can Parallel: NO | Wave 2 | Blocks: T4 | Blocked By: T1, T2

  **References**:
  - AGENTS.md: `qiaoqiao_companion/` 是 Flutter 子项目根
  - Command pattern: `flutter build apk --debug` 输出路径固定

  **Acceptance Criteria**:
  - [ ] APK 文件存在且大小 > 20MB（debug 含调试符号）
  - [ ] `aapt dump badging` 输出 `package: name='com.qiaoqiao.qiaoqiao_companion_02'`
  - [ ] `flutter analyze` 无新增 error

  **QA Scenarios**:
  ```
  Scenario: APK 构建成功且包名正确
    Tool: Bash
    Steps:
      1. cd D:\Developfile\baby-friends\qiaoqiao_companion
      2. flutter clean
      3. flutter pub get
      4. flutter build apk --debug
      5. Test-Path build/app/outputs/flutter-apk/app-debug.apk
      6. aapt dump badging build/app/outputs/flutter-apk/app-debug.apk | findstr package
    Expected: APK 存在，包名 = com.qiaoqiao.qiaoqiao_companion_02
    Evidence: .omo/evidence/fix-forbidden-overlay/task-T3-build-output.txt
  ```

  **Commit**: NO | (no source change in this task)

- [x] T4. 安装 v2 APK 到设备

  **What to do**:
  1. 执行：`adb -s 8711b87c install -r 'D:\Developfile\baby-friends\qiaoqiao_companion\build\app\outputs\flutter-apk\app-debug.apk'`
     （`-r` 保留数据，包括家长密码、设置等）
  2. 验证安装：`adb -s 8711b87c shell pm list packages | Select-String -Pattern 'qiaoqiao'`
     期望输出包含 `package:com.qiaoqiao.qiaoqiao_companion_01` 和 `package:com.qiaoqiao.qiaoqiao_companion_02`（两个都已安装）
  3. 启动 v2 app（用于让 service 起来）：`adb -s 8711b87c shell am start -n com.qiaoqiao.qiaoqiao_companion_02/.MainActivity`
  4. 等待 3 秒（service 启动）
  5. 验证 service：`adb -s 8711b87c shell dumpsys activity services com.qiaoqiao.qiaoqiao_companion_02 | Select-String -Pattern 'GuardService|MonitorForegroundService'`
     期望：至少一个 service 在 running

  **Must NOT do**:
  - 不要 `adb uninstall`（会清除家长密码、设置、监控配置）
  - 不要 `force-stop` 后再启动（保留 service 连续运行状态）

  **Recommended Agent Profile**:
  - Category: `quick` - Reason: 标准 adb install + verify
  - Skills: []

  **Parallelization**: Can Parallel: NO | Wave 2 | Blocks: T5, T6 | Blocked By: T3

  **References**:
  - Device: `M2105K81AC` id=`8711b87c`
  - v2 package: `com.qiaoqiao.qiaoqiao_companion_02`

  **Acceptance Criteria**:
  - [ ] `adb install -r` 返回 Success
  - [ ] v2 包名仍在 `pm list packages` 中
  - [ ] v2 app 启动后至少一个 service 在 running

  **QA Scenarios**:
  ```
  Scenario: v2 APK 安装成功且 v2 仍在设备上
    Tool: Bash
    Steps:
      1. adb -s 8711b87c install -r <apk-path>
      2. adb -s 8711b87c shell pm list packages | grep qiaoqiao
    Expected: 包含 com.qiaoqiao.qiaoqiao_companion_01 和 _02
    Evidence: .omo/evidence/fix-forbidden-overlay/task-T4-install-log.txt

  Scenario: v2 启动后 service 在运行
    Tool: Bash
    Steps:
      1. adb -s 8711b87c shell am start -n com.qiaoqiao.qiaoqiao_companion_02/.MainActivity
      2. sleep 3
      3. adb -s 8711b87c shell dumpsys activity services com.qiaoqiao.qiaoqiao_companion_02 | grep -E 'GuardService|MonitorForegroundService'
    Expected: 至少一个 service 出现
    Evidence: .omo/evidence/fix-forbidden-overlay/task-T4-service-running.txt
  ```

  **Commit**: NO

### Wave 3: 测试配置 + 设备测试

- [x] T5. 临时配置测试参数（DB 直写 + 添加测试被监控 app）

  **What to do**:
  1. **不修改家长模式**（避免家长密码未知阻塞），改用 DB 直写
  2. 找到 DB 文件位置：先查 `adb -s 8711b87c shell run-as com.qiaoqiao.qiaoqiao_companion_02 ls databases/` 或 `ls /data/data/com.qiaoqiao.qiaoqiao_companion_02/databases/`
     - 若 `run-as` 失败（生产构建无 debuggable），改用 root 或 adb pull + adb push
     - 备用：阅读 `lib/core/database/app_database.dart` 找 DB 名称
  3. **修改 continuous_usage_settings**：
     - 备份当前值：`SELECT * FROM continuous_usage_settings`
     - 临时 UPDATE：`UPDATE continuous_usage_settings SET limit_minutes=1, rest_minutes=0 WHERE id=1`（或对应 schema）
     - 若表/字段名不同（可能存在 `continuous_usage_setting` 单数命名），按实际 schema 调整
  4. **添加测试被监控 app**：
     - 检查当前被监控 app 列表：`SELECT * FROM monitored_apps`（如有）
     - 若已有一个测试友好的 app（系统 Settings `com.android.settings`），直接使用
     - 若无，添加 `com.android.settings` 到 monitored_apps 表：
       ```sql
       INSERT INTO monitored_apps (package_name, app_name, category, is_enabled, created_at, updated_at)
       VALUES ('com.android.settings', '设置', 'other', 1, strftime('%s','now')*1000, strftime('%s','now')*1000)
       ```
       （具体字段名以 schema 为准）
  5. 触发 v2 app 重新加载：重启 v2 app（不卸载）：`adb -s 8711b87c shell am force-stop com.qiaoqiao.qiaoqiao_companion_02` 然后 `am start ...MainActivity`
  6. 截图证据：DB 修改前/后状态

  **Must NOT do**:
  - 不要修改源码添加测试入口
  - 不要走家长模式 UI（家长密码未知）
  - 不要保留测试用被监控 app 到生产（任务 T7 恢复）
  - 不要修改 schema（migrations 风险）

  **Recommended Agent Profile**:
  - Category: `unspecified-high` - Reason: 需现场发现 DB schema + 字段名 + 时区处理
  - Skills: []

  **Parallelization**: Can Parallel: NO | Wave 3 | Blocks: T6 | Blocked By: T4

  **References**:
  - `lib/core/database/app_database.dart` 找 DB 名称和版本
  - `lib/core/database/daos/` 找 continuous_usage 和 monitored_apps 表 schema
  - 设备: `adb -s 8711b87c` 即可

  **Acceptance Criteria**:
  - [ ] `continuous_usage_settings` 表的 `limit_minutes=1, rest_minutes=0` 写入成功
  - [ ] `monitored_apps` 表至少含 1 个可测试 app（如 `com.android.settings`）
  - [ ] v2 app 重启后新配置生效（可通过打 logcat 验证 limit 读取）

  **QA Scenarios**:
  ```
  Scenario: DB 修改成功，limit_minutes=1, rest_minutes=0
    Tool: Bash + adb sqlite3
    Steps:
      1. 备份原值: SELECT * FROM continuous_usage_settings
      2. UPDATE continuous_usage_settings SET limit_minutes=1, rest_minutes=0
      3. 验证: SELECT * FROM continuous_usage_settings
    Expected: 字段值已更新
    Evidence: .omo/evidence/fix-forbidden-overlay/task-T5-db-config.txt

  Scenario: 重启 v2 app 后新 limit 生效
    Tool: Bash + adb logcat
    Steps:
      1. force-stop + start v2
      2. 触发被监控 app，60s 内 logcat 应出现 limit 相关日志
    Expected: 新 limit 生效
    Evidence: .omo/evidence/fix-forbidden-overlay/task-T5-restart-effective.txt
  ```

  **Commit**: NO (DB 状态变更，非源码)

- [x] T6. 端到端真机回归测试

  **What to do**:
  1. **状态前置**：
     - 设备唤醒：`adb -s 8711b87c shell input keyevent KEYCODE_WAKEUP`
     - 解锁（若需）：`adb -s 8711b87c shell input keyevent 82` 或 `input swipe ...`
     - 启动 v2 app：`adb -s 8711b87c shell am start -n com.qiaoqiao.qiaoqiao_companion_02/.MainActivity`
     - 截图 `screenshot-T6-01-pre-test.png`（记录测试前状态）
  2. **触发场景**：
     - 启动被监控 app（如 Settings）：`adb -s 8711b87c shell am start -n com.android.settings/.Settings`
     - **保持该 app 在前台 65 秒**（让连续使用时长达到 60s 限制）
     - 期间清空 logcat，等待结束后抓日志到 `.omo/evidence/fix-forbidden-overlay/task-T6-during-wait.txt`
  3. **期望：65s 后锁定弹窗出现**
     - 截图 `screenshot-T6-02-dialog-appeared.png`（用 `adb -s 8711b87c exec-out screencap -p > <file>`）
     - 日志应有 `[UsageMonitor] 触发强制休息` 和 `checkAndShowForbiddenReminder` 调用
  4. **关闭弹窗**：
     - 找到弹窗的"知道了"按钮坐标（一般屏幕中央偏下），点击
     - 用 `adb -s 8711b87c shell input tap <X> <Y>` 或 `uiautomator` 找元素
     - 截图 `screenshot-T6-03-after-dismiss.png`（确认弹窗已关闭）
  5. **静默 35 秒**（覆盖 5s 轮询 + 30s 冷却）：
     - 期间每 5s 截一次图（5-7 张），确认弹窗**不重弹**
     - `screenshot-T6-04-t5s.png`, `screenshot-T6-05-t15s.png`, `screenshot-T6-06-t25s.png`, `screenshot-T6-07-t35s.png`
  6. **最终验证**：
     - 35s 后无弹窗 → 截图 `screenshot-T6-08-final-no-repop.png`
     - 抓 logcat 验证 `_checkForbiddenApp` 早期 return (inRest) 或 `Lock dismiss cooldown active`
  7. **失败处理**：
     - 若 35s 内**任意时刻**弹窗重弹（即使是同一弹窗），测试失败
     - 立即截图 + 抓日志，报告失败

  **Must NOT do**:
  - 不要在测试中切换被监控 app（避免触发 `_handleContinuousUsageTransition` 干扰）
  - 不要修改源码（测试代码已定）
  - 不要 force-stop v2 app（会中断 5s 轮询）

  **Recommended Agent Profile**:
  - Category: `unspecified-high` - Reason: 长时序多步骤端到端测试，需精确控制时序
  - Skills: []

  **Parallelization**: Can Parallel: NO | Wave 3 | Blocks: T7, T8 | Blocked By: T5

  **References**:
  - 测试时序: 0s 启动 → 65s 等待 → 5s 关闭 → 35s 静默 → 验证
  - 截图命令: `adb -s 8711b87c exec-out screencap -p > .omo/evidence/fix-forbidden-overlay/screenshot-T6-NN-*.png`
  - 日志命令: `adb -s 8711b87c logcat -d -s flutter:* UsageMonitor:* OverlayState:* > <file>`

  **Acceptance Criteria**:
  - [ ] T+0s: 截图显示被监控 app 启动，无锁定弹窗
  - [ ] T+65s: 截图显示锁定弹窗出现（标题"时间结束"或类似）
  - [ ] T+65s 之后: 点击"知道了"按钮，截图显示弹窗消失
  - [ ] T+65s ~ T+100s (35s 内): 至少 4 张连续截图，**均显示弹窗未重弹**
  - [ ] logcat 显示 `[OverlayState] Lock dismiss cooldown active` 或 `强制休息中，跳过 _checkForbiddenApp 弹窗`

  **QA Scenarios**:
  ```
  Scenario: 关闭后 35s 内弹窗不重弹（HAPPY PATH — 核心修复验证）
    Tool: Bash + adb screencap + adb logcat
    Steps:
      1. 启动被监控 app
      2. sleep 65
      3. 截图（期望弹窗出现）
      4. 找"知道了"按钮坐标，input tap
      5. 截图（期望弹窗消失）
      6. for i in 5 10 15 20 25 30 35: sleep 5; 截图
      7. 抓 logcat 验证冷却日志
    Expected: 7 张静默期截图均无锁定弹窗
    Evidence: .omo/evidence/fix-forbidden-overlay/screenshot-T6-*.png + task-T6-final-log.txt

  Scenario: 35s 后弹窗可以重新出现（冷却解除，验证不过度）
    Tool: Bash
    Steps:
      1. 完成 happy path
      2. sleep 31 （让 _lastLockDismissedAt[X] 超过 30s）
      3. 观察是否重弹（应被 inRest 保护）
    Expected: 不在测试核心范围内，记录观察
    Evidence: .omo/evidence/fix-forbidden-overlay/task-T6-cooldown-expiry-observation.txt
  ```

  **Commit**: NO (test, no code change)

### Wave 4: 恢复 + 报告

- [x] T7. 恢复生产配置

  **What to do**:
  1. 恢复 `continuous_usage_settings`：
     - 从 T5 备份的 SQL 中 UPDATE 回生产默认值（`limit_minutes=30, rest_minutes=5`，若生产为其他值，按备份恢复）
     - SQL 示例：`UPDATE continuous_usage_settings SET limit_minutes=30, rest_minutes=5 WHERE id=1`
  2. 移除测试用被监控 app（若添加了 `com.android.settings`）：
     - `DELETE FROM monitored_apps WHERE package_name='com.android.settings'`
     - 仅当此 app **不是**用户原本监控的才删（可通过 backup 对比）
  3. 重启 v2 app 让新配置生效：`am force-stop` + `am start`
  4. 截图 `screenshot-T7-restored.png`（v2 设置界面截图证明已恢复，若需进入家长模式则跳过此步）
  5. DB 验证：`SELECT * FROM continuous_usage_settings` 和 `SELECT * FROM monitored_apps` 与备份一致

  **Must NOT do**:
  - 不要保留 `limit_minutes=1, rest_minutes=0` 到生产
  - 不要保留测试用被监控 app（除非是用户原有）

  **Recommended Agent Profile**:
  - Category: `quick` - Reason: 标准 DB restore
  - Skills: []

  **Parallelization**: Can Parallel: NO | Wave 4 | Blocks: T8 | Blocked By: T6

  **References**: T5 备份的 SQL 输出

  **Acceptance Criteria**:
  - [ ] `continuous_usage_settings.limit_minutes` 恢复为 30
  - [ ] `continuous_usage_settings.rest_minutes` 恢复为 5
  - [ ] `monitored_apps` 与 T5 前一致

  **QA Scenarios**:
  ```
  Scenario: DB 恢复成功
    Tool: Bash + adb sqlite3
    Steps:
      1. 读 T5 备份 SQL
      2. 执行恢复 UPDATE/DELETE
      3. 验证 SELECT 结果与备份一致
    Expected: 状态与 T5 前一致
    Evidence: .omo/evidence/fix-forbidden-overlay/task-T7-restore-db.txt
  ```

  **Commit**: NO

- [x] T8. 编写测试报告

  **What to do**:
  1. 写入 `.omo/evidence/fix-forbidden-overlay/test-report.md`，包含：
     - 测试环境（设备、包名、日期）
     - 问题描述（用户原话）
     - 根因（3 条：hard limit bypass、2s dedup 太短、原生兜底未写 restEndTime）
     - 修改文件清单（2 个 Dart 文件 + 行号 diff 摘要）
     - 测试步骤（6 步：配 limit、启 app、等 65s、关弹窗、静默 35s、验证）
     - 测试结果（8 张截图引用 + logcat 关键证据）
     - 结论（通过/不通过）
  2. 报告保存到 `.omo/evidence/fix-forbidden-overlay/test-report.md`
  3. 提交所有源码修改 + 报告

  **Must NOT do**:
  - 不要遗漏截图引用
  - 不要在报告里说"已修复"但实际测试未通过
  - 不要在测试未通过时强行打勾

  **Recommended Agent Profile**:
  - Category: `writing` - Reason: 文档编写
  - Skills: []

  **Parallelization**: Can Parallel: NO | Wave 4 | Blocks: F1-F4 | Blocked By: T7

  **References**:
  - 截图: `.omo/evidence/fix-forbidden-overlay/screenshot-T6-*.png`
  - 日志: `.omo/evidence/fix-forbidden-overlay/task-T*.txt`

  **Acceptance Criteria**:
  - [ ] 报告包含：问题描述、根因、修改清单、测试步骤、结果、结论
  - [ ] 至少 8 张截图引用
  - [ ] 报告 `.omo/evidence/fix-forbidden-overlay/test-report.md` 存在

  **QA Scenarios**:
  ```
  Scenario: 报告内容完整
    Tool: Bash (cat + grep)
    Steps:
      1. cat .omo/evidence/fix-forbidden-overlay/test-report.md
      2. grep -E '根因|修改文件|测试步骤|结论' .omo/evidence/fix-forbidden-overlay/test-report.md
    Expected: 4 个章节都存在
    Evidence: .omo/evidence/fix-forbidden-overlay/task-T8-report-grep.txt
  ```

  **Commit**: YES | Message: `docs(test): add test report for forbidden overlay rapid reshow fix` | Files: `.omo/evidence/fix-forbidden-overlay/test-report.md`

## Final Verification Wave (MANDATORY — after ALL implementation tasks)
> 4 review agents run in PARALLEL. ALL must APPROVE. Present consolidated results to user and get explicit "okay" before completing.
> **Do NOT auto-proceed after verification. Wait for user's explicit approval before marking work complete.**
> **Never mark F1-F4 as checked before getting user's okay.** Rejection or user feedback -> fix -> re-run -> present again -> wait for okay.

- [ ] F1. Plan Compliance Audit — oracle
- [ ] F2. Code Quality Review — unspecified-high
- [ ] F3. Real Manual QA — unspecified-high (+ 截图证据对比)
- [ ] F4. Scope Fidelity Check — deep

## Commit Strategy
- T1 + T2: 一次性提交（`fix: per-package lock dismiss cooldown + forceTriggerRest guard`）
- T8: 测试报告独立提交（`docs: test report`）
- 总计 2 个 commit
- 不创建分支（main 直接提交或按用户要求）

## Success Criteria
1. T1 修改无编译错误，OverlayStateManager 冷却逻辑就位
2. T2 修改无编译错误，_handleCountdownEnded 原生兜底分支也写 restEndTime
3. T3 v2 APK 构建成功，包名 `com.qiaoqiao.qiaoqiao_companion_02`
4. T4 v2 安装到设备 `M2105K81AC`
5. T5 测试配置就位（limitMinutes=1, restMinutes=0，被监控 app 已添加）
6. T6 端到端测试通过：关闭弹窗后 35 秒内**不重弹**
7. T7 生产配置恢复
8. T8 测试报告完整，含根因 + 修改清单 + 截图引用 + 结论
9. 4 个 Final Verification review 全部 APPROVE
10. 用户在 Final Wave 之后明确给"okay"批准

## 已知未修复问题（用户明确范围外）
- 5min 倒计时 widget 在某些场景下不显示（如 `alertsShown` 已含 `5min`、`limitSeconds <= 300` 等边界条件）。本次不修，留作后续任务。
- `dismissCountdown` 等方法中 `_lastLockDismissedAt` 未清理（仅在新 `onOverlayDismissed` 覆盖，长期累积可忽略；如需清理可在 `syncWithNative()` 中清空）。
