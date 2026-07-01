# Progress Log — Widget 倒计时问题修复

## 当前状态

**Phase 1 完成 ✅，Phase 2 待真机验证**

---

## 2026-06-09: 修复清单

### 修改文件
`qiaoqiao_companion/lib/core/services/usage_monitor_service.dart`

### 修复 1.1：离开监控 app 时立即隐藏 widget
- **改动**：`_handleContinuousUsageTransition` 中 `shouldTrackCurrent = false` 时立即调用 `_hideStopwatchWidget()`
- **条件**：强制休息期间不隐藏（`_forceRestInProgress` 保护）
- **效果**：符合用户需求"没使用就消失"

### 修复 1.2：`_hideStopwatchWidget` 不清除 DB 倒计时字段
- **改动**：移除 `_clearCountdownState()` 调用
- **效果**：用户回到监控 app 时能从 DB 恢复倒计时状态（剩余时间从 session.totalDurationSeconds 计算）

### 修复 1.3：`_syncWidgetStateWithNative` 尝试恢复而非清除
- **改动**：原生 widget 消失 + 正在使用被监控 app → 尝试恢复 widget
- **改动**：原生 widget 消失 + 不在使用被监控 app → 重置标志
- **效果**：避免 MIUI 内存回收导致 widget 永远消失

### 修复 1.4：移除 `_lastStopTime` 延迟隐藏机制
- **改动**：删除 `_lastStopTime` 变量
- **改动**：`_checkHideStopwatchAfterRest` → `_checkAndResetSessionAfterRest`
- **改动**：新方法使用 `session.lastActivityTime` 计算离开时间，仅重置会话不隐藏 widget

### 修复 1.5（新增）：禁用提示框关闭后 widget 不弹出
- **根因**：路径 A（原生兜底 lock overlay）关闭回调不走 `OverlayStateManager.onOverlayDismissed`，导致 `_state` 残留 `showingLock` → `_showStopwatchWidget` 被守卫阻挡
- **改动**：在 `_onLockOverlayDismissed` 中，关闭 lock overlay 后立即复位 OverlayStateManager 状态
- **效果**：禁用提示框关闭后 widget 能正常弹出

### 代码分析结果
- ✅ `dart analyze` 无新增 error/warning
- ✅ 所有 `_lastStopTime` 引用已清除

---

## 验证计划

### 场景推演

| 场景 | 预期行为 | 修复点 |
|------|----------|--------|
| A. 使用被监控 app | widget 显示倒计时 | 原有逻辑 |
| B. 切换到非监控 app | widget 立即消失 | 修复 1.1 |
| C. 切换回被监控 app | widget 从 DB 恢复倒计时 | 修复 1.2 |
| D. 强制休息期间 | widget 显示休息倒计时 | `_forceRestInProgress` 保护 |
| E. 原生 widget 被 MIUI 回收 | Flutter 尝试恢复 widget | 修复 1.3 |
| F. 禁用提示框关闭后 | widget 显示新的使用倒计时 | 修复 1.5 |

### 真机验证
需要在小米平板上安装测试版验证上述 6 个场景。

---