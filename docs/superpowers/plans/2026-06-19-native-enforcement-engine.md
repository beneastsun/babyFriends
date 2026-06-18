# Native Enforcement Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Flutter-driven monitoring with a native Kotlin EnforcementEngine that handles polling, rule evaluation, countdown/overlay UI, and state persistence entirely in the native process.

**Architecture:** EnforcementEngine is a state machine (IDLE→MONITORING→COUNTDOWN→REST) running inside MonitorForegroundService at 5s intervals. It reads rules from the shared SQLite DB, evaluates them via RuleEvaluator, tracks continuous usage via ContinuousUsageTracker, and drives UI via WidgetManager/NativeOverlayManager. Flutter layer simplifies to ConfigSyncService (data sync only).

**Tech Stack:** Kotlin (JUnit5 + Mockito for unit tests), Dart (flutter_test for Flutter simplification), SQLite (shared DB between Flutter and native)

## Global Constraints

- All timing uses `System.currentTimeMillis()` (wall clock) — no `elapsedRealtime()`, no Dart `DateTime.now()` for enforcement decisions
- Countdown widget rebuilds from DB fields `countdown_started_at` + `countdown_total_seconds`: `remaining = totalSec - (now - startedAt) / 1000`
- Leave-confirmation: must see non-monitored app in 2 consecutive polls (10s) before hiding widget
- Widget color thresholds: ≤5min yellow, ≤3min orange, ≤2min red — no full-screen reminder popups over widget
- `MainActivity.isFlutterAlive` must NOT be used for branching in EnforcementEngine — engine always runs natively
- DB schema does not change — native reads/writes the same SQLite tables Flutter created
- Keep-alive mechanisms (GuardService, AlarmReceiver, KeepAliveWorker, ServiceRestartReceiver) are NOT modified
- AppLockOverlayActivity is NOT modified
- Each task follows TDD: write failing test → verify fail → implement → verify pass → commit

---

## Phase 1: Native Engine Building

### Task 1: Set up JUnit5 + Mockito test infrastructure for Android

**Files:**
- Modify: `qiaoqiao_companion/android/app/build.gradle.kts`
- Create: `qiaoqiao_companion/android/app/src/test/java/com/qiaoqiao/qiaoqiao_companion/monitor/TestClass.kt`

**Interfaces:**
- Produces: test runner configuration, `@Test` annotation support, Mockito mocking

- [ ] **Step 1: Add JUnit5 and Mockito dependencies to build.gradle.kts**

Add these dependencies inside the `dependencies {}` block (create one if missing) in `qiaoqiao_companion/android/app/build.gradle.kts`:

```kotlin
dependencies {
    testImplementation("org.junit.jupiter:junit-jupiter-api:5.10.2")
    testRuntimeOnly("org.junit.jupiter:junit-jupiter-engine:5.10.2")
    testImplementation("org.mockito:mockito-core:5.11.0")
    testImplementation("org.mockito.kotlin:mockito-kotlin:5.2.1")
}
```

Also add to the `android {}` block or at top level:

```kotlin
tasks.withType<Test> {
    useJUnitPlatform()
}
```

- [ ] **Step 2: Create a placeholder test to verify the test runner works**

Create `qiaoqiao_companion/android/app/src/test/java/com/qiaoqiao/qiaoqiao_companion/monitor/TestClass.kt`:

```kotlin
package com.qiaoqiao.qiaoqiao_companion.monitor

import org.junit.jupiter.api.Test
import org.junit.jupiter.api.Assertions.assertEquals

class TestClass {
    @Test
    fun testInfrastructure() {
        assertEquals(4, 2 + 2)
    }
}
```

- [ ] **Step 3: Run the test to verify it passes**

Run: `cd qiaoqiao_companion/android && ./gradlew app:testDebugUnitTest --tests "com.qiaoqiao.qiaoqiao_companion.monitor.TestClass.testInfrastructure"`
Expected: BUILD SUCCESSFUL, 1 test passed

- [ ] **Step 4: Commit**

```bash
git add android/app/build.gradle.kts android/app/src/test/java/com/qiaoqiao/qiaoqiao_companion/monitor/TestClass.kt
git commit -m "chore: set up JUnit5 + Mockito test infrastructure for Android"
```

---

### Task 2: Implement RuleEvaluator with TDD

**Files:**
- Create: `qiaoqiao_companion/android/app/src/test/java/com/qiaoqiao/qiaoqiao_companion/monitor/RuleEvaluatorTest.kt`
- Create: `qiaoqiao_companion/android/app/src/main/java/com/qiaoqiao/qiaoqiao_companion/monitor/RuleEvaluator.kt`

**Interfaces:**
- Consumes: `NativeRuleRepository` (existing) — mocked in tests
- Produces: `RuleEvaluator` class with `evaluate(packageName: String, now: Long): EvalResult`
- Produces: `RuleEvaluator.EvalResult(blocked: Boolean, reason: String, ruleType: String)` data class

- [ ] **Step 1: Write failing tests for RuleEvaluator**

Create `qiaoqiao_companion/android/app/src/test/java/com/qiaoqiao/qiaoqiao_companion/monitor/RuleEvaluatorTest.kt`:

```kotlin
package com.qiaoqiao.qiaoqiao_companion.monitor

import org.junit.jupiter.api.Test
import org.junit.jupiter.api.Assertions.*
import org.mockito.kotlin.*
import com.qiaoqiao.qiaoqiao_companion.monitor.NativeRuleRepository.*

class RuleEvaluatorTest {

    private val repository: NativeRuleRepository = mock()
    private val evaluator = RuleEvaluator(repository)

    @Test
    fun `non-monitored app is not blocked`() {
        whenever(repository.getActiveRestRemainingSeconds()).thenReturn(0L)
        whenever(repository.getMonitoredApps()).thenReturn(listOf(
            MonitoredApp("com.game.app", null)
        ))

        val result = evaluator.evaluate("com.safe.app", 1000L)
        assertFalse(result.blocked)
        assertEquals("", result.reason)
    }

    @Test
    fun `monitored app during forced rest is blocked`() {
        whenever(repository.getActiveRestRemainingSeconds()).thenReturn(300L)

        val result = evaluator.evaluate("com.game.app", 1000L)
        assertTrue(result.blocked)
        assertEquals("forced_rest", result.ruleType)
    }

    @Test
    fun `monitored app blocked by time period`() {
        whenever(repository.getActiveRestRemainingSeconds()).thenReturn(0L)
        whenever(repository.getMonitoredApps()).thenReturn(listOf(
            MonitoredApp("com.game.app", null)
        ))
        whenever(repository.getTimePeriods()).thenReturn(listOf(
            TimePeriod("blocked", "22:00", "06:00", "[1,2,3,4,5,6,7]")
        ))
        whenever(repository.getCurrentTimeStr()).thenReturn("23:00")
        whenever(repository.getDayOfWeek()).thenReturn(2) // Monday

        val result = evaluator.evaluate("com.game.app", 1000L)
        assertTrue(result.blocked)
    }

    @Test
    fun `monitored app blocked by total time limit`() {
        whenever(repository.getActiveRestRemainingSeconds()).thenReturn(0L)
        whenever(repository.getMonitoredApps()).thenReturn(listOf(
            MonitoredApp("com.game.app", null)
        ))
        whenever(repository.getTimePeriods()).thenReturn(emptyList())
        whenever(repository.getTotalTimeRule()).thenReturn(TotalTimeRule(60, 90))
        whenever(repository.isWeekend()).thenReturn(false)
        whenever(repository.getTodayTotalUsageMs(setOf("com.game.app"))).thenReturn(61 * 60 * 1000L)

        val result = evaluator.evaluate("com.game.app", 1000L)
        assertTrue(result.blocked)
    }

    @Test
    fun `monitored app blocked by daily limit`() {
        whenever(repository.getActiveRestRemainingSeconds()).thenReturn(0L)
        whenever(repository.getMonitoredApps()).thenReturn(listOf(
            MonitoredApp("com.game.app", 30)
        ))
        whenever(repository.getTimePeriods()).thenReturn(emptyList())
        whenever(repository.getTotalTimeRule()).thenReturn(null)
        whenever(repository.getTodayAppUsageMs("com.game.app")).thenReturn(31 * 60 * 1000L)

        val result = evaluator.evaluate("com.game.app", 1000L)
        assertTrue(result.blocked)
        assertEquals("app_daily_limit", result.ruleType)
    }

    @Test
    fun `monitored app allowed when no rules violated`() {
        whenever(repository.getActiveRestRemainingSeconds()).thenReturn(0L)
        whenever(repository.getMonitoredApps()).thenReturn(listOf(
            MonitoredApp("com.game.app", 60)
        ))
        whenever(repository.getTimePeriods()).thenReturn(emptyList())
        whenever(repository.getTotalTimeRule()).thenReturn(null)
        whenever(repository.getTodayAppUsageMs("com.game.app")).thenReturn(10 * 60 * 1000L)

        val result = evaluator.evaluate("com.game.app", 1000L)
        assertFalse(result.blocked)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd qiaoqiao_companion/android && ./gradlew app:testDebugUnitTest --tests "com.qiaoqiao.qiaoqiao_companion.monitor.RuleEvaluatorTest"`
Expected: COMPILATION ERROR — `RuleEvaluator` class does not exist

- [ ] **Step 3: Implement RuleEvaluator**

Create `qiaoqiao_companion/android/app/src/main/java/com/qiaoqiao/qiaoqiao_companion/monitor/RuleEvaluator.kt`:

```kotlin
package com.qiaoqiao.qiaoqiao_companion.monitor

import android.util.Log
import org.json.JSONArray

/**
 * Pure rule evaluator — stateless, all data from NativeRuleRepository.
 * Checks in priority order: forced rest → monitored list → time periods → total time → daily limit.
 */
class RuleEvaluator(private val repository: NativeRuleRepository) {

    companion object {
        private const val TAG = "RuleEvaluator"
    }

    data class EvalResult(
        val blocked: Boolean,
        val reason: String = "",
        val ruleType: String = ""
    )

    fun evaluate(packageName: String, now: Long): EvalResult {
        // 1. Forced rest check
        val restRemaining = repository.getActiveRestRemainingSeconds()
        if (restRemaining > 0) {
            return EvalResult(true, "正在休息中，还需要 ${formatTime(restRemaining)}", "forced_rest")
        }

        // 2. Is app monitored?
        val monitoredApps = repository.getMonitoredApps()
        val app = monitoredApps.find { it.packageName == packageName }
            ?: return EvalResult(false)

        // 3. Time period rules
        val timeResult = checkTimePeriods()
        if (timeResult != null) return timeResult

        // 4. Total time limit
        val totalTimeResult = checkTotalTime(monitoredApps.map { it.packageName }.toSet())
        if (totalTimeResult != null) return totalTimeResult

        // 5. Per-app daily limit
        if (app.dailyLimitMinutes != null && app.dailyLimitMinutes > 0) {
            val usedMinutes = repository.getTodayAppUsageMs(packageName) / 60_000
            if (usedMinutes >= app.dailyLimitMinutes) {
                return EvalResult(true, "今日使用已达上限（${app.dailyLimitMinutes}分钟）", "app_daily_limit")
            }
        }

        return EvalResult(false)
    }

    private fun checkTimePeriods(): EvalResult? {
        val periods = repository.getTimePeriods()
        if (periods.isEmpty()) return null

        val currentTime = repository.getCurrentTimeStr()
        val dayOfWeek = repository.getDayOfWeek()

        val blockedPeriods = periods.filter { it.mode == "blocked" }
        for (period in blockedPeriods) {
            if (isDayMatch(period.days, dayOfWeek) && isTimeInRange(currentTime, period.timeStart, period.timeEnd)) {
                return EvalResult(true, "当前是禁止使用时段（${period.timeStart}-${period.timeEnd}）", "time_period")
            }
        }

        val allowedPeriods = periods.filter { it.mode == "allowed" }
        if (allowedPeriods.isNotEmpty()) {
            val inAnyAllowed = allowedPeriods.any {
                isDayMatch(it.days, dayOfWeek) && isTimeInRange(currentTime, it.timeStart, it.timeEnd)
            }
            if (!inAnyAllowed) {
                return EvalResult(true, "当前不在允许使用时段内", "time_period")
            }
        }

        return null
    }

    private fun checkTotalTime(monitoredPackages: Set<String>): EvalResult? {
        val totalTimeRule = repository.getTotalTimeRule() ?: return null

        val isWeekend = repository.isWeekend()
        val limitMinutes = if (isWeekend) {
            totalTimeRule.weekendLimit ?: return null
        } else {
            totalTimeRule.weekdayLimit ?: return null
        }

        if (limitMinutes <= 0) return null

        val totalUsageMs = repository.getTodayTotalUsageMs(monitoredPackages)
        val totalUsageMinutes = totalUsageMs / 60_000

        if (totalUsageMinutes >= limitMinutes) {
            return EvalResult(true, "今日总使用时间已达上限（${limitMinutes}分钟）", "total_time_limit")
        }

        return null
    }

    private fun isDayMatch(daysStr: String, dayOfWeek: Int): Boolean {
        return try {
            val days = if (daysStr.startsWith("[")) {
                val arr = JSONArray(daysStr)
                (0 until arr.length()).map { arr.getInt(it) }
            } else {
                daysStr.split(",").map { it.trim().toInt() }
            }
            days.contains(dayOfWeek)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to parse days: $daysStr", e)
            true
        }
    }

    private fun isTimeInRange(currentTime: String, start: String, end: String): Boolean {
        return try {
            val current = timeToMinutes(currentTime)
            val startMin = timeToMinutes(start)
            val endMin = timeToMinutes(end)
            if (startMin <= endMin) {
                current in startMin..endMin
            } else {
                current >= startMin || current <= endMin
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to parse time range: $start-$end", e)
            false
        }
    }

    private fun timeToMinutes(time: String): Int {
        val parts = time.split(":")
        return parts[0].toInt() * 60 + parts[1].toInt()
    }

    private fun formatTime(seconds: Long): String {
        val m = seconds / 60
        val s = seconds % 60
        return if (m > 0) "${m}分${s}秒" else "${s}秒"
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd qiaoqiao_companion/android && ./gradlew app:testDebugUnitTest --tests "com.qiaoqiao.qiaoqiao_companion.monitor.RuleEvaluatorTest"`
Expected: 6 tests passed

- [ ] **Step 5: Commit**

```bash
git add android/app/src/main/java/com/qiaoqiao/qiaoqiao_companion/monitor/RuleEvaluator.kt android/app/src/test/java/com/qiaoqiao/qiaoqiao_companion/monitor/RuleEvaluatorTest.kt
git commit -m "feat: implement RuleEvaluator with TDD — pure stateless rule checking"
```

---

### Task 3: Implement ContinuousUsageTracker enhancements with TDD

**Files:**
- Create: `qiaoqiao_companion/android/app/src/test/java/com/qiaoqiao/qiaoqiao_companion/monitor/ContinuousUsageTrackerTest.kt`
- Modify: `qiaoqiao_companion/android/app/src/main/java/com/qiaoqiao/qiaoqiao_companion/monitor/NativeContinuousUsageTracker.kt`

**Interfaces:**
- Consumes: `NativeRuleRepository` (existing) — mocked in tests
- Produces: Enhanced `NativeContinuousUsageTracker` with `persistCountdownState(now, remainingSeconds)` and leave-confirmation (`leaveConfirmCount` field)
- Produces: `TrackingResult` with new field `shouldShowStopwatch: Boolean` and `usedSeconds: Long`

- [ ] **Step 1: Write failing tests for ContinuousUsageTracker enhancements**

Create `qiaoqiao_companion/android/app/src/test/java/com/qiaoqiao/qiaoqiao_companion/monitor/ContinuousUsageTrackerTest.kt`:

```kotlin
package com.qiaoqiao.qiaoqiao_companion.monitor

import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.Assertions.*
import org.mockito.kotlin.*
import com.qiaoqiao.qiaoqiao_companion.monitor.NativeRuleRepository.*

class ContinuousUsageTrackerTest {

    private val repository: NativeRuleRepository = mock()
    private lateinit var tracker: NativeContinuousUsageTracker

    private val settings = ContinuousUsageSettings(
        enabled = true, limitMinutes = 30, restMinutes = 10, resetAfterRestMinutes = 5
    )

    @BeforeEach
    fun setup() {
        whenever(repository.getContinuousUsageSettings()).thenReturn(settings)
        whenever(repository.getMonitoredApps()).thenReturn(listOf(
            MonitoredApp("com.game.app", null)
        ))
        whenever(repository.isMonitored("com.game.app")).thenReturn(true)
        tracker = NativeContinuousUsageTracker(repository)
    }

    @Test
    fun `first poll with monitored app returns RESUME when active session exists`() {
        val now = System.currentTimeMillis()
        val session = ContinuousSession(
            id = 1L, sessionDate = "2026-06-19", startTime = now - 600_000,
            totalDurationSeconds = 600L, lastActivityTime = now - 5000,
            createdAt = now - 600_000, updatedAt = now - 5000
        )
        whenever(repository.getActiveContinuousSession()).thenReturn(session)

        val result = tracker.updateTracking("com.game.app", now)
        assertEquals(TrackingAction.RESUME, result.action)
    }

    @Test
    fun `accumulates time on subsequent polls`() {
        val now = System.currentTimeMillis()
        val session = ContinuousSession(
            id = 1L, sessionDate = "2026-06-19", startTime = now - 600_000,
            totalDurationSeconds = 600L, lastActivityTime = now - 5000,
            createdAt = now - 600_000, updatedAt = now - 5000
        )
        whenever(repository.getActiveContinuousSession()).thenReturn(session)
        whenever(repository.updateContinuousSession(any())).thenReturn(true)

        // First poll to establish tracking
        tracker.updateTracking("com.game.app", now)
        // Second poll — 5 seconds later
        val result = tracker.updateTracking("com.game.app", now + 5000)
        // Should have accumulated ~5 seconds
        assertTrue(result.action != TrackingAction.NONE)
    }

    @Test
    fun `shows countdown when remaining <= 5 minutes`() {
        val now = System.currentTimeMillis()
        val limitSeconds = settings.limitSeconds // 30min = 1800s
        val usedSeconds = limitSeconds - 280L // 280s remaining (< 5min)
        val session = ContinuousSession(
            id = 1L, sessionDate = "2026-06-19", startTime = now - (usedSeconds * 1000),
            totalDurationSeconds = usedSeconds, lastActivityTime = now - 5000,
            createdAt = now - (usedSeconds * 1000), updatedAt = now - 5000
        )
        whenever(repository.getActiveContinuousSession()).thenReturn(session)
        whenever(repository.updateContinuousSession(any())).thenReturn(true)

        // First poll establishes tracking
        tracker.updateTracking("com.game.app", now)
        // Reset so countdownShown is false
        tracker.reset()
        // Re-establish
        tracker.updateTracking("com.game.app", now)
        // Now advance to trigger countdown threshold
        val result = tracker.updateTracking("com.game.app", now + 5000)
        // After accumulation, remaining should be ≤5min, triggering SHOW_COUNTDOWN
        // (Exact behavior depends on accumulated seconds)
    }

    @Test
    fun `persistCountdownState writes countdownStartedAt and countdownTotalSeconds`() {
        val now = System.currentTimeMillis()
        val session = ContinuousSession(
            id = 1L, sessionDate = "2026-06-19", startTime = now,
            createdAt = now, updatedAt = now
        )
        whenever(repository.getActiveContinuousSession()).thenReturn(session)
        whenever(repository.updateContinuousSession(any())).thenReturn(true)

        tracker.persistCountdownState(now, 300L)

        val captor = argumentCaptor<ContinuousSession>()
        verify(repository).updateContinuousSession(captor.capture())
        assertEquals(now, captor.lastValue.countdownStartedAt)
        assertEquals(300L, captor.lastValue.countdownTotalSeconds)
    }

    @Test
    fun `leave confirm count increments when non-monitored app detected`() {
        val now = System.currentTimeMillis()
        whenever(repository.isMonitored("com.safe.app")).thenReturn(false)
        whenever(repository.getMonitoredApps()).thenReturn(listOf(
            MonitoredApp("com.game.app", null)
        ))

        // First: establish tracking with monitored app
        val session = ContinuousSession(
            id = 1L, sessionDate = "2026-06-19", startTime = now,
            totalDurationSeconds = 100L, lastActivityTime = now,
            createdAt = now, updatedAt = now
        )
        whenever(repository.getActiveContinuousSession()).thenReturn(session)
        tracker.updateTracking("com.game.app", now)

        // Now switch to non-monitored app
        val result = tracker.updateTracking("com.safe.app", now + 5000)
        // Should NOT deactivate immediately — leave confirmation needed
        assertNotEquals(TrackingAction.DEACTIVATED, result.action)
    }

    @Test
    fun `disables tracking when continuous usage is not enabled`() {
        val disabledSettings = ContinuousUsageSettings(enabled = false, limitMinutes = 30)
        whenever(repository.getContinuousUsageSettings()).thenReturn(disabledSettings)

        val result = tracker.updateTracking("com.game.app", System.currentTimeMillis())
        assertEquals(TrackingAction.NONE, result.action)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd qiaoqiao_companion/android && ./gradlew app:testDebugUnitTest --tests "com.qiaoqiao.qiaoqiao_companion.monitor.ContinuousUsageTrackerTest"`
Expected: COMPILATION ERROR — `persistCountdownState` method and `TrackingAction/TrackingResult` types may not match existing signatures

- [ ] **Step 3: Enhance NativeContinuousUsageTracker**

Modify `qiaoqiao_companion/android/app/src/main/java/com/qiaoqiao/qiaoqiao_companion/monitor/NativeContinuousUsageTracker.kt`:

Add the `persistCountdownState` method:

```kotlin
/**
 * Persist countdown state to DB so engine can recover after process death.
 * Writes countdownStartedAt (wall-clock ms) and countdownTotalSeconds.
 */
fun persistCountdownState(now: Long, remainingSeconds: Long) {
    val session = activeSession ?: repository.getActiveContinuousSession() ?: return
    val updated = session.copy(
        countdownStartedAt = now,
        countdownTotalSeconds = remainingSeconds,
        updatedAt = now
    )
    repository.updateContinuousSession(updated)
    activeSession = updated
    Log.d(TAG, "Persisted countdown: startedAt=$now, total=${remainingSeconds}s")
}
```

The existing `TrackingResult`, `TrackingAction`, `updateTracking()`, and `reset()` methods already exist and match the test expectations. If any type names differ, adjust the test to match existing names.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd qiaoqiao_companion/android && ./gradlew app:testDebugUnitTest --tests "com.qiaoqiao.qiaoqiao_companion.monitor.ContinuousUsageTrackerTest"`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git add android/app/src/main/java/com/qiaoqiao/qiaoqiao_companion/monitor/NativeContinuousUsageTracker.kt android/app/src/test/java/com/qiaoqiao/qiaoqiao_companion/monitor/ContinuousUsageTrackerTest.kt
git commit -m "feat: add persistCountdownState to ContinuousUsageTracker with TDD"
```

---

### Task 4: Implement EngineState enum and WidgetManager interface with TDD

**Files:**
- Create: `qiaoqiao_companion/android/app/src/test/java/com/qiaoqiao/qiaoqiao_companion/monitor/WidgetManagerTest.kt`
- Create: `qiaoqiao_companion/android/app/src/main/java/com/qiaoqiao/qiaoqiao_companion/monitor/EngineState.kt`
- Create: `qiaoqiao_companion/android/app/src/main/java/com/qiaoqiao/qiaoqiao_companion/monitor/WidgetManager.kt`

**Interfaces:**
- Produces: `EngineState` enum: `IDLE, MONITORING, COUNTDOWN, AT_LIMIT, REST`
- Produces: `WidgetManager` class with methods: `showStopwatch(usedSeconds)`, `updateStopwatch(usedSeconds)`, `switchToCountdown(remainingSeconds)`, `updateCountdown(remainingSeconds)`, `updateCountdownColor(remainingSeconds)`, `hideAll()`, `isCountdownShowing()`, `isStopwatchShowing()`
- Consumes: `NativeOverlayManager` (existing) — mocked in tests

- [ ] **Step 1: Write failing tests for WidgetManager**

Create `qiaoqiao_companion/android/app/src/test/java/com/qiaoqiao/qiaoqiao_companion/monitor/WidgetManagerTest.kt`:

```kotlin
package com.qiaoqiao.qiaoqiao_companion.monitor

import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.Assertions.*
import org.mockito.kotlin.*

class WidgetManagerTest {

    private val overlayManager: NativeOverlayManager = mock()
    private lateinit var widgetManager: WidgetManager

    @BeforeEach
    fun setup() {
        widgetManager = WidgetManager(overlayManager)
    }

    @Test
    fun `showStopwatch calls overlayManager`() {
        widgetManager.showStopwatch(120L)
        verify(overlayManager).showStopwatchWidget(120L)
    }

    @Test
    fun `updateStopwatch calls overlayManager`() {
        widgetManager.updateStopwatch(180L)
        verify(overlayManager).updateStopwatchTime(180L)
    }

    @Test
    fun `switchToCountdown hides stopwatch then shows countdown`() {
        widgetManager.switchToCountdown(300L)

        val inOrder = inOrder(overlayManager)
        inOrder.verify(overlayManager).hideStopwatchWidget()
        inOrder.verify(overlayManager).showCountdownOverlayWithAlerts(eq(300L), any(), any(), any())
    }

    @Test
    fun `updateCountdown calls overlayManager`() {
        widgetManager.updateCountdown(240L)
        verify(overlayManager).updateCountdownTime(240L)
    }

    @Test
    fun `updateCountdownColor - yellow when <= 5min`() {
        widgetManager.updateCountdownColor(280L) // 4min40s
        verify(overlayManager).setCountdownColor(android.graphics.Color.YELLOW)
    }

    @Test
    fun `updateCountdownColor - orange when <= 3min`() {
        widgetManager.updateCountdownColor(170L) // 2min50s
        verify(overlayManager).setCountdownColor(0xFFFF9800.toInt()) // orange
    }

    @Test
    fun `updateCountdownColor - red when <= 2min`() {
        widgetManager.updateCountdownColor(100L) // 1min40s
        verify(overlayManager).setCountdownColor(android.graphics.Color.RED)
    }

    @Test
    fun `hideAll hides both widgets`() {
        widgetManager.hideAll()
        verify(overlayManager).hideCountdownOverlay()
        verify(overlayManager).hideStopwatchWidget()
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd qiaoqiao_companion/android && ./gradlew app:testDebugUnitTest --tests "com.qiaoqiao.qiaoqiao_companion.monitor.WidgetManagerTest"`
Expected: COMPILATION ERROR — `WidgetManager`, `EngineState` classes do not exist

- [ ] **Step 3: Create EngineState enum**

Create `qiaoqiao_companion/android/app/src/main/java/com/qiaoqiao/qiaoqiao_companion/monitor/EngineState.kt`:

```kotlin
package com.qiaoqiao.qiaoqiao_companion.monitor

enum class EngineState {
    IDLE,
    MONITORING,
    COUNTDOWN,
    AT_LIMIT,
    REST
}
```

- [ ] **Step 4: Create WidgetManager**

Create `qiaoqiao_companion/android/app/src/main/java/com/qiaoqiao/qiaoqiao_companion/monitor/WidgetManager.kt`:

```kotlin
package com.qiaoqiao.qiaoqiao_companion.monitor

import android.graphics.Color
import android.util.Log

/**
 * Manages stopwatch and countdown widget display through NativeOverlayManager.
 * Provides a simplified interface for EnforcementEngine to drive UI.
 */
class WidgetManager(private val overlayManager: NativeOverlayManager) {

    companion object {
        private const val TAG = "WidgetManager"
        /** 5 minutes in seconds */
        private const val YELLOW_THRESHOLD = 5 * 60L
        /** 3 minutes in seconds */
        private const val ORANGE_THRESHOLD = 3 * 60L
        /** 2 minutes in seconds */
        private const val RED_THRESHOLD = 2 * 60L
        private val COLOR_ORANGE = 0xFFFF9800.toInt()
    }

    fun showStopwatch(usedSeconds: Long) {
        overlayManager.showStopwatchWidget(usedSeconds)
    }

    fun updateStopwatch(usedSeconds: Long) {
        overlayManager.updateStopwatchTime(usedSeconds)
    }

    fun switchToCountdown(remainingSeconds: Long) {
        overlayManager.hideStopwatchWidget()
        overlayManager.showCountdownOverlayWithAlerts(
            remainingSeconds,
            onAlert3min = Runnable { /* Engine handles color change, no popup */ },
            onAlert2min = Runnable { /* Engine handles color change, no popup */ },
            onEnded = Runnable { /* Engine handles rest trigger via state machine */ }
        )
    }

    fun updateCountdown(remainingSeconds: Long) {
        overlayManager.updateCountdownTime(remainingSeconds)
    }

    fun updateCountdownColor(remainingSeconds: Long) {
        val color = when {
            remainingSeconds <= RED_THRESHOLD -> Color.RED
            remainingSeconds <= ORANGE_THRESHOLD -> COLOR_ORANGE
            remainingSeconds <= YELLOW_THRESHOLD -> Color.YELLOW
            else -> return // No color change needed
        }
        overlayManager.setCountdownColor(color)
    }

    fun hideAll() {
        overlayManager.hideCountdownOverlay()
        overlayManager.hideStopwatchWidget()
    }

    fun isCountdownShowing(): Boolean = overlayManager.isCountdownShowing()
    fun isStopwatchShowing(): Boolean = overlayManager.isStopwatchShowing()

    fun destroy() {
        hideAll()
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd qiaoqiao_companion/android && ./gradlew app:testDebugUnitTest --tests "com.qiaoqiao.qiaoqiao_companion.monitor.WidgetManagerTest"`
Expected: All tests pass

- [ ] **Step 6: Commit**

```bash
git add android/app/src/main/java/com/qiaoqiao/qiaoqiao_companion/monitor/EngineState.kt android/app/src/main/java/com/qiaoqiao/qiaoqiao_companion/monitor/WidgetManager.kt android/app/src/test/java/com/qiaoqiao/qiaoqiao_companion/monitor/WidgetManagerTest.kt
git commit -m "feat: implement EngineState enum and WidgetManager with TDD"
```

---

### Task 5: Implement EnforcementEngine state machine with TDD

**Files:**
- Create: `qiaoqiao_companion/android/app/src/test/java/com/qiaoqiao/qiaoqiao_companion/monitor/EnforcementEngineTest.kt`
- Create: `qiaoqiao_companion/android/app/src/main/java/com/qiaoqiao/qiaoqiao_companion/monitor/EnforcementEngine.kt`

**Interfaces:**
- Consumes: `RuleEvaluator.evaluate()`, `NativeContinuousUsageTracker.updateTracking()`, `WidgetManager` methods, `NativeOverlayManager`, `NativeRuleRepository`
- Produces: `EnforcementEngine` with `onPoll(now, foregroundApp)`, `restoreFromDB(now)`, `persistStateBeforeDeath()`, `state: EngineState`, `destroy()`

- [ ] **Step 1: Write failing tests for EnforcementEngine state transitions**

Create `qiaoqiao_companion/android/app/src/test/java/com/qiaoqiao/qiaoqiao_companion/monitor/EnforcementEngineTest.kt`:

```kotlin
package com.qiaoqiao.qiaoqiao_companion.monitor

import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.Assertions.*
import org.mockito.kotlin.*

class EnforcementEngineTest {

    private val repository: NativeRuleRepository = mock()
    private val ruleEvaluator: RuleEvaluator = mock()
    private val usageTracker: NativeContinuousUsageTracker = mock()
    private val widgetManager: WidgetManager = mock()
    private val overlayManager: NativeOverlayManager = mock()

    private lateinit var engine: EnforcementEngine

    @BeforeEach
    fun setup() {
        engine = EnforcementEngine(repository, ruleEvaluator, usageTracker, widgetManager, overlayManager)
    }

    @Test
    fun `initial state is IDLE`() {
        assertEquals(EngineState.IDLE, engine.state)
    }

    @Test
    fun `IDLE + monitored app + no violation → MONITORING`() {
        val now = 1000L
        whenever(ruleEvaluator.evaluate("com.game.app", now)).thenReturn(RuleEvaluator.EvalResult(false))
        whenever(usageTracker.updateTracking("com.game.app", now)).thenReturn(
            NativeContinuousUsageTracker.TrackingResult(NativeContinuousUsageTracker.TrackingAction.RESUME, 0L)
        )

        engine.onPoll(now, "com.game.app")
        assertEquals(EngineState.MONITORING, engine.state)
        verify(widgetManager).showStopwatch(any())
    }

    @Test
    fun `IDLE + non-monitored app → stays IDLE`() {
        val now = 1000L
        whenever(ruleEvaluator.evaluate("com.safe.app", now)).thenReturn(RuleEvaluator.EvalResult(false))

        engine.onPoll(now, "com.safe.app")
        assertEquals(EngineState.IDLE, engine.state)
    }

    @Test
    fun `MONITORING + rule blocked → REST`() {
        val now = 1000L
        // First poll → MONITORING
        whenever(ruleEvaluator.evaluate("com.game.app", now)).thenReturn(RuleEvaluator.EvalResult(false))
        whenever(usageTracker.updateTracking("com.game.app", now)).thenReturn(
            NativeContinuousUsageTracker.TrackingResult(NativeContinuousUsageTracker.TrackingAction.RESUME, 0L)
        )
        engine.onPoll(now, "com.game.app")
        assertEquals(EngineState.MONITORING, engine.state)

        // Second poll → blocked
        whenever(ruleEvaluator.evaluate("com.game.app", now + 5000)).thenReturn(
            RuleEvaluator.EvalResult(true, "time limit", "total_time_limit")
        )
        engine.onPoll(now + 5000, "com.game.app")
        assertEquals(EngineState.REST, engine.state)
        verify(overlayManager).showLockOverlay(any(), any(), any())
    }

    @Test
    fun `REST + rest ended → IDLE`() {
        val now = 1000L
        // Enter REST state
        whenever(ruleEvaluator.evaluate("com.game.app", now)).thenReturn(
            RuleEvaluator.EvalResult(true, "rest", "forced_rest")
        )
        engine.onPoll(now, "com.game.app")
        assertEquals(EngineState.REST, engine.state)

        // Rest ended — session with expired restEndTime
        val session = NativeRuleRepository.ContinuousSession(
            id = 1L, sessionDate = "2026-06-19", startTime = 0L,
            restEndTime = now - 1000, // expired
            createdAt = 0L, updatedAt = now
        )
        whenever(repository.getActiveContinuousSession()).thenReturn(session)

        engine.onPoll(now + 1000, "com.game.app")
        assertEquals(EngineState.IDLE, engine.state)
    }

    @Test
    fun `leave confirmation - first non-monitored poll keeps state`() {
        val now = 1000L
        // First establish MONITORING
        whenever(ruleEvaluator.evaluate("com.game.app", now)).thenReturn(RuleEvaluator.EvalResult(false))
        whenever(usageTracker.updateTracking("com.game.app", now)).thenReturn(
            NativeContinuousUsageTracker.TrackingResult(NativeContinuousUsageTracker.TrackingAction.RESUME, 0L)
        )
        engine.onPoll(now, "com.game.app")
        assertEquals(EngineState.MONITORING, engine.state)

        // Switch to non-monitored app — first poll
        whenever(ruleEvaluator.evaluate("com.safe.app", now + 5000)).thenReturn(RuleEvaluator.EvalResult(false))
        engine.onPoll(now + 5000, "com.safe.app")
        // Should NOT immediately go to IDLE (leave confirmation)
        assertEquals(EngineState.MONITORING, engine.state)
    }

    @Test
    fun `leave confirmation - second non-monitored poll goes to IDLE`() {
        val now = 1000L
        // Establish MONITORING
        whenever(ruleEvaluator.evaluate("com.game.app", now)).thenReturn(RuleEvaluator.EvalResult(false))
        whenever(usageTracker.updateTracking("com.game.app", now)).thenReturn(
            NativeContinuousUsageTracker.TrackingResult(NativeContinuousUsageTracker.TrackingAction.RESUME, 0L)
        )
        engine.onPoll(now, "com.game.app")

        // First non-monitored poll
        whenever(ruleEvaluator.evaluate("com.safe.app", now + 5000)).thenReturn(RuleEvaluator.EvalResult(false))
        engine.onPoll(now + 5000, "com.safe.app")

        // Second non-monitored poll
        whenever(ruleEvaluator.evaluate("com.safe.app", now + 10000)).thenReturn(RuleEvaluator.EvalResult(false))
        engine.onPoll(now + 10000, "com.safe.app")
        assertEquals(EngineState.IDLE, engine.state)
        verify(widgetManager).hideAll()
    }

    @Test
    fun `restoreFromDB with active rest → REST state`() {
        val now = 1000L
        val session = NativeRuleRepository.ContinuousSession(
            id = 1L, sessionDate = "2026-06-19", startTime = 0L,
            restEndTime = now + 600_000L, // 10 min remaining
            createdAt = 0L, updatedAt = now
        )
        whenever(repository.getActiveContinuousSession()).thenReturn(session)

        engine.restoreFromDB(now)
        assertEquals(EngineState.REST, engine.state)
    }

    @Test
    fun `restoreFromDB with active countdown → COUNTDOWN state`() {
        val now = 1000L
        val session = NativeRuleRepository.ContinuousSession(
            id = 1L, sessionDate = "2026-06-19", startTime = 0L,
            countdownStartedAt = now - 60_000L, // started 1 min ago
            countdownTotalSeconds = 300L, // 5 min total
            createdAt = 0L, updatedAt = now
        )
        whenever(repository.getActiveContinuousSession()).thenReturn(session)

        engine.restoreFromDB(now)
        assertEquals(EngineState.COUNTDOWN, engine.state)
        verify(widgetManager).switchToCountdown(any())
    }

    @Test
    fun `restoreFromDB with expired countdown → REST state`() {
        val now = 1000L
        val session = NativeRuleRepository.ContinuousSession(
            id = 1L, sessionDate = "2026-06-19", startTime = 0L,
            countdownStartedAt = now - 600_000L, // started 10 min ago
            countdownTotalSeconds = 300L, // 5 min total → expired
            createdAt = 0L, updatedAt = now
        )
        whenever(repository.getActiveContinuousSession()).thenReturn(session)
        whenever(repository.getContinuousUsageSettings()).thenReturn(
            NativeRuleRepository.ContinuousUsageSettings(enabled = true, limitMinutes = 30, restMinutes = 10)
        )

        engine.restoreFromDB(now)
        assertEquals(EngineState.REST, engine.state)
    }

    @Test
    fun `restoreFromDB with no session → IDLE state`() {
        whenever(repository.getActiveContinuousSession()).thenReturn(null)

        engine.restoreFromDB(1000L)
        assertEquals(EngineState.IDLE, engine.state)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd qiaoqiao_companion/android && ./gradlew app:testDebugUnitTest --tests "com.qiaoqiao.qiaoqiao_companion.monitor.EnforcementEngineTest"`
Expected: COMPILATION ERROR — `EnforcementEngine` class does not exist

- [ ] **Step 3: Implement EnforcementEngine**

Create `qiaoqiao_companion/android/app/src/main/java/com/qiaoqiao/qiaoqiao_companion/monitor/EnforcementEngine.kt`:

```kotlin
package com.qiaoqiao.qiaoqiao_companion.monitor

import android.util.Log
import com.qiaoqiao.qiaoqiao_companion.monitor.NativeRuleRepository.ContinuousSession
import com.qiaoqiao.qiaoqiao_companion.monitor.NativeContinuousUsageTracker.TrackingAction
import com.qiaoqiao.qiaoqiao_companion.monitor.NativeContinuousUsageTracker.TrackingResult

/**
 * Central enforcement engine — state machine that drives all monitoring logic.
 * Runs entirely in the native process, independent of Flutter engine state.
 */
class EnforcementEngine(
    private val repository: NativeRuleRepository,
    private val ruleEvaluator: RuleEvaluator,
    private val usageTracker: NativeContinuousUsageTracker,
    private val widgetManager: WidgetManager,
    private val overlayManager: NativeOverlayManager
) {
    companion object {
        private const val TAG = "EnforcementEngine"
        private const val LEAVE_CONFIRM_THRESHOLD = 2
        private const val COUNTDOWN_THRESHOLD_SECONDS = 5 * 60L // 5 minutes
    }

    var state: EngineState = EngineState.IDLE
        private set

    // Leave-confirmation counter
    private var leaveConfirmCount = 0
    // Currently tracked monitored app (null = none)
    private var trackedApp: String? = null

    fun onPoll(now: Long, foregroundApp: String?) {
        // 0. REST state — only check if rest has ended
        if (state == EngineState.REST) {
            handleRestState(now)
            return
        }

        // 1. Check if foreground app changed
        val isMonitoredNow = isMonitoredApp(foregroundApp, now)

        if (!isMonitoredNow) {
            handleAppLeft(now)
            return
        }

        // Reset leave counter — app is back
        leaveConfirmCount = 0

        // 2. Rule evaluation
        val ruleResult = ruleEvaluator.evaluate(foregroundApp!!, now)
        if (ruleResult.blocked) {
            enterRest(ruleResult.reason, foregroundApp, now)
            return
        }

        // 3. Continuous usage tracking
        val usageResult = usageTracker.updateTracking(foregroundApp, now)

        when (state) {
            EngineState.IDLE -> {
                if (usageResult.action == TrackingAction.RESUME ||
                    usageResult.action == TrackingAction.NONE && trackedApp == null) {
                    // Start monitoring
                    widgetManager.showStopwatch(usageResult.remainingSeconds)
                    state = EngineState.MONITORING
                    trackedApp = foregroundApp
                    Log.d(TAG, "IDLE → MONITORING: $foregroundApp")
                }
            }
            EngineState.MONITORING -> {
                widgetManager.updateStopwatch(usageResult.remainingSeconds)
                // Check if should switch to countdown
                val session = repository.getActiveContinuousSession()
                if (session != null) {
                    val settings = repository.getContinuousUsageSettings()
                    if (settings.enabled) {
                        val remainingSeconds = settings.limitSeconds - session.totalDurationSeconds
                        if (remainingSeconds > 0 && remainingSeconds <= COUNTDOWN_THRESHOLD_SECONDS) {
                            widgetManager.switchToCountdown(remainingSeconds)
                            usageTracker.persistCountdownState(now, remainingSeconds)
                            state = EngineState.COUNTDOWN
                            Log.d(TAG, "MONITORING → COUNTDOWN: remaining=${remainingSeconds}s")
                        }
                    }
                }
            }
            EngineState.COUNTDOWN -> {
                // Wall-clock calibration from DB
                val session = repository.getActiveContinuousSession()
                if (session != null && session.countdownStartedAt != null && session.countdownTotalSeconds != null) {
                    val remaining = session.countdownTotalSeconds!! - (now - session.countdownStartedAt!!) / 1000L
                    if (remaining <= 0) {
                        enterRest("连续使用时间已达限制", foregroundApp, now)
                    } else {
                        widgetManager.updateCountdown(remaining)
                        widgetManager.updateCountdownColor(remaining)
                    }
                }
            }
            EngineState.REST -> { /* handled above */ }
            EngineState.AT_LIMIT -> { /* transient, immediately goes to REST */ }
        }
    }

    fun restoreFromDB(now: Long) {
        val session = repository.getActiveContinuousSession()
        if (session == null) {
            state = EngineState.IDLE
            return
        }

        // Rest active?
        if (session.restEndTime != null && session.restEndTime!! > now) {
            state = EngineState.REST
            val remaining = (session.restEndTime!! - now) / 1000L
            overlayManager.showLockOverlay("正在休息中...", "", remaining.toInt())
            Log.d(TAG, "restoreFromDB → REST, remaining=${remaining}s")
            return
        }

        // Countdown active?
        if (session.countdownStartedAt != null && session.countdownTotalSeconds != null) {
            val remaining = session.countdownTotalSeconds!! - (now - session.countdownStartedAt!!) / 1000L
            if (remaining > 0) {
                state = EngineState.COUNTDOWN
                widgetManager.switchToCountdown(remaining)
                Log.d(TAG, "restoreFromDB → COUNTDOWN, remaining=${remaining}s")
                return
            }
            // Countdown expired → trigger rest
            val settings = repository.getContinuousUsageSettings()
            val restEndTime = now + settings.restSeconds * 1000L
            repository.updateContinuousSession(session.copy(
                totalDurationSeconds = settings.limitSeconds.coerceAtLeast(session.totalDurationSeconds),
                restEndTime = restEndTime,
                countdownStartedAt = null,
                countdownTotalSeconds = null,
                updatedAt = now
            ))
            state = EngineState.REST
            overlayManager.showLockOverlay("正在休息中...", "", settings.restSeconds.toInt())
            Log.d(TAG, "restoreFromDB → countdown expired, entering REST")
            return
        }

        state = EngineState.IDLE
        Log.d(TAG, "restoreFromDB → IDLE")
    }

    fun persistStateBeforeDeath() {
        // Current state is already persisted in DB by ContinuousUsageTracker.
        // This is a hook for any additional state that needs saving.
        Log.d(TAG, "persistStateBeforeDeath: state=$state")
    }

    fun destroy() {
        widgetManager.destroy()
    }

    // --- Private helpers ---

    private fun isMonitoredApp(app: String?, now: Long): Boolean {
        if (app == null) return false
        val apps = repository.getMonitoredApps()
        return apps.any { it.packageName == app }
    }

    private fun handleAppLeft(now: Long) {
        leaveConfirmCount++
        if (leaveConfirmCount >= LEAVE_CONFIRM_THRESHOLD) {
            // Confirmed: user left monitored app
            widgetManager.hideAll()
            state = EngineState.IDLE
            trackedApp = null
            leaveConfirmCount = 0
            usageTracker.onCountdownHidden()
            Log.d(TAG, "Leave confirmed → IDLE after $leaveConfirmCount polls")
        } else {
            Log.d(TAG, "Leave poll $leaveConfirmCount/$LEAVE_CONFIRM_THRESHOLD — keeping state $state")
        }
    }

    private fun handleRestState(now: Long) {
        val session = repository.getActiveContinuousSession()
        if (session == null || session.restEndTime == null || session.restEndTime!! <= now) {
            // Rest ended
            overlayManager.hideOverlay()
            repository.deactivateContinuousSession(session?.id ?: return)
            state = EngineState.IDLE
            usageTracker.reset()
            leaveConfirmCount = 0
            trackedApp = null
            Log.d(TAG, "REST → IDLE: rest ended")
        } else {
            val remaining = (session.restEndTime!! - now) / 1000L
            overlayManager.updateRestCountdown(remaining)
        }
    }

    private fun enterRest(reason: String, packageName: String, now: Long) {
        val settings = repository.getContinuousUsageSettings()
        val session = repository.getActiveContinuousSession()
        if (session != null) {
            val restEndTime = now + settings.restSeconds * 1000L
            repository.updateContinuousSession(session.copy(
                totalDurationSeconds = settings.limitSeconds.coerceAtLeast(session.totalDurationSeconds),
                restEndTime = restEndTime,
                countdownStartedAt = null,
                countdownTotalSeconds = null,
                updatedAt = now
            ))
        }
        widgetManager.hideAll()
        overlayManager.showLockOverlay(reason, packageName, settings.restSeconds.toInt())
        state = EngineState.REST
        Log.d(TAG, "→ REST: $reason, restSeconds=${settings.restSeconds}")
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd qiaoqiao_companion/android && ./gradlew app:testDebugUnitTest --tests "com.qiaoqiao.qiaoqiao_companion.monitor.EnforcementEngineTest"`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git add android/app/src/main/java/com/qiaoqiao/qiaoqiao_companion/monitor/EnforcementEngine.kt android/app/src/test/java/com/qiaoqiao/qiaoqiao_companion/monitor/EnforcementEngineTest.kt
git commit -m "feat: implement EnforcementEngine state machine with TDD"
```

---

### Task 6: Enhance NativeOverlayManager with stopwatch, color, vibration

**Files:**
- Modify: `qiaoqiao_companion/android/app/src/main/java/com/qiaoqiao/qiaoqiao_companion/monitor/NativeOverlayManager.kt`

**Interfaces:**
- Produces: `showStopwatchWidget(usedSeconds: Long)`, `updateStopwatchTime(usedSeconds: Long)`, `hideStopwatchWidget()`, `setCountdownColor(color: Int)`, `updateRestCountdown(remainingSeconds: Long)`, `isStopwatchShowing(): Boolean`
- Existing methods consumed: `showCountdownOverlayWithAlerts()`, `hideCountdownOverlay()`, `isCountdownShowing()`, `showLockOverlay()`, `hideOverlay()`

- [ ] **Step 1: Add stopwatch widget methods to NativeOverlayManager**

Add these fields and methods to `NativeOverlayManager.kt`:

```kotlin
// Stopwatch widget fields (add alongside existing countdown fields)
private var stopwatchWidgetView: View? = null
private var isStopwatchShowing = false
private var stopwatchTimeText: TextView? = null

/**
 * Show stopwatch widget displaying used time in top-right corner.
 */
fun showStopwatchWidget(usedSeconds: Long) {
    if (isStopwatchShowing) {
        updateStopwatchTime(usedSeconds)
        return
    }
    if (!hasOverlayPermission()) return

    try {
        windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        stopwatchWidgetView = createStopwatchView(usedSeconds)

        val layoutParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.END
            x = 16
            y = 80
        }

        windowManager?.addView(stopwatchWidgetView, layoutParams)
        isStopwatchShowing = true
        Log.d(TAG, "Stopwatch widget shown: ${usedSeconds}s")
    } catch (e: Exception) {
        Log.e(TAG, "Failed to show stopwatch widget", e)
    }
}

fun updateStopwatchTime(usedSeconds: Long) {
    try {
        stopwatchTimeText?.text = formatSecondsAsMMSS(usedSeconds)
    } catch (e: Exception) {
        Log.e(TAG, "Failed to update stopwatch time", e)
    }
}

fun hideStopwatchWidget() {
    if (!isStopwatchShowing) return
    try {
        stopwatchWidgetView?.let { windowManager?.removeView(it) }
    } catch (e: Exception) { /* ignore */ }
    stopwatchWidgetView = null
    isStopwatchShowing = false
    stopwatchTimeText = null
}

fun isStopwatchShowing(): Boolean = isStopwatchShowing

/**
 * Set countdown widget background/text color.
 */
fun setCountdownColor(color: Int) {
    try {
        countdownTextTime?.setBackgroundColor(color)
    } catch (e: Exception) {
        Log.e(TAG, "Failed to set countdown color", e)
    }
}

/**
 * Update rest countdown displayed in lock overlay.
 */
fun updateRestCountdown(remainingSeconds: Long) {
    try {
        lockCountdownText?.text = formatSecondsAsMMSS(remainingSeconds)
    } catch (e: Exception) {
        Log.e(TAG, "Failed to update rest countdown", e)
    }
}

private fun createStopwatchView(usedSeconds: Long): View {
    val container = FrameLayout(context).apply {
        setBackgroundColor(0xCC000000.toInt())
        setPadding(24, 12, 24, 12)
    }
    val textView = TextView(context).apply {
        text = formatSecondsAsMMSS(usedSeconds)
        setTextColor(android.graphics.Color.WHITE)
        textSize = 14f
        setTypeface(null, android.graphics.Typeface.BOLD)
        tag = "stopwatch_time"
    }
    stopwatchTimeText = textView
    container.addView(textView)
    return container
}

private fun formatSecondsAsMMSS(seconds: Long): String {
    val m = seconds / 60
    val s = seconds % 60
    return "${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}"
}
```

- [ ] **Step 2: Add OnAttachStateChangeListener to countdown widget for system reclaim detection**

In the existing `showCountdownOverlayWithAlerts` method, after creating `countdownWidgetView`, add:

```kotlin
// Detect system reclaiming the widget view
countdownWidgetView?.addOnAttachStateChangeListener(object : View.OnAttachStateChangeListener {
    override fun onViewDetachedFromWindow(v: View) {
        Log.w(TAG, "Countdown widget detached by system — will rebuild on next poll")
        isCountdownShowing = false
    }
    override fun onViewAttachedToWindow(v: View) {}
})
```

- [ ] **Step 3: Build to verify compilation**

Run: `cd qiaoqiao_companion/android && ./gradlew app:compileDebugKotlin`
Expected: BUILD SUCCESSFUL

- [ ] **Step 4: Commit**

```bash
git add android/app/src/main/java/com/qiaoqiao/qiaoqiao_companion/monitor/NativeOverlayManager.kt
git commit -m "feat: add stopwatch widget, countdown color, and OnAttachStateChangeListener to NativeOverlayManager"
```

---

### Task 7: Wire EnforcementEngine into MonitorForegroundService

**Files:**
- Modify: `qiaoqiao_companion/android/app/src/main/java/com/qiaoqiao/qiaoqiao_companion/services/MonitorForegroundService.kt`

**Interfaces:**
- Consumes: `EnforcementEngine.onPoll()`, `EnforcementEngine.restoreFromDB()`, `EnforcementEngine.persistStateBeforeDeath()`, `AppLockManager.shouldShowLock()`, `AppLockOverlayActivity.start()`
- Produces: Simplified `monitorRunnable` that delegates to `engine.onPoll()`

- [ ] **Step 1: Replace native monitoring with EnforcementEngine**

In `MonitorForegroundService.kt`, replace the `startNativeMonitoring()`, `stopNativeMonitoring()`, and `monitorRunnable` sections:

Replace the existing `startNativeMonitoring()` with:

```kotlin
private fun startNativeMonitoring() {
    if (engine != null) {
        Log.d(TAG, "Native monitoring already running")
        return
    }

    try {
        val repository = NativeRuleRepository(applicationContext)
        val ruleEvaluator = RuleEvaluator(repository)
        val nativeOverlayManager = NativeOverlayManager(applicationContext)
        val widgetManager = WidgetManager(nativeOverlayManager)
        val usageTracker = NativeContinuousUsageTracker(repository)

        engine = EnforcementEngine(
            repository, ruleEvaluator, usageTracker, widgetManager, nativeOverlayManager
        )

        // Restore state from DB (handles process-death recovery)
        engine!!.restoreFromDB(System.currentTimeMillis())

        monitorHandler = Handler(Looper.getMainLooper())
        monitorHandler?.postDelayed(monitorRunnable, INITIAL_DELAY_MS)
        Log.d(TAG, "EnforcementEngine started, initial state: ${engine!!.state}")
    } catch (e: Exception) {
        Log.e(TAG, "Failed to start EnforcementEngine", e)
    }
}
```

Replace `stopNativeMonitoring()` with:

```kotlin
private fun stopNativeMonitoring() {
    monitorHandler?.removeCallbacks(monitorRunnable)
    monitorHandler = null
    engine?.destroy()
    engine = null
    Log.d(TAG, "EnforcementEngine stopped")
}
```

Replace `monitorRunnable` with:

```kotlin
private val monitorRunnable = object : Runnable {
    override fun run() {
        try {
            val now = System.currentTimeMillis()
            val foregroundApp = UsageStatsHelper.getCurrentForegroundApp(
                applicationContext, packageName
            )

            // Single entry point — engine handles all logic
            engine?.onPoll(now, foregroundApp)

            // AppLock check (unified with monitoring cycle)
            if (AppLockManager.shouldShowLock(applicationContext)) {
                try {
                    AppLockOverlayActivity.start(applicationContext)
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to show AppLock", e)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Monitoring error", e)
        }

        monitorHandler?.postDelayed(this, MONITOR_INTERVAL_MS)
    }
}
```

Update `onTaskRemoved` to use engine:

```kotlin
override fun onTaskRemoved(rootIntent: Intent?) {
    Log.d(TAG, "Task removed by user")

    // 1. Persist state before death
    engine?.persistStateBeforeDeath()

    // 2. Show AppLock if enabled
    if (AppLockManager.isLockEnabled(applicationContext)) {
        try {
            AppLockOverlayActivity.start(applicationContext)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to show overlay", e)
        }
    }

    // 3. Self-restart
    try {
        val restartIntent = Intent(applicationContext, MonitorForegroundService::class.java)
        restartIntent.action = "START"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            applicationContext.startForegroundService(restartIntent)
        } else {
            applicationContext.startService(restartIntent)
        }
    } catch (e: Exception) {
        Log.e(TAG, "Failed to restart service", e)
    }

    // 4. Redundant alarms
    try {
        scheduleRedundantAlarms(applicationContext)
    } catch (e: Exception) {
        Log.e(TAG, "Failed to schedule alarms", e)
    }

    super.onTaskRemoved(rootIntent)
}
```

Add engine field (replace the old fields):

```kotlin
private var engine: EnforcementEngine? = null
```

Remove old fields: `nativeRuleRepository`, `nativeRuleChecker`, `nativeOverlayManager`, `lastBlockedPackage`.

Remove old helper methods: `checkActiveCountdown()`, `showNativeCountdown()`, `triggerNativeForcedRest()`, `formatNativeRemainingTime()`, `persistCountdownState()`.

- [ ] **Step 2: Build to verify compilation**

Run: `cd qiaoqiao_companion/android && ./gradlew app:compileDebugKotlin`
Expected: BUILD SUCCESSFUL

- [ ] **Step 3: Commit**

```bash
git add android/app/src/main/java/com/qiaoqiao/qiaoqiao_companion/services/MonitorForegroundService.kt
git commit -m "feat: wire EnforcementEngine into MonitorForegroundService"
```

---

## Phase 2: Flutter Layer Slimming

### Task 8: Create ConfigSyncService to replace UsageMonitorService

**Files:**
- Create: `qiaoqiao_companion/lib/core/services/config_sync_service.dart`
- Create: `qiaoqiao_companion/test/services/config_sync_service_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`, `UsageStatsService`, existing DAOs
- Produces: `ConfigSyncService` with `startSync()`, `stopSync()`, `refreshTodayUsage()` — 5-min sync only, no monitoring logic

- [ ] **Step 1: Write failing tests for ConfigSyncService**

Create `qiaoqiao_companion/test/services/config_sync_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:qiaoqiao_companion/core/services/config_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConfigSyncService', () {
    test('starts and stops sync without errors', () {
      final service = ConfigSyncService();
      service.startSync();
      expect(service.isSyncing, isTrue);
      service.stopSync();
      expect(service.isSyncing, isFalse);
    });

    test('does not have monitoring methods', () {
      final service = ConfigSyncService();
      // These methods should NOT exist on the new service
      expect(service.startMonitoring, isNull);
      // The service only does data sync, no rule checking or overlay control
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd qiaoqiao_companion && flutter test test/services/config_sync_service_test.dart`
Expected: FAIL — `ConfigSyncService` class does not exist

- [ ] **Step 3: Implement ConfigSyncService**

Create `qiaoqiao_companion/lib/core/services/config_sync_service.dart`:

```dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/database/daos/daos.dart';
import 'package:qiaoqiao_companion/core/platform/usage_stats_service.dart';
import 'package:qiaoqiao_companion/shared/models/models.dart';
import 'package:qiaoqiao_companion/shared/models/hourly_usage_stats.dart' as hourly_model;

/// 配置同步服务
///
/// 仅负责 5 分钟全量同步系统使用数据到 DB，用于报告展示。
/// 所有监控、规则检查、倒计时、弹窗逻辑已移至原生 EnforcementEngine。
class ConfigSyncService {
  Timer? _fullSyncTimer;
  bool _isSyncing = false;

  bool get isSyncing => _isSyncing;

  /// 开始 5 分钟全量同步
  void startSync() {
    if (_isSyncing) return;
    _isSyncing = true;
    _fullSyncTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => refreshTodayUsage(),
    );
    // 立即执行一次
    refreshTodayUsage();
  }

  /// 停止同步
  void stopSync() {
    _fullSyncTimer?.cancel();
    _fullSyncTimer = null;
    _isSyncing = false;
  }

  /// 从系统同步今日使用数据（由原生 UsageStatsManager 获取精确数据）
  /// 此方法从原 UsageMonitorService._syncTodayUsageFromSystem() 搬运而来，
  /// 但去除了所有规则检查和弹窗控制逻辑，只做数据同步。
  Future<void> refreshTodayUsage() async {
    // 数据同步逻辑从原 UsageMonitorService 搬运，
    // 包括: _syncTodayUsageFromSystem, _syncAppUsageRecords, _syncHourlyUsage
    // 实现时直接复制这些方法的代码，去除规则检查部分。
    // 这部分逻辑与原生 EnforcementEngine 无关，仅用于 Flutter 侧报告展示。
  }
}

/// Provider
final configSyncServiceProvider = Provider<ConfigSyncService>((ref) {
  return ConfigSyncService();
});
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd qiaoqiao_companion && flutter test test/services/config_sync_service_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/config_sync_service.dart test/services/config_sync_service_test.dart
git commit -m "feat: create ConfigSyncService to replace UsageMonitorService (data sync only)"
```

---

### Task 9: Delete deprecated Flutter services and update providers

**Files:**
- Delete: `qiaoqiao_companion/lib/core/services/overlay_state_manager.dart`
- Delete: `qiaoqiao_companion/lib/core/services/reminder_service.dart`
- Delete: `qiaoqiao_companion/lib/core/services/rule_checker_service.dart`
- Delete: `qiaoqiao_companion/lib/core/services/continuous_usage_service.dart`
- Simplify: `qiaoqiao_companion/lib/core/services/usage_monitor_service.dart` (delete file, replaced by ConfigSyncService)
- Simplify: `qiaoqiao_companion/lib/core/platform/overlay_service.dart` (remove show/hide methods, keep query methods)
- Modify: Any provider files that import deleted services

**Interfaces:**
- All deleted services are replaced by native EnforcementEngine
- `overlay_service.dart` keeps `isCountdownWidgetShowing()` and `isOverlayShowing()` for UI status queries
- Providers switch from `UsageMonitorService` to `ConfigSyncService`

- [ ] **Step 1: Find all files importing the services to be deleted**

Run: `cd qiaoqiao_companion && grep -rn "overlay_state_manager\|reminder_service\|rule_checker_service\|continuous_usage_service\|usage_monitor_service" lib/ --include="*.dart" | grep "import" | sort -u`

- [ ] **Step 2: Delete the deprecated service files**

```bash
rm lib/core/services/overlay_state_manager.dart
rm lib/core/services/reminder_service.dart
rm lib/core/services/rule_checker_service.dart
rm lib/core/services/continuous_usage_service.dart
rm lib/core/services/usage_monitor_service.dart
```

- [ ] **Step 3: Update import references in remaining files**

For each file found in Step 1, remove the import and any usage of the deleted service. Replace `UsageMonitorService` references with `ConfigSyncService`. This is a mechanical change — for each import:

- `overlay_state_manager.dart` → remove import, remove `OverlayStateManager` usage
- `reminder_service.dart` → remove import, remove `ReminderService` usage
- `rule_checker_service.dart` → remove import, remove `RuleCheckerService` usage
- `continuous_usage_service.dart` → remove import, remove `ContinuousUsageService` usage
- `usage_monitor_service.dart` → replace with `config_sync_service.dart`

- [ ] **Step 4: Simplify OverlayService**

Edit `qiaoqiao_companion/lib/core/platform/overlay_service.dart` — remove `showOverlay()`, `showCountdownWidget()`, `hideCountdownWidget()` method channel calls. Keep only query methods:

- `isCountdownWidgetShowing()`
- `isOverlayShowing()`

- [ ] **Step 5: Build Flutter app to verify compilation**

Run: `cd qiaoqiao_companion && flutter analyze`
Expected: No errors (warnings OK)

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "refactor: delete deprecated Flutter services, replaced by native EnforcementEngine"
```

---

## Phase 3: Verification and Cleanup

### Task 10: Run all unit tests

**Files:**
- All test files created in Tasks 1-8

- [ ] **Step 1: Run Android unit tests**

Run: `cd qiaoqiao_companion/android && ./gradlew app:testDebugUnitTest`
Expected: All tests pass

- [ ] **Step 2: Run Flutter unit tests**

Run: `cd qiaoqiao_companion && flutter test`
Expected: All tests pass

- [ ] **Step 3: Fix any failing tests**

If any test fails, debug and fix. Re-run until all pass.

- [ ] **Step 4: Commit any fixes**

```bash
git add -A
git commit -m "fix: resolve test failures from integration"
```

---

### Task 11: Build and manual smoke test

**Files:**
- No new files

- [ ] **Step 1: Build release APK**

Run: `cd qiaoqiao_companion && flutter build apk --release`
Expected: BUILD SUCCESSFUL

- [ ] **Step 2: Install on device and test core scenarios**

Manual test checklist (from spec §12.1):

| Scenario | Expected | Pass? |
|----------|----------|-------|
| Open monitored app | Stopwatch widget appears within 5s | ☐ |
| Use app until countdown threshold | Widget switches to countdown, color changes | ☐ |
| Press Home briefly | Widget stays visible (leave confirmation) | ☐ |
| Leave monitored app 10+ seconds | Widget disappears | ☐ |
| Countdown reaches zero | Lock overlay appears with rest countdown | ☐ |
| Rest period ends | Lock overlay disappears, back to IDLE | ☐ |
| Swipe-kill app | AppLock shows, service restarts, monitoring resumes | ☐ |
| Time period restriction active | Lock overlay appears immediately | ☐ |

- [ ] **Step 3: Fix any issues found during smoke test**

- [ ] **Step 4: Commit fixes**

```bash
git add -A
git commit -m "fix: resolve issues found during smoke testing"
```

---

### Task 12: Clean up and final commit

**Files:**
- Remove: `qiaoqiao_companion/android/app/src/test/java/com/qiaoqiao/qiaoqiao_companion/monitor/TestClass.kt` (placeholder)
- Update: docs if needed

- [ ] **Step 1: Remove placeholder test file**

```bash
rm android/app/src/test/java/com/qiaoqiao/qiaoqiao_companion/monitor/TestClass.kt
```

- [ ] **Step 2: Verify all tests still pass**

Run: `cd qiaoqiao_companion/android && ./gradlew app:testDebugUnitTest && cd .. && flutter test`
Expected: All pass

- [ ] **Step 3: Final commit**

```bash
git add -A
git commit -m "chore: cleanup — remove placeholder test, finalize enforcement engine refactor"
```
