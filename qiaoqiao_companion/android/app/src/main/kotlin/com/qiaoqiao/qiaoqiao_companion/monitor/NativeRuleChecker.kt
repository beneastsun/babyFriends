package com.qiaoqiao.qiaoqiao_companion.monitor

import android.util.Log
import org.json.JSONArray

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
        val reason: String
    )

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
    fun checkApp(packageName: String): CheckResult {
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

        Log.d(TAG, "App $packageName allowed (no rule violation)")
        return CheckResult(false, "")
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
        val limitMinutes = if (isWeekend) {
            totalTimeRule.weekendLimit ?: return null
        } else {
            totalTimeRule.weekdayLimit ?: return null
        }

        if (limitMinutes <= 0) return null

        val totalUsageMs = repository.getTodayTotalUsageMs(monitoredPackages)
        val totalUsageMinutes = totalUsageMs / 60_000
        Log.d(TAG, "Total time: ${totalUsageMinutes}min / ${limitMinutes}min (weekend=$isWeekend)")

        if (totalUsageMinutes >= limitMinutes) {
            return CheckResult(true, "今日总使用时间已达上限（${limitMinutes}分钟）")
        }

        return null
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
