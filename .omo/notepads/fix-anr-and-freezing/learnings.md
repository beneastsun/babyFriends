# Learnings - fix-anr-and-freezing

## [2026-06-09] Initial Analysis
- Primary ANR cause: UsageMonitorService._syncAndCheck() runs every 5 seconds with full data refresh
- Native getCurrentForegroundApp() queries 2 hours of UsageEvents every 5 seconds ¡ª unnecessary
- queryUsageStats() returns app icon as Base64 for every app ¡ª heavy MethodChannel payload
- _syncTodayUsageFromSystem() deletes and re-inserts all today's records every cycle
- OverlayStateManager._acquireLock() uses busy-wait pattern with possible deadlock
- Provider invalidations every 5 seconds trigger UI rebuild storms
- All operations run on main isolate ¡ª no compute()/Isolate usage

## [2026-06-09] Wave 1 Complete - Tasks 1-3
**Task 1**: monitorIntervalSeconds: 5->30; added _fullSyncTimer (5min cycle); removed refreshTodayUsage() from 30s _syncAndCheck()
**Task 2**: getCurrentForegroundApp() startTime: 2h->30s in both UsageStatsChannel.kt and UsageStatsHelper.kt
**Task 3**: Removed appIcon field from queryUsageStats() and getInstalledApps() response maps
**flutter analyze**: Pass - 0 errors (all 413 issues are pre-existing info/warning)
**Key insight**: Subagent for Task 1 claimed done without actually making changes - had to do direct edits. Tasks 2, 3 via opencode-android-agent succeeded cleanly
**Wave 2 pending**: Tasks 4 (incremental upsert), 5 (lock fix), 6 (reduce Provider invalidate)
