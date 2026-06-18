package com.qiaoqiao.qiaoqiao_companion.monitor

import android.util.Log
import com.qiaoqiao.qiaoqiao_companion.monitor.NativeRuleRepository.ContinuousSession

/**
 * EnforcementEngine — the central state machine that coordinates all monitoring components.
 *
 * Coordinates [RuleEvaluator], [NativeContinuousUsageTracker], [WidgetManager],
 * and [NativeOverlayManager] to enforce usage rules.
 *
 * State transitions (per spec §4.2):
 *   IDLE -> MONITORING (when a monitored app is detected)
 *   MONITORING -> COUNTDOWN (when continuous usage approaches limit)
 *   MONITORING -> REST (when rule evaluator blocks the app)
 *   COUNTDOWN -> REST (when countdown reaches zero)
 *   REST -> IDLE (when rest period ends)
 *   Any -> IDLE (when app switches away after leave-confirmation threshold)
 *
 * All timing uses wall clock (System.currentTimeMillis()).
 * Leave-confirmation threshold = 2 consecutive non-monitored polls.
 * Widget color thresholds: <=5min yellow, <=3min orange, <=2min red.
 * `MainActivity.isFlutterAlive` is NOT used in this class.
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
        /** Number of consecutive non-monitored polls before transitioning to IDLE */
        private const val LEAVE_CONFIRM_THRESHOLD = 2
    }

    /** Current engine state */
    var state: EngineState = EngineState.IDLE
        private set

    /** Consecutive polls where the foreground app is not monitored */
    private var leaveConfirmCount: Int = 0

    /** The package name of the currently tracked monitored app */
    private var currentMonitoredApp: String? = null

    // ══════════════════════════════════════════════════════════════
    //  Main state machine loop — called on every poll cycle
    // ══════════════════════════════════════════════════════════════

    /**
     * Process a single poll cycle.
     *
     * @param now Current wall-clock time in millis.
     * @param foregroundApp The package name of the current foreground app, or null.
     */
    fun onPoll(now: Long, foregroundApp: String?) {
        when (state) {
            EngineState.REST -> handleRestState(now, foregroundApp)
            EngineState.IDLE -> handleIdleState(now, foregroundApp)
            EngineState.MONITORING -> handleMonitoringState(now, foregroundApp)
            EngineState.COUNTDOWN -> handleCountdownState(now, foregroundApp)
            EngineState.AT_LIMIT -> handleAtLimitState(now, foregroundApp)
        }
    }

    // ── REST state ────────────────────────────────────────────────

    /**
     * In REST state, only check if the rest period has ended.
     * No rule evaluation or tracking updates occur.
     */
    private fun handleRestState(now: Long, foregroundApp: String?) {
        val session = repository.getActiveContinuousSession()
        val restEndTime = session?.restEndTime

        if (restEndTime != null && restEndTime <= now) {
            // Rest period has ended
            Log.d(TAG, "Rest ended, transitioning to IDLE")
            overlayManager.hideOverlay()
            session.id?.let { repository.deactivateContinuousSession(it) }
            transitionTo(EngineState.IDLE)
            usageTracker.reset()
            widgetManager.hideAll()
            leaveConfirmCount = 0
            currentMonitoredApp = null
        } else {
            // Rest still active — the lock overlay manages its own countdown
            // (started when showLockOverlay was called with durationSeconds).
            // No additional update needed here.
            Log.d(TAG, "Rest still active, overlay manages its own countdown")
        }
    }

    // ── IDLE state ────────────────────────────────────────────────

    /**
     * In IDLE state, check if a monitored app has come to the foreground.
     * If the rule evaluator immediately blocks the app, go directly to REST.
     */
    private fun handleIdleState(now: Long, foregroundApp: String?) {
        if (foregroundApp == null) return

        if (!isMonitored(foregroundApp)) return

        // Monitored app detected — check rules first
        val evalResult = ruleEvaluator.evaluate(foregroundApp, now)
        if (evalResult.blocked) {
            // Immediately blocked — go directly to REST
            Log.d(TAG, "Monitored app $foregroundApp is blocked, transitioning directly to REST")
            overlayManager.showLockOverlay(evalResult.reason, foregroundApp)
            transitionTo(EngineState.REST)
            return
        }

        // Not blocked — transition to MONITORING
        Log.d(TAG, "Monitored app detected: $foregroundApp, transitioning to MONITORING")
        currentMonitoredApp = foregroundApp
        leaveConfirmCount = 0

        // Start tracking
        usageTracker.updateTracking(foregroundApp, now)
        val usedSeconds = getUsedSecondsFromSession()
        widgetManager.showStopwatch(usedSeconds)

        transitionTo(EngineState.MONITORING)
    }

    // ── MONITORING state ──────────────────────────────────────────

    /**
     * In MONITORING state, check for rule violations and countdown threshold.
     * Handle leave-confirmation for non-monitored apps.
     */
    private fun handleMonitoringState(now: Long, foregroundApp: String?) {
        if (foregroundApp == null || !isMonitored(foregroundApp)) {
            // Non-monitored or null foreground — increment leave confirm count
            leaveConfirmCount++
            Log.d(TAG, "Non-monitored foreground, leaveConfirmCount=$leaveConfirmCount")

            if (leaveConfirmCount >= LEAVE_CONFIRM_THRESHOLD) {
                // Confirmed leave — transition to IDLE
                Log.d(TAG, "Leave confirmed, transitioning to IDLE")
                widgetManager.hideAll()
                usageTracker.onCountdownHidden()
                transitionTo(EngineState.IDLE)
                leaveConfirmCount = 0
                currentMonitoredApp = null
            }
            return
        }

        // Monitored app is in foreground — reset leave confirm count
        leaveConfirmCount = 0
        currentMonitoredApp = foregroundApp

        // Update tracking
        val trackingResult = usageTracker.updateTracking(foregroundApp, now)

        // Check if rule evaluator blocks the app
        val evalResult = ruleEvaluator.evaluate(foregroundApp, now)
        if (evalResult.blocked) {
            // Rule violation — transition to REST
            Log.d(TAG, "Rule blocked: ${evalResult.reason}, transitioning to REST")
            widgetManager.hideAll()
            overlayManager.showLockOverlay(evalResult.reason, foregroundApp)
            transitionTo(EngineState.REST)
            return
        }

        // Check if continuous usage tracker signals countdown
        if (trackingResult.shouldShowCountdown) {
            // Approaching limit — transition to COUNTDOWN
            val remainingSeconds = trackingResult.remainingSeconds
            Log.d(TAG, "Countdown threshold reached, remaining=${remainingSeconds}s, transitioning to COUNTDOWN")
            widgetManager.switchToCountdown(remainingSeconds)
            usageTracker.persistCountdownState(now, remainingSeconds)
            transitionTo(EngineState.COUNTDOWN)
            return
        }

        // Still within limits — update stopwatch
        val usedSeconds = getUsedSecondsFromSession()
        widgetManager.updateStopwatch(usedSeconds)
    }

    // ── COUNTDOWN state ───────────────────────────────────────────

    /**
     * In COUNTDOWN state, use wall-clock calibration from DB
     * (countdownStartedAt + countdownTotalSeconds) to determine remaining time.
     */
    private fun handleCountdownState(now: Long, foregroundApp: String?) {
        if (foregroundApp == null || !isMonitored(foregroundApp)) {
            // Non-monitored or null foreground — increment leave confirm count
            leaveConfirmCount++
            Log.d(TAG, "COUNTDOWN: non-monitored foreground, leaveConfirmCount=$leaveConfirmCount")

            if (leaveConfirmCount >= LEAVE_CONFIRM_THRESHOLD) {
                // Confirmed leave — transition to IDLE
                Log.d(TAG, "Leave confirmed from COUNTDOWN, transitioning to IDLE")
                widgetManager.hideAll()
                usageTracker.onCountdownHidden()
                transitionTo(EngineState.IDLE)
                leaveConfirmCount = 0
                currentMonitoredApp = null
            }
            return
        }

        // Monitored app is in foreground — reset leave confirm count
        leaveConfirmCount = 0
        currentMonitoredApp = foregroundApp

        // Update tracking
        val trackingResult = usageTracker.updateTracking(foregroundApp, now)

        // Wall-clock calibration from DB
        val session = repository.getActiveContinuousSession()
        val remainingSeconds = calculateRemainingFromSession(session, now)

        if (remainingSeconds <= 0) {
            // Countdown expired — transition to REST
            Log.d(TAG, "Countdown expired, transitioning to REST")
            widgetManager.hideAll()
            overlayManager.showLockOverlay("连续使用时间已到，请休息一下", foregroundApp)
            transitionTo(EngineState.REST)
            return
        }

        // Countdown still running — update display
        widgetManager.updateCountdown(remainingSeconds)
        widgetManager.updateCountdownColor(remainingSeconds)
    }

    // ── AT_LIMIT state ────────────────────────────────────────────

    /**
     * AT_LIMIT is a transitional state that immediately leads to REST.
     * In practice, the engine transitions directly from MONITORING/COUNTDOWN to REST.
     * This handler exists for completeness.
     */
    private fun handleAtLimitState(now: Long, foregroundApp: String?) {
        // AT_LIMIT should immediately transition to REST
        // This state is kept for spec completeness but in practice
        // the engine goes directly MONITORING/COUNTDOWN -> REST
        val evalResult = if (foregroundApp != null) {
            ruleEvaluator.evaluate(foregroundApp, now)
        } else {
            RuleEvaluator.EvalResult(blocked = true, reason = "Time limit reached", ruleType = "at_limit")
        }

        if (evalResult.blocked) {
            widgetManager.hideAll()
            overlayManager.showLockOverlay(evalResult.reason, foregroundApp ?: "")
            transitionTo(EngineState.REST)
        } else {
            transitionTo(EngineState.IDLE)
        }
    }

    // ══════════════════════════════════════════════════════════════
    //  Restore from DB after process death
    // ══════════════════════════════════════════════════════════════

    /**
     * Recover state from DB after process death.
     *
     * Checks for:
     * 1. Active rest session -> REST state
     * 2. Active countdown (not expired) -> COUNTDOWN state
     * 3. Expired countdown -> REST state
     * 4. No active session -> IDLE state
     */
    fun restoreFromDB(now: Long) {
        val session = repository.getActiveContinuousSession()

        if (session == null) {
            Log.d(TAG, "restoreFromDB: no active session, staying IDLE")
            state = EngineState.IDLE
            return
        }

        // Check for active rest
        if (session.restEndTime != null && session.restEndTime > now) {
            Log.d(TAG, "restoreFromDB: active rest, transitioning to REST")
            overlayManager.showLockOverlay("正在休息中", "")
            state = EngineState.REST
            return
        }

        // Check for active countdown
        if (session.countdownStartedAt != null && session.countdownTotalSeconds != null) {
            val remainingSeconds = calculateRemainingFromSession(session, now)

            if (remainingSeconds <= 0) {
                // Countdown expired while process was dead -> REST
                Log.d(TAG, "restoreFromDB: expired countdown, transitioning to REST")
                overlayManager.showLockOverlay("连续使用时间已到，请休息一下", "")
                state = EngineState.REST
                return
            }

            // Countdown still active
            Log.d(TAG, "restoreFromDB: active countdown, remaining=${remainingSeconds}s, transitioning to COUNTDOWN")
            widgetManager.switchToCountdown(remainingSeconds)
            state = EngineState.COUNTDOWN
            return
        }

        // Rest ended or no countdown — stay IDLE
        Log.d(TAG, "restoreFromDB: no active rest or countdown, staying IDLE")
        state = EngineState.IDLE
    }

    // ══════════════════════════════════════════════════════════════
    //  Persist state before death
    // ══════════════════════════════════════════════════════════════

    /**
     * Hook for saving state before process death.
     * Most state is already persisted to DB by the tracker/evaluator,
     * so this is primarily a no-op hook for future use.
     */
    fun persistStateBeforeDeath() {
        // Most state is already in DB via usageTracker.persistCountdownState()
        // and repository.updateContinuousSession(). This is a hook for
        // any additional in-memory state that needs to be persisted.
        Log.d(TAG, "persistStateBeforeDeath: state=$state, currentMonitoredApp=$currentMonitoredApp")
    }

    // ══════════════════════════════════════════════════════════════
    //  Cleanup
    // ══════════════════════════════════════════════════════════════

    /**
     * Clean up all resources and reset state.
     */
    fun destroy() {
        widgetManager.destroy()
        usageTracker.reset()
        state = EngineState.IDLE
        leaveConfirmCount = 0
        currentMonitoredApp = null
        Log.d(TAG, "Engine destroyed, state reset to IDLE")
    }

    // ══════════════════════════════════════════════════════════════
    //  Internal helpers
    // ══════════════════════════════════════════════════════════════

    /**
     * Transition to a new state.
     */
    private fun transitionTo(newState: EngineState) {
        Log.d(TAG, "State transition: $state -> $newState")
        state = newState
    }

    /**
     * Check if the given package name is in the monitored apps list.
     */
    private fun isMonitored(packageName: String): Boolean {
        return repository.getMonitoredApps().any { it.packageName == packageName }
    }

    /**
     * Calculate remaining seconds from session using wall-clock calibration.
     * Uses countdownStartedAt and countdownTotalSeconds from the DB session.
     * Falls back to tracker's remaining seconds if countdown fields are not set.
     */
    private fun calculateRemainingFromSession(session: ContinuousSession?, now: Long): Long {
        if (session == null) return usageTracker.getRemainingSeconds()

        // Wall-clock calibration from DB
        val startedAt = session.countdownStartedAt
        val totalSeconds = session.countdownTotalSeconds

        if (startedAt != null && totalSeconds != null) {
            val elapsedSeconds = (now - startedAt) / 1000L
            return (totalSeconds - elapsedSeconds).coerceAtLeast(0L)
        }

        // Fallback to tracker's remaining seconds
        return usageTracker.getRemainingSeconds()
    }

    /**
     * Get the used seconds from the current active session.
     */
    private fun getUsedSecondsFromSession(): Long {
        val session = repository.getActiveContinuousSession()
        return session?.totalDurationSeconds ?: 0L
    }
}
