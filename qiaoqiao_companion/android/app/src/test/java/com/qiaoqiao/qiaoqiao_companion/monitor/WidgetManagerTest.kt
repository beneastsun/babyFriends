package com.qiaoqiao.qiaoqiao_companion.monitor

import android.graphics.Color
import android.util.Log
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import org.mockito.MockedStatic
import org.mockito.Mockito.anyString
import org.mockito.Mockito.mockStatic
import org.mockito.kotlin.*

/**
 * TDD tests for WidgetManager — a thin wrapper around NativeOverlayManager
 * that provides simplified methods for the EnforcementEngine to drive UI.
 *
 * Only manages a single countdown widget (no stopwatch).
 *
 * NativeOverlayManager is fully mocked; no Android framework needed.
 */
class WidgetManagerTest {

    private lateinit var overlayManager: NativeOverlayManager
    private lateinit var widgetManager: WidgetManager
    private lateinit var mockedLog: MockedStatic<Log>

    @BeforeEach
    fun setUp() {
        overlayManager = mock()
        widgetManager = WidgetManager(overlayManager)
        // Mock android.util.Log for unit tests (not available in JVM)
        mockedLog = mockStatic(Log::class.java)
        mockedLog.`when`<Int> { Log.d(anyString(), anyString()) }.thenReturn(0)
        mockedLog.`when`<Int> { Log.w(anyString(), anyString()) }.thenReturn(0)
        mockedLog.`when`<Int> { Log.e(anyString(), anyString()) }.thenReturn(0)
    }

    @AfterEach
    fun tearDown() {
        mockedLog.close()
    }

    // ══════════════════════════════════════════════════════════════
    //  1. showCountdown delegates to overlayManager.showCountdownOverlayWithAlerts()
    // ══════════════════════════════════════════════════════════════
    @Test
    @DisplayName("showCountdown calls overlayManager.showCountdownOverlayWithAlerts()")
    fun showCountdown_callsShowCountdownOverlayWithAlerts() {
        widgetManager.showCountdown(remainingSeconds = 300L)

        verify(overlayManager).showCountdownOverlayWithAlerts(
            eq(300L),
            any(),
            any(),
            any(),
            any()
        )
    }

    @Test
    @DisplayName("isCountdownShowing 直接反映 NativeOverlayManager 状态")
    fun isCountdownShowing_delegatesToOverlayManager() {
        whenever(overlayManager.isCountdownShowing()).thenReturn(true)
        org.junit.jupiter.api.Assertions.assertTrue(widgetManager.isCountdownShowing())
    }

    @Test
    @DisplayName("updateCountdown calls overlayManager.updateCountdownTime() when overlay showing")
    fun updateCountdown_callsUpdateCountdownTime() {
        // Simulate overlay is still showing (not reclaimed by system)
        whenever(overlayManager.isCountdownShowing()).thenReturn(true)

        widgetManager.updateCountdown(remainingSeconds = 180L)

        verify(overlayManager).updateCountdownTime(180L)
    }

    @Test
    @DisplayName("updateCountdown rebuilds widget when overlay lost (system reclaim)")
    fun updateCountdown_rebuildsWhenOverlayLost() {
        // Simulate overlay was reclaimed by system (isCountdownShowing = false)
        whenever(overlayManager.isCountdownShowing()).thenReturn(false)

        widgetManager.updateCountdown(remainingSeconds = 180L)

        // Should call showCountdownOverlayWithAlerts to rebuild, not updateCountdownTime
        verify(overlayManager).showCountdownOverlayWithAlerts(
            eq(180L),
            any(),
            any(),
            any()
        )
        verify(overlayManager, never()).updateCountdownTime(any())
    }

    @Test
    @DisplayName("updateCountdownColor sets YELLOW when remaining <= 5min")
    fun updateCountdownColor_yellowWhen5min() {
        widgetManager.updateCountdownColor(remainingSeconds = 280L)
        verify(overlayManager).setCountdownColor(Color.YELLOW)
    }

    @Test
    @DisplayName("updateCountdownColor sets ORANGE when remaining <= 3min")
    fun updateCountdownColor_orangeWhen3min() {
        widgetManager.updateCountdownColor(remainingSeconds = 170L)
        verify(overlayManager).setCountdownColor(0xFFFF9800.toInt())
    }

    @Test
    @DisplayName("updateCountdownColor sets RED when remaining <= 2min")
    fun updateCountdownColor_redWhen2min() {
        widgetManager.updateCountdownColor(remainingSeconds = 100L)
        verify(overlayManager).setCountdownColor(Color.RED)
    }

    @Test
    @DisplayName("updateCountdownColor does not change color when remaining > 5min")
    fun updateCountdownColor_noChangeWhenAbove5min() {
        widgetManager.updateCountdownColor(remainingSeconds = 400L)
        verify(overlayManager, never()).setCountdownColor(any<Int>())
    }

    @Test
    @DisplayName("hideCountdown hides countdown overlay")
    fun hideCountdown_hidesCountdownOverlay() {
        widgetManager.hideCountdown()
        verify(overlayManager).hideCountdownOverlay()
    }

    @Test
    @DisplayName("destroy calls overlayManager.destroy")
    fun destroy_callsOverlayManagerDestroy() {
        widgetManager.destroy()
        verify(overlayManager).destroy()
    }

    @Test
    @DisplayName("updateCountdown 使用传入剩余值 rebuild，不重置为旧整分钟")
    fun updateCountdown_rebuildUsesCurrentRemaining() {
        whenever(overlayManager.isCountdownShowing()).thenReturn(false)

        widgetManager.updateCountdown(remainingSeconds = 173L)

        verify(overlayManager).showCountdownOverlayWithAlerts(
            eq(173L),
            any(),
            any(),
            any(),
            any()
        )
    }
}
