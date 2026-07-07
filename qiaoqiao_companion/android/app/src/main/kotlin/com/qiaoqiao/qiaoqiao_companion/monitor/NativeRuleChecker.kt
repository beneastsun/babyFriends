package com.qiaoqiao.qiaoqiao_companion.monitor

import android.util.Log
import com.qiaoqiao.qiaoqiao_companion.monitor.NativeRuleRepository.ContinuousSession
import org.json.JSONArray
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * 原生规则检查器
 * 在 Flutter 引擎死亡时仍能检查规则并阻止被限制的 App
 *
 * 检查优先级（复刻自 Flutter 端 RuleCheckerService）：
 * 1. 该 App 是否在受监控列表中？不在 → 允许
 * 2. 当前时间是否在 blocked 时间段内？是 → 阻止
 * 3. 如果有 allowed 时间段，当前是否不在任何允许段内？否 → 阻止
 * 4. 总时间限制：所有受监控 App 今日总使用时间 >= 限制？是 → 阻止
 * 5. 单 App 每日限制：该 App 今日使用时间 >= daily_limit_minutes？是 → 阻止
 */
class NativeRuleChecker(private val repository: NativeRuleRepository) {

    companion object {
        private const val TAG = "NativeRuleChecker"
    }

    /**
     * 检查结果
     */
    data class CheckResult(
        val blocked: Boolean,
        val reason: String,
        val ruleType: String = "",
        /** -1 = 无倒计时，>0 = 需要显示倒计时，值为剩余秒数 */
        val countdownSeconds: Long = -1L
    ) {
        val needsCountdown: Boolean get() = countdownSeconds > 0
    }

    /**
     * 连续使用检查结果（stateless，每次从 DB 读取）
     */
    data class ContinuousUsageResult(
        val action: ContinuousUsageAction = ContinuousUsageAction.NONE,
        val remainingSeconds: Long = 0L
    ) {
        companion object {
            fun none() = ContinuousUsageResult()
            fun showCountdown(remaining: Long) = ContinuousUsageResult(ContinuousUsageAction.SHOW_COUNTDOWN, remaining)
            fun updateCountdown(remaining: Long) = ContinuousUsageResult(ContinuousUsageAction.UPDATE_COUNTDOWN, remaining)
            fun triggerRest() = ContinuousUsageResult(ContinuousUsageAction.TRIGGER_REST)
            fun restActive(remaining: Long) = ContinuousUsageResult(ContinuousUsageAction.REST_ACTIVE, remaining)
        }

        val shouldShowCountdown: Boolean get() = action == ContinuousUsageAction.SHOW_COUNTDOWN
        val shouldUpdateCountdown: Boolean get() = action == ContinuousUsageAction.UPDATE_COUNTDOWN
        val isRestTriggered: Boolean get() = action == ContinuousUsageAction.TRIGGER_REST
        val isRestActive: Boolean get() = action == ContinuousUsageAction.REST_ACTIVE
    }

    enum class ContinuousUsageAction {
        NONE,
        SHOW_COUNTDOWN,
        UPDATE_COUNTDOWN,
        TRIGGER_REST,
        REST_ACTIVE
    }

    // 缓存受监控应用列表（每30秒刷新一次）
    private var cachedMonitoredApps: List<NativeRuleRepository.MonitoredApp>? = null
    private var cachedMonitoredPackages: Set<String>? = null
    private var lastCacheTime: Long = 0
    private val CACHE_TTL_MS = 30_000L // 30秒缓存

    /**
     * 检查指定应用是否应该被阻止
     *
     * @param packageName 前台应用包名
     * @return CheckResult
     */
    fun checkApp(packageName: String, now: Long = System.currentTimeMillis()): CheckResult {
        val restRemainingSeconds = repository.getActiveRestRemainingSeconds()
        if (restRemainingSeconds > 0) {
            return CheckResult(true, "正在休息中，还需要 ${formatRemainingTime(restRemainingSeconds)}", "forced_rest")
        }

        // 1. 检查是否在受监控列表中
        val monitoredApps = getMonitoredApps()
        val monitoredApp = monitoredApps.find { it.packageName == packageName }
        if (monitoredApp == null) {
            return CheckResult(false, "")
        }

        Log.d(TAG, "Checking monitored app: $packageName, dailyLimit=${monitoredApp.dailyLimitMinutes}")

        // 2. 检查时间段规则
        val timeResult = checkTimePeriods()
        if (timeResult != null) {
            Log.d(TAG, "App $packageName blocked by time period: ${timeResult.reason}")
            return timeResult
        }

        // 3. 检查总时间限制
        val totalTimeResult = checkTotalTimeLimit(monitoredApps.map { it.packageName }.toSet())
        if (totalTimeResult != null) {
            Log.d(TAG, "App $packageName blocked by total time: ${totalTimeResult.reason}")
            return totalTimeResult
        }

        // 4. 检查单 App 每日限制
        if (monitoredApp.dailyLimitMinutes != null && monitoredApp.dailyLimitMinutes > 0) {
            val appUsageMs = repository.getTodayAppUsageMs(packageName)
            val appUsageMinutes = appUsageMs / 60_000
            Log.d(TAG, "App $packageName usage: ${appUsageMinutes}min / limit ${monitoredApp.dailyLimitMinutes}min")
            if (appUsageMinutes >= monitoredApp.dailyLimitMinutes) {
                Log.d(TAG, "App $packageName blocked by daily limit")
                return CheckResult(true, "今日使用已达上限（${monitoredApp.dailyLimitMinutes}分钟）")
            }
        }

        // 5. 连续使用检查（与禁止时段/总时间限制相同的 DB 读取路径）
        val countdownResult = checkContinuousCountdown(packageName, now)
        if (countdownResult != null) return countdownResult

        Log.d(TAG, "App $packageName allowed (no rule violation)")
        return CheckResult(false, "")
    }

    /**
     * 连续使用 → 倒计时/强制休息检查
     *
     * 与 checkApp 的其它检查（时间段/总时间）使用相同的 stateless DB 读取模式，
     * 每次从 [NativeRuleRepository] 读取连续使用设置和活跃会话，计算剩余时间并决策。
     *
     * 主路径：如果 Flutter 侧已经写入了 countdown_started_at / countdown_total_seconds，
     * 则按挂钟算术恢复剩余时间，避免 coerceIn(1,30) 累加在服务重启间隔内严重失准的问题。
     *
     * 兜底路径：若两列为空（纯原生追踪场景），使用原增量累加逻辑。
     *
     * @return 需要倒计时的 CheckResult，或 null（无需操作）
     */
    private fun checkContinuousCountdown(packageName: String, now: Long): CheckResult? {
        val settings = repository.getContinuousUsageSettings()
        if (!settings.enabled) return null

        if (!repository.isMonitored(packageName)) return null

        val restRemaining = repository.getActiveRestRemainingSeconds()
        if (restRemaining > 0) return null // 强制休息由 checkApp 开头的 rest 分支处理

        var session = repository.getActiveContinuousSession()
        if (session == null) {
            // Flutter 死亡且无活跃session → 创建新session
            // 场景：Flutter 被杀前还没来得及创建 session（如刚打开监控 app 就被划掉）
            if (com.qiaoqiao.qiaoqiao_companion.MainActivity.isFlutterAlive) {
                return null // Flutter 存活时由 Flutter 侧创建 session
            }
            val today = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
            session = ContinuousSession(
                sessionDate = today,
                startTime = now,
                lastActivityTime = now,
                createdAt = now,
                updatedAt = now
            )
            val id = repository.insertContinuousSession(session)
            if (id == null) return null
            session = session.copy(id = id)
            Log.d(TAG, "Created new session in native fallback: id=$id")
        }

        // ===== 预检：会话有已过期的 restEndTime → 休息已结束 =====
        // Flutter 侧的 checkRestEnded() 可能在异步提交中，原生侧先读取到旧数据。
        // 此时不应使用旧倒计时数据触发新的强制休息，而是清理倒计时字段并返回 null，
        // 让 Flutter 侧处理会话解激活。
        if (session.restEndTime != null && session.restEndTime!! <= now) {
            if (session.countdownStartedAt != null || session.countdownTotalSeconds != null) {
                repository.updateContinuousSession(session.copy(
                    countdownStartedAt = null,
                    countdownTotalSeconds = null,
                    updatedAt = now
                ))
                Log.d(TAG, "Cleared stale countdown state after rest ended")
            }
            return null
        }

        // ===== 主路径：根据持久化的倒计时状态按挂钟恢复 =====
        val startedAt = session.countdownStartedAt
        val totalSec = session.countdownTotalSeconds
        if (startedAt != null && totalSec != null) {
            val endMs = startedAt + totalSec * 1000L
            val remaining = ((endMs - now) / 1000L).coerceAtLeast(0L)

            if (remaining <= 0) {
                // 倒计时已过期 → 清空倒计时字段并触发强制休息
                val restEndTime = now + settings.restSeconds * 1000L
                repository.updateContinuousSession(session.copy(
                    totalDurationSeconds = settings.limitSeconds.coerceAtLeast(session.totalDurationSeconds),
                    restEndTime = restEndTime,
                    countdownStartedAt = null,
                    countdownTotalSeconds = null,
                    updatedAt = now
                ))
                Log.d(TAG, "Countdown expired (wall-clock), forced rest until $restEndTime")
                return CheckResult(
                    true,
                    "正在休息中，还需要 ${formatRemainingTime(settings.restSeconds)}",
                    "forced_rest"
                )
            }

            Log.d(TAG, "Countdown resume (wall-clock): remaining=${remaining}s (startedAt=$startedAt, total=$totalSec)")
            return CheckResult(false, "", "continuous_countdown", remaining)
        }

        // ===== 兜底路径：原增量累加逻辑 =====
        // Flutter 存活时不走此路径（避免双写争用，仅当进程重启后 Flutter 引擎死亡时启用）
        if (com.qiaoqiao.qiaoqiao_companion.MainActivity.isFlutterAlive) {
            Log.d(TAG, "Fallback skip: Flutter is alive")
            return null
        }

        val lastActivity = session.lastActivityTime ?: return null

        // 累计时间
        // 服务重启后的首次累加：使用完整的 gap（但不超过重置阈值）
        // 后续正常轮询（5秒间隔）：使用 coerceIn(1, 30) 的保守值
        val inactiveGapSeconds = ((now - lastActivity) / 1000L).coerceAtLeast(0L)
        val elapsedSeconds = if (inactiveGapSeconds > 30) {
            // 大 gap = 服务刚重启，补上完整间隔（不超过 resetAfterRestSeconds）
            inactiveGapSeconds.coerceIn(1L, settings.resetAfterRestSeconds)
        } else {
            // 正常轮询间隔，保守累加
            inactiveGapSeconds.coerceIn(1L, 30L)
        }
        val updatedSession = session.copy(
            totalDurationSeconds = session.totalDurationSeconds + elapsedSeconds,
            lastActivityTime = now,
            updatedAt = now
        )
        repository.updateContinuousSession(updatedSession)
        session = updatedSession

        val remainingSeconds = settings.limitSeconds - session.totalDurationSeconds
        Log.d(TAG, "Continuous: ${session.totalDurationSeconds}s used, ${remainingSeconds}s remaining")

        if (remainingSeconds <= 0) {
            // 已有已过期的强制休息 → 刚结束休息，停用会话防死循环
            if (session.restEndTime != null && session.restEndTime!! > 0 && session.restEndTime!! <= now) {
                repository.updateContinuousSession(session.copy(isActive = false, updatedAt = now))
                Log.d(TAG, "Rest ended, session deactivated")
                return null
            }
            // 触发强制休息
            val restEndTime = now + settings.restSeconds * 1000L
            repository.updateContinuousSession(session.copy(
                totalDurationSeconds = settings.limitSeconds.coerceAtLeast(session.totalDurationSeconds),
                restEndTime = restEndTime,
                updatedAt = now
            ))
            Log.d(TAG, "Rest triggered, ends in ${settings.restMinutes}min")
            return CheckResult(true, "正在休息中，还需要 ${formatRemainingTime(settings.restSeconds)}", "forced_rest")
        }

        if (remainingSeconds <= 300 && remainingSeconds < settings.limitSeconds) {
            return CheckResult(false, "", "continuous_countdown", remainingSeconds)
        }

        return null
    }

    /**
     * 检查时间段规则
     * @return 如果被阻止返回 CheckResult，否则返回 null
     */
    private fun checkTimePeriods(): CheckResult? {
        val periods = repository.getTimePeriods()
        if (periods.isEmpty()) {
            Log.d(TAG, "No time periods configured")
            return null
        }

        val currentTime = repository.getCurrentTimeStr()
        val dayOfWeek = repository.getDayOfWeek()
        Log.d(TAG, "Checking time periods: currentTime=$currentTime, dayOfWeek=$dayOfWeek, periods=${periods.size}")

        // 分离 blocked 和 allowed 类型的规则
        val blockedPeriods = periods.filter { it.mode == "blocked" }
        val allowedPeriods = periods.filter { it.mode == "allowed" }

        // 先检查 blocked 时间段
        for (period in blockedPeriods) {
            if (isDayMatch(period.days, dayOfWeek) && isTimeInRange(currentTime, period.timeStart, period.timeEnd)) {
                return CheckResult(true, "当前是禁止使用时段（${period.timeStart}-${period.timeEnd}）")
            }
        }

        // 再检查 allowed 时间段
        if (allowedPeriods.isNotEmpty()) {
            var inAnyAllowed = false
            for (period in allowedPeriods) {
                if (isDayMatch(period.days, dayOfWeek) && isTimeInRange(currentTime, period.timeStart, period.timeEnd)) {
                    inAnyAllowed = true
                    break
                }
            }
            if (!inAnyAllowed) {
                return CheckResult(true, "当前不在允许使用时段内")
            }
        }

        return null
    }

    /**
     * 检查总时间限制
     * @return 如果被阻止返回 CheckResult，否则返回 null
     */
    private fun checkTotalTimeLimit(monitoredPackages: Set<String>): CheckResult? {
        val totalTimeRule = repository.getTotalTimeRule()
        if (totalTimeRule == null) {
            Log.d(TAG, "No total time rule configured")
            return null
        }

        val isWeekend = repository.isWeekend()
        val baseLimitMinutes = if (isWeekend) {
            totalTimeRule.weekendLimit ?: return null
        } else {
            totalTimeRule.weekdayLimit ?: return null
        }

        // 应用日限额调整（加时券/任务惩罚）
        val adjustmentMinutes = repository.getDailyAdjustmentMinutes()
        val limitMinutes = (baseLimitMinutes + adjustmentMinutes).coerceIn(0, 480)

        if (limitMinutes <= 0) {
            return CheckResult(true, "昨日有未完成的任务，今日使用时长已被扣减")
        }

        val totalUsageMs = repository.getTodayTotalUsageMs(monitoredPackages)
        val totalUsageMinutes = totalUsageMs / 60_000
        Log.d(TAG, "Total time: ${totalUsageMinutes}min / ${limitMinutes}min (weekend=$isWeekend)")

        if (totalUsageMinutes >= limitMinutes) {
            return CheckResult(true, "今日总使用时间已达上限（${limitMinutes}分钟）")
        }

        return null
    }

    private fun formatRemainingTime(seconds: Long): String {
        val minutes = seconds / 60
        val remainingSeconds = seconds % 60
        return if (minutes > 0) "${minutes}分${remainingSeconds}秒" else "${remainingSeconds}秒"
    }

    /**
     * 判断当前星期几是否匹配规则中的天数
     * 支持两种格式：
     * - 逗号分隔: "1,2,3,4,5"（1=周日, 2=周一, ..., 7=周六，对应 Calendar 常量）
     * - JSON 数组: "[1,2,3,4,5]"
     *
     * @param daysStr 天数字符串
     * @param dayOfWeek Calendar.DAY_OF_WEEK 值
     */
    private fun isDayMatch(daysStr: String, dayOfWeek: Int): Boolean {
        return try {
            val days = if (daysStr.startsWith("[")) {
                // JSON 数组格式: "[1,2,3,4,5]"
                val arr = JSONArray(daysStr)
                (0 until arr.length()).map { arr.getInt(it) }
            } else {
                // 逗号分隔格式: "1,2,3,4,5"
                daysStr.split(",").map { it.trim().toInt() }
            }
            days.contains(dayOfWeek)
        } catch (e: Exception) {
            // 如果解析失败，默认匹配所有天
            Log.w(TAG, "Failed to parse days: $daysStr", e)
            true
        }
    }

    /**
     * 判断当前时间是否在指定范围内
     * @param currentTime "HH:mm" 格式
     * @param start "HH:mm" 格式
     * @param end "HH:mm" 格式
     */
    private fun isTimeInRange(currentTime: String, start: String, end: String): Boolean {
        return try {
            val current = timeToMinutes(currentTime)
            val startMin = timeToMinutes(start)
            val endMin = timeToMinutes(end)

            if (startMin <= endMin) {
                // 正常范围，如 08:00-18:00
                current in startMin..endMin
            } else {
                // 跨午夜范围，如 22:00-06:00
                current >= startMin || current <= endMin
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to parse time range: $start-$end", e)
            false
        }
    }

    /**
     * 将 "HH:mm" 转换为当天的分钟数
     */
    private fun timeToMinutes(time: String): Int {
        val parts = time.split(":")
        return parts[0].toInt() * 60 + parts[1].toInt()
    }

    /**
     * 获取受监控应用列表（带缓存）
     */
    private fun getMonitoredApps(): List<NativeRuleRepository.MonitoredApp> {
        val now = System.currentTimeMillis()
        if (cachedMonitoredApps != null && (now - lastCacheTime) < CACHE_TTL_MS) {
            return cachedMonitoredApps!!
        }

        cachedMonitoredApps = repository.getMonitoredApps()
        cachedMonitoredPackages = cachedMonitoredApps!!.map { it.packageName }.toSet()
        lastCacheTime = now
        Log.d(TAG, "Refreshed monitored apps cache: ${cachedMonitoredApps!!.size} apps")
        return cachedMonitoredApps!!
    }

    /**
     * 清除缓存（在服务销毁时调用）
     */
    fun clearCache() {
        cachedMonitoredApps = null
        cachedMonitoredPackages = null
        lastCacheTime = 0
    }
}
