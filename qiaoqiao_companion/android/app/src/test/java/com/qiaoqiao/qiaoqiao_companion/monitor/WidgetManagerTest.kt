package com.qiaoqiao.qiaoqiao_companion.monitor

import android.graphics.Color
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import org.mockito.InOrder
import org.mockito.kotlin.*

/**
 * TDD tests for WidgetManager — a thin wrapper around NativeOverlayManager
 * that provides simplified methods for the EnforcementEngine to drive UI.
 *
 * NativeOverlayManager is fully mocked; no Android framework needed.
 */
class WidgetManagerTest {

    private lateinit var overlayManager: NativeOverlayManager
    private lateinit var widgetManager: WidgetManager

    @BeforeEach
    fun setUp() {
        overlayManager = mock()
        widgetManager = WidgetManager(overlayManager)
    }

    // ══════════════════════════════════════════════════════════════
    //  1. showStopwatch delegates to overlayManager.showStopwatchWidget()
    // ══════════════════════════════════════════════════════════════
    @Test
    @DisplayName("showStopwatch calls overlayManager.showStopwatchWidget()")
    fun showStopwatch_callsShowStopwatchWidget() {
        widgetManager.showStopwatch(usedSeconds = 600L)

        verify(overlayManager).showStopwatchWidget(600L)
    }

    // ══════════════════════════════════════════════════════════════
    //  2. updateStopwatch delegates to overlayManager.updateStopwatchTime()
    // ══════════════════════════════════════════════════════════════
    @Test
    @DisplayName("updateStopwatch calls overlayManager.updateStopwatchTime()")
    fun updateStopwatch_callsUpdateStopwatchTime() {
        widgetManager.updateStopwatch(usedSeconds = 900L)

        verify(overlayManager).updateStopwatchTime(900L)
    }

    // ══════════════════════════════════════════════════════════════
    //  3. switchToCountdown hides stopwatch then shows countdown (inOrder)
    // ══════════════════════════════════════════════════════════════
    @Test
    @DisplayName("switchToCountdown hides stopwatch then shows countdown")
    fun switchToCountdown_hidesStopwatchThenShowsCountdown() {
        widgetManager.switchToCountdown(remainingSeconds = 300L)

        val inOrder = inOrder(overlayManager)
        inOrder.verify(overlayManager).hideStopwatchWidget()
        inOrder.verify(overlayManager).showCountdownOverlayWithAlerts(
            eq(300L),
            any(),
            any(),
            any()
        )
    }

    // ══════════════════════════════════════════════════════════════
    //  4. updateCountdown delegates to overlayManager.updateCountdownTime()
    // ══════════════════════════════════════════════════════════════
    @Test
    @DisplayName("updateCountdown calls overlayManager.updateCountdownTime()")
    fun updateCountdown_callsUpdateCountdownTime() {
        widgetManager.updateCountdown(remainingSeconds = 180L)

        verify(overlayManager).updateCountdownTime(180L)
    }

    // ══════════════════════════════════════════════════════════════
    //  5. updateCountdownColor — YELLOW when remaining <= 5min (300s)
    // ══════════════════════════════════════════════════════════════
    @Test
    @DisplayName("updateCountdownColor sets YELLOW when remaining <= 5min")
    fun updateCountdownColor_yellowWhen5min() {
        // 280 seconds remaining = 4min 40s, which is <= 300s (5min)
        widgetManager.updateCountdownColor(remainingSeconds = 280L)

        verify(overlayManager).setCountdownColor(Color.YELLOW)
    }

    // ══════════════════════════════════════════════════════════════
    //  6. updateCountdownColor — ORANGE (0xFFFF9800) when <= 3min (180s)
    // ══════════════════════════════════════════════════════════════
    @Test
    @DisplayName("updateCountdownColor sets ORANGE when remaining <= 3min")
    fun updateCountdownColor_orangeWhen3min() {
        // 170 seconds remaining = 2min 50s, which is <= 180s (3min)
        widgetManager.updateCountdownColor(remainingSeconds = 170L)

        verify(overlayManager).setCountdownColor(0xFFFF9800.toInt())
    }

    // ══════════════════════════════════════════════════════════════
    //  7. updateCountdownColor — RED when <= 2min (120s)
    // ══════════════════════════════════════════════════════════════
    @Test
    @DisplayName("updateCountdownColor sets RED when remaining <= 2min")
    fun updateCountdownColor_redWhen2min() {
        // 100 seconds remaining = 1min 40s, which is <= 120s (2min)
        widgetManager.updateCountdownColor(remainingSeconds = 100L)

        verify(overlayManager).setCountdownColor(Color.RED)
    }

    // ══════════════════════════════════════════════════════════════
    //  8. updateCountdownColor — no change when > 5min
    // ══════════════════════════════════════════════════════════════
    @Test
    @DisplayName("updateCountdownColor does not change color when remaining > 5min")
    fun updateCountdownColor_noChangeWhenAbove5min() {
        // 400 seconds remaining = 6min 40s, which is > 300s (5min)
        widgetManager.updateCountdownColor(remainingSeconds = 400L)

        verify(overlayManager, never()).setCountdownColor(any<Int>())
    }

    // ══════════════════════════════════════════════════════════════
    //  9. hideAll hides both countdown and stopwatch
    // ══════════════════════════════════════════════════════════════
    @Test
    @DisplayName("hideAll hides both countdown and stopwatch")
    fun hideAll_hidesBothCountdownAndStopwatch() {
        widgetManager.hideAll()

        verify(overlayManager).hideCountdownOverlay()
        verify(overlayManager).hideStopwatchWidget()
    }
}
