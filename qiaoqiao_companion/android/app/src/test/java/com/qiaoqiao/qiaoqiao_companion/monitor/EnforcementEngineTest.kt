package com.qiaoqiao.qiaoqiao_companion.monitor

import android.content.Context
import android.util.Log
import com.qiaoqiao.qiaoqiao_companion.monitor.NativeRuleRepository.ContinuousSession
import com.qiaoqiao.qiaoqiao_companion.monitor.NativeRuleRepository.ContinuousUsageSettings
import com.qiaoqiao.qiaoqiao_companion.monitor.NativeRuleRepository.MonitoredApp
import com.qiaoqiao.qiaoqiao_companion.monitor.RuleEvaluator.EvalResult
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNotEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import org.mockito.MockedStatic
import org.mockito.Mockito.anyString
import org.mockito.Mockito.mockStatic
import org.mockito.kotlin.any
import org.mockito.kotlin.doNothing
import org.mockito.kotlin.mock
import org.mockito.kotlin.never
import org.mockito.kotlin.spy
import org.mockito.kotlin.times
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever

class EnforcementEngineTest {

    private lateinit var repository: NativeRuleRepository
    private lateinit var ruleEvaluator: RuleEvaluator
    private lateinit var usageTracker: NativeContinuousUsageTracker
    private lateinit var widgetManager: WidgetManager
    private lateinit var overlayManager: NativeOverlayManager
    private lateinit var context: Context
    private lateinit var engine: EnforcementEngine
    private lateinit var mockedLog: MockedStatic<Log>

    @BeforeEach
    fun setUp() {
        repository = mock()
        ruleEvaluator = mock()
        usageTracker = mock()
        widgetManager = mock()
        overlayManager = mock()
        context = mock()
        engine = EnforcementEngine(repository, ruleEvaluator, usageTracker, widgetManager, overlayManager, context)

        mockedLog = mockStatic(Log::class.java)
        mockedLog.`when`<Int> { Log.d(anyString(), anyString()) }.thenReturn(0)
        mockedLog.`when`<Int> { Log.w(anyString(), anyString()) }.thenReturn(0)
        mockedLog.`when`<Int> { Log.e(anyString(), anyString()) }.thenReturn(0)

        whenever(repository.getMonitoredApps()).thenReturn(listOf(MonitoredApp("com.game.app", null)))
        whenever(repository.getContinuousUsageSettings()).thenReturn(
            ContinuousUsageSettings(enabled = true, limitMinutes = 30, restMinutes = 10)
        )
        whenever(repository.getActiveContinuousSession()).thenReturn(activeSession(totalDurationSeconds = 600L))
        whenever(ruleEvaluator.evaluate(any(), any())).thenReturn(EvalResult(blocked = false))
        whenever(usageTracker.updateTracking(any(), any())).thenReturn(NativeContinuousUsageTracker.TrackingResult.noop())
    }

    @AfterEach
    fun tearDown() {
        mockedLog.close()
    }

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

    @Test
    @DisplayName("初始状态为 IDLE")
    fun initialState_isIdle() {
        assertEquals(EngineState.IDLE, engine.state)
    }

    @Test
    @DisplayName("进入受限 app 后立即进入 COUNTDOWN 并显示剩余时间")
    fun monitoredApp_entersCountdown() {
        engine.onPoll(10_000L, "com.game.app")

        assertEquals(EngineState.COUNTDOWN, engine.state)
        verify(widgetManager).showCountdown(1200L)
        verify(usageTracker).persistCountdownState(10_000L, 1200L)
    }

    @Test
    @DisplayName("显式切到非受限 app 后 10 秒才隐藏 widget")
    fun explicitLeave_hidesAfterTenSeconds() {
        engine.onPoll(0L, "com.game.app")
        engine.onPoll(5_000L, "com.safe.app")
        assertEquals(EngineState.COUNTDOWN, engine.state)

        engine.onPoll(14_999L, "com.safe.app")
        assertEquals(EngineState.COUNTDOWN, engine.state)

        engine.onPoll(15_000L, "com.safe.app")
        assertEquals(EngineState.IDLE, engine.state)
        verify(widgetManager).hideCountdown()
    }

    @Test
    @DisplayName("self app 前台后 10 秒才隐藏 widget")
    fun selfAppForeground_hidesAfterTenSeconds() {
        engine.onPoll(0L, "com.game.app")
        engine.onPoll(5_000L, null, selfAppForeground = true)
        assertEquals(EngineState.COUNTDOWN, engine.state)

        engine.onPoll(14_999L, null, selfAppForeground = true)
        assertEquals(EngineState.COUNTDOWN, engine.state)

        engine.onPoll(15_000L, null, selfAppForeground = true)
        assertEquals(EngineState.IDLE, engine.state)
        verify(widgetManager).hideCountdown()
    }

    @Test
    @DisplayName("纯 null 检测空窗 15 秒内不误杀")
    fun unknownGap_doesNotHideTooEarly() {
        engine.onPoll(0L, "com.game.app")

        engine.onPoll(5_000L, null, selfAppForeground = false)
        engine.onPoll(15_000L, null, selfAppForeground = false)

        assertEquals(EngineState.COUNTDOWN, engine.state)
        verify(widgetManager, never()).hideCountdown()
    }

    @Test
    @DisplayName("纯 null 检测空窗持续 15 秒后才隐藏")
    fun unknownGap_hidesAfterFifteenSeconds() {
        engine.onPoll(0L, "com.game.app")
        engine.onPoll(5_000L, null, selfAppForeground = false)
        engine.onPoll(19_999L, null, selfAppForeground = false)
        assertEquals(EngineState.COUNTDOWN, engine.state)

        engine.onPoll(20_000L, null, selfAppForeground = false)
        assertEquals(EngineState.IDLE, engine.state)
        verify(widgetManager).hideCountdown()
    }

    @Test
    @DisplayName("离开缓冲窗口内回到受限 app 会取消离开判定")
    fun returnWithinGrace_resetsPendingLeave() {
        engine.onPoll(0L, "com.game.app")
        engine.onPoll(5_000L, "com.safe.app")
        engine.onPoll(9_000L, "com.game.app")
        assertEquals(EngineState.COUNTDOWN, engine.state)

        engine.onPoll(18_000L, "com.safe.app")
        assertEquals(EngineState.COUNTDOWN, engine.state)

        engine.onPoll(28_000L, "com.safe.app")
        assertEquals(EngineState.IDLE, engine.state)
    }

    @Test
    @DisplayName("规则命中时直接进入 REST 并显示锁层")
    fun blockedRule_entersRest() {
        val spyEngine = spy(engine)
        doNothing().`when`(spyEngine).moveToBackground()
        whenever(ruleEvaluator.evaluate("com.game.app", 0L)).thenReturn(
            EvalResult(blocked = true, reason = "time limit", ruleType = "total_time_limit")
        )

        spyEngine.onPoll(0L, "com.game.app")

        assertEquals(EngineState.REST, spyEngine.state)
        verify(overlayManager).showLockOverlay(any(), any(), any())
        verify(spyEngine).moveToBackground()
    }

    @Test
    @DisplayName("countdown 到期时立即进入 REST")
    fun expiredCountdown_entersRest() {
        val spyEngine = spy(engine)
        doNothing().`when`(spyEngine).moveToBackground()

        spyEngine.onPoll(0L, "com.game.app")
        whenever(repository.getActiveContinuousSession()).thenReturn(
            activeSession(countdownStartedAt = 0L, countdownTotalSeconds = 300L)
        )

        spyEngine.onPoll(301_000L, "com.game.app")

        assertEquals(EngineState.REST, spyEngine.state)
        verify(overlayManager).showLockOverlay(any(), any(), any())
        verify(spyEngine).moveToBackground()
    }

    @Test
    @DisplayName("restoreFromDB 使用 deadline 恢复准确剩余时间")
    fun restoreFromDb_usesDeadline() {
        whenever(repository.getActiveContinuousSession()).thenReturn(
            activeSession(countdownStartedAt = 1_000L, countdownTotalSeconds = 300L)
        )

        engine.restoreFromDB(101_000L)

        assertEquals(EngineState.COUNTDOWN, engine.state)
        verify(widgetManager).showCountdown(200L)
    }

    @Test
    @DisplayName("COUNTDOWN 轮询更新时按 DB deadline 校准，不按轮询次数推算")
    fun countdownUpdate_usesDeadlineFromDb() {
        engine.onPoll(0L, "com.game.app")
        whenever(repository.getActiveContinuousSession()).thenReturn(
            activeSession(countdownStartedAt = 10_000L, countdownTotalSeconds = 300L)
        )

        engine.onPoll(110_000L, "com.game.app")

        verify(widgetManager).updateCountdown(200L)
        verify(widgetManager).updateCountdownColor(200L)
    }

    @Test
    @DisplayName("休息结束但仍在受限 app 时保持 REST，等待手动关闭")
    fun restEndedOnMonitoredApp_staysRest() {
        whenever(ruleEvaluator.evaluate("com.game.app", 0L)).thenReturn(
            EvalResult(blocked = true, reason = "time limit", ruleType = "total_time_limit")
        )
        engine.onPoll(0L, "com.game.app")
        whenever(repository.getActiveContinuousSession()).thenReturn(
            activeSession(id = 42L, restEndTime = 10_000L)
        )

        engine.onPoll(11_000L, "com.game.app")

        assertEquals(EngineState.REST, engine.state)
        verify(repository).deactivateContinuousSession(42L)
        verify(overlayManager).markRestEnded()
        verify(overlayManager, never()).hideOverlay()
    }

    @Test
    @DisplayName("休息结束且用户已离开时返回 IDLE")
    fun restEndedAway_transitionsToIdle() {
        whenever(ruleEvaluator.evaluate("com.game.app", 0L)).thenReturn(
            EvalResult(blocked = true, reason = "time limit", ruleType = "total_time_limit")
        )
        engine.onPoll(0L, "com.game.app")
        whenever(repository.getActiveContinuousSession()).thenReturn(
            activeSession(id = 42L, restEndTime = 10_000L)
        )

        engine.onPoll(11_000L, "com.safe.app")

        assertEquals(EngineState.IDLE, engine.state)
        verify(overlayManager).hideOverlay()
        verify(repository).deactivateContinuousSession(42L)
    }

    @Test
    @DisplayName("家长从 countdown 绕过后进入宽限期，不会立即重触发")
    fun parentOverrideFromCountdown_entersGracePeriod() {
        engine.onPoll(0L, "com.game.app")
        engine.onParentOverrideFromCountdown()
        assertEquals(EngineState.IDLE, engine.state)

        engine.onPoll(1_000L, "com.game.app")
        assertEquals(EngineState.IDLE, engine.state)
        verify(widgetManager, times(1)).showCountdown(any())
    }

    @Test
    @DisplayName("destroy 会清理 widgetManager")
    fun destroy_callsWidgetManagerDestroy() {
        engine.destroy()
        verify(widgetManager).destroy()
    }

    @Test
    @DisplayName("persistStateBeforeDeath 为无异常 hook")
    fun persistStateBeforeDeath_noCrash() {
        engine.persistStateBeforeDeath()
        assertTrue(true)
    }

    @Test
    @DisplayName("手动关闭休息弹窗后回到 IDLE")
    fun dismissOverlay_transitionsToIdle() {
        whenever(ruleEvaluator.evaluate("com.game.app", 0L)).thenReturn(
            EvalResult(blocked = true, reason = "time limit", ruleType = "total_time_limit")
        )
        engine.onPoll(0L, "com.game.app")
        assertEquals(EngineState.REST, engine.state)

        engine.onOverlayDismissed()

        assertEquals(EngineState.IDLE, engine.state)
        verify(overlayManager).hideOverlayImmediate()
    }

    @Test
    @DisplayName("手动关闭休息弹窗且仍在受限 app 时可以恢复 countdown")
    fun dismissOverlayOnMonitoredApp_returnsToCountdown() {
        whenever(ruleEvaluator.evaluate("com.game.app", 0L)).thenReturn(
            EvalResult(blocked = true, reason = "time limit", ruleType = "total_time_limit")
        )
        engine.onPoll(0L, "com.game.app")
        whenever(repository.getActiveContinuousSession()).thenReturn(
            activeSession(id = 7L, totalDurationSeconds = 0L)
        )

        engine.onOverlayDismissedOnMonitoredApp("com.game.app", 20_000L)

        assertEquals(EngineState.COUNTDOWN, engine.state)
        verify(widgetManager, times(1)).showCountdown(1800L)
        verify(usageTracker).persistCountdownState(20_000L, 1800L)
        assertNotEquals(EngineState.REST, engine.state)
    }
}
