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

    /** Sticky foreground cache: bridges MIUI detection gaps during continuous app use */
    private var lastKnownForegroundApp: String? = null
    private var lastKnownForegroundTime: Long = 0
    /**
     * Cache validity window: 15 seconds.
     * We still need a short sticky window to bridge MIUI detection gaps, but the old
     * 90-second window kept stale foreground results far too long and delayed widget
     * disappearance after the child had already left the monitored app.
     */
    private const val STICKY_CACHE_MS = 15_000L

    /**
     * 上一次检测结果中，是否检测到了自身 app 在前台。
     * 当我们的 app 被检测为前台时（被 excludePackage 排除后 result=null），
     * 这与 MIUI 检测间隙导致的 null 本质不同：
     * - 自身 app 在前台 → 用户确实离开了受限制 app，应快速确认 leave
     * - 完全 null → MIUI 检测间隙，受限制 app 可能仍在使用，需更长确认
     *
     * EnforcementEngine 通过此标志区分两种 null，加速前者的 leave 确认。
     */
    var lastDetectionWasSelfApp: Boolean = false
        private set

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
     * @param queryWindowMs 查询时间窗口（毫秒）。MIUI 在持续使用同一 app 时不产生新的
     *        ACTIVITY_RESUMED 事件，唯一的 RESUMED 在 app 启动时。窗口必须 ≥ 会话时长
     *        才能捕获它。调用方应根据配置的限制时长传入 max(2小时, limitMinutes*2*60*1000)。
     * @return 前台应用包名，如果无法获取则返回 null
     */
    fun getCurrentForegroundApp(
        context: Context,
        excludePackage: String? = null,
        queryWindowMs: Long = 2 * 60 * 60 * 1000L  // 默认 2 小时
    ): String? {
        if (!hasUsageStatsPermission(context)) {
            Log.w(TAG, "No usage stats permission")
            lastDetectionWasSelfApp = false
            return null
        }

        val usageStatsManager = context.getSystemService(Context.USAGE_STATS_SERVICE)
                as UsageStatsManager

        val endTime = System.currentTimeMillis()
        // 动态查询窗口：MIUI 持续使用同一 app 时不产生新 RESUMED 事件，
        // 窗口必须覆盖会话时长才能捕获启动时的 RESUMED。详见函数文档。
        val startTime = endTime - queryWindowMs

        val usageEvents = usageStatsManager.queryEvents(startTime, endTime)
        var lastResumedPackage: String? = null
        var lastResumedTime: Long = 0
        var lastPausedPackage: String? = null
        var lastPausedTime: Long = 0
        // 标志：queryEvents 明确检测到最后 RESUMED 已被同包的 PAUSED 覆盖（用户确实离开了）
        // 此时不走 fallback / sticky cache，避免把已离开的 app 重新拉回前台
        var lastResumedWasPaused = false

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
        var selfAppDetected = false
        if (lastResumedPackage != null &&
            (lastPausedPackage != lastResumedPackage || lastPausedTime < lastResumedTime)) {
            if (excludePackage != null && lastResumedPackage == excludePackage) {
                result = null
                selfAppDetected = true // 检测到自身 app 在前台（被排除）
            } else {
                result = lastResumedPackage
            }
        } else if (lastResumedPackage != null &&
            lastPausedPackage == lastResumedPackage && lastPausedTime >= lastResumedTime) {
            // 最后的 RESUMED 已被同包的 PAUSED 覆盖 — 用户明确离开了该 app
            // （例如按 HOME 回桌面，launcher 被过滤后窗口内只剩该 app 的 RESUMED+PAUSED）
            // 此时绝不能走 fallback / sticky cache 把它拉回来
            lastResumedWasPaused = true
            Log.d(TAG, "getCurrentForegroundApp: last resumed ($lastResumedPackage) was PAUSED, " +
                    "skipping fallbacks (resumed=$lastResumedTime, paused=$lastPausedTime)")
        }

        // 兜底：如果 queryEvents 没有找到前台 app（MIUI 上常见），使用 queryUsageStats
        // 放宽阈值动态化：max(20分钟, queryWindowMs/4)，与查询窗口成正比
        // 注意：lastResumedWasPaused 时不走 fallback — queryEvents 已明确给出离开信号
        if (result == null && !selfAppDetected && !lastResumedWasPaused) {
            val relaxedThresholdMs = maxOf(20 * 60 * 1000L, queryWindowMs / 4)
            result = queryUsageStatsFallback(usageStatsManager, endTime, excludePackage, relaxedThresholdMs)
        }

        // 二级 fallback：使用 ForegroundAppWatcher（AccessibilityService）
        // 在 MIUI 上 queryEvents 和 queryUsageStats 都可能不可靠时，AccessibilityService 最为精确
        if (result == null && !selfAppDetected && !lastResumedWasPaused) {
            val watcherApp = com.qiaoqiao.qiaoqiao_companion.services.ForegroundAppWatcher
                .getLastForegroundApp(excludePackage)
            if (watcherApp != null) {
                result = watcherApp
                Log.d(TAG, "getCurrentForegroundApp: using ForegroundAppWatcher fallback, result=$watcherApp")
            }
        }

        // Sticky foreground cache: when all detection methods fail but we recently
        // detected a foreground app (within STICKY_CACHE_MS), return the cached app.
        // This bridges MIUI's detection gaps where both queryEvents and queryUsageStats
        // become unreliable during continuous app use (lastTimeUsed stops updating).
        //
        // Key rules:
        // 1. When result is a different non-null app (user genuinely switched), clear cache
        // 2. When result is our own app, KEEP cache — KeepAlive may trigger our Activity
        //    while user is still on monitored app; cache expires naturally after STICKY_CACHE_MS.
        //    Set selfAppDetected flag so EnforcementEngine can use fast leave confirmation.
        // 3. When result is null (no detection at all), use cache if valid — MIUI detection blackout
        if (result != null && result != excludePackage && !isSystemUiApp(result)) {
            if (lastKnownForegroundApp != null && result != lastKnownForegroundApp) {
                // User genuinely switched to a DIFFERENT app — clear cache immediately
                Log.d(TAG, "getCurrentForegroundApp: different app detected ($result vs cached $lastKnownForegroundApp), clearing sticky cache")
                lastKnownForegroundApp = null
            }
            // Update cache with new detection
            lastKnownForegroundApp = result
            lastKnownForegroundTime = endTime
        } else if (result == null && selfAppDetected) {
            // Our own app is in foreground — user definitely left the monitored app.
            // Keep sticky cache (don't clear it), but don't use it to mask the real result.
            // The selfAppDetected flag tells EnforcementEngine to use fast leave confirmation.
            if (lastKnownForegroundApp != null) {
                Log.d(TAG, "getCurrentForegroundApp: self app detected (excludePackage=$excludePackage), " +
                        "keeping sticky cache for $lastKnownForegroundApp " +
                        "(age=${(endTime - lastKnownForegroundTime) / 1000}s)")
            }
        } else if (result == null && lastResumedWasPaused) {
            // queryEvents 明确检测到最后 RESUMED 已被 PAUSED — 用户离开了
            // 清除 sticky cache，不使用它（避免把已离开的 app 拉回来当前台）
            if (lastKnownForegroundApp != null) {
                Log.d(TAG, "getCurrentForegroundApp: clearing sticky cache — $lastKnownForegroundApp was PAUSED")
                lastKnownForegroundApp = null
            }
        } else if (result == null) {
            val cachedApp = lastKnownForegroundApp
            if (cachedApp != null && cachedApp != excludePackage &&
                (endTime - lastKnownForegroundTime) < STICKY_CACHE_MS) {
                result = cachedApp
                Log.d(TAG, "getCurrentForegroundApp: using sticky cache, app=$cachedApp, " +
                        "age=${(endTime - lastKnownForegroundTime) / 1000}s")
            } else if (cachedApp != null) {
                // Cache expired — clear it
                lastKnownForegroundApp = null
                Log.d(TAG, "getCurrentForegroundApp: sticky cache expired for $cachedApp")
            }
        } else {
            // result is a system UI app — clear sticky cache
            lastKnownForegroundApp = null
        }

        // 更新 selfAppDetected 标志供 EnforcementEngine 读取
        lastDetectionWasSelfApp = selfAppDetected && result == null

        Log.d(TAG, "getCurrentForegroundApp: result=$result, lastResumedPackage=$lastResumedPackage, " +
                "lastPausedPackage=$lastPausedPackage, selfApp=$selfAppDetected, wasPaused=$lastResumedWasPaused")
        return result
    }

    /**
     * 使用 queryUsageStats 作为 fallback 检测前台 app。
     * 在 MIUI 等系统上 queryEvents 可能返回空结果，但 queryUsageStats 通常可用。
     *
     * 判断标准：lastTimeUsed 在最近 relaxedThresholdMs 内的 app 视为在前台。
     * MIUI 上 lastTimeUsed 在持续使用期间会更新，但有 7-10 分钟延迟，
     * 因此阈值需足够大（默认 20 分钟，由调用方按会话时长动态传入）。
     */
    private fun queryUsageStatsFallback(
        usageStatsManager: UsageStatsManager,
        endTime: Long,
        excludePackage: String?,
        relaxedThresholdMs: Long = 20 * 60 * 1000L  // 默认 20 分钟
    ): String? {
        try {
            val stats = usageStatsManager.queryUsageStats(
                UsageStatsManager.INTERVAL_BEST,
                endTime - relaxedThresholdMs,
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
            // lastTimeUsed 在最近 10 秒内视为前台 app（严格阈值）
            val foregroundThreshold = endTime - 10_000L
            if (bestPackage != null && bestLastTime > foregroundThreshold) {
                Log.d(TAG, "queryUsageStatsFallback: result=$bestPackage, lastTimeUsed=$bestLastTime, threshold=$foregroundThreshold")
                return bestPackage
            }
            // 放宽到 relaxedThresholdMs（MIUI lastTimeUsed 有 7-10 分钟延迟，需大阈值兜底）
            if (bestPackage != null && bestLastTime > endTime - relaxedThresholdMs) {
                Log.d(TAG, "queryUsageStatsFallback (relaxed): result=$bestPackage, lastTimeUsed=$bestLastTime, threshold=${relaxedThresholdMs}ms")
                return bestPackage
            }
        } catch (e: Exception) {
            Log.w(TAG, "queryUsageStats fallback failed", e)
        }
        return null
    }

    private fun isSystemUiApp(packageName: String): Boolean {
        return packageName == "com.android.systemui" ||
                packageName == "com.miui.home" ||
                packageName == "com.android.launcher" ||
                packageName.contains("launcher", ignoreCase = true)
    }
}
