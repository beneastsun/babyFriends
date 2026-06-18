# 巧巧小伙伴核心功能测试计划

## TL;DR
> **Summary**: 针对连续使用限制、倒计时Widget、弹窗提醒等核心功能的完整测试计划，重点验证之前出现的Widget多次显示/消失、计时不准确、弹窗被自动关闭等问题
> **Deliverables**: 
> - 完整的测试用例执行报告
> - 关键功能截图保存
> - 问题发现和修复建议
> **Effort**: Large
> **Parallel**: YES - 3 waves
> **Critical Path**: 测试环境准备 → 功能测试 → 异常场景测试 → 报告生成

## Context

### Original Request
用户要求针对app的核心功能制定详细的测试计划，重点是：
1. 连续使用限制功能
2. Widget倒计时功能
3. 倒计时的准确性
4. 弹窗是否正常弹出
5. 之前经常出现的问题：Widget多次显示/消失、计时不准确、弹窗被自动关闭等

### Interview Summary
- **核心功能**：连续使用限制、倒计时Widget、弹窗提醒
- **已知问题**：Widget多次显示/消失不正常、计时不准确、弹窗限制自己关闭
- **测试目标**：通过OpenCode执行测试用例，生成完整测试报告，保存关键截图

### Technical Analysis (from code exploration)

#### 核心组件
1. **ContinuousUsageService** (`lib/core/services/continuous_usage_service.dart`)
   - 管理连续使用会话状态
   - 跟踪使用时间累加
   - 触发强制休息

2. **UsageMonitorService** (`lib/core/services/usage_monitor_service.dart`)
   - 30秒轮询监控前台应用
   - 管理倒计时Widget显示/隐藏
   - 处理应用切换逻辑

3. **OverlayService** (`lib/core/platform/overlay_service.dart`)
   - 原生倒计时Widget管理
   - 显示/隐藏倒计时悬浮窗

4. **ReminderDialog** (`lib/shared/widgets/reminder_dialog.dart`)
   - 提醒弹窗组件
   - 支持倒计时显示

5. **ContinuousUsageReminder** (`lib/features/parent_mode/presentation/widgets/continuous_usage_reminder.dart`)
   - 连续使用提醒弹窗
   - 可拖动设计

#### 已知问题分析
1. **Widget多次显示/消失**：
   - `usage_monitor_service.dart:238-253` - 原生widget可能被系统回收但内存标志仍为true
   - `_syncWidgetStateWithNative()` 方法用于同步状态

2. **计时不准确**：
   - `continuous_usage_service.dart:85-99` - 累加时间计算
   - `usage_monitor_service.dart:146-153` - 时间合理性验证

3. **弹窗被自动关闭**：
   - `reminder_service.dart:179-193` - `hideReminderUnlessLock` 方法
   - `overlay_state_manager.dart` - 状态管理

## Work Objectives

### Core Objective
执行完整的核心功能测试，验证连续使用限制、倒计时Widget、弹窗提醒的功能正确性和稳定性。

### Deliverables
1. 测试用例执行报告（包含通过/失败状态）
2. 关键功能截图（至少20张）
3. 问题发现清单
4. 改进建议文档

### Definition of Done (verifiable conditions with commands)
- [ ] 所有测试用例执行完毕
- [ ] 测试报告生成并保存
- [ ] 关键截图保存到指定目录
- [ ] 问题清单整理完成

### Must Have
- 连续使用限制功能正常工作
- 倒计时Widget正确显示/隐藏
- 弹窗提醒按预期触发
- 计时准确性验证

### Must NOT Have (guardrails)
- 不修改任何源代码
- 不影响用户正常使用
- 不删除任何测试数据

## Verification Strategy
> ZERO HUMAN INTERVENTION - all verification is agent-executed.

- Test decision: **tests-after** + **manual verification**
- QA policy: 每个测试场景都有截图和日志记录
- Evidence: `.omo/evidence/task-{N}-{slug}.{ext}`

## Execution Strategy

### Parallel Execution Waves

**Wave 1: 测试环境准备**
- Task 1: 检查测试环境和依赖
- Task 2: 准备测试设备和配置

**Wave 2: 核心功能测试**
- Task 3: 连续使用限制功能测试
- Task 4: 倒计时Widget显示/隐藏测试
- Task 5: 弹窗提醒功能测试
- Task 6: 计时准确性测试

**Wave 3: 异常场景测试**
- Task 7: 应用切换场景测试
- Task 8: 进程被杀恢复测试
- Task 9: 多重限制叠加测试

**Wave 4: 报告生成**
- Task 10: 生成测试报告
- Task 11: 整理问题清单

### Dependency Matrix
```
Task 1 → Task 3, 4, 5, 6
Task 2 → Task 3, 4, 5, 6
Task 3 → Task 7, 8, 9
Task 4 → Task 7, 8, 9
Task 5 → Task 7, 8, 9
Task 6 → Task 7, 8, 9
Task 7, 8, 9 → Task 10
Task 10 → Task 11
```

### Agent Dispatch Summary
- Wave 1: 2 tasks (quick)
- Wave 2: 4 tasks (deep)
- Wave 3: 3 tasks (deep)
- Wave 4: 2 tasks (writing)

## TODOs

- [ ] 1. 检查测试环境和依赖

  **What to do**: 
  - 验证Flutter SDK版本
  - 检查测试设备连接状态
  - 确认应用已安装并可运行
  - 验证测试工具可用性

  **Must NOT do**: 
  - 不修改任何配置文件
  - 不安装额外依赖

  **Recommended Agent Profile**:
  - Category: `quick`
  - Skills: []
  - Omitted: []

  **Parallelization**: Can Parallel: YES | Wave 1 | Blocks: [3, 4, 5, 6] | Blocked By: []

  **References**:
  - `CLAUDE.md` - 项目概述和命令
  - `pubspec.yaml` - 依赖配置

  **Acceptance Criteria**:
  - [ ] Flutter SDK版本 >= 3.11.1
  - [ ] 测试设备已连接
  - [ ] 应用可正常启动

  **QA Scenarios**:
  ```
  Scenario: 验证测试环境
    Tool: Bash
    Steps:
      1. 执行 `flutter --version` 检查SDK版本
      2. 执行 `flutter devices` 检查设备连接
      3. 执行 `flutter pub get` 检查依赖
    Expected: 所有命令执行成功，无错误
    Evidence: .omo/evidence/task-1-env-check.txt
  ```

  **Commit**: NO

---

- [ ] 2. 准备测试设备和配置

  **What to do**:
  - 配置测试设备（小米Android平板）
  - 启用开发者选项和USB调试
  - 授予必要权限（使用统计、悬浮窗、自启动）
  - 配置测试数据

  **Must NOT do**:
  - 不修改系统设置
  - 不删除用户数据

  **Recommended Agent Profile**:
  - Category: `quick`
  - Skills: []
  - Omitted: []

  **Parallelization**: Can Parallel: YES | Wave 1 | Blocks: [3, 4, 5, 6] | Blocked By: []

  **References**:
  - `android/app/src/main/AndroidManifest.xml` - 权限配置
  - `lib/core/platform/` - 平台通道

  **Acceptance Criteria**:
  - [ ] 使用统计权限已授予
  - [ ] 悬浮窗权限已授予
  - [ ] 自启动权限已配置

  **QA Scenarios**:
  ```
  Scenario: 验证设备权限
    Tool: Bash
    Steps:
      1. 执行 `adb shell appops get com.qiaoqiao.qiaoqiao_companion USAGE_STATS`
      2. 执行 `adb shell appops get com.qiaoqiao.qiaoqiao_companion SYSTEM_ALERT_WINDOW`
      3. 检查应用启动状态
    Expected: 权限状态为allow，应用可正常启动
    Evidence: .omo/evidence/task-2-permission-check.txt
  ```

  **Commit**: NO

---

- [ ] 3. 连续使用限制功能测试

  **What to do**:
  - 测试连续使用限制的触发条件
  - 验证强制休息功能
  - 测试休息时间配置
  - 验证会话状态管理

  **Must NOT do**:
  - 不修改限制时间配置
  - 不删除测试会话数据

  **Recommended Agent Profile**:
  - Category: `deep`
  - Skills: []
  - Omitted: []

  **Parallelization**: Can Parallel: YES | Wave 2 | Blocks: [7, 8, 9] | Blocked By: [1, 2]

  **References**:
  - `lib/core/services/continuous_usage_service.dart` - 连续使用服务
  - `lib/shared/providers/continuous_usage_provider.dart` - 状态管理
  - `test/services/reminder_service_test.dart` - 测试模式参考

  **Acceptance Criteria**:
  - [ ] 连续使用会话正确创建
  - [ ] 使用时间正确累加
  - [ ] 达到限制时触发强制休息
  - [ ] 休息时间正确配置

  **QA Scenarios**:
  **Scenario: 连续使用限制触发**
    Tool: Bash
    Steps:
      1. 启动应用并进入被监控应用
      2. 等待使用时间达到限制（或使用forceTriggerRest模拟）
      3. 验证强制休息触发
      4. 检查休息倒计时显示
    Expected: 强制休息正确触发，倒计时显示正确
    Evidence: .omo/evidence/task-3-continuous-usage.png

  **Scenario: 会话状态恢复**
    Tool: Bash
    Steps:
      1. 创建连续使用会话
      2. 切换到非监控应用
      3. 等待超过阈值时间
      4. 验证会话被停用
    Expected: 会话正确停用，下次使用从0开始
    Evidence: .omo/evidence/task-3-session-recovery.png

  **Commit**: NO

---

- [ ] 4. 倒计时Widget显示/隐藏测试

  **What to do**:
  - 测试倒计时Widget的显示条件
  - 验证Widget的隐藏逻辑
  - 测试应用切换时的Widget行为
  - 验证Widget状态同步

  **Must NOT do**:
  - 不修改Widget显示逻辑
  - 不影响其他应用

  **Recommended Agent Profile**:
  - Category: `deep`
  - Skills: []
  - Omitted: []

  **Parallelization**: Can Parallel: YES | Wave 2 | Blocks: [7, 8, 9] | Blocked By: [1, 2]

  **References**:
  - `lib/core/services/usage_monitor_service.dart:230-320` - Widget显示逻辑
  - `lib/core/platform/overlay_service.dart` - 原生Widget管理
  - `android/app/src/main/kotlin/.../monitor/NativeContinuousUsageTracker.kt` - 原生跟踪器

  **Acceptance Criteria**:
  - [ ] Widget在正确时机显示
  - [ ] Widget在离开监控应用时隐藏
  - [ ] Widget状态与原生同步
  - [ ] 无重复显示/隐藏问题

  **QA Scenarios**:
  **Scenario: Widget显示时机**
    Tool: Bash
    Steps:
      1. 启动应用并进入被监控应用
      2. 等待使用时间接近限制（5分钟内）
      3. 验证倒计时Widget显示
      4. 检查Widget显示位置和样式
    Expected: Widget在剩余5分钟时正确显示
    Evidence: .omo/evidence/task-4-widget-show.png

  **Scenario: Widget隐藏逻辑**
    Tool: Bash
    Steps:
      1. 启动倒计时Widget
      2. 切换到非监控应用
      3. 验证Widget隐藏
      4. 检查隐藏延迟机制
    Expected: Widget在离开监控应用后正确隐藏
    Evidence: .omo/evidence/task-4-widget-hide.png

  **Scenario: Widget状态同步**
    Tool: Bash
    Steps:
      1. 启动倒计时Widget
      2. 模拟原生Widget被系统回收
      3. 验证Flutter侧状态同步
      4. 检查Widget恢复显示
    Expected: 状态同步正确，Widget可恢复显示
    Evidence: .omo/evidence/task-4-widget-sync.png

  **Commit**: NO

---

- [ ] 5. 弹窗提醒功能测试

  **What to do**:
  - 测试各种提醒类型的弹窗显示
  - 验证弹窗的关闭逻辑
  - 测试弹窗的优先级机制
  - 验证弹窗的自动关闭问题

  **Must NOT do**:
  - 不修改弹窗显示逻辑
  - 不影响用户体验

  **Recommended Agent Profile**:
  - Category: `deep`
  - Skills: []
  - Omitted: []

  **Parallelization**: Can Parallel: YES | Wave 2 | Blocks: [7, 8, 9] | Blocked By: [1, 2]

  **References**:
  - `lib/shared/widgets/reminder_dialog.dart` - 提醒弹窗
  - `lib/core/services/reminder_service.dart` - 提醒服务
  - `lib/core/services/overlay_state_manager.dart` - 状态管理

  **Acceptance Criteria**:
  - [ ] 温和提醒正确显示
  - [ ] 认真警告正确显示
  - [ ] 最后警告正确显示
  - [ ] 锁定弹窗正确显示
  - [ ] 弹窗不会被自动关闭

  **QA Scenarios**:
  **Scenario: 温和提醒弹窗**
    Tool: Bash
    Steps:
      1. 配置连续使用限制为5分钟
      2. 使用应用4分30秒
      3. 验证温和提醒弹窗显示
      4. 检查弹窗内容和倒计时
    Expected: 温和提醒正确显示，倒计时准确
    Evidence: .omo/evidence/task-5-gentle-reminder.png

  **Scenario: 弹窗关闭问题**
    Tool: Bash
    Steps:
      1. 触发锁定弹窗
      2. 尝试自动关闭弹窗
      3. 验证弹窗保持显示
      4. 检查用户手动关闭逻辑
    Expected: 锁定弹窗不会被自动关闭
    Evidence: .omo/evidence/task-5-dialog-close.png

  **Scenario: 弹窗优先级**
    Tool: Bash
      1. 同时触发多个提醒
      2. 验证高优先级弹窗显示
      3. 检查低优先级弹窗被阻止
    Expected: 优先级机制正确工作
    Evidence: .omo/evidence/task-5-dialog-priority.png

  **Commit**: NO

---

- [ ] 6. 计时准确性测试

  **What to do**:
  - 验证倒计时显示的准确性
  - 测试时间累加的正确性
  - 验证跨应用切换的时间计算
  - 测试进程被杀后的恢复

  **Must NOT do**:
  - 不修改时间计算逻辑
  - 不影响系统时间

  **Recommended Agent Profile**:
  - Category: `deep`
  - Skills: []
  - Omitted: []

  **Parallelization**: Can Parallel: YES | Wave 2 | Blocks: [7, 8, 9] | Blocked By: [1, 2]

  **References**:
  - `lib/core/services/continuous_usage_service.dart:85-99` - 时间累加
  - `lib/core/services/usage_monitor_service.dart:146-153` - 时间验证
  - `lib/core/platform/overlay_service.dart` - 原生倒计时

  **Acceptance Criteria**:
  - [ ] 倒计时显示准确（误差<2秒）
  - [ ] 时间累加正确
  - [ ] 跨应用切换时间计算正确
  - [ ] 进程恢复后时间正确

  **QA Scenarios**:
  **Scenario: 倒计时准确性**
    Tool: Bash
    Steps:
      1. 启动倒计时Widget
      2. 记录开始时间
      3. 等待倒计时结束
      4. 验证结束时间准确性
    Expected: 倒计时准确，误差<2秒
    Evidence: .omo/evidence/task-6-countdown-accuracy.png

  **Scenario: 时间累加验证**
    Tool: Bash
    Steps:
      1. 启动连续使用会话
      2. 使用应用1分钟
      3. 验证累加时间
      4. 检查数据库记录
    Expected: 时间累加正确，数据库记录准确
    Evidence: .omo/evidence/task-6-time-accumulation.png

  **Scenario: 进程恢复测试**
    Tool: Bash
    Steps:
      1. 启动倒计时Widget
      2. 强制停止应用
      3. 重新启动应用
      4. 验证倒计时恢复
    Expected: 进程恢复后倒计时正确恢复
    Evidence: .omo/evidence/task-6-process-recovery.png

  **Commit**: NO

---

- [ ] 7. 应用切换场景测试

  **What to do**:
  - 测试在被监控应用间切换
  - 测试在监控与非监控应用间切换
  - 验证切换时的状态保持
  - 测试快速切换场景

  **Must NOT do**:
  - 不修改应用切换逻辑
  - 不影响其他应用

  **Recommended Agent Profile**:
  - Category: `deep`
  - Skills: []
  - Omitted: []

  **Parallelization**: Can Parallel: YES | Wave 3 | Blocks: [10] | Blocked By: [3, 4, 5, 6]

  **References**:
  - `lib/core/services/usage_monitor_service.dart:141-228` - 应用切换处理
  - `lib/core/services/continuous_usage_service.dart:54-82` - 会话管理

  **Acceptance Criteria**:
  - [ ] 监控应用间切换保持会话
  - [ ] 非监控应用切换暂停计时
  - [ ] 快速切换正确处理
  - [ ] 状态保持正确

  **QA Scenarios**:
  **Scenario: 监控应用间切换**
    Tool: Bash
    Steps:
      1. 启动应用A（监控应用）
      2. 切换到应用B（监控应用）
      3. 验证会话保持
      4. 检查时间累加
    Expected: 会话保持，时间正确累加
    Evidence: .omo/evidence/task-7-app-switch.png

  **Scenario: 快速切换测试**
    Tool: Bash
    Steps:
      1. 快速在多个应用间切换
      2. 验证状态稳定性
      3. 检查Widget显示
      4. 验证时间计算
    Expected: 快速切换时状态稳定
    Evidence: .omo/evidence/task-7-quick-switch.png

  **Commit**: NO

---

- [ ] 8. 进程被杀恢复测试

  **What to do**:
  - 测试应用进程被杀后的恢复
  - 验证倒计时状态恢复
  - 测试服务重启机制
  - 验证数据持久化

  **Must NOT do**:
  - 不修改进程管理逻辑
  - 不影响系统稳定性

  **Recommended Agent Profile**:
  - Category: `deep`
  - Skills: []
  - Omitted: []

  **Parallelization**: Can Parallel: YES | Wave 3 | Blocks: [10] | Blocked By: [3, 4, 5, 6]

  **References**:
  - `lib/core/services/usage_monitor_service.dart:550-616` - 状态同步
  - `android/app/src/main/kotlin/.../services/MonitorForegroundService.kt` - 前台服务
  - `android/app/src/main/kotlin/.../workers/KeepAliveWorker.kt` - 保活机制

  **Acceptance Criteria**:
  - [ ] 进程被杀后服务重启
  - [ ] 倒计时状态正确恢复
  - [ ] 数据持久化正确
  - [ ] 用户无感知中断

  **QA Scenarios**:
  **Scenario: 进程被杀恢复**
    Tool: Bash
    Steps:
      1. 启动倒计时Widget
      2. 强制停止应用（adb shell am force-stop）
      3. 等待服务重启
      4. 验证倒计时恢复
    Expected: 服务重启，倒计时正确恢复
    Evidence: .omo/evidence/task-8-process-kill.png

  **Scenario: 数据持久化验证**
    Tool: Bash
    Steps:
      1. 创建连续使用会话
      2. 强制停止应用
      3. 重启应用
      4. 验证数据库中的会话数据
    Expected: 数据正确持久化
    Evidence: .omo/evidence/task-8-data-persistence.png

  **Commit**: NO

---

- [ ] 9. 多重限制叠加测试

  **What to do**:
  - 测试连续使用限制与总时长限制叠加
  - 测试多个应用限制叠加
  - 验证限制优先级
  - 测试限制冲突处理

  **Must NOT do**:
  - 不修改限制逻辑
  - 不影响用户体验

  **Recommended Agent Profile**:
  - Category: `deep`
  - Skills: []
  - Omitted: []

  **Parallelization**: Can Parallel: YES | Wave 3 | Blocks: [10] | Blocked By: [3, 4, 5, 6]

  **References**:
  - `lib/core/services/rule_checker_service.dart:52-126` - 规则检查优先级
  - `lib/shared/providers/rules_provider.dart` - 规则管理

  **Acceptance Criteria**:
  - [ ] 多重限制正确叠加
  - [ ] 优先级机制正确
  - [ ] 冲突处理正确
  - [ ] 用户提示清晰

  **QA Scenarios**:
  **Scenario: 限制叠加测试**
    Tool: Bash
    Steps:
      1. 配置连续使用限制30分钟
      2. 配置总时长限制1小时
      3. 使用应用接近30分钟
      4. 验证连续使用限制触发
    Expected: 优先触发连续使用限制
    Evidence: .omo/evidence/task-9-limit-superposition.png

  **Scenario: 限制冲突测试**
    Tool: Bash
    Steps:
      1. 配置多个冲突限制
      2. 触发限制
      3. 验证提示信息
      4. 检查限制执行
    Expected: 正确处理冲突，用户提示清晰
    Evidence: .omo/evidence/task-9-limit-conflict.png

  **Commit**: NO

---

- [ ] 10. 生成测试报告

  **What to do**:
  - 汇总所有测试结果
  - 生成测试报告
  - 整理截图和证据
  - 标注问题和建议

  **Must NOT do**:
  - 不修改测试结果
  - 不遗漏任何测试用例

  **Recommended Agent Profile**:
  - Category: `writing`
  - Skills: []
  - Omitted: []

  **Parallelization**: Can Parallel: NO | Wave 4 | Blocks: [11] | Blocked By: [7, 8, 9]

  **References**:
  - `.omo/evidence/` - 测试证据目录
  - `test/` - 测试文件

  **Acceptance Criteria**:
  - [ ] 测试报告完整
  - [ ] 截图整理完毕
  - [ ] 问题清单清晰
  - [ ] 建议可执行

  **QA Scenarios**:
  **Scenario: 生成测试报告**
    Tool: Bash
    Steps:
      1. 汇总所有测试结果
      2. 生成Markdown格式报告
      3. 整理截图文件
      4. 保存到指定目录
    Expected: 测试报告完整生成
    Evidence: .omo/evidence/task-10-test-report.md

  **Commit**: NO

---

- [ ] 11. 整理问题清单

  **What to do**:
  - 汇总发现的问题
  - 分类问题严重程度
  - 提供复现步骤
  - 给出修复建议

  **Must NOT do**:
  - 不夸大问题严重性
  - 不遗漏关键问题

  **Recommended Agent Profile**:
  - Category: `writing`
  - Skills: []
  - Omitted: []

  **Parallelization**: Can Parallel: NO | Wave 4 | Blocks: [] | Blocked By: [10]

  **References**:
  - 测试执行过程中的发现
  - 代码分析结果

  **Acceptance Criteria**:
  - [ ] 问题清单完整
  - [ ] 严重程度分类
  - [ ] 复现步骤清晰
  - [ ] 修复建议可行

  **QA Scenarios**:
  **Scenario: 生成问题清单**
    Tool: Bash
    Steps:
      1. 汇总所有发现的问题
      2. 分类严重程度（P0/P1/P2）
      3. 提供复现步骤
      4. 给出修复建议
    Expected: 问题清单完整清晰
    Evidence: .omo/evidence/task-11-issue-list.md

  **Commit**: NO

## Final Verification Wave (MANDATORY — after ALL implementation tasks)
> 4 review agents run in PARALLEL. ALL must APPROVE. Present consolidated results to user and get explicit "okay" before completing.

- [ ] F1. Plan Compliance Audit — oracle
- [ ] F2. Code Quality Review — unspecified-high
- [ ] F3. Real Manual QA — unspecified-high (+ playwright if UI)
- [ ] F4. Scope Fidelity Check — deep

## Commit Strategy
- 无代码提交，仅测试执行和报告生成

## Success Criteria
1. 所有测试用例执行完毕
2. 测试报告完整生成
3. 关键截图保存完整
4. 问题清单清晰可执行
5. 无新增P0级别问题
