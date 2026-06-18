package com.qiaoqiao.qiaoqiao_companion.monitor

import android.graphics.Color

/**
 * WidgetManager — thin wrapper around [NativeOverlayManager] that provides
 * simplified methods for the EnforcementEngine to drive UI.
 *
 * Responsibilities:
 * - Show/update stopwatch during MONITORING state
 * - Switch from stopwatch to countdown when approaching limit
 * - Update countdown time and color based on remaining seconds
 * - Hide all overlays when monitoring stops
 *
 * Color thresholds for countdown:
 * - > 5min (300s): default color (no change)
 * - <= 5min (300s): YELLOW
 * - <= 3min (180s): ORANGE (0xFFFF9800)
 * - <= 2min (120s): RED
 */
class WidgetManager(private val overlayManager: NativeOverlayManager) {

    companion object {
        /** 5 minutes in seconds — YELLOW threshold */
        private const val THRESHOLD_5MIN = 300L
        /** 3 minutes in seconds — ORANGE threshold */
        private const val THRESHOLD_3MIN = 180L
        /** 2 minutes in seconds — RED threshold */
        private const val THRESHOLD_2MIN = 120L
        /** Orange color for 3-minute warning */
        private const val COLOR_ORANGE = 0xFFFF9800.toInt()
    }

    private var stopwatchShowing = false
    private var countdownShowing = false

    /**
     * Show the stopwatch widget with the current used time.
     * Called during MONITORING state.
     */
    fun showStopwatch(usedSeconds: Long) {
        overlayManager.showStopwatchWidget(usedSeconds)
        stopwatchShowing = true
    }

    /**
     * Update the stopwatch display with the current used time.
     * Called during MONITORING state on each poll cycle.
     */
    fun updateStopwatch(usedSeconds: Long) {
        overlayManager.updateStopwatchTime(usedSeconds)
    }

    /**
     * Switch from stopwatch to countdown overlay.
     * Hides the stopwatch first, then shows the countdown.
     * Called when transitioning from MONITORING to COUNTDOWN state.
     *
     * Alert callbacks are passed as empty Runnables because the engine
     * handles color changes via [updateCountdownColor] instead.
     */
    fun switchToCountdown(remainingSeconds: Long) {
        overlayManager.hideStopwatchWidget()
        stopwatchShowing = false
        overlayManager.showCountdownOverlayWithAlerts(
            remainingSeconds,
            Runnable { },
            Runnable { },
            Runnable { }
        )
        countdownShowing = true
    }

    /**
     * Update the countdown display with the current remaining time.
     * Called during COUNTDOWN state on each poll cycle.
     */
    fun updateCountdown(remainingSeconds: Long) {
        overlayManager.updateCountdownTime(remainingSeconds)
    }

    /**
     * Update the countdown widget color based on remaining time.
     * Color thresholds:
     * - > 5min: no change (default color)
     * - <= 5min: YELLOW
     * - <= 3min: ORANGE
     * - <= 2min: RED
     */
    fun updateCountdownColor(remainingSeconds: Long) {
        when {
            remainingSeconds <= THRESHOLD_2MIN -> overlayManager.setCountdownColor(Color.RED)
            remainingSeconds <= THRESHOLD_3MIN -> overlayManager.setCountdownColor(COLOR_ORANGE)
            remainingSeconds <= THRESHOLD_5MIN -> overlayManager.setCountdownColor(Color.YELLOW)
            // > 5min: no color change needed
        }
    }

    /**
     * Hide all overlays (both countdown and stopwatch).
     * Called when transitioning to IDLE or REST state.
     */
    fun hideAll() {
        overlayManager.hideCountdownOverlay()
        countdownShowing = false
        overlayManager.hideStopwatchWidget()
        stopwatchShowing = false
    }

    /**
     * Check if the countdown overlay is currently showing.
     */
    fun isCountdownShowing(): Boolean = countdownShowing

    /**
     * Check if the stopwatch widget is currently showing.
     */
    fun isStopwatchShowing(): Boolean = stopwatchShowing

    /**
     * Clean up all resources.
     */
    fun destroy() {
        overlayManager.destroy()
        stopwatchShowing = false
        countdownShowing = false
    }
}
