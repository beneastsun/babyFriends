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