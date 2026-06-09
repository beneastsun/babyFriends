package com.qiaoqiao.qiaoqiao_companion.utils

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.os.Build
import android.util.Log

/**
 * 前台应用检测工具类
 * 从 UsageStatsChannel 提取，可被原生服务直接调用，无需 Flutter 引擎
 */
object UsageStatsHelper {

    private const val TAG = "UsageStatsHelper"

    /**
     * 检查是否有使用统计权限
     */
    fun hasUsageStatsPermission(context: Context): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            android.os.Process.myUid(),
            context.packageName
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    /**
     * 获取当前前台应用包名
     * 使用 UsageEvents 获取更精确的前台应用信息
     *
     * @param context 上下文
     * @param excludePackage 要排除的包名（通常是自身包名）
     * @return 前台应用包名，如果无法获取则返回 null
     */
    fun getCurrentForegroundApp(context: Context, excludePackage: String? = null): String? {
        if (!hasUsageStatsPermission(context)) {
            Log.w(TAG, "No usage stats permission")
            return null
        }

        val usageStatsManager = context.getSystemService(Context.USAGE_STATS_SERVICE)
                as UsageStatsManager

        val endTime = System.currentTimeMillis()
        // 扩大查询窗口到 60 秒，确保能捕获到长时间在前台的 app
        val startTime = endTime - 60_000L

        val usageEvents = usageStatsManager.queryEvents(startTime, endTime)
        var lastResumedPackage: String? = null
        var lastResumedTime: Long = 0
        var lastPausedPackage: String? = null
        var lastPausedTime: Long = 0

        while (usageEvents.hasNextEvent()) {
            val event = UsageEvents.Event()
            usageEvents.getNextEvent(event)
            val packageName = event.packageName ?: continue

            if (isSystemUiApp(packageName)) {
                continue
            }

            when (event.eventType) {
                UsageEvents.Event.ACTIVITY_RESUMED -> {
                    if (event.timeStamp >= lastResumedTime) {
                        lastResumedTime = event.timeStamp
                        lastResumedPackage = packageName
                    }
                }
                UsageEvents.Event.ACTIVITY_PAUSED -> {
                    if (event.timeStamp >= lastPausedTime) {
                        lastPausedTime = event.timeStamp
                        lastPausedPackage = packageName
                    }
                }
            }
        }

        // 判断前台 app：最后一次 resume 的 app 且没有被更新的 pause 覆盖
        var result: String? = null
        if (lastResumedPackage != null &&
            (lastPausedPackage != lastResumedPackage || lastPausedTime < lastResumedTime)) {
            if (excludePackage != null && lastResumedPackage == excludePackage) {
                result = null
            } else {
                result = lastResumedPackage
            }
        }

        // 兜底：如果事件查询没有找到前台 app，使用 queryUsageStats 获取最近使用的 app
        if (result == null) {
            try {
                val stats = usageStatsManager.queryUsageStats(
                    UsageStatsManager.INTERVAL_BEST,
                    endTime - 10_000L,
                    endTime
                )
                var bestPackage: String? = null
                var bestLastTime: Long = 0
                for (stat in stats) {
                    val pkg = stat.packageName
                    if (pkg == excludePackage || isSystemUiApp(pkg)) continue
                    if (stat.lastTimeUsed > bestLastTime) {
                        bestLastTime = stat.lastTimeUsed
                        bestPackage = pkg
                    }
                }
                if (bestPackage != null && bestLastTime > endTime - 60_000L) {
                    result = bestPackage
                    Log.d(TAG, "getCurrentForegroundApp fallback: using queryUsageStats, result=$bestPackage, lastTimeUsed=$bestLastTime")
                }
            } catch (e: Exception) {
                Log.w(TAG, "queryUsageStats fallback failed", e)
            }
        }

        Log.d(TAG, "getCurrentForegroundApp: result=$result, lastResumedPackage=$lastResumedPackage, lastPausedPackage=$lastPausedPackage")
        return result
    }

    private fun isSystemUiApp(packageName: String): Boolean {
        return packageName == "com.android.systemui" ||
                packageName == "com.miui.home" ||
                packageName == "com.android.launcher" ||
                packageName.contains("launcher", ignoreCase = true)
    }
}
