# 连续使用时长功能 - 测试执行计划

## TL;DR
> **Summary**: 对连续使用时长功能进行全面测试，重点验证倒计时widget机制和倒计时准确性
> **Deliverables**: 测试用例文档 + 真实设备测试执行 + 截图记录 + 测试报告
> **Effort**: Medium
> **Parallel**: NO - 顺序执行测试用例
> **Critical Path**: 设计测试用例 → 连接设备 → 逐步执行测试 → 截图记录 → 生成报告

## Context

### Original Request
用户要求对连续使用时长功能进行全面测试，重点测试：
1. widget弹窗的机制
2. 倒计时的机制（之前有倒计时过程中消失、时间不准确等问题）
3. 多次限时间到期，不同app切换是否正常
4. 最近打开中删除本app后连续使用限时是否正常
5. 相关其他主要功能

### 代码分析结论

**核心组件**:
- `ContinuousUsageService` - 管理会话状态（totalDurationSeconds, restEndTime, alertsShown）
- `UsageMonitorService` - 每30秒轮询前台app，累加时间，检查提醒
- `OverlayStateManager` - 弹窗状态管理，优先级抢占机制
- `OverlayChannel` (原生层) - 显示倒计时widget和锁定弹窗
- `NativeContinuousUsageTracker` - Flutter进程死亡时的兜底跟踪

**状态流转**:
```
normal → warning5min (剩余≤5分钟，显示倒计时widget)
warning5min → warning3min (剩余≤3分钟，弹3分钟提醒)
warning3min → warning2min (剩余≤2分钟，弹2分钟提醒)
warning2min → atLimit (时间到，触发强制休息)
atLimit → inRest (强制休息中，显示lock overlay)
inRest → normal (休息结束，停用旧会话)
```

**已知问题**:
1. 倒计时过程中消失 - MIUI系统回收widget，内存标志与原生状态不同步
2. 倒计时时间不准确 - 系统时间变化，轮询间隔导致时间漂移
3. 多次限时间到期切换app异常 - 会话状态未正确重置
4. 最近打开中删除本app异常 - 监控状态未更新

## Work Objectives

### Core Objective
设计完整的测试用例集，在真实设备上执行测试，验证连续使用时长功能的正确性

### Deliverables
1. 完整的测试用例文档（32个测试用例）
2. 真实设备测试执行记录
3. 关键场景截图
4. 测试报告（包含通过/失败统计和问题发现）

### Definition of Done
- [ ] 所有测试用例执行完成
- [ ] 关键场景有截图记录
- [ ] 测试报告生成
- [ ] 已知问题验证完成

### Must Have
- 测试用例覆盖所有核心功能
- 重点测试倒计时widget和弹窗机制
- 验证已知问题是否已修复
- 截图记录关键状态

### Must NOT Have
- 不修改任何代码
- 不影响应用正常运行
- 不删除用户数据

## Verification Strategy
> ZERO HUMAN INTERVENTION - all verification is agent-executed.
- Test decision: 手动测试 + adb命令验证
- QA policy: 每个测试用例都有明确的预期结果和截图记录
- Evidence: 截图文件 + 测试报告

## Execution Strategy

### Sequential Execution
> 按测试用例顺序执行，每个用例执行后记录结果

### Test Execution Order
1. 基础功能测试 (TC-01 ~ TC-03)
2. 倒计时Widget测试 (TC-04 ~ TC-08)
3. 提醒弹窗测试 (TC-09 ~ TC-12)
4. 强制休息测试 (TC-13 ~ TC-16)
5. 多App切换测试 (TC-17 ~ TC-19)
6. 会话重置测试 (TC-20 ~ TC-21)
7. 多次限制到期测试 (TC-22 ~ TC-24)
8. 删除监控应用测试 (TC-25 ~ TC-26)
9. 设置变更测试 (TC-27 ~ TC-28)
10. 边界条件测试 (TC-29 ~ TC-32)

## TODOs

- [ ] 1. 准备测试环境

  **What to do**: 
  - 确认设备连接状态
  - 安装/启动应用
  - 截图记录初始状态

  **Acceptance Criteria**:
  - [ ] 设备连接成功
  - [ ] 应用正常启动
  - [ ] 初始状态截图保存

  **QA Scenarios**:
  ```
  Scenario: 验证设备连接
    Tool: Bash
    Steps: 执行 adb devices
    Expected: 返回设备ID
    Evidence: .omo/evidence/task-1-device-check.txt
  ```

- [ ] 2. 执行基础功能测试 (TC-01 ~ TC-03)

  **What to do**: 
  - 测试开启/关闭连续使用限制
  - 测试限制时长滑块调节
  - 测试休息时长滑块调节

  **Acceptance Criteria**:
  - [ ] TC-01 通过：开关状态正确保存
  - [ ] TC-02 通过：限制时长正确更新
  - [ ] TC-03 通过：休息时长正确更新

  **QA Scenarios**:
  ```
  Scenario: 验证开关状态
    Tool: adb + 手动操作
    Steps: 
      1. 进入家长模式 → 连续使用设置
      2. 开启开关
      3. 截图
      4. 关闭开关
      5. 截图
    Expected: 开关状态正确切换
    Evidence: .omo/evidence/task-2-tc01-screenshot.png
  ```

- [ ] 3. 执行倒计时Widget测试 (TC-04 ~ TC-08)

  **What to do**: 
  - 测试倒计时widget显示条件
  - 测试倒计时时间准确性
  - 测试倒计时widget拖动功能
  - 测试倒计时widget消失场景
  - 测试倒计时widget进程被杀恢复

  **Acceptance Criteria**:
  - [ ] TC-04 通过：5分钟后显示倒计时widget
  - [ ] TC-05 通过：倒计时时间准确
  - [ ] TC-06 通过：widget可拖动
  - [ ] TC-07 通过：切换app时widget正确处理
  - [ ] TC-08 通过：进程被杀后恢复

  **QA Scenarios**:
  ```
  Scenario: 验证倒计时widget显示
    Tool: adb + 手动操作
    Steps:
      1. 设置限制为5分钟
      2. 打开监控应用
      3. 等待5分钟
      4. 截图右上角
    Expected: 出现倒计时widget
    Evidence: .omo/evidence/task-3-tc04-widget-show.png
  ```

- [ ] 4. 执行提醒弹窗测试 (TC-09 ~ TC-12)

  **What to do**: 
  - 测试3分钟提醒弹窗
  - 测试2分钟提醒弹窗
  - 测试提醒弹窗不重复显示
  - 测试提醒弹窗优先级

  **Acceptance Criteria**:
  - [ ] TC-09 通过：3分钟时弹出提醒
  - [ ] TC-10 通过：2分钟时弹出提醒
  - [ ] TC-11 通过：提醒不重复显示
  - [ ] TC-12 通过：弹窗优先级正确

- [ ] 5. 执行强制休息测试 (TC-13 ~ TC-16)

  **What to do**: 
  - 测试倒计时结束触发强制休息
  - 测试锁定弹窗倒计时准确性
  - 测试锁定弹窗关闭后恢复
  - 测试休息期间widget显示

  **Acceptance Criteria**:
  - [ ] TC-13 通过：倒计时结束弹出锁定弹窗
  - [ ] TC-14 通过：锁定弹窗倒计时准确
  - [ ] TC-15 通过：关闭后恢复使用
  - [ ] TC-16 通过：休息期间widget显示

- [ ] 6. 执行多App切换测试 (TC-17 ~ TC-19)

  **What to do**: 
  - 测试监控应用之间切换
  - 测试监控应用与非监控应用切换
  - 测试多次切换应用压力测试

  **Acceptance Criteria**:
  - [ ] TC-17 通过：切换时倒计时不重置
  - [ ] TC-18 通过：widget正确显示/隐藏
  - [ ] TC-19 通过：多次切换无异常

- [ ] 7. 执行会话重置测试 (TC-20 ~ TC-21)

  **What to do**: 
  - 测试离开监控应用超过重置阈值
  - 测试离开监控应用未超过重置阈值

  **Acceptance Criteria**:
  - [ ] TC-20 通过：超过阈值会话重置
  - [ ] TC-21 通过：未超过阈值会话继续

- [ ] 8. 执行多次限制到期测试 (TC-22 ~ TC-24)

  **What to do**: 
  - 测试第一次限制到期后恢复使用
  - 测试第二次限制到期
  - 测试快速连续触发多次限制

  **Acceptance Criteria**:
  - [ ] TC-22 通过：第一次限制正常
  - [ ] TC-23 通过：第二次限制正常
  - [ ] TC-24 通过：多次限制无异常

- [ ] 9. 执行删除监控应用测试 (TC-25 ~ TC-27)

  **What to do**: 
  - 测试在最近打开中删除被监控应用（com.qiaoqiao.qiaoqiao_companion_02）后，主要功能是否正常
  - 验证：倒计时widget、倒计时准确性、强制休息、提醒弹窗等核心功能

  **Acceptance Criteria**:
  - [ ] TC-25 通过：删除被监控应用后倒计时widget正常显示/隐藏
  - [ ] TC-26 通过：删除被监控应用后倒计时时间准确
  - [ ] TC-27 通过：删除被监控应用后强制休息正常触发

- [ ] 10. 执行设置变更测试 (TC-27 ~ TC-28)

  **What to do**: 
  - 测试使用过程中修改限制时长
  - 测试使用过程中关闭功能

  **Acceptance Criteria**:
  - [ ] TC-27 通过：修改后倒计时更新
  - [ ] TC-28 通过：关闭后widget消失

- [ ] 11. 执行边界条件测试 (TC-29 ~ TC-32)

  **What to do**: 
  - 测试最小限制时长（1分钟）
  - 测试最大限制时长（60分钟）
  - 测试最小休息时长（1分钟）
  - 测试最大休息时长（30分钟）

  **Acceptance Criteria**:
  - [ ] TC-29 通过：1分钟限制正常
  - [ ] TC-30 通过：60分钟限制正常
  - [ ] TC-31 通过：1分钟休息正常
  - [ ] TC-32 通过：30分钟休息正常

- [ ] 12. 生成测试报告

  **What to do**: 
  - 汇总测试结果
  - 记录发现的问题
  - 生成最终测试报告

  **Acceptance Criteria**:
  - [ ] 测试报告包含所有用例结果
  - [ ] 问题清单完整
  - [ ] 截图记录完整

## Final Verification Wave

- [ ] F1. 测试用例执行完整性检查
- [ ] F2. 截图记录完整性检查
- [ ] F3. 测试报告完整性检查
- [ ] F4. 已知问题验证结果汇总

## Commit Strategy
> N/A - 不修改代码，仅测试和记录

## Success Criteria
- [ ] 所有32个测试用例执行完成
- [ ] 关键场景有截图记录
- [ ] 测试报告生成
- [ ] 已知问题验证完成
- [ ] 发现的问题记录完整
