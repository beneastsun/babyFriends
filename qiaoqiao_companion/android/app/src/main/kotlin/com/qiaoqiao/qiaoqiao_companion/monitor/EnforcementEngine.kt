package com.qiaoqiao.qiaoqiao_companion.monitor

import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Central enforcement engine — simplified state machine that drives all monitoring logic.
 *
 * State machine:
 * ```
 * ┌───────┐  enter monitored app  ┌───────────┐  countdown=0  ┌───────┐
 * │ IDLE  │──────────────────────→│ COUNTDOWN │──────────────→│ REST  │
 * └───┬───┘                       └─────┬─────┘               └───┬───┘
 *     ↑                                 │                        │
 *     │  leave app (confirmed)          │ leave app (confirmed)  │ rest ended + user away / dismiss
 *     └─────────────────────────────────┘                        │
 *     ┌──────────────────────────────────────────────────────────┘
 * ```
 *
 * IDLE:      No monitored app in foreground. No widget.
 * COUNTDOWN: Monitored app in foreground. Countdown widget shows remaining time,
 *            color changes at 5min/3min/2min thresholds.
 * REST:      Forced rest. Lock overlay shown (no rest countdown displayed).
 *            User can dismiss overlay immediately or enter parent password to override.
 *            If user leaves monitored app during REST, overlay is hidden but REST continues.
 *
 * Key design decisions:
 * - Only one widget: the countdown (no separate stopwatch).
 *   The child sees "how much time is left", not "how long you've been playing".
 * - Wall-clock calibration: remaining = countdownTotalSeconds - (now - countdownStartedAt) / 1000
 * - Leave confirmation uses wall-clock grace windows, not poll counts:
 *   explicit leave = 10s, unknown/null gap = 15s
 * - No isFlutterAlive branching — engine always runs natively
 * - On entering REST, the monitored app is automatically moved to background (HOME intent)
 * - REST overlay does NOT auto-dismiss when rest countdown ends; user must manually close
 */
class EnforcementEngine(
    private val repository: NativeRuleRepository,
    private val ruleEvaluator: RuleEvaluator,
    private val usageTracker: NativeContinuousUsageTracker,
    private val widgetManager: WidgetManager,
    private val overlayManager: NativeOverlayManager,
    private val context: Context
) {
    companion object {
        private const val TAG = "EnforcementEngine"
        private const val EXPLICIT_LEAVE_GRACE_MS = 10_000L
        private const val UNKNOWN_LEAVE_GRACE_MS = 15_000L
        /** 家长覆盖后的宽限期（毫秒）：在此期间不会对同一 app 重新触发限制 */
        private const val PARENT_OVERRIDE_GRACE_MS = 30_000L // 30秒
        /** 时间范围违规的固定休息时长（1 分钟） */
        private const val TIME_PERIOD_REST_SECONDS = 60
        /** 时间范围违规关闭后的防抖时间（毫秒）：让 launchMainActivity 有时间切走，避免立即重弹 */
        private const val TIME_PERIOD_DISMISS_DEBOUNCE_MS = 3_000L
    }

    var state: EngineState = EngineState.IDLE
        private set

    // 记录显式离开的起点（明确检测到其他 app 或自身 app 在前台）
    private var pendingLeaveSinceMs: Long? = null
    // 记录未知离开的起点（纯 null 检测 gap）
    private var pendingUnknownSinceMs: Long? = null
    // Currently tracked monitored app (null = none)
    private var trackedApp: String? = null
    // Whether the rest countdown has completed (overlay stays until user dismisses)
    private var restCompleted = false
    // Whether the lock overlay is currently visible
    private var overlayShowing = false
    // Timestamp of last parent override — used to prevent immediate re-trigger
    private var parentOverrideUntil: Long = 0L
    // 当前 REST 的违规类型："continuous"（连续使用）或 "time_period"（时间范围违规）
    private var currentViolationType: String = "continuous"
    // 时间范围违规防抖截止时间（墙上时钟 ms）：密码/按钮关闭后 3s 防抖，让 launchMainActivity 切走，
    // 防抖期过后切回受限 app 立即重新弹窗
    private var timePeriodOverrideUntil: Long = 0L
    // 时间范围违规的休息结束时间（墙上时钟 ms）：用于 handleRestState 判断休息是否结束
    // （时间范围违规可能无 continuous session，不能依赖 session.restEndTime）
    private var timePeriodRestEndTime: Long = 0L

    /**
     * Process a monitoring poll.
     * @param now Current timestamp
     * @param foregroundApp Detected foreground app package name, or null if undetected
     * @param selfAppForeground True when foregroundApp is null because our own app was detected
     *        as foreground (e.g. KeepAlive triggered AppLockOverlayActivity). This indicates
     *        the user definitely left the monitored app, so explicit leave grace is used.
     */
    fun onPoll(now: Long, foregroundApp: String?, selfAppForeground: Boolean = false) {
        // 0. REST state — check rest status and handle app leave/return
        if (state == EngineState.REST) {
            handleRestState(now, foregroundApp, selfAppForeground)
            return
        }

        // 0.5 Parent override grace period — skip monitoring for recently overridden app
        if (parentOverrideUntil > now) {
            Log.d(TAG, "onPoll: skipping — parent override grace period active (remaining=${(parentOverrideUntil - now) / 1000}s)")
            return
        }

        // 1. Check if foreground app is monitored
        val isMonitoredNow = isMonitoredApp(foregroundApp)

        if (!isMonitoredNow && state != EngineState.IDLE) {
            // If user is actively entering password in the password dialog,
            // soft keyboard may cause foregroundApp detection to return null/wrong app.
            // Skip leave detection to prevent widget/overlay flicker.
            if (overlayManager.isPasswordInputActive || NativeOverlayManager.passwordInputActivityActive) {
                Log.d(TAG, "onPoll: password input active, skipping leave detection")
                return
            }
            handleCountdownAway(now, foregroundApp, selfAppForeground)
            return
        }

        if (state == EngineState.IDLE && !isMonitoredNow) {
            // Not monitoring, nothing to do
            return
        }

        // App is back — clear any pending leave debounce
        resetPendingLeave()

        // 2. Rule evaluation (time period, total time, daily limit, forced rest)
        val ruleResult = ruleEvaluator.evaluate(foregroundApp!!, now)
        if (ruleResult.blocked) {
            val isTimePeriod = ruleResult.ruleType == "time_period"
            // 时间范围违规防抖期内：跳过监控，让 launchMainActivity 有时间切到纹纹小伙伴，
            // 避免关闭弹窗瞬间立即重弹。防抖期过后切回受限 app 立即重新弹窗。
            if (isTimePeriod && now < timePeriodOverrideUntil) {
                Log.d(TAG, "onPoll: time period dismiss debounce active (remaining=${(timePeriodOverrideUntil - now) / 1000}s), skipping")
                return
            }
            val restDuration = if (isTimePeriod) TIME_PERIOD_REST_SECONDS else null
            val violationType = if (isTimePeriod) "time_period" else "continuous"
            enterRest(ruleResult.reason, foregroundApp, now, restDuration, violationType)
            return
        }

        // 3. Continuous usage tracking
        usageTracker.updateTracking(foregroundApp, now)
        val session = repository.getActiveContinuousSession()
        val settings = repository.getContinuousUsageSettings()

        Log.d(TAG, "onPoll: state=$state, foreground=$foregroundApp, monitored=$isMonitoredNow, " +
                "enabled=${settings.enabled}, session=${session?.id}, " +
                "totalDuration=${session?.totalDurationSeconds}s, limit=${settings.limitSeconds}s, " +
                "widgetShowing=${widgetManager.isCountdownShowing()}")

        if (!settings.enabled || session == null) {
            Log.w(TAG, "onPoll: early return — enabled=${settings.enabled}, session=$session")
            return
        }

        // Calculate remaining seconds from continuous usage
        val remainingSeconds = settings.limitSeconds - session.totalDurationSeconds

        when (state) {
            EngineState.IDLE -> {
                if (remainingSeconds > 0) {
                    widgetManager.showCountdown(remainingSeconds)
                    widgetManager.updateCountdownColor(remainingSeconds)
                    usageTracker.persistCountdownState(now, remainingSeconds)
                    state = EngineState.COUNTDOWN
                    trackedApp = foregroundApp
                    Log.d(TAG, "IDLE → COUNTDOWN: $foregroundApp, remaining=${remainingSeconds}s")
                } else {
                    // 时间已用完（可能是之前会话累积），直接进入 REST
                    enterRest("连续使用时间已达限制", foregroundApp, now)
                    Log.d(TAG, "IDLE → REST: $foregroundApp, remainingSeconds=$remainingSeconds (session already exhausted)")
                }
            }
            EngineState.COUNTDOWN -> {
                val remaining = calculateCountdownRemaining(session, now)
                if (remaining <= 0) {
                    enterRest("连续使用时间已达限制", foregroundApp, now)
                } else {
                    widgetManager.updateCountdown(remaining)
                    widgetManager.updateCountdownColor(remaining)
                }
            }
            EngineState.REST -> Unit
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
            restCompleted = false
            overlayShowing = true
            resetPendingLeave()
            val remaining = (session.restEndTime!! - now) / 1000L
            overlayManager.showLockOverlay("正在休息中...", "", remaining.toInt().coerceAtLeast(0))
            Log.d(TAG, "restoreFromDB → REST, remaining=${remaining}s")
            return
        }

        // Countdown active?
        if (session.countdownStartedAt != null && session.countdownTotalSeconds != null) {
            val remaining = calculateCountdownRemaining(session, now)
            if (remaining > 0) {
                state = EngineState.COUNTDOWN
                trackedApp = trackedApp ?: repository.getMonitoredApps().firstOrNull()?.packageName
                resetPendingLeave()
                widgetManager.showCountdown(remaining)
                widgetManager.updateCountdownColor(remaining)
                Log.d(TAG, "restoreFromDB → COUNTDOWN, remaining=${remaining}s")
                return
            }
            // Countdown expired → trigger rest
            triggerRestFromExpiredCountdown(now)
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

    /**
     * Called when user manually dismisses the lock overlay (e.g. clicks "回到纹纹小伙伴" button).
     * Transitions from REST to IDLE.
     *
     * 重构（解决"关闭后立刻又弹"+问题B）：
     * - 彻底清理会话（deactivate）+ 重置 tracker（activeSession=null），
     *   使下一轮询 getOrCreateSession 新建 totalDurationSeconds=0 的会话，
     *   IDLE 分支 remainingSeconds=limitSeconds>0 → 正常进 COUNTDOWN 显示倒计时widget，不会重弹 REST。
     * - 不设置 parentOverrideUntil 宽限期（原实现设了 30s 宽限期，导致关闭后切回受限 app
     *   30s 内 widget 不显示，必须 home+重开才出 —— 正是问题B的根因）。
     */
    fun onOverlayDismissed() {
        if (state == EngineState.REST) {
            // 立即移除 view（无动画），消除 200ms 淡出窗口内按钮重复点击 / poll 竞争导致"弹窗不消失"
            overlayManager.hideOverlayImmediate()
            overlayShowing = false
            val session = repository.getActiveContinuousSession()
            if (session != null) {
                repository.deactivateContinuousSession(session.id ?: return)
            }
            usageTracker.reset()
            // 时间范围违规：按钮关闭设置 3s 防抖，让 launchMainActivity 有时间切到纹纹小伙伴，
            // 防抖期过后切回受限 app 立即重新弹窗（不再当天放行）
            if (currentViolationType == "time_period") {
                timePeriodOverrideUntil = System.currentTimeMillis() + TIME_PERIOD_DISMISS_DEBOUNCE_MS
                timePeriodRestEndTime = 0L
                Log.d(TAG, "REST → IDLE: user dismissed time_period overlay, debounce ${TIME_PERIOD_DISMISS_DEBOUNCE_MS / 1000}s")
            }
            state = EngineState.IDLE
            restCompleted = false
            resetPendingLeave()
            trackedApp = null
            currentViolationType = "continuous"
            Log.d(TAG, "REST → IDLE: user dismissed overlay (session deactivated, tracker reset)")
        }
    }

    /**
     * Called when user manually dismisses the lock overlay while on a monitored app.
     * Transitions from REST to COUNTDOWN if a valid session exists.
     */
    fun onOverlayDismissedOnMonitoredApp(packageName: String, now: Long) {
        if (state == EngineState.REST) {
            overlayManager.hideOverlayImmediate()
            overlayShowing = false
            restCompleted = false
            resetPendingLeave()
            trackedApp = null

            // 时间范围违规：在受监控 app 上关闭设置 3s 防抖，直接转 IDLE（不进入 COUNTDOWN 显示 widget）。
            // 防抖期过后切回受限 app 立即重新弹窗（不再当天放行）
            val wasTimePeriod = currentViolationType == "time_period"
            if (wasTimePeriod) {
                timePeriodOverrideUntil = System.currentTimeMillis() + TIME_PERIOD_DISMISS_DEBOUNCE_MS
                timePeriodRestEndTime = 0L
                currentViolationType = "continuous"
                state = EngineState.IDLE
                Log.d(TAG, "REST → IDLE: user dismissed time_period overlay on monitored app, debounce ${TIME_PERIOD_DISMISS_DEBOUNCE_MS / 1000}s")
                return
            }

            // 连续使用违规：检查是否能进入 COUNTDOWN 继续倒计时
            val session = repository.getActiveContinuousSession()
            val settings = repository.getContinuousUsageSettings()

            if (settings.enabled && session != null) {
                val remainingSeconds = settings.limitSeconds - session.totalDurationSeconds
                if (remainingSeconds > 0) {
                    widgetManager.showCountdown(remainingSeconds)
                    widgetManager.updateCountdownColor(remainingSeconds)
                    usageTracker.persistCountdownState(now, remainingSeconds)
                    state = EngineState.COUNTDOWN
                    trackedApp = packageName
                    Log.d(TAG, "REST → COUNTDOWN: user dismissed overlay on monitored app, remaining=${remainingSeconds}s")
                    return
                }
            }

            state = EngineState.IDLE
            Log.d(TAG, "REST → IDLE: user dismissed overlay on monitored app, no valid session")
        }
    }

    /**
     * Called when parent verifies password from the countdown widget.
     * Hides countdown, deactivates session, resets tracker, transitions to IDLE.
     * Child can continue using the app — no REST is triggered.
     * Sets a grace period to prevent immediate re-triggering for the same app.
     */
    fun onParentOverrideFromCountdown() {
        if (state == EngineState.COUNTDOWN) {
            widgetManager.hideCountdown()
            val session = repository.getActiveContinuousSession()
            if (session != null) {
                repository.deactivateContinuousSession(session.id ?: return)
            }
            usageTracker.reset()
            state = EngineState.IDLE
            resetPendingLeave()
            trackedApp = null
            // Set grace period to prevent immediate re-trigger
            parentOverrideUntil = System.currentTimeMillis() + PARENT_OVERRIDE_GRACE_MS
            Log.d(TAG, "COUNTDOWN → IDLE: parent override, session deactivated (grace=${PARENT_OVERRIDE_GRACE_MS / 1000}s)")
        }
    }

    /**
     * Called when parent verifies password from the lock overlay.
     * Hides overlay, deactivates session, resets tracker, transitions to IDLE.
     * Sets a grace period to prevent immediate re-triggering for the same app.
     */
    fun onParentOverrideFromLock() {
        if (state == EngineState.REST) {
            // Only hide overlay if it's still showing (avoid double-hide with NativeOverlayManager's own hideOverlay call)
            if (overlayShowing) {
                overlayManager.hideOverlayImmediate()
                overlayShowing = false
            }
            val session = repository.getActiveContinuousSession()
            if (session != null) {
                repository.deactivateContinuousSession(session.id ?: return)
            }
            usageTracker.reset()
            // 时间范围违规：密码关闭设置 3s 防抖，让 launchMainActivity 有时间切走，
            // 防抖期过后切回受限 app 立即重新弹窗（不再当天放行）
            if (currentViolationType == "time_period") {
                timePeriodOverrideUntil = System.currentTimeMillis() + TIME_PERIOD_DISMISS_DEBOUNCE_MS
                timePeriodRestEndTime = 0L
                Log.d(TAG, "REST → IDLE: parent override for time_period, debounce ${TIME_PERIOD_DISMISS_DEBOUNCE_MS / 1000}s")
            }
            state = EngineState.IDLE
            restCompleted = false
            resetPendingLeave()
            trackedApp = null
            currentViolationType = "continuous"
            // Set grace period to prevent immediate re-trigger
            parentOverrideUntil = System.currentTimeMillis() + PARENT_OVERRIDE_GRACE_MS
            Log.d(TAG, "REST → IDLE: parent override dismiss (grace=${PARENT_OVERRIDE_GRACE_MS / 1000}s)")
        }
    }

    // --- Private helpers ---

    private fun isMonitoredApp(app: String?): Boolean {
        if (app == null) return false
        val apps = repository.getMonitoredApps()
        return apps.any { it.packageName == app }
    }

    private fun handleCountdownAway(now: Long, foregroundApp: String?, selfAppForeground: Boolean) {
        if (state != EngineState.COUNTDOWN) {
            performLeave()
            return
        }

        if (foregroundApp == null && !selfAppForeground) {
            if (pendingUnknownSinceMs == null) {
                pendingUnknownSinceMs = now
            }
            pendingLeaveSinceMs = null
            val elapsed = now - pendingUnknownSinceMs!!
            if (elapsed >= UNKNOWN_LEAVE_GRACE_MS) {
                Log.d(TAG, "Unknown leave confirmed after ${elapsed}ms")
                performLeave()
            } else {
                Log.d(TAG, "Unknown foreground gap ${elapsed}ms/${UNKNOWN_LEAVE_GRACE_MS}ms — keeping COUNTDOWN")
            }
            return
        }

        if (pendingLeaveSinceMs == null) {
            pendingLeaveSinceMs = now
        }
        pendingUnknownSinceMs = null
        val elapsed = now - pendingLeaveSinceMs!!
        if (elapsed >= EXPLICIT_LEAVE_GRACE_MS) {
            Log.d(TAG, "Explicit leave confirmed after ${elapsed}ms, fg=$foregroundApp, self=$selfAppForeground")
            performLeave()
        } else {
            Log.d(TAG, "Explicit leave ${elapsed}ms/${EXPLICIT_LEAVE_GRACE_MS}ms — keeping COUNTDOWN")
        }
    }

    /**
     * Execute leave: hide widget, transition to IDLE, reset counters.
     * Called when leave is confirmed (either normal or null-leave).
     */
    private fun performLeave() {
        widgetManager.hideCountdown()
        state = EngineState.IDLE
        trackedApp = null
        resetPendingLeave()
        Log.d(TAG, "Leave confirmed → IDLE (widget hidden)")
    }

    private fun resetPendingLeave() {
        pendingLeaveSinceMs = null
        pendingUnknownSinceMs = null
    }

    /**
     * Handle REST state logic:
     * - If rest is still active and user left monitored app → hide overlay (user not on restricted app)
     * - If rest is still active and user is on monitored app → keep overlay (or re-show if hidden)
     * - If rest ended and user on monitored app → keep overlay (wait for manual dismiss)
     * - If rest ended and user away from monitored app → hide overlay, transition to IDLE
     */
    private fun handleRestState(now: Long, foregroundApp: String?, selfAppForeground: Boolean) {
        val isOnMonitoredApp = isMonitoredApp(foregroundApp)

        // If user is actively entering password, don't hide/show overlay based on foregroundApp changes.
        // Soft keyboard may cause foregroundApp detection to return null/wrong app.
        // Check both the overlay's internal flag and the PasswordInputActivity flag.
        if (overlayManager.isPasswordInputActive || NativeOverlayManager.passwordInputActivityActive) {
            Log.d(TAG, "REST: password input active, skipping overlay visibility change")
            return
        }

        // 时间范围违规：休息倒计时由 overlay 内部 ticker 管理（归零时自动 markRestEnded 启用按钮）
        // 不依赖 session（时间范围违规可能无 continuous session），不调用 markRestEnded（避免提前启用按钮）
        // handleRestState 只负责：用户离开受监控 app 时隐藏 overlay；用户切回时按剩余时间重新显示
        if (currentViolationType == "time_period") {
            val restStillActive = now < timePeriodRestEndTime
            if (restStillActive) {
                if (isOnMonitoredApp) {
                    resetPendingLeave()
                    // 用户在受监控 app 上 — 如果 overlay 未显示（如切后台后切回），按剩余时间重新显示
                    if (!overlayShowing && foregroundApp != null) {
                        val restRemainingSec = ((timePeriodRestEndTime - now) / 1000L).toInt().coerceAtLeast(0)
                        overlayManager.showLockOverlay("正在休息中...", foregroundApp, restRemainingSec, "time_period")
                        overlayShowing = true
                        Log.d(TAG, "REST(time_period): re-showed overlay (countdown=${restRemainingSec}s)")
                    }
                } else if (foregroundApp != null || selfAppForeground) {
                    resetPendingLeave()
                    // 用户离开受监控 app — 隐藏 overlay
                    if (overlayShowing) {
                        overlayManager.hideOverlay()
                        overlayShowing = false
                        Log.d(TAG, "REST(time_period): user left monitored app, overlay hidden")
                    }
                }
            } else {
                // 1 分钟倒计时已结束（ticker 已自动 markRestEnded 启用按钮）
                if (isOnMonitoredApp) {
                    resetPendingLeave()
                    // 用户仍在受监控 app — 调用 markRestEnded 确保按钮启用（覆盖 ticker 被取消的场景）
                    overlayManager.markRestEnded()
                    Log.d(TAG, "REST(time_period): rest ended, user on monitored app, waiting for manual dismiss")
                } else if (foregroundApp != null || selfAppForeground) {
                    resetPendingLeave()
                    // 用户已离开受监控 app — 隐藏 overlay，转 IDLE
                    if (overlayShowing) {
                        overlayManager.hideOverlay()
                        overlayShowing = false
                    }
                    state = EngineState.IDLE
                    restCompleted = false
                    trackedApp = null
                    timePeriodRestEndTime = 0L
                    currentViolationType = "continuous"
                    Log.d(TAG, "REST(time_period) → IDLE: rest ended, user away from monitored app")
                }
            }
            return
        }

        // 连续使用违规的原有逻辑
        val session = repository.getActiveContinuousSession()
        val restStillActive = session != null && session.restEndTime != null && session.restEndTime!! > now

        if (restStillActive) {
            // Rest is still counting down
            if (isOnMonitoredApp) {
                resetPendingLeave()
                // User is on monitored app — show overlay if not showing
                if (!overlayShowing) {
                    val restRemainingSec = ((session!!.restEndTime!! - now) / 1000L).toInt().coerceAtLeast(0)
                    overlayManager.showLockOverlay("正在休息中...", "", restRemainingSec)
                    overlayShowing = true
                    Log.d(TAG, "REST: re-showed overlay (countdown=${restRemainingSec}s)")
                }
            } else if (foregroundApp != null || selfAppForeground) {
                resetPendingLeave()
                // User left monitored app — hide overlay
                if (overlayShowing) {
                    overlayManager.hideOverlay()
                    overlayShowing = false
                    Log.d(TAG, "REST: user left monitored app, overlay hidden")
                }
            } else {
                Log.d(TAG, "REST: foreground unknown, keeping current overlay visibility")
            }
        } else {
            // Rest has ended
            if (!restCompleted) {
                // First poll detecting rest ended — deactivate session so next monitored-app
                // entry creates a fresh session (totalDurationSeconds from 0).
                restCompleted = true
                repository.deactivateContinuousSession(session?.id ?: return)
                usageTracker.reset()
                Log.d(TAG, "REST: rest countdown ended, session deactivated, waiting for user dismiss")
            }

            if (isOnMonitoredApp) {
                resetPendingLeave()
                // User is on monitored app — keep overlay visible (wait for manual dismiss)
                // 重构（解决⑥）：明确视觉反馈 —— 按钮转绿、文案改"可以继续啦"，让用户知道休息已结束、可手动关闭。
                // 保持 REST 状态（不转 IDLE），避免 markRestEnded 的弹窗与倒计时widget同屏。
                // 用户点按钮 → onOverlayDismissed → IDLE；用户切走 → 下方 else 分支 → IDLE。
                overlayManager.markRestEnded()
                Log.d(TAG, "REST: rest ended, user on monitored app, overlay marked rest-ended for manual dismiss")
            } else if (foregroundApp != null || selfAppForeground) {
                resetPendingLeave()
                // User left monitored app — hide overlay and transition to IDLE
                overlayManager.hideOverlay()
                overlayShowing = false
                state = EngineState.IDLE
                restCompleted = false
                trackedApp = null
                Log.d(TAG, "REST → IDLE: rest ended, user away from monitored app")
            } else {
                Log.d(TAG, "REST: rest ended but foreground unknown, waiting for explicit signal or user dismiss")
            }
        }
    }

    private fun enterRest(
        reason: String,
        packageName: String,
        now: Long,
        restDurationSeconds: Int? = null,
        violationType: String = "continuous"
    ) {
        val settings = repository.getContinuousUsageSettings()
        val restSeconds = restDurationSeconds ?: settings.restSeconds.toInt()
        val session = repository.getActiveContinuousSession()
        // 时间范围违规：不更新 session（1 分钟休息与连续使用会话无关，避免 restoreFromDB 误恢复为连续使用违规）
        if (session != null && violationType != "time_period") {
            val restEndTime = now + restSeconds * 1000L
            repository.updateContinuousSession(session.copy(
                totalDurationSeconds = settings.limitSeconds.coerceAtLeast(session.totalDurationSeconds),
                restEndTime = restEndTime,
                countdownStartedAt = null,
                countdownTotalSeconds = null,
                updatedAt = now
            ))
        }
        currentViolationType = violationType
        // 时间范围违规：记录休息结束时间（handleRestState 用它判断休息是否结束，不依赖 session）
        if (violationType == "time_period") {
            timePeriodRestEndTime = now + restSeconds * 1000L
        } else {
            timePeriodRestEndTime = 0L
        }
        widgetManager.hideCountdown()
        resetPendingLeave()
        overlayManager.showLockOverlay(reason, packageName, restSeconds, violationType)
        overlayShowing = true
        restCompleted = false
        state = EngineState.REST

        // Move the monitored app to background (same as pressing HOME)
        moveToBackground()

        Log.d(TAG, "→ REST: $reason, restSeconds=$restSeconds, violationType=$violationType")
    }

    /**
     * 倒计时归零回调入口 —— 由 WidgetManager 在 ticker 归零瞬间调用（通过 MonitorForegroundService 注入）。
     *
     * 解决①：原实现 widget 的 onEnded 为空，REST 完全靠 5s 轮询的 COUNTDOWN 分支检测 remaining<=0 触发，
     * 导致 widget 卡在 0:00 最多 5s 才弹禁用窗。现在归零瞬间立刻进入 REST，消除空窗。
     *
     * 幂等：若状态已不是 COUNTDOWN（例如已被轮询触发），直接返回，避免重复 enterRest。
     */
    fun onCountdownZero() {
        if (state != EngineState.COUNTDOWN) {
            Log.d(TAG, "onCountdownZero: ignored, state=$state (not COUNTDOWN)")
            return
        }
        val now = System.currentTimeMillis()
        val pkg = trackedApp ?: return
        enterRest("连续使用时间已达限制", pkg, now)
    }

    private fun triggerRestFromExpiredCountdown(now: Long) {
        val settings = repository.getContinuousUsageSettings()
        val session = repository.getActiveContinuousSession() ?: return
        val restEndTime = now + settings.restSeconds * 1000L
        repository.updateContinuousSession(session.copy(
            totalDurationSeconds = settings.limitSeconds.coerceAtLeast(session.totalDurationSeconds),
            restEndTime = restEndTime,
            countdownStartedAt = null,
            countdownTotalSeconds = null,
            updatedAt = now
        ))
        state = EngineState.REST
        restCompleted = false
        overlayShowing = true
        resetPendingLeave()
        overlayManager.showLockOverlay("正在休息中...", "", settings.restSeconds.toInt())

        // Move the monitored app to background
        moveToBackground()

        Log.d(TAG, "restoreFromDB → countdown expired, entering REST")
    }

    private fun calculateCountdownRemaining(session: NativeRuleRepository.ContinuousSession, now: Long): Long {
        val startedAt = session.countdownStartedAt
        val totalSeconds = session.countdownTotalSeconds
        if (startedAt == null || totalSeconds == null) {
            val fallback = repository.getContinuousUsageSettings().limitSeconds - session.totalDurationSeconds
            return fallback.coerceAtLeast(0)
        }
        val elapsedSeconds = ((now - startedAt).coerceAtLeast(0)) / 1000L
        return (totalSeconds - elapsedSeconds).coerceAtLeast(0)
    }

    /**
     * Send HOME intent to move the current app to background.
     * Equivalent to pressing the HOME button.
     * Visible for testing — can be overridden in tests.
     */
    fun moveToBackground() {
        try {
            val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_HOME)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            context.startActivity(homeIntent)
            Log.d(TAG, "Moved app to background via HOME intent")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to move app to background", e)
        }
    }
}
