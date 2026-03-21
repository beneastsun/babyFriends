# Findings & Decisions

<!--
  WHAT: 任务的知识库。存储所有发现和决策。
  WHY: 上下文窗口有限。此文件是"外部记忆" - 持久且无限。
  WHEN: 在任何发现后更新，特别是 2 次 view/browser/search 操作后（2-Action Rule）。
-->

## Requirements

<!-- 从用户请求中捕获的需求 -->
- 帮助 11 岁女孩健康使用平板的游戏化陪伴应用
- 控制平板总使用时间和特定应用使用时间
- 设置禁止使用时段（学习、睡觉时间）
- 通过游戏化激励机制，让孩子主动配合
- 提供使用数据报告，了解习惯变化
- 目标设备：Android 小米平板

## Research Findings

<!-- 探索过程中的关键发现 -->
- 项目尚未初始化，只有设计文档
- 设计文档路径：`d:\Developfile\baby-Friends\docs\superpowers\specs\2026-03-15-qiaoqiao-companion-design.md`
- 设计文档非常详细，包含完整的技术架构、数据库设计、UI 设计

### 技术栈（来自设计文档）

| 层面 | 技术 | 说明 |
|------|------|------|
| 框架 | Flutter | 跨平台，UI 开发效率高 |
| 语言 | Dart + Kotlin | Dart 主逻辑，Kotlin 原生通道 |
| 状态管理 | Riverpod | 响应式状态管理 |
| 数据库 | SQLite (sqflite) | 本地数据存储 |
| 动画 | Lottie | 巧巧动画效果 |

### 数据库表设计

| 表名 | 说明 |
|------|------|
| app_usage_records | 使用记录表 |
| rules | 规则配置表 |
| points_history | 积分流水表 |
| coupons | 加时券表 |
| daily_stats | 每日统计表 |
| app_categories | 应用分类表 |

---

## Technical Decisions

<!-- 带有理由的架构和实现选择 -->

| Decision | Rationale |
|----------|-----------|
| 使用 Flutter + Dart + Kotlin | 设计文档中确定的技术栈 |
| 状态管理用 Riverpod | 响应式、性能好、文档完善 |
| 路由用 GoRouter | 声明式路由，支持深层链接 |
| 数据库用 sqflite | Flutter 官方推荐的 SQLite 库 |
| 巧巧形象用占位图 | 用户确认，后续可替换 |
| 使用 Overlay 悬浮窗作为主锁定方案 | 实现相对简单，兼容性较好 |
| 规则界面采用 3 Tab 布局 | 用户选择，清晰分离时间段/应用/连续使用 |
| 连续使用会话存数据库 | 支持跨重启恢复，用 SharedPreferences 只存设置 |

---

## Issues Encountered

<!-- 遇到的问题及解决方法 -->

| Issue | Resolution |
|-------|------------|
| - | - |

---

## Resources

<!-- 有用的 URL、文件路径、API 引用 -->

### 文档
- 设计文档：`d:\Developfile\baby-Friends\docs\superpowers\specs\2026-03-15-qiaoqiao-companion-design.md`

### 依赖包
- flutter_riverpod: ^2.4.9
- sqflite: ^2.3.0
- go_router: ^13.0.0
- lottie: ^2.7.0
- fl_chart: ^0.66.0

### 项目结构
```
qiaoqiao_companion/
├── lib/
│   ├── main.dart
│   ├── app/                    # App 配置、路由
│   ├── core/                   # 数据库、平台通道、主题
│   ├── features/               # 功能模块
│   ├── shared/                 # 共享组件、Provider
│   └── l10n/                   # 国际化
├── android/                    # 原生代码
└── assets/                     # 资源文件
```

---

## Visual/Browser Findings

<!-- 从图片、PDF 或浏览器结果中获取的信息 -->
- 暂无

---

<!--
  REMINDER: The 2-Action Rule
  After every 2 view/browser/search operations, you MUST update this file.
  This prevents visual information from being lost when context resets.
-->
*Update this file after every 2 view/browser/search operations*
