package com.qiaoqiao.qiaoqiao_companion.monitor

import android.graphics.Color
import android.util.Log

/**
 * WidgetManager — thin wrapper around [NativeOverlayManager] that provides
 * simplified methods for the EnforcementEngine to drive UI.
 *
 * Only manages a single countdown widget that shows remaining time from
 * the moment a monitored app is opened. No stopwatch — the child sees
 * "how much time is left", not "how long you've been playing".
 *
 * Color thresholds for countdown:
 * - > 5min (300s): default color (no change)
 * - <= 5min (300s): YELLOW
 * - <= 3min (180s): ORANGE (0xFFFF9800)
 * - <= 2min (120s): RED
 *
 * 重构要点（解决倒计时归零衔接、显示抖动、颜色时机）：
 * - 倒计时归零瞬间通过 [onCountdownZero] 立刻触发 REST，消除"widget 卡 0:00 最多 5s 才弹禁用窗"的空窗。
 * - 颜色阈值不再依赖每轮询的 remaining 外部驱动，而是由 ticker 内部维护的权威剩余毫秒决定，
 *   这样即使 MIUI 检测 gap 导致状态机 null-leave 期间不调用 updateCountdownColor，颜色仍持续准确。
 */
class WidgetManager(private val overlayManager: NativeOverlayManager) {

    companion object {
        /** Color stages for countdown thresholds */
        private const val COLOR_STAGE_NONE = 0
        private const val COLOR_STAGE_YELLOW = 1
        private const val COLOR_STAGE_ORANGE = 2
        private const val COLOR_STAGE_RED = 3

        /** 5 minutes in seconds — YELLOW threshold */
        private const val THRESHOLD_5MIN = 300L
        /** 3 minutes in seconds — ORANGE threshold */
        private const val THRESHOLD_3MIN = 180L
        /** 2 minutes in seconds — RED threshold */
        private const val THRESHOLD_2MIN = 120L
        /** Orange color for 3-minute warning */
        private const val COLOR_ORANGE = 0xFFFF9800.toInt()
    }

    /** 最近一次应用的阈值色阶，避免每秒重复 setCountdownColor 触发背景重建 */
    private var lastAppliedColorStage: Int = COLOR_STAGE_NONE

    /**
     * 倒计时归零回调 — 由 EnforcementEngine 注入，归零瞬间触发 REST。
     */
    var onCountdownZero: (() -> Unit)? = null
    /**
     * 家长入口回调 — 从倒计时widget点击家长入口
     */
    var onParentEntryFromWidget: (() -> Unit)? = null
    /**
     * 家长密码验证成功回调
     */
    var onParentPasswordVerified: (() -> Unit)? = null

    init {
        // 让 NativeOverlayManager 在 ticker 归零时回调本 WidgetManager，再转发给 EnforcementEngine
        overlayManager.onCountdownZeroReachedHook = Runnable {
            try {
                onCountdownZero?.invoke()
            } catch (e: Exception) {
                Log.e("WidgetManager", "onCountdownZero failed", e)
            }
        }
    }

    /**
     * Show the countdown widget with the remaining time.
     * Called when entering COUNTDOWN state (monitored app detected).
     */
    fun showCountdown(remainingSeconds: Long) {
        lastAppliedColorStage = COLOR_STAGE_NONE
        overlayManager.showCountdownOverlayWithAlerts(
            remainingSeconds,
            Runnable { },
            Runnable { },
            Runnable { },
            Runnable { }
        )
        // 透传家长入口回调
        overlayManager.onParentEntryFromWidget = onParentEntryFromWidget
        overlayManager.onParentPasswordVerified = onParentPasswordVerified
    }

    /**
     * Update the countdown display with the current remaining time.
     * Called during COUNTDOWN state on each poll cycle.
     *
     * If the underlying overlay was reclaimed by the system (MIUI etc.),
     * automatically rebuilds it so the countdown never disappears silently.
     */
    fun updateCountdown(remainingSeconds: Long) {
        if (!overlayManager.isCountdownShowing()) {
            // Widget was reclaimed by the system — rebuild it
            Log.w("WidgetManager", "Countdown overlay lost (system reclaim?), rebuilding with ${remainingSeconds}s")
            showCountdown(remainingSeconds)
            return
        }
        overlayManager.updateCountdownTime(remainingSeconds)
        // 颜色阈值优先以 ticker 维护的权威剩余时间为准（见 applyColorStageIfNeeded）
        applyColorStageIfNeeded()
    }

    /**
     * Update the countdown widget color based on remaining time.
     * Color thresholds:
     * - > 5min: no change (default color)
     * - <= 5min: YELLOW
     * - <= 3min: ORANGE
     * - <= 2min: RED
     *
     * 保留对外暴露（EnforcementEngine 在状态转换时调用），但日常刷新已内移到 [applyColorStageIfNeeded]。
     */
    fun updateCountdownColor(remainingSeconds: Long) {
        applyColorStageForSeconds(remainingSeconds)
    }

    /**
     * 以 ticker 维护的权威剩余毫秒判定并切换色阶。
     * 即使状态机因 null-leave 不调用 updateCountdown，只要 ticker 在走，颜色就持续准确。
     */
    private fun applyColorStageIfNeeded() {
        val remainingSec = overlayManager.getCountdownRemainingMs() / 1000L
        applyColorStageForSeconds(remainingSec)
    }

    /**
     * 根据剩余秒数切换色阶，仅在色阶变化时才调 setCountdownColor，避免重复重建背景。
     */
    private fun applyColorStageForSeconds(remainingSeconds: Long) {
        val stage = when {
            remainingSeconds <= THRESHOLD_2MIN -> COLOR_STAGE_RED
            remainingSeconds <= THRESHOLD_3MIN -> COLOR_STAGE_ORANGE
            remainingSeconds <= THRESHOLD_5MIN -> COLOR_STAGE_YELLOW
            else -> COLOR_STAGE_NONE
        }
        if (stage == lastAppliedColorStage) return
        lastAppliedColorStage = stage
        when (stage) {
            COLOR_STAGE_RED -> overlayManager.setCountdownColor(Color.RED)
            COLOR_STAGE_ORANGE -> overlayManager.setCountdownColor(COLOR_ORANGE)
            COLOR_STAGE_YELLOW -> overlayManager.setCountdownColor(Color.YELLOW)
            // NONE: 回到默认色（不主动重置，NativeOverlayManager 未展示默认色重置 API）
        }
    }

    /**
     * Hide the countdown widget.
     * Called when transitioning to IDLE or REST state.
     */
    fun hideCountdown() {
        overlayManager.hideCountdownOverlay()
        lastAppliedColorStage = COLOR_STAGE_NONE
    }

    /**
     * Check if the countdown overlay is currently showing.
     */
    fun isCountdownShowing(): Boolean = overlayManager.isCountdownShowing()

    /**
     * Clean up all resources.
     */
    fun destroy() {
        overlayManager.destroy()
        lastAppliedColorStage = COLOR_STAGE_NONE
    }

}
