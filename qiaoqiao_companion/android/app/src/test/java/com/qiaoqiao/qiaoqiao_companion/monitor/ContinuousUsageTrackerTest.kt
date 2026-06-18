package com.qiaoqiao.qiaoqiao_companion.monitor

import android.util.Log
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import org.mockito.MockedStatic
import org.mockito.Mockito.*
import org.mockito.kotlin.mock
import org.mockito.kotlin.never
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever
import com.qiaoqiao.qiaoqiao_companion.monitor.NativeRuleRepository.ContinuousSession
import com.qiaoqiao.qiaoqiao_companion.monitor.NativeRuleRepository.ContinuousUsageSettings
import com.qiaoqiao.qiaoqiao_companion.monitor.NativeRuleRepository.MonitoredApp

/**
 * TDD tests for NativeContinuousUsageTracker — focus on persistCountdownState
 * and related state management.
 *
 * NativeRuleRepository is mocked; android.util.Log is mocked statically.
 */
class ContinuousUsageTrackerTest {

    private lateinit var repository: NativeRuleRepository
    private lateinit var tracker: NativeContinuousUsageTracker
    private lateinit var mockedLog: MockedStatic<Log>

    @BeforeEach
    fun setUp() {
        repository = mock(NativeRuleRepository::class.java)
        tracker = NativeContinuousUsageTracker(repository)
        // Silence android.util.Log in unit tests
        mockedLog = mockStatic(Log::class.java)
        mockedLog.`when`<Int> { Log.d(anyString(), anyString()) }.thenReturn(0)
        mockedLog.`when`<Int> { Log.w(anyString(), anyString()) }.thenReturn(0)
        mockedLog.`when`<Int> { Log.e(anyString(), anyString()) }.thenReturn(0)
    }

    @AfterEach
    fun tearDown() {
        mockedLog.close()
    }

    // ── Helpers ───────────────────────────────────────────────────

    private fun activeSession(
        id: Long = 1L,
        totalDurationSeconds: Long = 1200L,
        countdownStartedAt: Long? = null,
        countdownTotalSeconds: Long? = null
    ): ContinuousSession = ContinuousSession(
        id = id,
        sessionDate = "2026-06-19",
        startTime = 1000_000L,
        totalDurationSeconds = totalDurationSeconds,
        lastActivityTime = 1000_000L + totalDurationSeconds * 1000,
        restEndTime = null,
        alertsShown = emptySet(),
        isActive = true,
        countdownStartedAt = countdownStartedAt,
        countdownTotalSeconds = countdownTotalSeconds,
        createdAt = 1000_000L,
        updatedAt = 1000_000L
    )

    /**
     * Drive the tracker through two updateTracking calls so that it accumulates
     * time and can reach the countdown threshold.
     * - Call 1: establishes currentTrackedApp (returns noop/resume)
     * - Call 2: accumulates elapsed time and checks countdown
     */
    private fun setupTrackingWithCountdown(
        limitMinutes: Int = 20,
        sessionDurationSeconds: Long = 900L,
        pollIntervalSeconds: Long = 5L
    ): NativeContinuousUsageTracker.TrackingResult {
        val settings = ContinuousUsageSettings(enabled = true, limitMinutes = limitMinutes)
        whenever(repository.getContinuousUsageSettings()).thenReturn(settings)
        whenever(repository.getMonitoredApps()).thenReturn(
            listOf(MonitoredApp("com.game.app", null))
        )
        whenever(repository.isMonitored("com.game.app")).thenReturn(true)
        val session = activeSession(totalDurationSeconds = sessionDurationSeconds)
        whenever(repository.getActiveContinuousSession()).thenReturn(session)
        whenever(repository.updateContinuousSession(org.mockito.kotlin.any())).thenReturn(true)

        // First call: establishes tracking (currentTrackedApp was null)
        val t0 = 2_000_000L
        tracker.updateTracking("com.game.app", t0)

        // Second call: accumulates elapsed time and evaluates countdown
        val t1 = t0 + pollIntervalSeconds * 1000L
        return tracker.updateTracking("com.game.app", t1)
    }

    // ══════════════════════════════════════════════════════════════
    //  1. persistCountdownState writes countdownStartedAt and
    //     countdownTotalSeconds to session
    // ══════════════════════════════════════════════════════════════
    @Test
    @DisplayName("persistCountdownState writes countdownStartedAt and countdownTotalSeconds to session")
    fun persistCountdownState_writesCountdownFields() {
        val session = activeSession(id = 42L)
        whenever(repository.getActiveContinuousSession()).thenReturn(session)

        val now = 5_000_000L
        val remainingSeconds = 300L

        tracker.persistCountdownState(now, remainingSeconds)

        // Verify updateContinuousSession was called with the correct fields
        val expected = session.copy(
            countdownStartedAt = now,
            countdownTotalSeconds = remainingSeconds,
            updatedAt = now
        )
        verify(repository).updateContinuousSession(expected)
    }

    // ══════════════════════════════════════════════════════════════
    //  2. persistCountdownState does nothing when no active session
    // ══════════════════════════════════════════════════════════════
    @Test
    @DisplayName("persistCountdownState does nothing when no active session")
    fun persistCountdownState_noActiveSession_doesNothing() {
        whenever(repository.getActiveContinuousSession()).thenReturn(null)

        tracker.persistCountdownState(5_000_000L, 300L)

        verify(repository, never()).updateContinuousSession(org.mockito.kotlin.any())
    }

    // ══════════════════════════════════════════════════════════════
    //  3. persistCountdownState updates the activeSession field
    // ══════════════════════════════════════════════════════════════
    @Test
    @DisplayName("persistCountdownState updates the activeSession field")
    fun persistCountdownState_updatesActiveSessionField() {
        val session = activeSession(id = 10L)
        whenever(repository.getActiveContinuousSession()).thenReturn(session)

        val now = 9_000_000L
        val remainingSeconds = 180L

        tracker.persistCountdownState(now, remainingSeconds)

        // After persisting, getActiveSession should reflect the updated values
        val updatedSession = tracker.getActiveSession()
        assertNotNull(updatedSession)
        assertEquals(now, updatedSession!!.countdownStartedAt)
        assertEquals(remainingSeconds, updatedSession.countdownTotalSeconds)
        assertEquals(now, updatedSession.updatedAt)
    }

    // ══════════════════════════════════════════════════════════════
    //  4. onCountdownHidden resets countdownShown flag
    // ══════════════════════════════════════════════════════════════
    @Test
    @DisplayName("onCountdownHidden resets countdownShown flag — next updateTracking can show countdown again")
    fun onCountdownHidden_resetsCountdownShownFlag() {
        // Drive tracker to a state where countdown is shown
        // 20min limit, 900s used => 300s remaining (5min) => triggers SHOW_COUNTDOWN
        val result1 = setupTrackingWithCountdown(
            limitMinutes = 20,
            sessionDurationSeconds = 900L
        )
        // After two updateTracking calls, countdown should be shown or updating
        assertTrue(
            result1.shouldShowCountdown || result1.shouldUpdateCountdown,
            "After tracking, countdown should be shown or updating (got ${result1.action})"
        )

        // If countdown was shown, a subsequent call should NOT show a NEW countdown
        // (it should be UPDATE_COUNTDOWN since countdownShown=true)
        if (result1.shouldShowCountdown) {
            val settings = ContinuousUsageSettings(enabled = true, limitMinutes = 20)
            whenever(repository.getContinuousUsageSettings()).thenReturn(settings)
            whenever(repository.getMonitoredApps()).thenReturn(
                listOf(MonitoredApp("com.game.app", null))
            )
            whenever(repository.isMonitored("com.game.app")).thenReturn(true)
            val session2 = activeSession(totalDurationSeconds = 910L)
            whenever(repository.getActiveContinuousSession()).thenReturn(session2)
            whenever(repository.updateContinuousSession(org.mockito.kotlin.any())).thenReturn(true)

            val result2 = tracker.updateTracking("com.game.app", 2_011_000L)
            assertFalse(result2.shouldShowCountdown,
                "Should not show NEW countdown when countdownShown=true (got ${result2.action})")
        }

        // Now hide the countdown
        tracker.onCountdownHidden()

        // Next call should be able to show countdown again
        val settings3 = ContinuousUsageSettings(enabled = true, limitMinutes = 20)
        whenever(repository.getContinuousUsageSettings()).thenReturn(settings3)
        whenever(repository.getMonitoredApps()).thenReturn(
            listOf(MonitoredApp("com.game.app", null))
        )
        whenever(repository.isMonitored("com.game.app")).thenReturn(true)
        val session3 = activeSession(totalDurationSeconds = 920L)
        whenever(repository.getActiveContinuousSession()).thenReturn(session3)
        whenever(repository.updateContinuousSession(org.mockito.kotlin.any())).thenReturn(true)

        val result3 = tracker.updateTracking("com.game.app", 2_012_000L)
        assertTrue(result3.shouldShowCountdown,
            "After onCountdownHidden, countdown can be shown again (got ${result3.action})")
    }

    // ══════════════════════════════════════════════════════════════
    //  5. reset clears all tracking state
    // ══════════════════════════════════════════════════════════════
    @Test
    @DisplayName("reset clears all tracking state")
    fun reset_clearsAllTrackingState() {
        // Establish some state by simulating tracking
        val settings = ContinuousUsageSettings(enabled = true, limitMinutes = 30)
        whenever(repository.getContinuousUsageSettings()).thenReturn(settings)
        whenever(repository.getMonitoredApps()).thenReturn(
            listOf(MonitoredApp("com.game.app", null))
        )
        whenever(repository.isMonitored("com.game.app")).thenReturn(true)
        val session = activeSession(totalDurationSeconds = 500L)
        whenever(repository.getActiveContinuousSession()).thenReturn(session)
        whenever(repository.updateContinuousSession(org.mockito.kotlin.any())).thenReturn(true)
        whenever(repository.insertContinuousSession(org.mockito.kotlin.any())).thenReturn(1L)

        // Simulate some tracking
        tracker.updateTracking("com.game.app", 2_000_000L)

        // Before reset, state should be non-trivial
        assertNotNull(tracker.getActiveSession())
        assertNotNull(tracker.getCurrentTrackedApp())
        assertTrue(tracker.getRemainingSeconds() >= 0)

        // Reset
        tracker.reset()

        // After reset, everything should be cleared
        assertNull(tracker.getActiveSession(), "activeSession should be null after reset")
        assertNull(tracker.getCurrentTrackedApp(), "currentTrackedApp should be null after reset")
        assertEquals(0L, tracker.getRemainingSeconds(), "remainingSeconds should be 0 after reset")
    }
}
