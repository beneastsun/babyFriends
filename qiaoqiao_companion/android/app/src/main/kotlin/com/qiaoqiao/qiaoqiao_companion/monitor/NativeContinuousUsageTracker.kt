package com.qiaoqiao.qiaoqiao_companion.monitor

import android.util.Log
import com.qiaoqiao.qiaoqiao_companion.monitor.NativeRuleRepository.ContinuousSession
import com.qiaoqiao.qiaoqiao_companion.monitor.NativeRuleRepository.ContinuousUsageSettings
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * 原生连续使用跟踪器
 *
 * 在 Flutter 引擎死亡时跟踪监控应用的连续使用时间，触发倒计时和强制休息。
 * 复刻自 Flutter 端 [ContinuousUsageService]。
 *
 * 跟踪逻辑：
 * 1. 每5s轮询时调用 [updateTracking]
 * 2. 如果前台是监控应用，累加连续使用时间
 * 3. 状态机根据 session 数据决定是否显示/更新倒计时
 * 4. 切换到非监控应用超过阈值时，停用会话
 *
 * 重构说明（单一时间源）：
 * - 本类的秒累加（totalDurationSeconds）现在**仅作为 REST 触发的兜底判据**，
 *   以及进程重启后恢复会话的持久化数据。
 * - widget 上显示的倒计时数值、颜色阈值切换，统一由 wall-clock 单一源驱动
 *   （NativeOverlayManager 的 countdownEndTimeMs + EnforcementEngine 读 DB 的
 *   countdownStartedAt/countdownTotalSeconds），不再以本类的累加值为权威显示值。
 * - 这样消除了"轮询累加"与"widget 自走倒计时"两套时间源漂移导致的计时不准与整秒抖动。
 * - Doze/省电下轮询延迟导致累加漏计，只会让 REST 触发略晚（最多 5s），但 widget
 *   显示始终精确，因为 widget 走的是 System.currentTimeMillis()。
 */
class NativeContinuousUsageTracker(
    private val repository: NativeRuleRepository
) {

    companion object {
        private const val TAG = "NativeContinuousTracker"
        private const val RESTORE_THRESHOLD_MINUTES = 5 // 5分钟内切回算连续
    }

    // 当前跟踪的应用包名
    private var currentTrackedApp: String? = null
    // 当前活跃会话（从 DB 加载）
    private var activeSession: ContinuousSession? = null
    // 上次轮询时间
    private var lastPollTime: Long = 0L
    // 暂停开始时间（切换到非监控应用时记录）
    private var pauseStartTime: Long = 0L
    // 当前设置缓存
    private var cachedSettings: ContinuousUsageSettings? = null
    // 设置缓存时间
    private var settingsCacheTime: Long = 0L
    private val SETTINGS_CACHE_TTL_MS = 30_000L

    /**
     * 更新跟踪状态（每5s由 monitorRunnable 调用）
     *
     * @param packageName 当前前台应用包名
     * @param now 当前时间戳
     * @return 跟踪结果，仅表达会话事实，不表达 UI 决策
     */
    fun updateTracking(packageName: String, now: Long): TrackingResult {
        val settings = getSettings()
        if (!settings.enabled) {
            return TrackingResult.noop()
        }

        val monitoredApps = repository.getMonitoredApps()
        val appMonitored = monitoredApps.any { it.packageName == packageName }

        return if (appMonitored) {
            handleMonitoredApp(packageName, now, settings)
        } else {
            handleNonMonitoredApp(now, settings)
        }
    }

    /**
     * 处理监控应用在前台的情况
     */
    private fun handleMonitoredApp(packageName: String, now: Long, settings: ContinuousUsageSettings): TrackingResult {
        // 重置暂停状态
        pauseStartTime = 0L

        val session = getOrCreateSession(now)

        if (currentTrackedApp != null && currentTrackedApp != packageName) {
            // 切换到不同的监控应用，重置但不结束会话
            Log.d(TAG, "Switched from $currentTrackedApp to $packageName - keeping session")
            currentTrackedApp = packageName
            lastPollTime = now
            return TrackingResult.noop()
        }

        // 首次跟踪或恢复跟踪
        if (currentTrackedApp == null) {
            currentTrackedApp = packageName
            lastPollTime = now

            // 检查是否需要恢复之前暂停的会话（5分钟内）
            if (session != null && session.isActive) {
                val inactiveDuration = if (session.lastActivityTime != null) {
                    (now - session.lastActivityTime) / 1000
                } else 0L
                if (inactiveDuration < RESTORE_THRESHOLD_MINUTES * 60L) {
                    Log.d(TAG, "Resumed session, remaining: ${settings.limitSeconds - session.totalDurationSeconds}s")
                    return TrackingResult.resume(settings.limitSeconds - session.totalDurationSeconds)
                }
            }
            return TrackingResult.noop()
        }

        // 正常累加时间
        if (lastPollTime > 0) {
            val elapsedSeconds = (now - lastPollTime) / 1000
            if (elapsedSeconds > 0 && elapsedSeconds < 30) {
                activeSession?.let { sess ->
                    val updatedDuration = sess.totalDurationSeconds + elapsedSeconds
                    val updatedSession = sess.copy(
                        totalDurationSeconds = updatedDuration,
                        lastActivityTime = now,
                        updatedAt = now
                    )
                    repository.updateContinuousSession(updatedSession)
                    activeSession = updatedSession
                    Log.d(TAG, "Accumulated ${elapsedSeconds}s, total=${updatedDuration}s")
                }
            }
        }

        lastPollTime = now

        // 计算剩余时间并返回结果
        val sessionDuration = activeSession?.totalDurationSeconds ?: 0L
        val remainingSeconds = settings.limitSeconds - sessionDuration

        if (remainingSeconds <= 0) {
            return TrackingResult.limitReached()
        }

        return TrackingResult.active(remainingSeconds)
    }

    /**
     * 处理非监控应用（或没有前台应用）的情况
     */
    private fun handleNonMonitoredApp(now: Long, settings: ContinuousUsageSettings): TrackingResult {
        if (currentTrackedApp != null) {
            if (pauseStartTime == 0L) {
                pauseStartTime = now
                Log.d(TAG, "Paused tracking, current app left: $currentTrackedApp")
            } else {
                val pausedSeconds = (now - pauseStartTime) / 1000
                if (pausedSeconds >= settings.resetAfterRestSeconds) {
                    // 超过阈值，停用会话
                    activeSession?.let {
                        if (it.isActive) {
                            repository.deactivateContinuousSession(it.id ?: return TrackingResult.noop())
                            Log.d(TAG, "Session deactivated after ${pausedSeconds}s pause")
                        }
                    }
                    reset()
                    return TrackingResult.deactivated()
                }
            }
        }
        return TrackingResult.noop()
    }

    /**
     * 获取或创建今日活跃会话
     *
     * 跨日期处理：如果内存缓存的 session 是昨天的，停用旧 session 并创建今日新 session。
     * 这确保 DB 查询 `session_date = today` 总能命中，且计时从 0 重新开始。
     */
    private fun getOrCreateSession(now: Long): ContinuousSession? {
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())

        // 检查内存缓存的 session 是否过期（跨日期）
        if (activeSession != null && activeSession!!.isActive) {
            if (activeSession!!.sessionDate == today) {
                return activeSession
            }
            // 跨日期：停用旧 session，重置 tracker 状态，下一轮创建新 session
            Log.w(TAG, "Session date crossed: ${activeSession!!.sessionDate} → $today, deactivating old session")
            repository.deactivateContinuousSession(activeSession!!.id ?: run {
                activeSession = null
                currentTrackedApp = null
                lastPollTime = 0L
                return null
            })
            activeSession = null
            currentTrackedApp = null
            lastPollTime = 0L
            // 继续走下面的 DB 查询 + 创建逻辑
        }

        // 从 DB 加载今日活跃 session
        var session = repository.getActiveContinuousSession()
        if (session != null) {
            activeSession = session
            return session
        }

        // 创建今日新会话
        session = ContinuousSession(
            sessionDate = today,
            startTime = now,
            createdAt = now,
            updatedAt = now
        )
        val id = repository.insertContinuousSession(session)
        if (id != null) {
            activeSession = session.copy(id = id)
            Log.d(TAG, "Created new session: id=$id")
            return activeSession
        }

        return null
    }

    /**
     * 重置跟踪状态
     */
    fun reset() {
        currentTrackedApp = null
        activeSession = null
        lastPollTime = 0L
        pauseStartTime = 0L
        cachedSettings = null  // 清除缓存，下次 getSettings() 从 DB/SP 读取最新值
        Log.d(TAG, "Tracking reset")
    }

    /**
     * 获取当前剩余连续使用时间（秒）
     */
    fun getRemainingSeconds(): Long {
        val session = activeSession ?: return 0L
        return (getSettings().limitSeconds - session.totalDurationSeconds).coerceAtLeast(0)
    }

    /**
     * 获取当前被跟踪的应用
     */
    fun getCurrentTrackedApp(): String? = currentTrackedApp

    /**
     * 获取活跃会话
     */
    fun getActiveSession(): ContinuousSession? = activeSession

    /**
     * 获取当前设置（带缓存）
     */
    fun getSettings(): ContinuousUsageSettings {
        val now = System.currentTimeMillis()
        if (cachedSettings != null && (now - settingsCacheTime) < SETTINGS_CACHE_TTL_MS) {
            return cachedSettings!!
        }
        cachedSettings = repository.getContinuousUsageSettings()
        settingsCacheTime = now
        return cachedSettings!!
    }

    /**
     * 标记倒计时已隐藏（当用户离开监控应用时）
     */
    fun onCountdownHidden() = Unit

    /**
     * Persist countdown state to DB so engine can recover after process death.
     * Writes countdownStartedAt (wall-clock ms) and countdownTotalSeconds.
     */
    fun persistCountdownState(now: Long, remainingSeconds: Long) {
        val session = activeSession ?: repository.getActiveContinuousSession() ?: return
        val updated = session.copy(
            countdownStartedAt = now,
            countdownTotalSeconds = remainingSeconds,
            updatedAt = now
        )
        repository.updateContinuousSession(updated)
        activeSession = updated
        Log.d(TAG, "Persisted countdown: startedAt=$now, total=${remainingSeconds}s")
    }

    /**
     * 延长当前倒计时（积分兑换加时后调用）
     * 更新 continuous_usage_sessions.countdown_total_seconds 并持久化
     */
    fun extendCountdown(extraSeconds: Long) {
        val session = activeSession ?: repository.getActiveContinuousSession() ?: return
        val now = System.currentTimeMillis()
        val currentTotal = session.countdownTotalSeconds ?: 0L
        val newTotal = currentTotal + extraSeconds
        val updated = session.copy(
            countdownTotalSeconds = newTotal,
            updatedAt = now
            // 不重置 countdownStartedAt，保持剩余时间 = (total + extra) - elapsed = currentRemaining + extra
        )
        repository.updateContinuousSession(updated)
        activeSession = updated
        Log.d(TAG, "Countdown extended: +${extraSeconds}s, newTotal=${newTotal}s")
    }

    /**
     * 跟踪结果
     */
    data class TrackingResult(
        val action: TrackingAction,
        val remainingSeconds: Long = 0L
    ) {
        companion object {
            fun noop() = TrackingResult(TrackingAction.NONE)
            fun resume(remaining: Long) = TrackingResult(TrackingAction.RESUME, remaining.coerceAtLeast(0))
            fun active(remaining: Long) = TrackingResult(TrackingAction.ACTIVE, remaining.coerceAtLeast(0))
            fun limitReached() = TrackingResult(TrackingAction.LIMIT_REACHED)
            fun deactivated() = TrackingResult(TrackingAction.DEACTIVATED)
        }

        val isActive: Boolean get() = action == TrackingAction.ACTIVE
        val isLimitReached: Boolean get() = action == TrackingAction.LIMIT_REACHED
    }

    enum class TrackingAction {
        NONE,
        RESUME,
        ACTIVE,
        LIMIT_REACHED,
        DEACTIVATED
    }
}
