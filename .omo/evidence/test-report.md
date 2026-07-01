# 连续使用时长功能 - 测试报告

## 测试概要

| 项目 | 详情 |
|------|------|
| **测试日期** | 2026-06-11 |
| **测试设备** | Xiaomi M2105K81AC (设备ID: 8711b87c) |
| **应用版本** | com.qiaoqiao.qiaoqiao_companion_02 |
| **测试环境** | Android, Flutter Release Build |
| **测试人员** | AI Agent (Atlas) |

## 测试配置

- **连续使用限制**: 已开启 (limit=2分钟, rest=1分钟)
- **被监控应用**: 通过数据库手动添加 (原monitored_apps表为空)
  - com.wedobest.shudu (数独)
  - com.tencent.mm (WeChat)
  - tv.danmaku.bilibilihd (Bilibili)
  - com.quark.browser (夸克浏览器)

## 测试结果汇总

### 通过的测试用例

| 测试用例 | 状态 | 说明 |
|----------|------|------|
| TC-04: 倒计时Widget显示 | ✅ 通过 | 当使用时间接近限制时，右上角正确显示倒计时widget |
| TC-13: 第一轮强制休息弹窗 | ✅ 通过 | 时间到期后正确弹出"时间结束"对话框，显示"知道了"按钮 |
| TC-14: 锁定弹窗倒计时 | ✅ 通过 | 第二轮弹窗显示5秒倒计时后才可关闭 |
| TC-17: 多App切换 | ✅ 通过 | 切换被监控应用时，倒计时继续从原始会话倒计时（正确行为） |
| TC-23: 第二轮限制到期 | ✅ 通过 | 第二次时间到期后正确触发强制休息 |

### 发现的问题

#### 🔴 严重问题

**问题1: 监控应用列表为空 (P0)**
- **描述**: `monitored_apps` 数据库表为空，导致`shouldTrackCurrent=false`，连续使用跟踪完全不激活
- **影响**: 用户无法通过正常流程添加被监控应用，连续使用功能形同虚设
- **复现步骤**: 
  1. 新安装应用
  2. 不进入家长模式配置应用
  3. 观察监控日志
- **预期**: 应有默认监控应用或引导用户添加
- **实际**: 监控服务运行但不跟踪任何应用
- **日志证据**: `[UsageMonitor] shouldTrackCurrent=false: currentApp=..., lastSessionApp=null, isActive=false`

**问题2: 多次限制到期后强制休息失效 (P1)**
- **描述**: 在多次强制休息循环后，系统停留在`atLimit`状态，但不再实际触发锁定overlay，使用时间持续累加
- **影响**: 孩子可以无限期使用应用，连续使用限制被完全绕过
- **数据**: 累计使用达13801秒（约3.8小时），远超2分钟限制
- **日志证据**: 
  ```
  [ContinuousUsage] Accumulated 30s for tv.danmaku.bilibilihd, new total: 13801s
  [UsageMonitor] Session atLimit, skip stopwatch widget (waiting for forced rest)
  [UsageMonitor] 强制休息处理中，跳过 _checkForbiddenApp 弹窗
  ```
- **分析**: 强制休息状态机在多次循环后出现状态不一致，`_forceRestInProgress`标志未正确重置

#### 🟡 中等问题

**问题3: 家长密码无法通过SharedPreferences读取 (P2)**
- **描述**: 密码存储在FlutterSecureStorage中（加密），无法通过adb直接读取
- **影响**: 测试自动化受限，需要手动输入密码
- **建议**: 提供测试模式或万能密码

**问题4: Android原生搜索框输入中文报错 (P2)**
- **描述**: 通过adb向Android原生搜索框输入中文时抛出NullPointerException
- **影响**: 无法通过UI自动化测试设置页面
- **解决方案**: 使用monkey命令启动应用

#### 🟢 轻微问题

**问题5: 倒计时Widget偶尔消失**
- **描述**: 倒计时widget在某些情况下会短暂消失后重新出现
- **影响**: 用户体验不佳，但功能正常
- **可能原因**: MIUI系统回收widget或内存标志与原生状态不同步

## 核心功能验证

### ✅ 正常工作的功能

1. **监控服务轮询**: UsageMonitorService每30秒正确轮询前台app
2. **被监控应用识别**: 当monitored_apps表有数据时，正确识别被监控应用
3. **时间累加**: 正确累加被监控应用的使用时间
4. **倒计时Widget**: 在剩余时间≤5分钟时正确显示倒计时
5. **强制休息弹窗**: 时间到期后正确弹出"时间结束"对话框
6. **会话重置**: 离开被监控应用超过阈值后正确重置会话
7. **应用切换处理**: 切换被监控应用时正确保持倒计时状态

### ❌ 异常行为

1. **多次循环后失效**: 强制休息机制在多次循环后停止工作
2. **初始配置缺失**: 新安装应用的monitored_apps表为空

## 建议修复方案

### 针对问题1 (P0)
1. 在首次启动引导流程中添加"选择要监控的应用"步骤
2. 或提供一些默认推荐的监控应用（如常见游戏、视频app）
3. 确保`monitored_apps`表在应用初始化时有合理的默认数据

### 针对问题2 (P1)
1. 检查`_forceRestInProgress`标志的重置逻辑
2. 在强制休息结束后确保状态机完全重置
3. 添加强制休息状态的持久化检查，防止状态不一致
4. 建议在`ContinuousUsageService`中添加状态校验机制

## 测试结论

连续使用时长功能的**核心机制正常工作**：
- 监控服务正确轮询和识别被监控应用
- 时间累加和倒计时显示正确
- 单次强制休息弹窗正确触发

但存在**严重的状态管理问题**，导致多次循环后功能失效。建议优先修复问题2（多次限制到期后强制休息失效），这是影响产品核心价值的关键bug。

## 附录

### 测试环境截图
- 倒计时widget显示截图
- 强制休息弹窗截图（第一轮、第二轮）
- 异常状态截图（累计13801秒）

### 关键日志片段
```
# 正常工作
[UsageMonitor] Polling - currentApp: tv.danmaku.bilibilihd
[ContinuousUsage] Accumulated 30s for tv.danmaku.bilibilihd, new total: 59s
[UsageMonitor] Session atLimit, skip stopwatch widget

# 异常状态
[ContinuousUsage] Accumulated 30s for tv.danmaku.bilibilihd, new total: 13801s
[UsageMonitor] 强制休息处理中，跳过 _checkForbiddenApp 弹窗
```

---
**报告生成时间**: 2026-06-11 07:35
**测试状态**: 完成
