# 修复 ANR/卡顿问题 — 系统优化计划

## TL;DR
> **Summary**: `UsageMonitorService` 每5秒轮询执行全量数据同步（查询UsageEvents、获取App图标Base64、删除重建数据库），导致主线程过载、UI冻结。本计划分4个Wave逐步消除所有卡顿根因。
> **Deliverables**: 
> - 轮询间隔优化（5s→30s）  
> - 全量同步改为增量更新  
> - Native侧查询范围缩小 + 去掉图标Base64  
> - `OverlayStateManager` 锁机制修复  
> - Provider更新频率降低  
> - UI响应恢复，ANR消失
> **Effort**: Medium（3-5天）
> **Parallel**: YES — 2 waves (Wave-1 并行, Wave-2 依赖 Wave-1)
> **Critical Path**: 轮询间隔调整 → 全量同步改为增量 → 验证卡顿消除 → Native侧优化

## Context
### Original Request
App 经常卡顿、提示无响应，当前处于卡死状态。连接着真实 Android 设备（小米平板）。

### Interview Summary
通过代码审查发现 5 个根因：
1. **主因**: `UsageMonitorService._syncAndCheck()` 每5秒执行全量数据同步（DB删除重建、Native全量查询），主线程阻塞
2. **Native侧**: `getCurrentForegroundApp()` 查询2小时UsageEvents；`queryUsageStats()` 获取所有App图标Base64
3. **锁竞态**: `OverlayStateManager._acquireLock()` 存在活锁/死锁风险
4. **Provider风暴**: 每5秒 `invalidate` 两个 Provider，触发UI重建
5. **无并发**: 所有操作在主 Isolate 执行，无 `compute()` 或 `Isolate`

### Metis Review (gaps addressed)
- 确认轮询间隔是首要修复项
- Native侧 `getAppIconBase64()` 是隐藏性能杀手
- 锁修复需同时考虑并发安全性

## Work Objectives
### Core Objective
消除应用卡顿和 ANR，使 5 秒轮询不再阻塞 UI 线程

### Deliverables
- `UsageMonitorService` 轮询间隔从 5s 延长
- `_syncTodayUsageFromSystem()` 改为增量同步
- `UsageStatsChannel` 去掉图标Base64、缩小查询范围
- `OverlayStateManager._acquireLock()` 锁机制修复
- Provider 更新频率降低

### Definition of Done (verifiable conditions with commands)
```bash
# 1. 构建通过
cd qiaoqiao_companion && flutter analyze

# 2. 运行测试通过
flutter test

# 3. 实际运行验证（真机）
flutter run --release
# 观察 5 分钟，确认不再有 ANR 弹窗
# 确认 app 使用统计仍然正常显示
```

### Must Have
- Wave 1（立即止损）: 轮询间隔改为30s以上，全量同步改为增量
- Wave 2（Native侧优化）: 缩小查询范围，去掉图标Base64
- Wave 3（稳定性）: 锁修复 + Provider优化

### Must NOT Have (guardrails, AI slop patterns, scope boundaries)
- 不要改变 `ContinuousUsageService` 的核心业务逻辑
- 不要重构整个架构（先解决卡顿问题）
- 不要引入新的第三方依赖
- 不要修改 UI 布局/样式
- 不要改动 `ReminderService` 的提醒逻辑

## Verification Strategy
- **Test decision**: tests-after（项目已有部分测试，本次不新增TDD）
- **QA policy**: 每个TODO完成后用真机验证卡顿是否消除
- **Evidence**: adb logcat 输出 + 人工观察 ANR 弹窗

## Execution Strategy
### Parallel Execution Waves

**Wave 1**: 立即止损（3个任务可并行）
- Task 1: 延长轮询间隔 + 减少全量同步频率
- Task 2: Native侧 `getCurrentForegroundApp()` 优化查询范围
- Task 3: `getAppIconBase64()` 移除

**Wave 2**: 增量同步改造（依赖 Wave 1）
- Task 4: `_syncTodayUsageFromSystem()` 改为增量更新
- Task 5: `OverlayStateManager._acquireLock()` 锁修复
- Task 6: Provider invalidate 频率降低

**Wave 3**: 验证和收尾
- Task 7: 构建、分析、测试
- Task 8: 真机运行验证

### Dependency Matrix
| Task | 依赖 | 被依赖 |
|------|------|--------|
| T1 | - | T4 |
| T2 | - | T4 |
| T3 | - | - |
| T4 | T1, T2 | T7 |
| T5 | - | T7 |
| T6 | - | T7 |
| T7 | T4, T5, T6 | T8 |
| T8 | T7 | - |

### Agent Dispatch Summary
- Wave 1: 3 tasks (quick/unspecified-low)
- Wave 2: 3 tasks (unspecified-high)
- Wave 3: 2 tasks (verification)

## TODOs

- [x] 1. 延长轮询间隔并减少全量同步频率

  **What to do**:
  1. 在 `UsageMonitorService` 中将 `monitorIntervalSeconds` 从 `5` 改为 `30`（第66行）
  2. 创建一个独立的 `_fullSyncTimer` 每 5 分钟执行一次全量 `_syncTodayUsageFromSystem()`
  3. 30 秒轮询中只执行：`getCurrentForegroundApp()` + 连续使用跟踪 + 规则检查
  4. 全量同步（`refreshTodayUsage()`）只在 `_fullSyncTimer` 中调用

  **Must NOT do**:
  - 不要改动 `_handleContinuousUsageTransition()` 的业务逻辑
  - 不要在增量同步中引入新 bug（连续使用倒计时不能受影响）

  **Recommended Agent Profile**:
  - Category: `unspecified-high` - Reason: 涉及核心监控服务逻辑修改，需要理解完整状态机
  - Skills: [] - 无需额外技能

  **Parallelization**: Can Parallel: YES | Wave 1 | Blocks: T4 | Blocked By: -

  **References**:
  - Pattern: `qiaoqiao_companion/lib/core/services/usage_monitor_service.dart:66` - `monitorIntervalSeconds` 常量
  - Pattern: `usage_monitor_service.dart:82-93` - `startMonitoring()` Timer 启动逻辑
  - Pattern: `usage_monitor_service.dart:542-606` - `_syncAndCheck()` 完整轮询逻辑
  - Pattern: `usage_monitor_service.dart:1119-1124` - `refreshTodayUsage()` 调用链

  **Acceptance Criteria**:
  - [x] `monitorIntervalSeconds` 从 5 改为 30
  - [x] 新增 `_fullSyncTimer` 变量，类型 `Timer?`
  - [x] `startMonitoring()` 中启动两个 Timer：30s `_syncAndCheck()` 和 5min 全量同步
  - [x] `stopMonitoring()` 中取消两个 Timer
  - [x] `_syncAndCheck()` 中不再调用 `refreshTodayUsage()`
  - [x] `flutter analyze` 通过

  **QA Scenarios**:
  ```
  Scenario: 轮询间隔验证
    Tool: Bash
    Steps: 
      1. 启动 app：cd qiaoqiao_companion && flutter run --release
      2. 观察 adb logcat 输出：adb logcat | findstr UsageMonitor
      3. 确认 "[UsageMonitor] Polling - currentApp:" 每 30 秒出现一次
      4. 确认不再每 5 秒出现 "Syncing X apps from system"
    Expected: Polling 日志间隔约 30 秒，全量同步日志最多每 5 分钟一次
    Evidence: .omo/evidence/task-1-polling.log

  Scenario: 连续使用功能不受影响
    Tool: Bash
    Steps:
      1. 打开一个被监控的应用（如游戏）
      2. 等待 2 分钟
      3. 检查是否正常出现连续使用倒计时（5分钟警告）
    Expected: 连续使用提醒功能正常触发
    Evidence: .omo/evidence/task-1-continuous-usage.log
  ```

  **Commit**: YES | Message: `fix(monitor): reduce poll interval to 30s and add separate 5min full sync timer` | Files: `qiaoqiao_companion/lib/core/services/usage_monitor_service.dart`

- [x] 2. 优化 Native 侧 `getCurrentForegroundApp()` 查询范围

  **What to do**:
  1. 在 `UsageStatsChannel.kt` 的 `getCurrentForegroundApp()` 中，将 `startTime` 从 `endTime - 2小时` 改为 `endTime - 30秒`
  2. 同样修复 `UsageStatsHelper.kt` 中的 `getCurrentForegroundApp()`
  3. 确保 `queryUsageStats()` 和 `queryHourlyUsage()` 的 startTime 保持当天0点不变（这些已由 Flutter 侧传入）

  **Must NOT do**:
  - 不要改动 `queryUsageStats()` 和 `queryHourlyUsage()` 的查询范围
  - 不要改动 `isSystemUiApp()` 的过滤逻辑

  **Recommended Agent Profile**:
  - Category: `quick` - Reason: Kotlin 文件修改，范围明确
  - Skills: [] - 无需额外技能

  **Parallelization**: Can Parallel: YES | Wave 1 | Blocks: - | Blocked By: -

  **References**:
  - Pattern: `UsageStatsChannel.kt:384-434` - `getCurrentForegroundApp()` 方法
  - Pattern: `UsageStatsHelper.kt:39-93` - `getCurrentForegroundApp()` 方法
  - Line: `UsageStatsChannel.kt:393` - `val startTime = endTime - 1000L * 60 * 60 * 2`
  - Line: `UsageStatsHelper.kt:49` - `val startTime = endTime - 1000L * 60 * 60 * 2`

  **Acceptance Criteria**:
  - [x] `UsageStatsChannel.kt:393` 的 `startTime` 改为 `endTime - 30_000L`
  - [x] `UsageStatsHelper.kt:49` 的 `startTime` 改为 `endTime - 30_000L`
  - [x] 构建通过：`cd qiaoqiao_companion && flutter build apk --debug`

  **QA Scenarios**:
  ```
  Scenario: 前台应用检测正常
    Tool: Bash
    Steps:
      1. 安装修改后的 APK
      2. 打开任意应用
      3. 观察 adb logcat: adb logcat -s UsageStatsChannel | findstr getCurrentForegroundApp
    Expected: 能正确识别当前前台应用包名
    Evidence: .omo/evidence/task-2-foreground-app.log
  ```

  **Commit**: YES | Message: `fix(native): reduce getCurrentForegroundApp query range from 2h to 30s` | Files: `qiaoqiao_companion/android/app/src/main/kotlin/com/qiaoqiao/qiaoqiao_companion/channels/UsageStatsChannel.kt`, `qiaoqiao_companion/android/app/src/main/kotlin/com/qiaoqiao/qiaoqiao_companion/utils/UsageStatsHelper.kt`

- [x] 3. 移除 Native 侧 `queryUsageStats()` 中的 App 图标 Base64 传输

  **What to do**:
  1. 在 `UsageStatsChannel.kt` 的 `queryUsageStats()` 中，从返回的 map 中移除 `"appIcon"` 字段
  2. 删除 `getAppIconBase64()` 方法（或保留但不再调用）
  3. 同时从 `getInstalledApps()` 中移除 `"appIcon"` 字段（如果需要保留图标功能则在其他地方处理）

  **Must NOT do**:
  - 不要删除 `getAppIconBase64()` 方法如果其他地方有用到
  - 不要影响 `appName`、`packageName` 等核心字段

  **Recommended Agent Profile**:
  - Category: `quick` - Reason: 单文件修改，删字段
  - Skills: [] - 无需额外技能

  **Parallelization**: Can Parallel: YES | Wave 1 | Blocks: - | Blocked By: -

  **References**:
  - Pattern: `UsageStatsChannel.kt:208-217` - `queryUsageStats()` 返回 map 构建
  - Line: `UsageStatsChannel.kt:216` - `"appIcon" to getAppIconBase64(packageName)`
  - Pattern: `UsageStatsChannel.kt:446` - `getInstalledApps()` 中的 `"appIcon"`

  **Acceptance Criteria**:
  - [x] `queryUsageStats()` 返回的 map 中不再包含 `"appIcon"` 字段
  - [x] `getInstalledApps()` 返回的 map 中不再包含 `"appIcon"` 字段
  - [x] 构建通过

  **QA Scenarios**:
  ```
  Scenario: 使用统计功能正常
    Tool: Bash
    Steps:
      1. 安装修改后的 APK
      2. 打开使用统计页面
      3. 确认各应用的使用时间正常显示（无图标不影响功能）
    Expected: 使用统计页面正常加载，无空白/错误
    Evidence: .omo/evidence/task-3-usage-stats.log
  ```

  **Commit**: YES | Message: `fix(native): remove app icon base64 from queryUsageStats to reduce MethodChannel payload` | Files: `qiaoqiao_companion/android/app/src/main/kotlin/com/qiaoqiao/qiaoqiao_companion/channels/UsageStatsChannel.kt`

- [x] 4. `_syncTodayUsageFromSystem()` 改为增量更新

  **What to do**:
  1. 重写 `_syncTodayUsageFromSystem()`：不再每次删除重建，而是从系统获取增量数据
  2. 比较新旧数据，只更新有变化的条目
  3. `_syncAppUsageRecords()` 改为 UPSERT 逻辑（存在则更新，不存在则插入）
  4. `_syncHourlyUsage()` 同样改为 UPSERT
  5. `_syncAndCheck()` 中的全量同步调用保留到 `_fullSyncTimer` 中

  **Must NOT do**:
  - 不要改变 `DailyStats.setDurations()` 的语义
  - 不要改变数据库表结构
  - 保持 `refreshTodayUsage()` 对外行为一致

  **Recommended Agent Profile**:
  - Category: `unspecified-high` - Reason: 核心业务逻辑修改，需理解完整数据流
  - Skills: [] - 无需额外技能

  **Parallelization**: Can Parallel: NO | Wave 2 | Blocks: T7 | Blocked By: T1, T2

  **References**:
  - Pattern: `usage_monitor_service.dart:609-679` - `_syncTodayUsageFromSystem()` 当前实现
  - Pattern: `usage_monitor_service.dart:682-716` - `_syncAppUsageRecords()` 当前实现
  - Pattern: `usage_monitor_service.dart:719-758` - `_syncHourlyUsage()` 当前实现
  - Pattern: `app_usage_dao.dart` - `AppUsageDao` 全部方法
  - Pattern: `hourly_usage_dao.dart` - `HourlyUsageDao` 全部方法（已有`upsertBatch`）

  **Acceptance Criteria**:
  - [x] `_syncTodayUsageFromSystem()` 不再调用 `deleteByDate()` 全量删除
  - [x] `_syncAppUsageRecords()` 使用 INSERT OR REPLACE 逻辑
  - [x] `_syncHourlyUsage()` 使用已有的 `upsertBatch()`（不做删除）
  - [x] 每日统计仍然正确（totalSeconds/gameSeconds/videoSeconds 等）
  - [x] `flutter analyze` 通过

  **QA Scenarios**:
  ```
  Scenario: 使用统计准确性验证
    Tool: Bash
    Steps:
      1. 安装修改后的 APK
      2. 使用某个被监控应用 2 分钟
      3. 刷新使用统计页面
    Expected: 使用时间显示为约 2 分钟，数据准确
    Evidence: .omo/evidence/task-4-accuracy.log
  ```

  **Commit**: YES | Message: `fix(monitor): change full sync to incremental upsert in _syncTodayUsageFromSystem` | Files: `qiaoqiao_companion/lib/core/services/usage_monitor_service.dart`, `qiaoqiao_companion/lib/core/database/daos/app_usage_dao.dart`

- [x] 5. 修复 `OverlayStateManager._acquireLock()` 锁机制

  **What to do**:
  1. 将 `_acquireLock()` / `_releaseLock()` 的 `Completer` 实现改为 `bool` 互斥锁
  2. 使用 `synchronized` 包或手动 `_locked` 标志 + `Completer` 队列（避免活锁）
  3. 关键：确保 `_releaseLock()` 只会唤醒一个等待者

  **Must NOT do**:
  - 不要引入新的第三方依赖（可以用现有dart:async实现）
  - 不要改变对外接口（`requestOverlay`/`dismissCurrent` 签名不变）

  **Recommended Agent Profile**:
  - Category: `unspecified-high` - Reason: 并发逻辑修改，需要仔细处理竞态
  - Skills: [] - 无需额外技能

  **Parallelization**: Can Parallel: YES | Wave 2 | Blocks: T7 | Blocked By: -

  **References**:
  - Pattern: `overlay_state_manager.dart:340-351` - `_acquireLock()` / `_releaseLock()` 当前实现
  - Line: `overlay_state_manager.dart:95` - `Completer<void>? _lock` 定义
  - Pattern: `overlay_state_manager.dart:112-183` - `requestOverlay()` 调用锁

  **Acceptance Criteria**:
  - [x] `_acquireLock()` 不再使用 `while(_lock != null) { await _lock!.future }` 模式
  - [x] 改为队列式互斥锁
  - [x] 高并发下不会死锁/活锁
  - [x] `flutter analyze` 通过

  **QA Scenarios**:
  ```
  Scenario: 弹窗叠加场景测试
    Tool: Bash
    Steps:
      1. 安装修改后的 APK
      2. 快速连续触发多个弹窗条件（如同时到达总时长限制和连续使用限制）
      3. 观察弹窗是否正常显示（高优先级覆盖低优先级）
    Expected: 弹窗按优先级正确显示，不会卡死
    Evidence: .omo/evidence/task-5-overlay.log
  ```

  **Commit**: YES | Message: `fix(overlay): fix _acquireLock deadlock by replacing busy-wait with queue-based mutex` | Files: `qiaoqiao_companion/lib/core/services/overlay_state_manager.dart`

- [x] 6. 降低 Provider invalidate 频率

  **What to do**:
  1. 将 `refreshTodayUsage()` 中的 `_ref.invalidate()` 调用改为只在全量同步时触发
  2. 轮询中只调用 `_ref.read(todayUsageProvider.notifier).loadToday()`
  3. 延迟 `todayHourlyTimelineNotifierProvider` 和 `filteredAppUsageProvider` 的 invalidate 到全量同步

  **Must NOT do**:
  - 不要移除 `loadToday()` 的调用（轮询需要更新今日使用数据）
  - 不要影响首页 UI 的实时更新

  **Recommended Agent Profile**:
  - Category: `unspecified-low` - Reason: 逻辑简单但需要理解 Provider 依赖
  - Skills: [] - 无需额外技能

  **Parallelization**: Can Parallel: YES | Wave 2 | Blocks: T7 | Blocked By: -

  **References**:
  - Pattern: `usage_monitor_service.dart:1119-1124` - `refreshTodayUsage()` 方法
  - Pattern: `today_usage_provider.dart:93-100` - `startAutoRefresh()` 已有 30 秒定时

  **Acceptance Criteria**:
  - [x] `refreshTodayUsage()` 只在全量同步时 invalidate 时间线和过滤 provider
  - [x] `loadToday()` 仍然每 30 秒调用一次
  - [x] `flutter analyze` 通过

  **QA Scenarios**:
  ```
  Scenario: UI 无卡顿
    Tool: Bash
    Steps:
      1. 安装修改后的 APK
      2. 打开首页，观察使用时间数字是否正常更新
      3. 快速滑动页面
    Expected: 使用时间定期更新，滑动流畅无卡顿
    Evidence: .omo/evidence/task-6-ui-smooth.log
  ```

  **Commit**: YES | Message: `fix(provider): reduce invalidate frequency to avoid UI rebuild storms` | Files: `qiaoqiao_companion/lib/core/services/usage_monitor_service.dart`

- [x] 7. 构建、分析和运行测试

  **What to do**:
  1. 运行 `cd qiaoqiao_companion && flutter clean && flutter pub get`
  2. 运行 `flutter analyze` 确认无编译错误和警告
  3. 运行 `flutter test` 确认所有测试通过
  4. 修复任何发现的问题

  **Must NOT do**:
  - 不要跳过分析步骤
  - 不要在修复问题时代入新的变更

  **Recommended Agent Profile**:
  - Category: `quick` - Reason: 标准化验证流程
  - Skills: [] - 无需额外技能

  **Parallelization**: Can Parallel: NO | Wave 3 | Blocks: T8 | Blocked By: T4, T5, T6

  **References**: 无

  **Acceptance Criteria**:
  - [x] `flutter analyze` 零错误零警告
  - [x] `flutter test` 全部通过
  - [x] `flutter build apk --debug` 构建成功

  **QA Scenarios**:
  ```
  Scenario: 验证
    Tool: Bash
    Steps:
      1. cd qiaoqiao_companion
      2. flutter clean && flutter pub get
      3. flutter analyze
      4. flutter test
    Expected: analyze 无错误，test 全部通过
    Evidence: .omo/evidence/task-7-analyze.log
  ```

  **Commit**: NO（如需要修复问题则在原任务 commit 中处理）

- [x] 8. 真机运行验证（需要连接 Android 设备后手动执行）

  **What to do**:
  1. 用 `flutter run --release` 在真机上安装运行
  2. 通过 `adb logcat` 观察日志
  3. 验证 5 分钟内无 ANR 弹窗
  4. 验证使用统计、规则检查、连续使用提醒均正常工作

  **Must NOT do**:
  - 如果发现问题，回到对应 Task 修复，不要在此 task 中直接改代码

  **Recommended Agent Profile**:
  - Category: `quick` - Reason: 人工验证流程
  - Skills: [] - 无需额外技能

  **Parallelization**: Can Parallel: NO | Wave 3 | Blocks: - | Blocked By: T7

  **References**: 无

  **Acceptance Criteria**:
  - [x] app 运行 5 分钟无 ANR 弹窗
  - [x] logcat 中无 UI 线程超时警告
  - [x] 使用统计页面数据正常

  **QA Scenarios**:
  ```
  Scenario: 长时间运行验证
    Tool: Bash
    Steps:
      1. flutter run --release
      2. adb logcat -s UsageMonitor flutter:* | findstr /i "anr notresponding"
      3. 正常使用 app 5 分钟，包括切换页面、触发提醒等
    Expected: 无 ANR 相关日志，app 响应流畅
    Evidence: .omo/evidence/task-8-verification.log
  ```

  **Commit**: NO（验证任务，不修改代码）

## Final Verification Wave (MANDATORY)
- [ ] F1. Plan Compliance Audit — 检查所有 Task 是否按计划完成
- [ ] F2. Code Quality Review — 确认 `flutter analyze` 零警告
- [ ] F3. Real Manual QA — 真机运行 5 分钟无 ANR
- [ ] F4. Scope Fidelity Check — 确认未引入计划外变更

## Commit Strategy
每个 Task 独立 commit，commit message 格式：`type(scope): description`

## Success Criteria
1. `flutter analyze` 零错误
2. 真机运行 5 分钟无 ANR
3. 使用统计功能正常
4. 连续使用提醒功能正常
5. 规则检查功能正常
6. 锁屏/弹窗功能正常
