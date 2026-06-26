package com.qiaoqiao.qiaoqiao_companion.monitor

import android.util.Log
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
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
 * TDD tests for NativeContinuousUsageTracker — focus on session persistence
 * and keeping UI decisions out of the tracker.
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

    private fun configureDefaultTracking(
        limitMinutes: Int = 20,
        sessionDurationSeconds: Long = 900L
    ) {
        val settings = ContinuousUsageSettings(enabled = true, limitMinutes = limitMinutes)
        whenever(repository.getContinuousUsageSettings()).thenReturn(settings)
        whenever(repository.getMonitoredApps()).thenReturn(
            listOf(MonitoredApp("com.game.app", null))
        )
        whenever(repository.isMonitored("com.game.app")).thenReturn(true)
        val session = activeSession(totalDurationSeconds = sessionDurationSeconds)
        whenever(repository.getActiveContinuousSession()).thenReturn(session)
        whenever(repository.updateContinuousSession(org.mockito.kotlin.any())).thenReturn(true)
    }

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

    @Test
    @DisplayName("persistCountdownState does nothing when no active session")
    fun persistCountdownState_noActiveSession_doesNothing() {
        whenever(repository.getActiveContinuousSession()).thenReturn(null)

        tracker.persistCountdownState(5_000_000L, 300L)

        verify(repository, never()).updateContinuousSession(org.mockito.kotlin.any())
    }

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

    @Test
    @DisplayName("updateTracking 只返回会话活跃事实，不负责触发 REST")
    fun updateTracking_returnsActiveFactOnly() {
        configureDefaultTracking(limitMinutes = 20, sessionDurationSeconds = 900L)

        tracker.updateTracking("com.game.app", 2_000_000L)
        val result = tracker.updateTracking("com.game.app", 2_005_000L)

        assertEquals(NativeContinuousUsageTracker.TrackingAction.ACTIVE, result.action)
        assertEquals(295L, result.remainingSeconds)
    }

    @Test
    @DisplayName("reset clears all tracking state")
    fun reset_clearsAllTrackingState() {
        configureDefaultTracking(limitMinutes = 30, sessionDurationSeconds = 500L)

        tracker.updateTracking("com.game.app", 2_000_000L)
        assertNotNull(tracker.getActiveSession())
        assertNotNull(tracker.getCurrentTrackedApp())
        assertTrue(tracker.getRemainingSeconds() >= 0)

        tracker.reset()

        assertNull(tracker.getActiveSession())
        assertNull(tracker.getCurrentTrackedApp())
        assertEquals(0L, tracker.getRemainingSeconds())
    }

    @Test
    @DisplayName("暂停超过阈值后停用 session")
    fun nonMonitoredPause_deactivatesSession() {
        configureDefaultTracking(limitMinutes = 30, sessionDurationSeconds = 500L)
        whenever(repository.isMonitored("com.safe.app")).thenReturn(false)

        tracker.updateTracking("com.game.app", 1_000_000L)
        tracker.updateTracking("com.safe.app", 1_005_000L)
        val result = tracker.updateTracking("com.safe.app", 1_065_000L)

        assertEquals(NativeContinuousUsageTracker.TrackingAction.DEACTIVATED, result.action)
        verify(repository).deactivateContinuousSession(1L)
    }

    @Test
    @DisplayName("超过限制时返回 LIMIT_REACHED，由状态机决定是否进 REST")
    fun overLimit_returnsLimitReached() {
        configureDefaultTracking(limitMinutes = 10, sessionDurationSeconds = 599L)

        tracker.updateTracking("com.game.app", 1_000_000L)
        val result = tracker.updateTracking("com.game.app", 1_005_000L)

        assertEquals(NativeContinuousUsageTracker.TrackingAction.LIMIT_REACHED, result.action)
    }
}
