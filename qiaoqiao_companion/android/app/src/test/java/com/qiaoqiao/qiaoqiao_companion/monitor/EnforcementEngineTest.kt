package com.qiaoqiao.qiaoqiao_companion.monitor

import android.util.Log
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Nested
import org.junit.jupiter.api.Test
import org.mockito.MockedStatic
import org.mockito.Mockito.*
import org.mockito.kotlin.any
import org.mockito.kotlin.eq
import org.mockito.kotlin.isNull
import org.mockito.kotlin.mock
import org.mockito.kotlin.never
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever
import com.qiaoqiao.qiaoqiao_companion.monitor.NativeRuleRepository.ContinuousSession
import com.qiaoqiao.qiaoqiao_companion.monitor.NativeRuleRepository.ContinuousUsageSettings
import com.qiaoqiao.qiaoqiao_companion.monitor.NativeRuleRepository.MonitoredApp
import com.qiaoqiao.qiaoqiao_companion.monitor.RuleEvaluator.EvalResult

/**
 * TDD tests for EnforcementEngine — the central state machine that coordinates
 * RuleEvaluator, NativeContinuousUsageTracker, WidgetManager, and NativeOverlayManager.
 *
 * All dependencies are mocked; android.util.Log is mocked statically.
 */
class EnforcementEngineTest {

    private lateinit var repository: NativeRuleRepository
    private lateinit var ruleEvaluator: RuleEvaluator
    private lateinit var usageTracker: NativeContinuousUsageTracker
    private lateinit var widgetManager: WidgetManager
    private lateinit var overlayManager: NativeOverlayManager
    private lateinit var engine: EnforcementEngine
    private lateinit var mockedLog: MockedStatic<Log>

    @BeforeEach
    fun setUp() {
        repository = mock(NativeRuleRepository::class.java)
        ruleEvaluator = mock(RuleEvaluator::class.java)
        usageTracker = mock(NativeContinuousUsageTracker::class.java)
        widgetManager = mock(WidgetManager::class.java)
        overlayManager = mock(NativeOverlayManager::class.java)
        engine = EnforcementEngine(repository, ruleEvaluator, usageTracker, widgetManager, overlayManager)

        // Silence android.util.Log in unit tests
        mockedLog = mockStatic(Log::class.java)
        mockedLog.`when`<Int> { Log.d(anyString(), anyString()) }.thenReturn(0)
        mockedLog.`when`<Int> { Log.w(anyString(), anyString()) }.thenReturn(0)
        mockedLog.`when`<Int> { Log.e(anyString(), anyString()) }.thenReturn(0)

        // Default stubs
        whenever(repository.getMonitoredApps()).thenReturn(
            listOf(MonitoredApp("com.game.app", null))
        )
        whenever(usageTracker.updateTracking(any(), any())).thenReturn(
            NativeContinuousUsageTracker.TrackingResult.noop()
        )
        // Default: rule evaluator does NOT block
        whenever(ruleEvaluator.evaluate(any(), any())).thenReturn(
            EvalResult(blocked = false)
        )
    }

    @AfterEach
    fun tearDown() {
        mockedLog.close()
    }

    // ── Helpers ───────────────────────────────────────────────────

    private fun activeSession(
        id: Long = 1L,
        totalDurationSeconds: Long = 600L,
        restEndTime: Long? = null,
        countdownStartedAt: Long? = null,
        countdownTotalSeconds: Long? = null,
        isActive: Boolean = true
    ): ContinuousSession = ContinuousSession(
        id = id,
        sessionDate = "2026-06-19",
        startTime = 1_000_000L,
        totalDurationSeconds = totalDurationSeconds,
        lastActivityTime = 1_000_000L + totalDurationSeconds * 1000,
        restEndTime = restEndTime,
        alertsShown = emptySet(),
        isActive = isActive,
        countdownStartedAt = countdownStartedAt,
        countdownTotalSeconds = countdownTotalSeconds,
        createdAt = 1_000_000L,
        updatedAt = 1_000_000L
    )

    private fun trackingResultShowCountdown(remaining: Long = 300L) =
        NativeContinuousUsageTracker.TrackingResult.showCountdown(remaining)

    private fun trackingResultUpdateCountdown(remaining: Long = 250L) =
        NativeContinuousUsageTracker.TrackingResult.updateCountdown(remaining)

    private fun trackingResultRestTriggered() =
        NativeContinuousUsageTracker.TrackingResult.restTriggered(0)

    private fun trackingResultNoop() =
        NativeContinuousUsageTracker.TrackingResult.noop()

    // ══════════════════════════════════════════════════════════════
    //  1. Initial state is IDLE
    // ══════════════════════════════════════════════════════════════
    @Test
    @DisplayName("Initial state is IDLE")
    fun initialState_isIdle() {
        assertEquals(EngineState.IDLE, engine.state)
    }

    // ══════════════════════════════════════════════════════════════
    //  2. IDLE + monitored app + no violation -> MONITORING
    // ══════════════════════════════════════════════════════════════
    @Test
    @DisplayName("IDLE + monitored app + no violation -> MONITORING (showStopwatch called)")
    fun idle_monitoredApp_noViolation_transitionsToMonitoring() {
        val now = 10_000_000L

        engine.onPoll(now, "com.game.app")

        assertEquals(EngineState.MONITORING, engine.state)
        verify(widgetManager).showStopwatch(any())
    }

    // ══════════════════════════════════════════════════════════════
    //  3. IDLE + null foreground app -> stays IDLE
    // ══════════════════════════════════════════════════════════════
    @Test
    @DisplayName("IDLE + null foreground app -> stays IDLE")
    fun idle_nullForeground_staysIdle() {
        val now = 10_000_000L

        engine.onPoll(now, null)

        assertEquals(EngineState.IDLE, engine.state)
        verify(widgetManager, never()).showStopwatch(any())
    }

    // ══════════════════════════════════════════════════════════════
    //  4. IDLE + non-monitored app -> stays IDLE
    // ══════════════════════════════════════════════════════════════
    @Test
    @DisplayName("IDLE + non-monitored app -> stays IDLE")
    fun idle_nonMonitoredApp_staysIdle() {
        val now = 10_000_000L

        engine.onPoll(now, "com.safe.app")

        assertEquals(EngineState.IDLE, engine.state)
        verify(widgetManager, never()).showStopwatch(any())
    }

    // ══════════════════════════════════════════════════════════════
    //  5. MONITORING + rule blocked -> REST (showLockOverlay called)
    // ══════════════════════════════════════════════════════════════
    @Test
    @DisplayName("MONITORING + rule blocked -> REST (showLockOverlay called)")
    fun monitoring_ruleBlocked_transitionsToRest() {
        val now = 10_000_000L

        // First poll: IDLE -> MONITORING
        engine.onPoll(now, "com.game.app")
        assertEquals(EngineState.MONITORING, engine.state)

        // Second poll: MONITORING -> REST (rule evaluator says blocked)
        val now2 = now + 5_000L
        whenever(ruleEvaluator.evaluate("com.game.app", now2)).thenReturn(
            EvalResult(blocked = true, reason = "Time limit exceeded", ruleType = "total_time_limit")
        )
        engine.onPoll(now2, "com.game.app")

        assertEquals(EngineState.REST, engine.state)
        verify(overlayManager).showLockOverlay(any(), any(), any())
    }

    // ══════════════════════════════════════════════════════════════
    //  6. MONITORING + countdown threshold -> COUNTDOWN
    // ══════════════════════════════════════════════════════════════
    @Test
    @DisplayName("MONITORING + countdown threshold -> COUNTDOWN (switchToCountdown + persistCountdownState)")
    fun monitoring_countdownThreshold_transitionsToCountdown() {
        val now = 10_000_000L

        // First poll: IDLE -> MONITORING
        engine.onPoll(now, "com.game.app")
        assertEquals(EngineState.MONITORING, engine.state)

        // Second poll: MONITORING -> COUNTDOWN
        // Tracker signals showCountdown
        val now2 = now + 5_000L
        whenever(usageTracker.updateTracking("com.game.app", now2)).thenReturn(
            trackingResultShowCountdown(remaining = 300L)
        )

        engine.onPoll(now2, "com.game.app")

        assertEquals(EngineState.COUNTDOWN, engine.state)
        verify(widgetManager).switchToCountdown(300L)
        verify(usageTracker).persistCountdownState(now2, 300L)
    }

    // ══════════════════════════════════════════════════════════════
    //  7. COUNTDOWN + countdown expired -> REST
    // ══════════════════════════════════════════════════════════════
    @Test
    @DisplayName("COUNTDOWN + countdown expired -> REST (wall-clock from DB countdownStartedAt/countdownTotalSeconds)")
    fun countdown_expired_transitionsToRest() {
        // Simulate a session where countdown was started 301 seconds ago
        // countdownStartedAt = now - 301_000, countdownTotalSeconds = 300
        // Therefore remaining = 300 - (now - countdownStartedAt) / 1000 = 300 - 301 = -1 <= 0
        val countdownStartedAt = 10_000_000L
        val countdownTotalSeconds = 300L
        val now = countdownStartedAt + 301_000L // 301 seconds later

        // First poll: IDLE -> MONITORING
        engine.onPoll(countdownStartedAt, "com.game.app")

        // Second poll: MONITORING -> COUNTDOWN
        whenever(usageTracker.updateTracking("com.game.app", countdownStartedAt + 5_000L)).thenReturn(
            trackingResultShowCountdown(remaining = 300L)
        )
        engine.onPoll(countdownStartedAt + 5_000L, "com.game.app")
        assertEquals(EngineState.COUNTDOWN, engine.state)

        // Third poll: COUNTDOWN -> REST (countdown expired via wall-clock)
        // The session in DB has countdownStartedAt/countdownTotalSeconds
        whenever(repository.getActiveContinuousSession()).thenReturn(
            activeSession(
                countdownStartedAt = countdownStartedAt,
                countdownTotalSeconds = countdownTotalSeconds
            )
        )

        engine.onPoll(now, "com.game.app")

        assertEquals(EngineState.REST, engine.state)
        verify(overlayManager).showLockOverlay(any(), any(), any())
    }

    // ══════════════════════════════════════════════════════════════
    //  8. COUNTDOWN + countdown still running -> stays COUNTDOWN
    // ══════════════════════════════════════════════════════════════
    @Test
    @DisplayName("COUNTDOWN + countdown still running -> stays COUNTDOWN (updateCountdown + updateCountdownColor)")
    fun countdown_stillRunning_staysCountdown() {
        val now = 10_000_000L

        // Get into MONITORING first
        engine.onPoll(now, "com.game.app")

        // Transition to COUNTDOWN
        val now2 = now + 5_000L
        whenever(usageTracker.updateTracking("com.game.app", now2)).thenReturn(
            trackingResultShowCountdown(remaining = 300L)
        )
        engine.onPoll(now2, "com.game.app")
        assertEquals(EngineState.COUNTDOWN, engine.state)

        // Poll again — countdown still running (200s remaining by wall-clock)
        // countdownStartedAt = now2, countdownTotalSeconds = 300
        // at now3 = now2 + 100_000L, elapsed = 100s, remaining = 300 - 100 = 200
        val now3 = now2 + 100_000L // 100 seconds later
        whenever(repository.getActiveContinuousSession()).thenReturn(
            activeSession(countdownStartedAt = now2, countdownTotalSeconds = 300L)
        )

        engine.onPoll(now3, "com.game.app")

        assertEquals(EngineState.COUNTDOWN, engine.state)
        verify(widgetManager).updateCountdown(200L)
        verify(widgetManager).updateCountdownColor(200L)
    }

    // ══════════════════════════════════════════════════════════════
    //  9. REST + rest ended -> IDLE
    // ══════════════════════════════════════════════════════════════
    @Test
    @DisplayName("REST + rest ended -> IDLE (hideOverlay + deactivateContinuousSession)")
    fun rest_ended_transitionsToIdle() {
        val restEndTime = 10_000_000L
        val now = restEndTime + 1_000L // 1 second after rest ends

        // Put engine into REST state directly (IDLE + blocked)
        whenever(ruleEvaluator.evaluate("com.game.app", 9_000_000L)).thenReturn(
            EvalResult(blocked = true, reason = "Time limit", ruleType = "total_time_limit")
        )
        engine.onPoll(9_000_000L, "com.game.app")
        assertEquals(EngineState.REST, engine.state)

        // Set up session with restEndTime that has passed
        whenever(repository.getActiveContinuousSession()).thenReturn(
            activeSession(id = 42L, restEndTime = restEndTime)
        )

        // Poll after rest ends — should transition to IDLE
        engine.onPoll(now, "com.game.app")

        assertEquals(EngineState.IDLE, engine.state)
        verify(overlayManager).hideOverlay()
        verify(repository).deactivateContinuousSession(42L)
    }

    // ══════════════════════════════════════════════════════════════
    //  10. REST + rest still active -> stays REST
    // ══════════════════════════════════════════════════════════════
    @Test
    @DisplayName("REST + rest still active -> stays REST")
    fun rest_stillActive_staysRest() {
        val now = 10_000_000L
        val restEndTime = now + 600_000L // Rest ends 10 minutes from now

        // Put engine into REST state directly (IDLE + blocked)
        whenever(ruleEvaluator.evaluate("com.game.app", 9_000_000L)).thenReturn(
            EvalResult(blocked = true, reason = "Time limit", ruleType = "total_time_limit")
        )
        engine.onPoll(9_000_000L, "com.game.app")
        assertEquals(EngineState.REST, engine.state)

        // Set up session with active rest
        whenever(repository.getActiveContinuousSession()).thenReturn(
            activeSession(id = 42L, restEndTime = restEndTime)
        )

        // Poll while rest is still active
        engine.onPoll(now, "com.game.app")

        assertEquals(EngineState.REST, engine.state)
    }

    // ══════════════════════════════════════════════════════════════
    //  11. Leave confirmation - first non-monitored poll keeps state
    // ══════════════════════════════════════════════════════════════
    @Test
    @DisplayName("Leave confirmation - first non-monitored poll keeps MONITORING state")
    fun leaveConfirmation_firstNonMonitoredPoll_keepsMonitoring() {
        val now = 10_000_000L

        // Get into MONITORING
        engine.onPoll(now, "com.game.app")
        assertEquals(EngineState.MONITORING, engine.state)

        // First non-monitored poll — should stay MONITORING (leave confirm count = 1)
        val now2 = now + 5_000L
        engine.onPoll(now2, "com.safe.app")

        assertEquals(EngineState.MONITORING, engine.state)
    }

    // ══════════════════════════════════════════════════════════════
    //  12. Leave confirmation - second non-monitored poll -> IDLE
    // ══════════════════════════════════════════════════════════════
    @Test
    @DisplayName("Leave confirmation - second non-monitored poll -> IDLE (widgetManager.hideAll)")
    fun leaveConfirmation_secondNonMonitoredPoll_transitionsToIdle() {
        val now = 10_000_000L

        // Get into MONITORING
        engine.onPoll(now, "com.game.app")
        assertEquals(EngineState.MONITORING, engine.state)

        // First non-monitored poll
        val now2 = now + 5_000L
        engine.onPoll(now2, "com.safe.app")
        assertEquals(EngineState.MONITORING, engine.state)

        // Second non-monitored poll — should transition to IDLE
        val now3 = now2 + 5_000L
        engine.onPoll(now3, "com.safe.app")

        assertEquals(EngineState.IDLE, engine.state)
        verify(widgetManager).hideAll()
    }

    // ══════════════════════════════════════════════════════════════
    //  13. restoreFromDB with active rest -> REST state
    // ══════════════════════════════════════════════════════════════
    @Test
    @DisplayName("restoreFromDB with active rest -> REST state")
    fun restoreFromDB_activeRest_transitionsToRest() {
        val now = 10_000_000L
        val restEndTime = now + 600_000L // 10 min from now

        whenever(repository.getActiveContinuousSession()).thenReturn(
            activeSession(id = 5L, restEndTime = restEndTime)
        )

        engine.restoreFromDB(now)

        assertEquals(EngineState.REST, engine.state)
        verify(overlayManager).showLockOverlay(any(), any(), any())
    }

    // ══════════════════════════════════════════════════════════════
    //  14. restoreFromDB with active countdown -> COUNTDOWN state
    // ══════════════════════════════════════════════════════════════
    @Test
    @DisplayName("restoreFromDB with active countdown -> COUNTDOWN state")
    fun restoreFromDB_activeCountdown_transitionsToCountdown() {
        val now = 10_000_000L
        val countdownStartedAt = now - 100_000L // started 100s ago
        val countdownTotalSeconds = 300L // 5 min total

        whenever(repository.getActiveContinuousSession()).thenReturn(
            activeSession(
                countdownStartedAt = countdownStartedAt,
                countdownTotalSeconds = countdownTotalSeconds
            )
        )

        engine.restoreFromDB(now)

        assertEquals(EngineState.COUNTDOWN, engine.state)
        // Should show the countdown with remaining seconds calculated from wall clock
        // remaining = countdownTotalSeconds - (now - countdownStartedAt) / 1000 = 300 - 100 = 200
        verify(widgetManager).switchToCountdown(200L)
    }

    // ══════════════════════════════════════════════════════════════
    //  15. restoreFromDB with expired countdown -> REST state
    // ══════════════════════════════════════════════════════════════
    @Test
    @DisplayName("restoreFromDB with expired countdown -> REST state")
    fun restoreFromDB_expiredCountdown_transitionsToRest() {
        val now = 10_000_000L
        val countdownStartedAt = now - 301_000L // started 301s ago
        val countdownTotalSeconds = 300L // 5 min total, so expired

        whenever(repository.getActiveContinuousSession()).thenReturn(
            activeSession(
                countdownStartedAt = countdownStartedAt,
                countdownTotalSeconds = countdownTotalSeconds
            )
        )

        engine.restoreFromDB(now)

        assertEquals(EngineState.REST, engine.state)
        verify(overlayManager).showLockOverlay(any(), any(), any())
    }

    // ══════════════════════════════════════════════════════════════
    //  16. restoreFromDB with no session -> IDLE state
    // ══════════════════════════════════════════════════════════════
    @Test
    @DisplayName("restoreFromDB with no session -> IDLE state")
    fun restoreFromDB_noSession_staysIdle() {
        val now = 10_000_000L

        whenever(repository.getActiveContinuousSession()).thenReturn(null)

        engine.restoreFromDB(now)

        assertEquals(EngineState.IDLE, engine.state)
    }

    // ══════════════════════════════════════════════════════════════
    //  Additional edge-case tests
    // ══════════════════════════════════════════════════════════════

    @Nested
    @DisplayName("Leave confirmation resets on monitored app return")
    inner class LeaveConfirmationReset {

        @Test
        @DisplayName("Leave confirm count resets when monitored app returns")
        fun leaveConfirmCount_resetsOnMonitoredAppReturn() {
            val now = 10_000_000L

            // Get into MONITORING
            engine.onPoll(now, "com.game.app")
            assertEquals(EngineState.MONITORING, engine.state)

            // First non-monitored poll
            engine.onPoll(now + 5_000L, "com.safe.app")
            assertEquals(EngineState.MONITORING, engine.state)

            // Return to monitored app — resets leave confirm count
            engine.onPoll(now + 10_000L, "com.game.app")
            assertEquals(EngineState.MONITORING, engine.state)

            // One non-monitored poll should NOT transition to IDLE (count was reset)
            engine.onPoll(now + 15_000L, "com.safe.app")
            assertEquals(EngineState.MONITORING, engine.state)

            // Second consecutive non-monitored poll should transition to IDLE
            engine.onPoll(now + 20_000L, "com.safe.app")
            assertEquals(EngineState.IDLE, engine.state)
        }
    }

    @Nested
    @DisplayName("MONITORING continuous update of stopwatch")
    inner class MonitoringStopwatch {

        @Test
        @DisplayName("Subsequent polls in MONITORING state update stopwatch")
        fun monitoring_subsequentPolls_updateStopwatch() {
            val now = 10_000_000L

            // First poll: IDLE -> MONITORING (showStopwatch)
            engine.onPoll(now, "com.game.app")

            // Second poll: still MONITORING (updateStopwatch)
            val now2 = now + 30_000L
            engine.onPoll(now2, "com.game.app")

            assertEquals(EngineState.MONITORING, engine.state)
            verify(widgetManager).updateStopwatch(any())
        }
    }

    @Nested
    @DisplayName("REST state ignores non-rest checks")
    inner class RestStateBehavior {

        @Test
        @DisplayName("REST state only checks if rest ended, not rule evaluation")
        fun restState_onlyChecksRestEnd() {
            // Put engine into REST state directly (IDLE + blocked)
            whenever(ruleEvaluator.evaluate("com.game.app", 9_000_000L)).thenReturn(
                EvalResult(blocked = true, reason = "Time limit", ruleType = "total_time_limit")
            )
            engine.onPoll(9_000_000L, "com.game.app")
            assertEquals(EngineState.REST, engine.state)

            // Poll during rest with active rest session
            val now = 9_500_000L
            val restEndTime = now + 300_000L
            whenever(repository.getActiveContinuousSession()).thenReturn(
                activeSession(id = 1L, restEndTime = restEndTime)
            )

            engine.onPoll(now, "com.game.app")

            // Rule evaluator should NOT be called with the REST-poll timestamp
            // (it was called once for the initial IDLE->REST transition)
            verify(ruleEvaluator, never()).evaluate(any(), eq(now))
            assertEquals(EngineState.REST, engine.state)
        }
    }

    @Nested
    @DisplayName("COUNTDOWN with null foreground app")
    inner class CountdownWithNullApp {

        @Test
        @DisplayName("COUNTDOWN + null foreground app increments leave confirm count")
        fun countdown_nullForeground_incrementsLeaveConfirm() {
            val now = 10_000_000L

            // Get into MONITORING
            engine.onPoll(now, "com.game.app")

            // Transition to COUNTDOWN
            val now2 = now + 5_000L
            whenever(usageTracker.updateTracking("com.game.app", now2)).thenReturn(
                trackingResultShowCountdown(remaining = 300L)
            )
            engine.onPoll(now2, "com.game.app")
            assertEquals(EngineState.COUNTDOWN, engine.state)

            // Null foreground app — first poll (leave confirm = 1)
            val now3 = now2 + 5_000L
            engine.onPoll(now3, null)

            // Should still be COUNTDOWN after first leave confirmation poll
            assertEquals(EngineState.COUNTDOWN, engine.state)
        }
    }

    @Nested
    @DisplayName("destroy cleanup")
    inner class DestroyCleanup {

        @Test
        @DisplayName("destroy calls widgetManager.destroy and resets state to IDLE")
        fun destroy_resetsStateAndCallsDestroy() {
            val now = 10_000_000L

            // Get into MONITORING
            engine.onPoll(now, "com.game.app")
            assertEquals(EngineState.MONITORING, engine.state)

            engine.destroy()

            assertEquals(EngineState.IDLE, engine.state)
            verify(widgetManager).destroy()
            verify(usageTracker).reset()
        }
    }

    @Nested
    @DisplayName("persistStateBeforeDeath")
    inner class PersistStateBeforeDeath {

        @Test
        @DisplayName("persistStateBeforeDeath does not crash and is a no-op hook")
        fun persistStateBeforeDeath_noOpHook() {
            // Most state is already persisted to DB by the tracker/evaluator
            // This is just a hook for future use
            engine.persistStateBeforeDeath()
            // No exception thrown = pass
        }
    }
}
