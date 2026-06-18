# Issues - fix-anr-and-freezing

## [2026-06-09] P0: 5-second poll interval causes main thread starvation
- UsageMonitorService.monitorIntervalSeconds = 5 is too aggressive
- Each poll cycle does: Native channel call + DB queries + DB writes + Provider invalidations
- Timer can queue up if a single cycle takes >5 seconds
- Fix: Change to 30 seconds, move full sync to separate 5-minute timer

## [2026-06-09] P0: Native getCurrentForegroundApp queries 2 hours of events
- UsageStatsChannel.getCurrentForegroundApp() queries endTime - 2 hours
- Gets called every 5 seconds from Flutter side
- Should only need last 30 seconds to determine current foreground app
- Same issue in UsageStatsHelper.kt

## [2026-06-09] P1: App icon Base64 encoding in every usage stats query
- queryUsageStats() calls getAppIconBase64() for every app
- Creates Bitmap ¡ú compress to PNG ¡ú Base64 encode ¡ú pass through MethodChannel
- This is wasted work when usage stats page isn't even visible
- Fix: Remove "appIcon" from response map

## [2026-06-09] P1: Full data rebuild every poll cycle
- _syncTodayUsageFromSystem() calls deleteByDate() then inserts fresh data
- Same for hourly usage data
- Should use UPSERT / incremental update instead

## [2026-06-09] P2: _acquireLock busy-wait pattern
- while (_lock != null) { await _lock!.future; } is a spin-wait
- Race condition between _releaseLock() and next _acquireLock()
- Should use queue-based mutex

## [2026-06-09] P2: Provider invalidate storm
- Every poll cycle invalidates 	odayHourlyTimelineNotifierProvider and ilteredAppUsageProvider
- Triggers unnecessary widget rebuilds
- Should only invalidate on full sync (every 5 minutes)
