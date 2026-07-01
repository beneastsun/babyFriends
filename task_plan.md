# Task Plan: Widget 倒计时混乱问题修复

<!--
  WHAT: 修复方案路线图，磁盘上的"工作记忆"
  WHY: 在多次工具调用后，原始目标可能被遗忘。此文件保持目标清晰。
  WHEN: 首先创建此文件，每完成一个阶段后更新。
-->

## Goal

修复连续使用倒计时 widget 的显示/隐藏逻辑混乱问题。
用户要求：在平板使用限制的 app 的时候，才显示 widget 倒计时；没使用就立即消失。
目前问题：两套逻辑控制 widget（Flutter 侧 + 原生侧），导致 widget 有时出现有时消失。

## Current Phase

**Phase 1: 修复 Flutter 侧 widget 显示/隐藏逻辑**（进行中）

---

### 阶段总览

| 阶段 | 内容 | 状态 |
|------|------|------|
| **Phase 1** | 修复 Flutter 侧 widget 显示/隐藏逻辑 | 🟡 进行中 |
| **Phase 2** | 验证修复效果 | 🔴 待开始 |

---

## Phase 1: 修复 Flutter 侧 widget 显示/隐藏逻辑

### 修复 1.1：离开监控 app 时立即隐藏 widget

文件：`qiaoqiao_companion/lib/core/services/usage_monitor_service.dart`
位置：`_handleContinuousUsageTransition` 方法（L186-203）

**当前行为**：离开监控 app → 设置 `_lastStopTime` → 等 `resetAfterRestSeconds` 后才隐藏
**修复行为**：离开监控 app → 立即隐藏 widget（调用 `_hideStopwatchWidget()`）

**具体改动**：
- 在 `shouldTrackCurrent = false` 分支中，立即调用 `_hideStopwatchWidget()`
- 移除注释"不立即隐藏 widget"的逻辑
- 保留 `_checkHideStopwatchAfterRest` 用于会话重置，但不控制 widget 隐藏时机
- 清除 `_lastStopTime` 相关的延迟隐藏机制

**注意**：如果 `_forceRestInProgress = true`（正在强制休息中），不隐藏 widget。
因为此时 widget 显示的是休息倒计时，不应因用户短暂离开而消失。

### 修复 1.2：回到监控 app 时立即恢复 widget

文件：`qiaoqiao_companion/lib/core/services/usage_monitor_service.dart`
位置：`_handleContinuousUsageTransition` 方法（L167-183）

**当前行为**：回到监控 app → `_showStopwatchWidget()` 有多个守卫条件可能阻止显示
**修复行为**：确保回到监控 app 时 widget 能可靠地恢复显示

**具体改动**：
- 在 `_showStopwatchWidget` 中，如果 `_currentSessionApp != currentApp`（应用切换），
  先隐藏旧 widget 再显示新的（而不是直接跳过）
- 确保 `_hideStopwatchWidget()` 正确重置所有标志，让下次 `_showStopwatchWidget` 不被守卫阻挡

### 修复 1.3：`_syncWidgetStateWithNative` 更健壮

文件：`qiaoqiao_companion/lib/core/services/usage_monitor_service.dart`
位置：`_syncWidgetStateWithNative` 方法（L489-507）

**当前行为**：原生 widget 不在 → 清除所有 Flutter 状态 + DB 倒计时字段
**修复行为**：原生 widget 不在但 Flutter 认为应该显示 → 尝试重新显示 widget

**具体改动**：
- 检查当前前台 app 是否是被监控 app
- 如果是 → 尝试重新显示 widget（调用 `_showStopwatchWidget`）
- 如果不是 → 才清除状态（与修复 1.1 一致：不在使用就消失）

### 修复 1.4：移除 `_lastStopTime` 延迟隐藏机制

文件：`qiaoqiao_companion/lib/core/services/usage_monitor_service.dart`

**改动**：
- `_handleContinuousUsageTransition` 中不再设置 `_lastStopTime`
- `_checkHideStopwatchAfterRest` 改为只负责重置连续使用会话，不再隐藏 widget
- 在 `_syncAndCheck` 中，会话重置逻辑通过 `_continuousUsageService.restoreSession()` 处理

---

## Phase 2: 验证修复效果

### 验证方式

1. **代码分析**：`flutter analyze` 无新增 error
2. **逻辑推演**：
   - 场景 A：使用被监控 app → widget 应立即显示倒计时
   - 场景 B：切换到非监控 app → widget 应立即消失
   - 场景 C：切换回被监控 app → widget 应立即重新出现
   - 场景 D：强制休息期间 → widget 显示休息倒计时，不因应用切换而消失
   - 场景 E：原生 widget 被系统回收 → Flutter 应尝试恢复 widget
3. **真机验证**：在小米平板上安装测试

---

## Key Questions

1. ~~是否确实存在两套逻辑？~~ → ✅ 确认：Flutter 侧 + 原生侧
2. ~~根本冲突点在哪里？~~ → ✅ 确认：三个关键冲突点
3. ~~用户期望的行为是什么？~~ → ✅ 确认：使用被监控 app 时显示，不使用时消失

---

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| 离开监控 app → 立即隐藏 widget | 符合用户明确需求 |
| `_syncWidgetStateWithNative` → 尝试恢复而非清除 | 避免 MIUI 内存回收导致 widget 永远消失 |
| 保留原生侧 Flutter 死亡时的接管逻辑 | 不改变原生侧逻辑 |
| 不移除 `_checkHideStopwatchAfterRest` | 仍用于重置会话，只是不控制 widget 隐藏 |

---

## Errors Encountered

| Error | Attempt | Resolution |
|-------|---------|------------|
| - | - | - |

---

*最后更新：2026-06-09*