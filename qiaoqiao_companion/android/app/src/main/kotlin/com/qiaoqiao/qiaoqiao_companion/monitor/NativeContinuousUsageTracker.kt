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
 * 3. 剩余时间 <= 5min 时，通过回调触发显示倒计时悬浮窗
 * 4. 剩余时间 <= 0 时，触发强制休息（写 DB rest_end_time）
 * 5. 切换到非监控应用超过阈值时，停用会话
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

    // 提醒是否已显示（避免每5s重复触发）
    private var countdownShown: Boolean = false
    // 当前显示的剩余秒数
    private var currentRemainingSeconds: Long = 0L

    /**
     * 更新跟踪状态（每5s由 monitorRunnable 调用）
     *
     * @param packageName 当前前台应用包名
     * @param now 当前时间戳
     * @return true 如果当前应用需要显示/更新倒计时
     */
    fun updateTracking(packageName: String, now: Long): TrackingResult {
        val settings = getSettings()
        if (!settings.enabled) {
            return TrackingResult.noop()
        }

        val isMonitored = repository.isMonitored(packageName)
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
                    return TrackingResult.resume()
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
        currentRemainingSeconds = remainingSeconds.coerceAtLeast(0)

        if (remainingSeconds <= 0) {
            // 时间到，触发强制休息
            triggerRest(settings)
            return TrackingResult.restTriggered(0)
        }

        if (remainingSeconds <= 5 * 60 && !countdownShown) {
            countdownShown = true
            return TrackingResult.showCountdown(remainingSeconds)
        }

        // 倒计时已经在显示，更新剩余时间
        if (countdownShown) {
            return TrackingResult.updateCountdown(remainingSeconds)
        }

        return TrackingResult.noop()
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
     */
    private fun getOrCreateSession(now: Long): ContinuousSession? {
        if (activeSession != null && activeSession!!.isActive) {
            return activeSession
        }

        // 从 DB 加载
        var session = repository.getActiveContinuousSession()
        if (session != null) {
            activeSession = session
            return session
        }

        // 创建新会话
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
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
     * 触发强制休息
     */
    private fun triggerRest(settings: ContinuousUsageSettings) {
        val now = System.currentTimeMillis()
        val restEndTime = now + settings.restSeconds * 1000L

        activeSession?.let { sess ->
            val updatedSession = sess.copy(
                totalDurationSeconds = settings.limitSeconds.coerceAtLeast(sess.totalDurationSeconds),
                lastActivityTime = now,
                restEndTime = restEndTime,
                updatedAt = now
            )
            repository.updateContinuousSession(updatedSession)
            activeSession = updatedSession
        }
        Log.d(TAG, "Rest triggered, ends in ${settings.restMinutes}min")
        countdownShown = false
    }

    /**
     * 重置跟踪状态
     */
    fun reset() {
        currentTrackedApp = null
        activeSession = null
        lastPollTime = 0L
        pauseStartTime = 0L
        countdownShown = false
        currentRemainingSeconds = 0L
        Log.d(TAG, "Tracking reset")
    }

    /**
     * 获取当前剩余连续使用时间（秒）
     */
    fun getRemainingSeconds(): Long = currentRemainingSeconds

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
    fun onCountdownHidden() {
        countdownShown = false
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
            fun resume() = TrackingResult(TrackingAction.RESUME)
            fun showCountdown(remaining: Long) = TrackingResult(TrackingAction.SHOW_COUNTDOWN, remaining)
            fun updateCountdown(remaining: Long) = TrackingResult(TrackingAction.UPDATE_COUNTDOWN, remaining)
            fun restTriggered(remaining: Long) = TrackingResult(TrackingAction.REST_TRIGGERED, remaining)
            fun deactivated() = TrackingResult(TrackingAction.DEACTIVATED)
        }

        val shouldShowCountdown: Boolean get() = action == TrackingAction.SHOW_COUNTDOWN
        val shouldUpdateCountdown: Boolean get() = action == TrackingAction.UPDATE_COUNTDOWN
        val isRestTriggered: Boolean get() = action == TrackingAction.REST_TRIGGERED
    }

    enum class TrackingAction {
        NONE,
        RESUME,
        SHOW_COUNTDOWN,
        UPDATE_COUNTDOWN,
        REST_TRIGGERED,
        DEACTIVATED
    }
}
