package com.qiaoqiao.qiaoqiao_companion.channels

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.drawable.BitmapDrawable
import android.os.Build
import android.os.Process
import android.provider.Settings
import android.util.Base64
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

/**
 * 应用使用统计通道
 * 提供应用使用数据查询功能
 */
class UsageStatsChannel(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "com.qiaoqiao.companion/usage_stats"

        /**
         * 检查是否有使用统计权限
         */
        fun hasUsageStatsPermission(context: Context): Boolean {
            val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                appOps.unsafeCheckOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    Process.myUid(),
                    context.packageName
                )
            } else {
                @Suppress("DEPRECATION")
                appOps.checkOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    Process.myUid(),
                    context.packageName
                )
            }
            return mode == AppOpsManager.MODE_ALLOWED
        }

        /**
         * 打开使用统计权限设置页面
         */
        fun openUsageStatsSettings(context: Context) {
            val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasPermission" -> {
                result.success(hasUsageStatsPermission(context))
            }

            "requestPermission" -> {
                openUsageStatsSettings(context)
                result.success(null)
            }

            "queryUsageStats" -> {
                val startTime = call.argument<Long>("startTime")
                val endTime = call.argument<Long>("endTime")
                if (startTime != null && endTime != null) {
                    val stats = queryUsageStats(startTime, endTime)
                    result.success(stats)
                } else {
                    result.error("INVALID_ARGUMENTS", "startTime and endTime are required", null)
                }
            }

            "queryEvents" -> {
                val startTime = call.argument<Long>("startTime")
                val endTime = call.argument<Long>("endTime")
                if (startTime != null && endTime != null) {
                    val events = queryEvents(startTime, endTime)
                    result.success(events)
                } else {
                    result.error("INVALID_ARGUMENTS", "startTime and endTime are required", null)
                }
            }

            "getCurrentForegroundApp" -> {
                val packageName = getCurrentForegroundApp()
                result.success(packageName)
            }

            "getInstalledApps" -> {
                val apps = getInstalledApps()
                result.success(apps)
            }

            "getAppName" -> {
                val packageName = call.argument<String>("packageName")
                if (packageName != null) {
                    val name = getAppName(packageName)
                    result.success(name)
                } else {
                    result.error("INVALID_ARGUMENTS", "packageName is required", null)
                }
            }

            "queryHourlyUsage" -> {
                val startTime = call.argument<Long>("startTime")
                val endTime = call.argument<Long>("endTime")
                if (startTime != null && endTime != null) {
                    val hourlyStats = queryHourlyUsage(startTime, endTime)
                    result.success(hourlyStats)
                } else {
                    result.error("INVALID_ARGUMENTS", "startTime and endTime are required", null)
                }
            }

            else -> {
                result.notImplemented()
            }
        }
    }

    /**
     * 查询应用使用统计
     * 使用 Events 精确计算使用时间（基于 resume/pause 事件）
     * 这与系统的屏幕时间管理计算方式更接近
     */
    private fun queryUsageStats(startTime: Long, endTime: Long): List<Map<String, Any?>> {
        if (!hasUsageStatsPermission(context)) {
            return emptyList()
        }

        val usageStatsManager = context.getSystemService(Context.USAGE_STATS_SERVICE)
                as UsageStatsManager

        android.util.Log.d("UsageStatsChannel", "queryUsageStats: startTime=$startTime, endTime=$endTime")

        // 使用 Events 来精确计算每个应用的使用时间
        val usageEvents = usageStatsManager.queryEvents(startTime, endTime)

        // 记录每个应用的最后 resume 时间
        val lastResumeTime = mutableMapOf<String, Long>()

        // 按包名累计使用时间（毫秒）
        val usageTimeMap = mutableMapOf<String, Long>()

        // 记录首次和最后使用时间
        val firstUseTime = mutableMapOf<String, Long>()
        val lastUseTime = mutableMapOf<String, Long>()

        while (usageEvents.hasNextEvent()) {
            val event = UsageEvents.Event()
            usageEvents.getNextEvent(event)

            val packageName = event.packageName

            // 过滤系统界面应用
            if (isSystemUiApp(packageName)) {
                continue
            }

            when (event.eventType) {
                UsageEvents.Event.ACTIVITY_RESUMED -> {
                    lastResumeTime[packageName] = event.timeStamp
                    // 记录首次使用时间
                    if (!firstUseTime.containsKey(packageName)) {
                        firstUseTime[packageName] = event.timeStamp
                    }
                }
                UsageEvents.Event.ACTIVITY_PAUSED -> {
                    val resumeTime = lastResumeTime[packageName]
                    if (resumeTime != null && event.timeStamp > resumeTime) {
                        // 计算这个时间段的使用时间
                        val duration = event.timeStamp - resumeTime
                        usageTimeMap.merge(packageName, duration) { old, new -> old + new }
                        lastUseTime[packageName] = event.timeStamp
                        // 清除 resume 时间
                        lastResumeTime.remove(packageName)
                    }
                }
            }
        }

        android.util.Log.d("UsageStatsChannel", "=== CALCULATED FROM EVENTS ===")
        val result = mutableListOf<Map<String, Any?>>()
        for ((packageName, totalTimeMs) in usageTimeMap) {
            val appName = getAppName(packageName)
            val totalSeconds = totalTimeMs / 1000
            android.util.Log.d("UsageStatsChannel", "CALC: $packageName | $appName | ${totalSeconds}s")

            result.add(mapOf(
                "packageName" to packageName,
                "appName" to appName,
                "totalTimeInForeground" to totalTimeMs,
                "lastTimeUsed" to (lastUseTime[packageName] ?: 0L),
                "firstTimeStamp" to (firstUseTime[packageName] ?: 0L),
                "lastTimeStamp" to (lastUseTime[packageName] ?: 0L),
                "appIcon" to getAppIconBase64(packageName)
            ))
        }
        android.util.Log.d("UsageStatsChannel", "=== END CALCULATED (${result.size} apps) ===")

        return result
    }

    /**
     * 查询应用使用事件
     */
    private fun queryEvents(startTime: Long, endTime: Long): List<Map<String, Any?>> {
        if (!hasUsageStatsPermission(context)) {
            return emptyList()
        }

        val usageStatsManager = context.getSystemService(Context.USAGE_STATS_SERVICE)
                as UsageStatsManager

        val usageEvents = usageStatsManager.queryEvents(startTime, endTime)
        val events = mutableListOf<Map<String, Any?>>()

        while (usageEvents.hasNextEvent()) {
            val event = UsageEvents.Event()
            usageEvents.getNextEvent(event)

            events.add(mapOf(
                "packageName" to event.packageName,
                "eventType" to when (event.eventType) {
                    UsageEvents.Event.ACTIVITY_RESUMED -> "resume"
                    UsageEvents.Event.ACTIVITY_PAUSED -> "pause"
                    UsageEvents.Event.DEVICE_SHUTDOWN -> "shutdown"
                    UsageEvents.Event.DEVICE_STARTUP -> "startup"
                    else -> "unknown"
                },
                "timeStamp" to event.timeStamp,
                "appName" to getAppName(event.packageName)
            ))
        }

        return events
    }

    /**
     * 查询按时段统计的使用数据
     * 利用 UsageEvents 的 resume/pause 事件计算每个应用在每小时的精确使用时长
     */
    private fun queryHourlyUsage(startTime: Long, endTime: Long): List<Map<String, Any?>> {
        if (!hasUsageStatsPermission(context)) {
            return emptyList()
        }

        val usageStatsManager = context.getSystemService(Context.USAGE_STATS_SERVICE)
                as UsageStatsManager

        val usageEvents = usageStatsManager.queryEvents(startTime, endTime)

        // 记录每个应用的最后 resume 时间
        val lastResumeTime = mutableMapOf<String, Long>()

        // 按包名 -> 小时 -> 累计时长（毫秒）
        val hourlyMap = mutableMapOf<String, MutableMap<Int, Long>>()

        // 应用信息缓存
        val appNames = mutableMapOf<String, String>()

        // 获取时区偏移（用于将时间戳转换为本地小时）
        val calendar = java.util.Calendar.getInstance()

        while (usageEvents.hasNextEvent()) {
            val event = UsageEvents.Event()
            usageEvents.getNextEvent(event)

            val packageName = event.packageName

            // 过滤系统界面应用，与 queryUsageStats 保持一致
            if (isSystemUiApp(packageName)) {
                continue
            }

            when (event.eventType) {
                UsageEvents.Event.ACTIVITY_RESUMED -> {
                    lastResumeTime[packageName] = event.timeStamp
                }
                UsageEvents.Event.ACTIVITY_PAUSED -> {
                    val resumeTime = lastResumeTime[packageName]
                    if (resumeTime != null && event.timeStamp > resumeTime) {
                        // 计算这个时间段的时长
                        val duration = event.timeStamp - resumeTime

                        // 分配到对应的小时
                        var currentTime = resumeTime
                        var remainingDuration = duration

                        while (remainingDuration > 0 && currentTime < event.timeStamp) {
                            // 获取当前小时
                            calendar.timeInMillis = currentTime
                            val hour = calendar.get(java.util.Calendar.HOUR_OF_DAY)

                            // 计算当前小时的剩余时间
                            calendar.set(java.util.Calendar.MINUTE, 59)
                            calendar.set(java.util.Calendar.SECOND, 59)
                            calendar.set(java.util.Calendar.MILLISECOND, 999)
                            val hourEndTime = calendar.timeInMillis

                            // 计算在这个小时内的时长
                            val durationInHour = minOf(
                                remainingDuration,
                                hourEndTime - currentTime + 1,
                                event.timeStamp - currentTime
                            )

                            if (durationInHour > 0) {
                                hourlyMap.getOrPut(packageName) { mutableMapOf() }
                                    .merge(hour, durationInHour) { old, new -> old + new }
                            }

                            remainingDuration -= durationInHour
                            currentTime += durationInHour
                        }

                        // 清除 resume 时间
                        lastResumeTime.remove(packageName)
                    }
                }
            }

            // 缓存应用名
            if (!appNames.containsKey(packageName)) {
                appNames[packageName] = getAppName(packageName)
            }
        }

        // 获取日期字符串
        calendar.timeInMillis = startTime
        val dateFormat = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.getDefault())
        val dateStr = dateFormat.format(java.util.Date(startTime))

        // 转换为结果列表
        val result = mutableListOf<Map<String, Any?>>()
        for ((packageName, hours) in hourlyMap) {
            for ((hour, durationMs) in hours) {
                if (durationMs > 0) {
                    result.add(mapOf(
                        "date" to dateStr,
                        "hour" to hour,
                        "packageName" to packageName,
                        "appName" to (appNames[packageName] ?: packageName),
                        "durationSeconds" to (durationMs / 1000).toInt()
                    ))
                }
            }
        }

        android.util.Log.d("UsageStatsChannel", "queryHourlyUsage: returned ${result.size} records for $dateStr")
        return result
    }

    /**
     * 获取当前前台应用包名
     * 使用 UsageEvents 获取更精确的前台应用信息
     */
    private fun getCurrentForegroundApp(): String? {
        if (!hasUsageStatsPermission(context)) {
            return null
        }

        val usageStatsManager = context.getSystemService(Context.USAGE_STATS_SERVICE)
                as UsageStatsManager

        val endTime = System.currentTimeMillis()
        val startTime = endTime - 1000 * 60 * 5 // 最近5分钟

        val usageEvents = usageStatsManager.queryEvents(startTime, endTime)
        var lastResumedPackage: String? = null
        var lastResumedTime: Long = 0

        while (usageEvents.hasNextEvent()) {
            val event = UsageEvents.Event()
            usageEvents.getNextEvent(event)

            if (event.eventType == UsageEvents.Event.ACTIVITY_RESUMED) {
                if (event.timeStamp > lastResumedTime) {
                    lastResumedTime = event.timeStamp
                    lastResumedPackage = event.packageName
                }
            }
        }

        // 添加调试日志
        android.util.Log.d("UsageStatsChannel", "getCurrentForegroundApp: lastResumedPackage=$lastResumedPackage, lastResumedTime=$lastResumedTime, elapsed=${endTime - lastResumedTime}ms")

        // 验证是否是最近的活跃应用
        // 注意：用户持续使用一个app时不会有新的RESUMED事件，所以需要较长的时间窗口
        // 将时间窗口扩大到30分钟，以支持连续使用监控的正常工作
        // 连续使用限制通常不会超过30分钟
        if (lastResumedPackage != null && (endTime - lastResumedTime) < 1800000) {
            return lastResumedPackage
        }

        return null
    }

    /**
     * 获取已安装应用列表
     * 返回所有已安装的应用（包括没有启动入口但有使用记录的应用）
     */
    private fun getInstalledApps(): List<Map<String, Any?>> {
        val packageManager = context.packageManager
        val installedApps = packageManager.getInstalledApplications(PackageManager.GET_META_DATA)

        return installedApps
            .map { appInfo ->
                mapOf(
                    "packageName" to appInfo.packageName,
                    "appName" to packageManager.getApplicationLabel(appInfo).toString(),
                    "isSystemApp" to (appInfo.flags and ApplicationInfo.FLAG_SYSTEM != 0),
                    "appIcon" to getAppIconBase64(appInfo.packageName)
                )
            }
    }

    /**
     * 获取应用名称
     */
    private fun getAppName(packageName: String): String {
        return try {
            val packageManager = context.packageManager
            val appInfo = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
            val name = packageManager.getApplicationLabel(appInfo).toString()
            android.util.Log.d("UsageStatsChannel", "getAppName: $packageName -> $name")
            name
        } catch (e: PackageManager.NameNotFoundException) {
            android.util.Log.w("UsageStatsChannel", "getAppName: $packageName not found: ${e.message}")
            packageName
        } catch (e: Exception) {
            android.util.Log.e("UsageStatsChannel", "getAppName: $packageName error: ${e.message}")
            packageName
        }
    }

    /**
     * 判断应用是否有启动入口（排除纯后台服务）
     */
    private fun isLaunchableApp(packageName: String): Boolean {
        return try {
            val intent = context.packageManager.getLaunchIntentForPackage(packageName)
            intent != null
        } catch (e: Exception) {
            false
        }
    }

    /**
     * 判断是否为系统应用
     */
    private fun isSystemApp(packageName: String): Boolean {
        return try {
            val appInfo = context.packageManager.getApplicationInfo(packageName, 0)
            (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0
        } catch (e: PackageManager.NameNotFoundException) {
            true  // 找不到的应用视为系统应用，过滤掉
        }
    }

    /**
     * 判断是否为系统界面应用（仅过滤启动器和纯后台服务）
     * 注意：设置、安全中心等有用户交互的应用不过滤，因为系统的屏幕时间管理也统计这些应用
     */
    private fun isSystemUiApp(packageName: String): Boolean {
        val systemUiPackages = setOf(
            // 启动器（桌面）- 不计入使用时间
            "com.miui.home",           // MIUI 启动器
            "com.android.launcher",    // Android 原生启动器
            "com.android.launcher3",   // Launcher3
            "com.google.android.apps.nexuslauncher",  // Pixel 启动器
            // 系统UI（状态栏、导航栏等）- 纯后台显示
            "com.android.systemui",    // 系统 UI
            // 系统服务 - 纯后台
            "com.lbe.security.miui",   // MIUI 安全服务
            "com.miui.packageinstaller", // 包安装器
            "com.android.packageinstaller", // 包安装器
            // 输入法 - 附属输入
            "com.iflytek.inputmethod.miui", // 讯飞输入法小米版
            "com.sohu.inputmethod.sogou.xiaomi", // 搜狗输入法小米版
        )
        return packageName in systemUiPackages
    }

    /**
     * 获取应用图标为Base64字符串
     */
    private fun getAppIconBase64(packageName: String): String? {
        return try {
            val packageManager = context.packageManager
            val drawable = packageManager.getApplicationIcon(packageName)

            // 将 Drawable 转换为 Bitmap
            val bitmap = when (drawable) {
                is BitmapDrawable -> drawable.bitmap
                else -> {
                    // 对于其他类型的 Drawable，创建一个 Bitmap
                    val width = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth else 96
                    val height = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight else 96
                    val bmp = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                    val canvas = android.graphics.Canvas(bmp)
                    drawable.setBounds(0, 0, canvas.width, canvas.height)
                    drawable.draw(canvas)
                    bmp
                }
            }

            // 压缩为 PNG 并转换为 Base64
            val stream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
            val byteArray = stream.toByteArray()
            Base64.encodeToString(byteArray, Base64.NO_WRAP)
        } catch (e: Exception) {
            null
        }
    }
}
