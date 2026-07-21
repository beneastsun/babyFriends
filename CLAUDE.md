# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**巧巧小伙伴 (Qiaoqiao Companion)** - A gamified Android app to help children develop healthy tablet usage habits. Target device: Xiaomi Android tablets.

**Core Concept**: Trust + Companionship + Incentives > Forced Control. Children earn "阳光积分" (sunshine points) by following time rules, which can be exchanged for extra entertainment time.

## Commands

```bash
# Working directory
cd qiaoqiao_companion

# Install dependencies
flutter pub get

# Run the app (debug)
flutter run

# Build release APK
flutter build apk --release

# Analyze code
flutter analyze

# Run tests
flutter test

# Run single test file
flutter test test/path/to/test.dart

# Clean build
flutter clean && flutter pub get

# Generate Riverpod providers (if using @riverpod annotations)
flutter pub run build_runner build --delete-conflicting-outputs
```

## Architecture

### Flutter + Dart + Kotlin

```
lib/
├── main.dart                    # Entry point with ProviderScope
├── app/                         # App configuration
│   ├── router.dart              # GoRouter routes (uses ShellRoute for bottom nav)
│   ├── app_initializer.dart     # Startup logic (DB, permissions, onboarding)
│   └── shell_page.dart          # Bottom navigation shell
├── core/
│   ├── database/                # SQLite with sqflite
│   │   ├── app_database.dart    # DB schema (6 tables)
│   │   ├── database_service.dart # DB singleton service
│   │   └── daos/                # Data Access Objects
│   ├── platform/                # Flutter ↔ Android native channels
│   │   ├── usage_stats_service.dart
│   │   ├── overlay_service.dart
│   │   └── monitor_service.dart
│   ├── services/                # Business logic services
│   ├── constants/               # App constants
│   └── theme/                   # App theme
├── features/                    # Feature modules (domain-driven)
│   ├── home/                    # Home page with Qiaoqiao avatar
│   ├── report/                  # Usage reports & weekly summary
│   ├── rules/                   # Rule display for child
│   ├── settings/                # App settings & backup
│   ├── onboarding/              # First-time setup wizard (6 steps)
│   ├── parent_mode/             # Password-protected parent controls
│   ├── points/                  # Points history view
│   └── achievement/             # Achievement badges
└── shared/
    ├── models/                  # Data models (AppUsageRecord, Rule, Coupon, etc.)
    ├── providers/               # Riverpod providers
    └── widgets/                 # Shared UI (ReminderDialog, CouponExchangeDialog, etc.)
```

### Android Native Channels

Located in `android/app/src/main/kotlin/com/qiaoqiao/qiaoqiao_companion/`:

| Channel | Channel Name | Purpose |
|---------|--------------|---------|
| `UsageStatsChannel` | `com.qiaoqiao.companion/usage_stats` | Query app usage stats via UsageStatsManager |
| `OverlayChannel` | `com.qiaoqiao.companion/overlay` | Display lock overlay windows |
| `ServiceChannel` | `com.qiaoqiao.qiaoqiao_companion/service` | Control foreground monitoring service |
| `BootReceiver` | N/A | Auto-start on boot via RECEIVE_BOOT_COMPLETED |

### ROM-Specific Adaptations

`RomUtils.kt` handles manufacturer-specific settings for auto-start permissions:

| ROM Type | Needs Auto-Start Permission Guide |
|----------|-----------------------------------|
| MIUI (Xiaomi) | Yes - primary target device |
| EMUI/Harmony (Huawei) | Yes |
| ColorOS (OPPO) | Yes |
| FunTouch/OriginOS (vivo) | Yes |
| OneUI (Samsung) | Yes |
| Stock Android | No |

Use `ServiceChannel.checkAutoStartPermission()` to detect if auto-start guidance is needed.

### Database Tables (`core/database/app_database.dart`)

| Table | Purpose |
|-------|---------|
| `app_usage_records` | App usage time tracking (indexed by date, package_name) |
| `rules` | Time/category/app rules configuration |
| `points_history` | Points transaction log (indexed by created_at) |
| `coupons` | Time-extension coupons (status: available/used/expired) |
| `daily_stats` | Daily usage statistics (indexed by date) |
| `app_categories` | App category mappings (custom flag for manual classification) |

Note: `achievements` table not yet implemented in current schema.

### State Management (Riverpod)

Key providers in `shared/providers/`:
- `appInitializationProvider` - App initialization state (database, permissions, onboarding)
- `todayUsageProvider` - Today's usage stats
- `rulesProvider` - Active rules
- `pointsProvider` - Current points balance
- `couponsProvider` - Available coupons
- `achievementProvider` - User achievements
- `usageMonitorServiceProvider` - Background monitoring service

### Core Services (`core/services/`)

| Service | Purpose |
|---------|---------|
| `UsageMonitorService` | Polls every 30s, records usage, checks rules |
| `ReminderService` | Triggers tiered reminders based on rule violations |
| `RuleCheckerService` | Evaluates rules against current usage |
| `AppCategoryMatcher` | Auto-classifies apps by package name |
| `BackupService` | Export/import data as CSV |
| `SoundService` | Plays reminder sound effects |
| `AnimationService` | Manages Lottie animations for Qiaoqiao |

### App Flow

1. **AppInitializer** (`app/app_initializer.dart`) checks: database ready → permissions granted → onboarding completed
2. Router (`app/router.dart`) determines initial route based on initialization state:
   - `/loading` → database not ready
   - `/permissions` → database ready but permissions missing
   - `/onboarding` → permissions granted but onboarding incomplete
   - `/home` → fully initialized
3. Main app uses `ShellRoute` with bottom navigation (home/report/rules/settings)
4. Parent mode accessed via long-press on home avatar + password verification (`ParentAuthService`)
5. On completion, `UsageMonitorService` and `MonitorForegroundService` start automatically

## Key Implementation Details

### Permission Requirements

- `PACKAGE_USAGE_STATS` - App usage statistics
- `SYSTEM_ALERT_WINDOW` - Overlay lock screen
- `FOREGROUND_SERVICE` - Background monitoring
- `RECEIVE_BOOT_COMPLETED` - Auto-start on boot

### Monitoring Service

`UsageMonitorService` polls every 30 seconds:
1. Gets current foreground app via native channel
2. Records usage time to database
3. Checks rules and triggers reminders
4. Updates daily statistics

### Reminder Levels (4 levels)

1. **5 min before limit** - Gentle reminder, can continue
2. **At limit** - Serious reminder, can continue
3. **5 min over limit** - Final warning with countdown
4. **8 min over limit** - Force lock via overlay

### Points System

- Earn: Early stop (+10), Daily compliance (+20), Forbidden period compliance (+15), 3-day streak (+30)
- Spend: Exchange for time coupons (15/30/60 min)
- Cap: 9999 points max, 0 min

## Design Document

Full product spec: `docs/superpowers/specs/2026-03-15-qiaoqiao-companion-design.md`

## 要求
在完成任何任务前，描述你将如何验证这项工作。

---

# 双模式自动执行规则

## 核心判断逻辑
你必须先根据用户输入自动判断任务类型，再对应执行，无需用户手动指定模式、无需手动敲斜杠命令。

### 模式1：单项任务（默认优先匹配）
#### 触发条件
用户描述仅涉及单一研发环节，关键词包含但不限于：评审、审查、审计、检查、排查、分析、优化、设计，且未提及「完整开发、做一个功能、全流程」等表述。

#### 自动映射规则
匹配到对应场景后，**自动调用对应能力执行**，输出结果直接返回，禁止跳步：

| 用户场景描述 | 自动调用能力 | 输出要求 |
|--------------|-------------|----------|
| 代码评审、代码审查、查代码质量 | `superpowers:requesting-code-review`（审任意文件）；若已有 git diff 则追加 `/review` | 按 P0/P1/P2 分级输出问题，附文件路径+行号+修复建议 |
| 安全审计、查安全漏洞、安全检查 | `/cso` | 重点覆盖 SQL 注入、权限越权、输入校验、数据泄露，按风险等级输出 |
| 需求规格化、需求分析、写需求文档 | `/spec` | 输出五阶段结构化需求规格，含业务边界、异常场景、验收标准 |
| 产品方向讨论、值不值得做、产品头脑风暴 | `/office-hours` | YC 风格产品讨论，输出方向建议和关键决策点 |
| 方案设计、技术选型、实现路径探索 | `superpowers:brainstorming`（方案探索）→ `superpowers:writing-plans`（写实现计划） | 输出模块划分、接口定义、数据结构、风险点、落地方案 |
| 故障排查、bug 定位、根因分析 | `/debug-systemic-thinking`（Flutter+原生多层系统优先）→ `/investigate`（通用场景兜底） | 先定位根因再给修复方案，禁止未定位根因直接改代码 |
| 发布交付、创建 PR、推送代码 | `/ship` | 执行 PR 创建+推送流程，含 diff 审查、版本号更新、CHANGELOG |
| 测试驱动开发、写测试用例 | `superpowers:test-driven-development` + `flutter test` | TDD 红绿重构循环，覆盖正常/异常/边界用例 |
| Web 应用 QA 测试 | `/qa`（仅限 Web 应用，需 headless browser） | 输出 QA 测试报告，含 bug 修复和健康度评分 |
| 代码健康度检查、质量评分 | `/health` | 输出 0-10 综合评分，含类型检查、lint、死代码检测趋势 |
| UI 视觉审查、设计打磨 | `/design-review` | 找出视觉不一致、间距问题、层级问题，自动修复 |
| 浏览器自动化、网页交互、截图 | `/agent-browser`（Playwright 双向交互，非 /browse） | 完成浏览器操作任务，输出截图或交互结果 |
| Android 后台保活、MIUI 强杀排查 | `/android-background-service` | 系统化排查 ROM 强杀问题，输出保活方案 |
| API 接口测试 | `/api-test` | 自动生成测试用例、执行 HTTP 请求、输出测试报告 |
| 系统测试、真机测试、UI 测试、自动化测试 | `android-uiautomator-test` | 基于 UIAutomator2 + ADB 的端到端系统测试，生成框架代码、执行测试、输出报告 |

#### 单项任务硬性规则
1. 只读类任务（评审、审计、排查）默认只分析不修改代码，如需修改必须先征得用户同意
2. 输出必须结构化，禁止冗余废话，直接给结论和可执行建议
3. 优先使用自定义技能（debug-systemic-thinking、agent-browser、android-background-service、api-test、android-uiautomator-test），gstack 技能作为补充

---

### 模式2：全流程半自动开发
#### 触发条件
用户描述为完整功能/模块开发，关键词包含但不限于：开发、实现、新增、做一个功能、搭建一个模块、完整需求，且涉及从需求到交付的全链路。

#### 自动执行逻辑
1. 自动调用 `Agent` tool，指定 `subagent_type: "dev-pipeline-bot"` 承接任务
2. 严格按照「需求规格→方案计划→TDD编码→三审→验收交付」五阶段推进
3. 需求定稿、方案确认、发布审批 三个节点必须暂停，等待用户确认后再继续
4. 每个阶段完成后主动告知当前进度和成果，禁止静默跳步