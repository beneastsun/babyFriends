# Task Plan: 巧巧小伙伴 - 完整开发路线图

<!--
  WHAT: 项目路线图，磁盘上的"工作记忆"
  WHY: 在多次工具调用后，原始目标可能被遗忘。此文件保持目标清晰。
  WHEN: 首先创建此文件，每完成一个阶段后更新。
-->

## Goal

创建巧巧小伙伴 Flutter 应用，帮助 11 岁女孩健康使用平板的游戏化陪伴应用。

## Current Phase

**Phase UI-Redesign: UI 重设计 - 苹果式简洁风格**（进行中）

> 🎨 设计目标: 精简配色 + 大量留白 + 柔和渐变 + 精致动效
> 📋 设计原则: 参考苹果设计，整体风格统一，只做一套精致的设计系统

---

### 阶段总览（更新）

| 阶段 | 内容 | 预估时间 | 状态 |
|------|------|----------|------|
| **阶段 UI-Redesign** | UI 重设计 - 苹果式简洁风格 | 约 3 天 | 🟡 进行中 |
| **阶段 1-5.0** | 基础框架 + 核心功能 | 已完成 | ✅ 完成 |
| **阶段 6** | 核心功能完善 | 约 1.5 周 | 🔴 待开始 |
| **阶段 7** | 用户体验优化 | 约 1 周 | 🔴 待开始 |

---

## 开发阶段总览

| 阶段 | 内容 | 预估时间 | 状态 |
|------|------|----------|------|
| **阶段 1** | 基础框架搭建 | 约 1 周 | ✅ 完成 |
| **阶段 2** | 监控与规则核心 | 约 1.5 周 | ✅ 完成 |
| **阶段 3** | 提醒与积分系统 | 约 1 周 | ✅ 完成 |
| **阶段 4** | 报告与完善 | 约 1 周 | ✅ 完成 |
| **阶段 5** | 核心功能完善 | 约 1.5 周 | 🔴 待开始 |
| **阶段 6** | 用户体验优化 | 约 1 周 | 🔴 待开始 |

---

## 阶段 UI-Redesign: UI 重设计 - 苹果式简洁风格

### 设计原则

参考苹果设计语言 + 适合 11 岁女孩的活泼感：

| 原则 | 描述 | 实现方式 |
|------|------|----------|
| **精简配色** | 只用 2-3 个主色，不花哨 | 主色 + 辅助色 + 语义色 |
| **大量留白** | 空间宽松，不拥挤 | 间距增加 20-30% |
| **柔和渐变** | 非霓虹色，舒适渐变 | 同色系渐变，低饱和度 |
| **精致动效** | 微动画，不夸张 | 缩放、淡入、弹性 |
| **整体统一** | 只做一套设计系统 | 所有页面用相同组件 |

### 新配色方案（苹果式简洁）

```dart
// 主色 - 柔和樱花粉
static const Color primary = Color(0xFFEC8B9F);      // 主色
static const Color primaryLight = Color(0xFFF5B5C4); // 浅色（悬停）
static const Color primaryDark = Color(0xFFD66A80);  // 深色（按下）

// 辅助色 - 淡薰衣草
static const Color secondary = Color(0xFFC5B3E6);    // 辅助
static const Color secondaryLight = Color(0xFFDDD0F0);

// 背景色 - 暖白
static const Color background = Color(0xFFFAF9F8);   // 背景暖白
static const Color surface = Color(0xFFFFFFFF);      // 卡片纯白

// 文字色 - 深灰
static const Color textPrimary = Color(0xFF1D1D1F);  // 主文字
static const Color textSecondary = Color(0xFF86868B); // 次文字
```

### Phase UI-1: 设计系统重构

- [ ] 创建新配色文件 `app_colors_simple.dart`
- [ ] 精简现有配色（移除多主题，只保留一套）
- [ ] 更新 Design Tokens（间距、圆角、阴影）
- [ ] 创建新的组件库（卡片、按钮、输入框）
- **Status:** 🔴 pending

### Phase UI-2: 首页重设计

- [ ] 重构巧巧卡片（大头像 + 简洁文字）
- [ ] 重构使用时间显示（大数字 + 进度环）
- [ ] 重构应用列表（简约卡片，左图标右信息）
- [ ] 添加微动效（淡入、缩放、滑动）
- **Status:** 🔴 pending

### Phase UI-3: 规则页面重设计

- [ ] 重构规则展示（卡片式布局，图标化）
- [ ] 重构进度条（细线、柔和颜色）
- [ ] 添加空状态插画
- **Status:** 🔴 pending

### Phase UI-4: 其他页面统一

- [ ] 设置页面统一风格
- [ ] 报告页面统一风格
- [ ] 家长模式页面统一风格
- **Status:** 🔴 pending

### Phase UI-5: 动效系统

- [ ] 创建通用动画组件（淡入、滑动、缩放）
- [ ] 添加页面切换动画
- [ ] 添加列表滚动动画
- **Status:** 🔴 pending

---

### Phase 1: 环境检查与项目初始化
- [x] 运行 `flutter doctor` 检查环境
- [x] 创建 Flutter 项目 `flutter create --org com.qiaoqiao --platforms android qiaoqiao_companion`
- [x] 配置 pubspec.yaml 依赖
- [x] 创建项目目录结构
- **Status:** ✅ complete

### Phase 2: 数据库设计与初始化
- [x] 创建 AppDatabase 主类
- [x] 创建 7 张数据表（app_usage_records, rules, points_history, coupons, daily_stats, app_categories, user_achievements）
- [x] 创建 DAO 层（7 个 DAO）
- [x] 测试数据库初始化
- **Status:** ✅ complete

### Phase 3: Android 原生通道搭建
- [x] 配置 AndroidManifest.xml 权限
- [x] 创建 UsageStatsChannel.kt（使用统计）
- [x] 创建 OverlayChannel.kt（悬浮窗）
- [x] 创建 Dart 端平台通道接口
- **Status:** ✅ complete

### Phase 4: 状态管理架构
- [x] 配置 Riverpod Provider
- [x] 创建状态模型（TodayUsage, PointsState, Rule 等）
- [x] 连接数据库与状态管理
- **Status:** ✅ complete

### Phase 5: UI 框架与导航
- [x] 配置 GoRouter 路由
- [x] 创建底部导航栏
- [x] 创建首页/报告/规则/设置 4 个页面框架
- [x] 配置主题和颜色
- **Status:** ✅ complete

### Phase 6: 集成测试与验证
- [x] 运行应用验证 UI
- [x] 测试数据库操作
- [x] 测试原生通道通信
- [x] 构建调试 APK
- **Status:** ✅ complete

---

## 阶段 2：监控与规则核心

### Phase 2.1: 应用使用监控服务
- [x] 创建 UsageMonitorService
- [x] 实现定时轮询机制（30秒间隔）
- [x] 记录使用时长到数据库
- [x] 实现前台应用检测
- **Status:** ✅ complete

### Phase 2.2: 提醒服务
- [x] 创建 ReminderService
- [x] 实现 4 级提醒逻辑（温和→认真→严肃→锁定）
- [x] 提醒时机计算（提前5分钟、时间到、超时5分钟、超时8分钟）
- **Status:** ✅ complete

### Phase 2.3: 规则检查服务
- [x] 创建 RuleCheckerService
- [x] 实现时间规则检查（每日限额、禁止时段）
- [x] 实现应用分类规则检查
- [x] 实现单独应用规则检查
- **Status:** ✅ complete

### Phase 2.4: 应用初始化逻辑
- [x] 创建 AppInitializer
- [x] 实现权限检查逻辑
- [x] 实现数据库预初始化
- [x] 实现预设规则加载
- **Status:** ✅ complete

### Phase 2.5: 权限引导页面
- [x] 创建 PermissionGuidePage
- [x] 实现使用统计权限引导
- [x] 实现悬浮窗权限引导
- [x] 权限状态实时检查
- **Status:** ✅ complete

---

## 阶段 3：提醒与积分系统

### Phase 3.1: 提醒对话框组件
- [x] 创建 ReminderDialog
- [x] 实现 4 种提醒类型 UI（温和/认真/严肃/锁定）
- [x] 巧巧形象状态切换
- [x] 倒计时显示
- **Status:** ✅ complete

### Phase 3.2: 积分动画组件
- [x] 创建 PointsAnimation 组件
- [x] 实现积分获得动画
- [x] 实现积分消耗动画
- [x] 实现积分数字滚动效果
- **Status:** ✅ complete

### Phase 3.3: 加时券兑换对话框
- [x] 创建 CouponExchangeDialog
- [x] 实现小/中/大加时券展示
- [x] 积分不足提示
- [x] 兑换确认与积分扣减
- **Status:** ✅ complete

### Phase 3.4: 积分历史页面
- [x] 创建 PointsHistoryPage
- [x] 积分流水列表展示
- [x] 积分余额显示
- [x] 获得积分类型统计
- **Status:** ✅ complete

---

## 阶段 4：报告与优化

### Phase 4.1: 成就系统
- [x] 创建 Achievement 模型和 AchievementDao
- [x] 创建 AchievementProvider
- [x] 创建 AchievementPage 展示页面
- [x] 定义成就列表（连续达标、积分里程碑等）
- **Status:** ✅ complete

### Phase 4.2: 设置页面完善
- [x] 通知设置开关
- [x] 主题切换功能
- [x] 提醒音效开关
- [x] 关于对话框
- **Status:** ✅ complete

### Phase 4.3: 整体优化
- [x] 清理 withOpacity 警告
- [x] 添加积分历史、成就页面路由
- [x] 更新积分相关枚举和常量
- **Status:** ✅ complete

---

## 阶段 5：家长管理规则界面重构 🟡 规格已完成

> 📋 规格文档: `docs/superpowers/specs/2026-03-19-parent-rules-redesign.md`
> 📋 实现计划: `docs/superpowers/plans/2026-03-19-parent-rules-redesign.md`

### Phase 5.0.1: 数据层 - 数据模型
- [x] 创建 `MonitoredApp` 模型 (`lib/shared/models/monitored_app.dart`)
- [x] 创建 `TimePeriod` 模型 (`lib/shared/models/time_period.dart`)
- [x] 创建 `ContinuousSession` 模型 (`lib/shared/models/continuous_session.dart`)
- [x] 在 `models.dart` 中导出新模型
- **Status:** ✅ complete

### Phase 5.0.2: 数据层 - DAO
- [x] 创建 `MonitoredAppDao` (`lib/core/database/daos/monitored_app_dao.dart`)
- [x] 创建 `TimePeriodDao` (`lib/core/database/daos/time_period_dao.dart`)
- [x] 创建 `ContinuousSessionDao` (`lib/core/database/daos/continuous_session_dao.dart`)
- [x] 在 `daos.dart` 中导出新 DAO
- **Status:** ✅ complete

### Phase 5.0.3: 数据层 - 数据库迁移
- [x] 更新数据库版本号 (v2 → v3)
- [x] 添加 `monitored_apps` 表
- [x] 添加 `time_periods` 表
- [x] 添加 `continuous_usage_sessions` 表
- [x] 实现数据迁移逻辑（timeBlock→time_periods, appSingle→monitored_apps）
- **Status:** ✅ complete

### Phase 5.0.4: 数据层 - Provider
- [x] 创建 `MonitoredAppsProvider`
- [x] 创建 `TimePeriodsProvider`
- [x] 创建 `ContinuousUsageProvider`
- **Status:** ✅ complete

### Phase 5.0.5: 服务层
- [x] 创建 `AppDiscoveryService`（发现已安装应用）
- [x] 创建 `ContinuousUsageService`（连续使用监控）
- [x] 重构 `RuleCheckerService`（新规则检查逻辑）
- **Status:** ✅ complete

### Phase 5.0.6: UI 层 - 组件
- [x] 创建 `TimePeriodCard` 组件
- [x] 创建 `MonitoredAppCard` 组件
- [x] 创建 `ContinuousUsageReminder` 弹窗
- **Status:** ✅ complete

### Phase 5.0.7: UI 层 - Tab 页面
- [x] 创建 `TimePeriodsTab`（时间段设置）
- [x] 创建 `AppManagementTab`（应用管理）
- [x] 创建 `AppSelectionPage`（应用选择）
- [x] 创建 `ContinuousUsageTab`（连续使用设置）
- **Status:** ✅ complete

### Phase 5.0.8: UI 层 - 主页面重构
- [x] 重构 `EditRulesPage` 为 Tab 布局
- **Status:** ✅ complete

### Phase 5.0.9: 集成测试
- [x] 端到端测试
- [x] 数据迁移验收
- [x] 功能验收
- **Status:** ✅ complete

---

## 阶段 6：核心功能完善 🔴 待开始

### Phase 6.1: 前台服务保活机制
- [ ] 创建 Android ForegroundService
- [ ] 添加常驻通知栏显示"巧巧守护中"
- [ ] 配置 WorkManager 心跳（15分钟检查）
- [ ] 实现服务被杀后自动重启
- **Status:** 🔴 pending

### Phase 5.2: 厂商 ROM 适配
- [ ] 小米 MIUI：自启动权限引导
- [ ] 华为 EMUI：受保护应用引导
- [ ] 创建厂商适配设置页面
- [ ] 添加电池优化白名单引导
- **Status:** 🔴 pending

### Phase 5.3: 家长模式入口
- [ ] 实现长按巧巧形象 5 秒触发
- [ ] 创建密码输入对话框
- [ ] 创建家长模式主页面
- [ ] 实现密码设置/修改功能
- **Status:** 🔴 pending

### Phase 5.4: 家长模式功能
- [ ] 修改时间规则功能
- [ ] 修改应用分类功能
- [ ] 发放加时券功能
- [ ] 调整积分功能
- [ ] 暂停监控功能
- **Status:** 🔴 pending

### Phase 5.5: 开机自启动
- [ ] 配置 RECEIVE_BOOT_COMPLETED 权限
- [ ] 创建 BootCompletedReceiver
- [ ] 开机后自动启动监控服务
- **Status:** 🔴 pending

---

## 阶段 6：用户体验优化 🔴 待开始

### Phase 6.1: 完整 Onboarding 流程
- [ ] 欢迎页面（巧巧动画打招呼）
- [ ] 家长确认页面（设置密码）
- [ ] 权限引导页面（已有，需整合）
- [ ] 基础规则设置页面
- [ ] 应用分类扫描与确认页面
- [ ] 介绍给孩子页面（玩法说明）
- **Status:** 🔴 pending

### Phase 6.2: 巧巧动画系统
- [ ] 设计/获取巧巧动画素材（4 种状态）
- [ ] 集成 Lottie 动画库
- [ ] 创建 QiaoqiaoAvatar 动画组件
- [ ] 根据状态自动切换动画
- **Status:** 🔴 pending

### Phase 6.3: 提醒音效系统
- [ ] 获取/制作提醒音效文件
- [ ] 集成 audioplayers 库
- [ ] 实现音效播放服务
- [ ] 设置页面音效开关关联
- **Status:** 🔴 pending

### Phase 6.4: 周报生成
- [ ] 实现周使用趋势计算
- [ ] 创建柱状图组件
- [ ] 最常用 App 排行统计
- [ ] 规则遵守评分计算（⭐ 评分）
- [ ] 周报详情页面
- **Status:** 🔴 pending

### Phase 6.5: 应用分类自动匹配
- [ ] 创建预设应用分类数据库（500+ 主流应用）
- [ ] 实现包名自动匹配逻辑
- [ ] 实现未分类应用首次使用提示
- [ ] 创建分类管理页面
- **Status:** 🔴 pending

### Phase 6.6: 数据备份恢复
- [ ] 实现每日自动备份（凌晨3点）
- [ ] 保留最近 7 天备份
- [ ] 数据导出 CSV 功能
- [ ] 数据恢复功能
- **Status:** 🔴 pending

---

## 阶段 7：测试与发布（未来）

### Phase 7.1: 测试
- [ ] 单元测试编写
- [ ] 集成测试编写
- [ ] 真机测试（小米平板）
- [ ] 长时间运行稳定性测试

### Phase 7.2: 发布准备
- [ ] 应用图标设计
- [ ] 应用截图准备
- [ ] 隐私政策编写
- [ ] 用户协议编写
- [ ] 软件著作权申请

### Phase 7.3: 上架
- [ ] 小米应用商店上架
- [ ] 华为应用商店上架
- [ ] 其他渠道上架

---

## Key Questions

1. ~~Flutter 环境是否正常工作？~~ → ✅ 已确认
2. ~~巧巧形象素材如何处理？~~ → 使用占位图，后续替换
3. 巧巧动画素材来源？ → 待确认（设计制作/网络获取）
4. 提醒音效来源？ → 待确认
5. 家长密码存储方式？ → 本地加密存储

---

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| 使用 Flutter + Dart + Kotlin | 设计文档中确定的技术栈 |
| 状态管理用 Riverpod | 响应式、性能好、文档完善 |
| 路由用 GoRouter | 声明式路由，支持深层链接 |
| 数据库用 sqflite | Flutter 官方推荐的 SQLite 库 |
| 巧巧形象用占位图 | 用户确认，后续可替换 |
| 保活用 ForegroundService | Android 标准后台保活方案 |
| 动画用 Lottie | 跨平台、性能好、设计文档推荐 |

---

## Errors Encountered

| Error | Attempt | Resolution |
|-------|---------|------------|
| - | - | - |

---

## Notes

- Update phase status as you progress: pending → in_progress → complete
- Re-read this plan before major decisions (attention manipulation)
- Log ALL errors - they help avoid repetition
- 最后更新：2026-03-15
