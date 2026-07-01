package com.qiaoqiao.qiaoqiao_companion.monitor

import com.qiaoqiao.qiaoqiao_companion.monitor.NativeRuleRepository.MonitoredApp
import com.qiaoqiao.qiaoqiao_companion.monitor.NativeRuleRepository.TotalTimeRule

/**
 * Pure, stateless rule evaluator that checks if an app should be blocked.
 *
 * All data comes from [NativeRuleRepository]; no internal state is kept.
 * The [now] parameter is accepted for testability but typically defaults to
 * [System.currentTimeMillis].
 *
 * Priority order:
 * 1. Forced rest (active rest session) — blocks all monitored apps
 * 2. Is the app monitored? — non-monitored apps are never blocked
 * 3. Time period rules (blocked / allowed modes)
 * 4. Total time limit (weekday vs weekend)
 * 5. Per-app daily limit
 */
class RuleEvaluator(
    private val repository: NativeRuleRepository
) {

    /**
     * Result of evaluating rules for a single app.
     */
    data class EvalResult(
        val blocked: Boolean,
        val reason: String = "",
        val ruleType: String = ""
    )

    /**
     * Evaluate whether [packageName] should be blocked at time [now].
     *
     * @param packageName The app package name to check.
     * @param now         Current wall-clock time in millis (unused directly but
     *                    available for callers that need deterministic timestamps;
     *                    time-sensitive data is read from the repository).
     * @return [EvalResult] indicating whether the app is blocked and why.
     */
    fun evaluate(packageName: String, now: Long): EvalResult {
        // ── 1. Forced rest (highest priority, blocks everything) ─────
        val restRemaining = repository.getActiveRestRemainingSeconds()
        if (restRemaining > 0) {
            return EvalResult(
                blocked = true,
                reason = "正在休息中，还需要 ${formatRemainingTime(restRemaining)}",
                ruleType = "forced_rest"
            )
        }

        // ── 2. Is the app monitored? ────────────────────────────────
        val monitoredApps = repository.getMonitoredApps()
        val monitoredApp = monitoredApps.find { it.packageName == packageName }
        if (monitoredApp == null) {
            return EvalResult(blocked = false)
        }

        // ── 3. Time period rules ────────────────────────────────────
        val timePeriodResult = checkTimePeriods()
        if (timePeriodResult != null) {
            return timePeriodResult
        }

        // ── 4. Total time limit ─────────────────────────────────────
        val totalTimeResult = checkTotalTimeLimit(monitoredApps.map { it.packageName }.toSet())
        if (totalTimeResult != null) {
            return totalTimeResult
        }

        // ── 5. Per-app daily limit ──────────────────────────────────
        val perAppResult = checkPerAppDailyLimit(monitoredApp)
        if (perAppResult != null) {
            return perAppResult
        }

        // No rule violated
        return EvalResult(blocked = false)
    }

    // ── Time period checking ────────────────────────────────────────

    /**
     * Check time period rules. Returns [EvalResult] if blocked, null if allowed.
     *
     * Logic:
     * - "blocked" periods: if the current time falls in any matching blocked period, block.
     * - "allowed" periods: if any allowed periods exist and the current time is not in
     *   any of them, block.
     */
    private fun checkTimePeriods(): EvalResult? {
        val periods = repository.getTimePeriods()
        if (periods.isEmpty()) return null

        val currentTime = repository.getCurrentTimeStr()
        val dayOfWeek = repository.getIsoDayOfWeek()

        val blockedPeriods = periods.filter { it.mode == "blocked" }
        val allowedPeriods = periods.filter { it.mode == "allowed" }

        // Check blocked periods first
        for (period in blockedPeriods) {
            if (isDayMatch(period.days, dayOfWeek) &&
                isTimeInRange(currentTime, period.timeStart, period.timeEnd)
            ) {
                return EvalResult(
                    blocked = true,
                    reason = "当前是禁止使用时段（${period.timeStart}-${period.timeEnd}）",
                    ruleType = "time_period"
                )
            }
        }

        // Check allowed periods — if any exist and we're outside all of them, block
        if (allowedPeriods.isNotEmpty()) {
            val inAnyAllowed = allowedPeriods.any { period ->
                isDayMatch(period.days, dayOfWeek) &&
                    isTimeInRange(currentTime, period.timeStart, period.timeEnd)
            }
            if (!inAnyAllowed) {
                return EvalResult(
                    blocked = true,
                    reason = "当前不在允许使用时段内",
                    ruleType = "time_period"
                )
            }
        }

        return null
    }

    // ── Total time limit checking ───────────────────────────────────

    /**
     * Check total time limit across all monitored apps.
     * Returns [EvalResult] if blocked, null if allowed.
     */
    private fun checkTotalTimeLimit(monitoredPackages: Set<String>): EvalResult? {
        val totalTimeRule = repository.getTotalTimeRule() ?: return null

        val isWeekend = repository.isWeekend()
        val limitMinutes = if (isWeekend) {
            totalTimeRule.weekendLimit ?: return null
        } else {
            totalTimeRule.weekdayLimit ?: return null
        }

        if (limitMinutes <= 0) return null

        val totalUsageMs = repository.getTodayTotalUsageMs(monitoredPackages)
        val totalUsageMinutes = totalUsageMs / 60_000

        if (totalUsageMinutes >= limitMinutes) {
            return EvalResult(
                blocked = true,
                reason = "今日总使用时间已达上限（${limitMinutes}分钟）",
                ruleType = "total_time_limit"
            )
        }

        return null
    }

    // ── Per-app daily limit checking ─────────────────────────────────

    /**
     * Check per-app daily limit.
     * Returns [EvalResult] if blocked, null if allowed.
     */
    private fun checkPerAppDailyLimit(app: MonitoredApp): EvalResult? {
        val dailyLimit = app.dailyLimitMinutes
        if (dailyLimit == null || dailyLimit <= 0) return null

        val appUsageMs = repository.getTodayAppUsageMs(app.packageName)
        val appUsageMinutes = appUsageMs / 60_000

        if (appUsageMinutes >= dailyLimit) {
            return EvalResult(
                blocked = true,
                reason = "今日使用已达上限（${dailyLimit}分钟）",
                ruleType = "app_daily_limit"
            )
        }

        return null
    }

    // ── Time parsing utilities (from NativeRuleChecker) ──────────────

    /**
     * Check if [dayOfWeek] matches the days specified in [daysStr].
     * [daysStr] can be a JSON array like "[1,2,3]" or comma-separated like "1,2,3".
     * [dayOfWeek] uses ISO convention (1=Monday..7=Sunday), matching the Flutter side's
     * `TimePeriod.days` storage (which uses Dart's `DateTime.weekday`).
     */
    internal fun isDayMatch(daysStr: String, dayOfWeek: Int): Boolean {
        return try {
            // Strip brackets and split by comma — handles both "[1,2,3]" and "1,2,3"
            val cleaned = daysStr.trim()
                .removeSurrounding("[", "]")
            val days = cleaned.split(",")
                .map { it.trim().toInt() }
            days.contains(dayOfWeek)
        } catch (e: Exception) {
            // Default to matching all days if parsing fails
            true
        }
    }

    /**
     * Check if [currentTime] (HH:mm) falls within the range [start]-[end].
     * Supports cross-midnight ranges (e.g., 22:00-06:00).
     */
    internal fun isTimeInRange(currentTime: String, start: String, end: String): Boolean {
        return try {
            val current = timeToMinutes(currentTime)
            val startMin = timeToMinutes(start)
            val endMin = timeToMinutes(end)

            if (startMin <= endMin) {
                // Normal range, e.g., 08:00-18:00
                current in startMin..endMin
            } else {
                // Cross-midnight range, e.g., 22:00-06:00
                current >= startMin || current <= endMin
            }
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Convert "HH:mm" string to minutes since midnight.
     */
    internal fun timeToMinutes(time: String): Int {
        val parts = time.split(":")
        return parts[0].toInt() * 60 + parts[1].toInt()
    }

    /**
     * Format remaining seconds into a human-readable string.
     */
    private fun formatRemainingTime(seconds: Long): String {
        val minutes = seconds / 60
        val remainingSeconds = seconds % 60
        return if (minutes > 0) "${minutes}分${remainingSeconds}秒" else "${remainingSeconds}秒"
    }
}
