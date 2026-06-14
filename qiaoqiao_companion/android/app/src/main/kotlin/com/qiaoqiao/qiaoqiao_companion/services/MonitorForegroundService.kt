package com.qiaoqiao.qiaoqiao_companion.services

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import com.qiaoqiao.qiaoqiao_companion.MainActivity
import com.qiaoqiao.qiaoqiao_companion.R
import com.qiaoqiao.qiaoqiao_companion.activities.AlarmProxyActivity
import com.qiaoqiao.qiaoqiao_companion.activities.AppLockOverlayActivity
import com.qiaoqiao.qiaoqiao_companion.managers.AppLockManager
import com.qiaoqiao.qiaoqiao_companion.monitor.NativeOverlayManager
import com.qiaoqiao.qiaoqiao_companion.monitor.NativeRuleChecker
import com.qiaoqiao.qiaoqiao_companion.monitor.NativeRuleRepository
import com.qiaoqiao.qiaoqiao_companion.receivers.AlarmReceiver
import com.qiaoqiao.qiaoqiao_companion.receivers.ServiceRestartReceiver
import com.qiaoqiao.qiaoqiao_companion.utils.UsageStatsHelper
import com.qiaoqiao.qiaoqiao_companion.workers.KeepAliveWorker

/**
 * 监控前台服务
 * 保持应用在后台运行，防止被系统杀死
 */
class MonitorForegroundService : Service() {

    companion object {
        private const val TAG = "MonitorService"
        private const val CHANNEL_ID = "qiaoqiao_monitor_channel"
        private const val CHANNEL_NAME = "纹纹守护服务"
        private const val NOTIFICATION_ID = 1001

        // 服务是否正在运行
        @Volatile
        private var isRunning = false

        /**
         * 检查服务是否正在运行
         */
        fun isServiceRunning(): Boolean = isRunning

        /**
         * 启动服务
         */
        fun start(context: Context) {
            val intent = Intent(context, MonitorForegroundService::class.java)
            intent.action = "START"
            try {
                // 先尝试 startService（MIUI 对 startForegroundService 有额外限制）
                // 服务在 onCreate 中会调用 startForeground() 提升为前台服务
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    try {
                        context.startService(intent)
                        Log.d(TAG, "Started via startService()")
                    } catch (e: Exception) {
                        // startService 也被限制时，尝试 startForegroundService
                        Log.w(TAG, "startService failed, trying startForegroundService", e)
                        context.startForegroundService(intent)
                    }
                } else {
                    context.startService(intent)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start service", e)
            }
        }

        /**
         * 停止服务
         */
        fun stop(context: Context) {
            val intent = Intent(context, MonitorForegroundService::class.java)
            intent.action = "STOP"
            context.startService(intent)
        }

        /**
         * 更新通知内容
         */
        fun updateNotification(context: Context, title: String, message: String) {
            val intent = Intent(context, MonitorForegroundService::class.java)
            intent.action = "UPDATE"
            intent.putExtra("title", title)
            intent.putExtra("message", message)
            context.startService(intent)
        }
    }

    private var notificationManager: NotificationManager? = null
    private var currentTitle: String = ""
    private var currentMessage = "正在保护你的健康使用习惯"

    // 原生监控组件（Flutter 引擎死亡时仍能工作）
    private var monitorHandler: Handler? = null
    private val MONITOR_INTERVAL_MS = 5_000L // 5秒检查一次
    private val INITIAL_DELAY_MS = 1_000L // 首次延迟1秒（原2秒）
    private var nativeRuleRepository: NativeRuleRepository? = null
    private var nativeRuleChecker: NativeRuleChecker? = null
    private var nativeOverlayManager: NativeOverlayManager? = null
    private var lastBlockedPackage: String? = null

    // (WAKEUP_ENGINE 已移除：MIUI 阻止后台 Activity 启动，改用原生直接显示倒计时)

    override fun onCreate() {
        super.onCreate()
        notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        createNotificationChannel()
        // 初始化应用名称
        currentTitle = getString(R.string.app_name) + "守护中"
        // 在 onCreate 中立即调用 startForeground，满足 Android 12+ 5秒超时要求
        // 同时确保 START_STICKY 重建服务时（intent=null）也能正确启动前台服务
        startAsForeground()
        Log.d(TAG, "Service created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "START" -> {
                // startForeground 已在 onCreate 中调用，这里确保服务已启动
                if (!isRunning) {
                    startAsForeground()
                }
                startNativeMonitoring()
            }
            "STOP" -> {
                stopForegroundService()
            }
            "UPDATE" -> {
                currentTitle = intent.getStringExtra("title") ?: currentTitle
                currentMessage = intent.getStringExtra("message") ?: currentMessage
                updateNotification()
            }
            // null intent (START_STICKY 重建) 时也需要启动原生监控
            null -> {
                startNativeMonitoring()
                // START_STICKY 重建 = 被系统杀死后重启，检查是否需要显示 AppLock
                if (AppLockManager.shouldShowLock(applicationContext)) {
                    try {
                        AppLockOverlayActivity.start(applicationContext)
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to show app lock on restart", e)
                    }
                }
            }
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    /**
     * 创建通知渠道
     */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val appName = getString(R.string.app_name)
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "保持${appName}在后台运行"
                setShowBadge(false)
                setSound(null, null)
                enableVibration(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            notificationManager?.createNotificationChannel(channel)
        }
    }

    /**
     * 构建通知
     */
    private fun buildNotification(): Notification {
        // 点击通知打开应用的 PendingIntent
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("$currentTitle [PID:${android.os.Process.myPid()}]")
            .setContentText(currentMessage)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()
    }

    /**
     * 启动前台服务
     */
    private fun startAsForeground() {
        if (isRunning) {
            Log.d(TAG, "Service already running")
            return
        }

        val notification = buildNotification()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            ServiceCompat.startForeground(
                this,
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        isRunning = true
        Log.d(TAG, "Service started as foreground")
    }

    /**
     * 停止前台服务
     */
    private fun stopForegroundService() {
        stopNativeMonitoring()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
        isRunning = false
        Log.d(TAG, "Service stopped")
    }

    /**
     * 更新通知
     */
    private fun updateNotification() {
        if (isRunning) {
            notificationManager?.notify(NOTIFICATION_ID, buildNotification())
            Log.d(TAG, "Notification updated")
        }
    }

    // ==================== 原生监控逻辑 ====================

    /**
     * 启动原生监控循环
     * 在 Flutter 引擎死亡时仍能检测和阻止被限制的 App
     */
    private fun startNativeMonitoring() {
        if (monitorHandler != null) {
            Log.d(TAG, "Native monitoring already running")
            return
        }

        try {
            nativeRuleRepository = NativeRuleRepository(applicationContext)
            nativeRuleChecker = NativeRuleChecker(nativeRuleRepository!!)
            nativeOverlayManager = NativeOverlayManager(applicationContext)
            monitorHandler = Handler(Looper.getMainLooper())

            // 首次延迟 1 秒启动（加快检测响应）
            monitorHandler?.postDelayed(monitorRunnable, INITIAL_DELAY_MS)
            Log.d(TAG, "Native monitoring started")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start native monitoring", e)
        }
    }

    /**
     * 停止原生监控循环
     */
    private fun stopNativeMonitoring() {
        monitorHandler?.removeCallbacks(monitorRunnable)
        monitorHandler = null
        nativeRuleChecker?.clearCache()
        nativeRuleRepository?.close()
        nativeOverlayManager?.destroy()
        nativeRuleRepository = null
        nativeRuleChecker = null
        nativeOverlayManager = null
        lastBlockedPackage = null
        Log.d(TAG, "Native monitoring stopped")
    }

    /**
     * 原生监控轮询 Runnable
     * 每 5 秒检测前台 App，检查规则，必要时显示锁定覆盖层或倒计时悬浮窗
     *
     * 分两步：
     *  步骤 A：倒计时恢复（独立于前台应用）。只要 DB 里有活跃倒计时，且 Flutter 已死，
     *         就保证原生倒计时悬浮窗显示并校准剩余时间；倒计时过期则触发强制休息。
     *         这是修复「划掉 App 后倒计时不再出现」的核心。
     * 步骤 B：针对前台受监控 App 的原有规则检查（时间段/总时间/每日上限/连续使用）。
     *         当 Flutter 死亡时，直接用 NativeOverlayManager 显示倒计时/锁屏，
     *         不依赖 WAKEUP_ENGINE（MIUI 会阻止后台 Activity 启动）。
     */
    private val monitorRunnable = object : Runnable {
        override fun run() {
            try {
                val now = System.currentTimeMillis()
                val foregroundApp = UsageStatsHelper.getCurrentForegroundApp(
                    applicationContext, packageName
                )

                // ===== 步骤 A：倒计时恢复（与前台应用无关）=====
                if (!MainActivity.isFlutterAlive) {
                    val remaining = checkActiveCountdown(now)
                    if (remaining != null) {
                        if (remaining > 0) {
                            // 清除可能与倒计时冲突的锁屏覆盖层残留
                            if (lastBlockedPackage != null) {
                                nativeOverlayManager?.hideOverlay()
                                lastBlockedPackage = null
                            }
                            if (nativeOverlayManager?.isCountdownShowing() != true) {
                                showNativeCountdown(remaining)
                            } else {
                                // 已经显示：每 5 秒用挂钟时间校准一次，防止 animator 漂移
                                nativeOverlayManager?.updateCountdownTime(remaining)
                            }
                        } else {
                            // 倒计时已过期 → 强制休息
                            nativeOverlayManager?.hideCountdownOverlay()
                            triggerNativeForcedRest(now)
                        }
                    }
                }

                // ===== 步骤 B：原有规则检查（针对前台受监控 App）=====
                if (foregroundApp != null) {
                    val result = nativeRuleChecker!!.checkApp(foregroundApp, now)

                    if (MainActivity.isFlutterAlive) {
                        // Flutter 引擎还活着 → 所有 UI 由 Flutter 侧处理，原生只清理残留
                        if (nativeOverlayManager?.isCountdownShowing() == true) {
                            nativeOverlayManager?.hideCountdownOverlay()
                        }
                        if (lastBlockedPackage != null) {
                            nativeOverlayManager?.hideOverlay()
                            lastBlockedPackage = null
                        }
                    } else {
                        // Flutter 死亡 → 原生接管所有 UI（锁屏 / 倒计时 / 强制休息）
                        // 不再尝试 WAKEUP_ENGINE（MIUI 阻止后台 Activity 启动）
                        if (result.blocked) {
                            // 阻止级别：显示锁屏前先清掉倒计时悬浮窗（锁屏优先级更高）
                            if (nativeOverlayManager?.isCountdownShowing() == true) {
                                nativeOverlayManager?.hideCountdownOverlay()
                            }
                            nativeOverlayManager!!.showLockOverlay(result.reason, foregroundApp)
                            lastBlockedPackage = foregroundApp
                            Log.d(TAG, "Blocked $foregroundApp: ${result.reason} (${result.ruleType})")
                        } else if (result.needsCountdown) {
                            // 需要倒计时但未被阻止：直接用原生倒计时悬浮窗显示
                            // 这是修复「划掉 App 后无提示」的核心改动
                            if (nativeOverlayManager?.isCountdownShowing() != true) {
                                showNativeCountdown(result.countdownSeconds)
                                // 持久化倒计时状态到 DB，让步骤 A 后续能独立维护
                                persistCountdownState(now, result.countdownSeconds)
                            } else {
                                nativeOverlayManager?.updateCountdownTime(result.countdownSeconds)
                            }
                            if (lastBlockedPackage != null) {
                                nativeOverlayManager?.hideOverlay()
                                lastBlockedPackage = null
                            }
                            Log.d(TAG, "Native countdown for $foregroundApp: remaining=${result.countdownSeconds}s (${result.ruleType})")
                        } else if (lastBlockedPackage == foregroundApp) {
                            nativeOverlayManager!!.hideOverlay()
                            lastBlockedPackage = null
                        }
                        // 注意：不再尝试 WAKEUP_ENGINE，完全由原生接管 UI
                    }
                } else {
                    // 无前台应用（启动器等被 isSystemUiApp 过滤）→ 只清理锁屏覆盖层残留。
                    // 重要：不再调用 hideCountdownOverlay()，倒计时由步骤 A 独立维护。
                    if (lastBlockedPackage != null) {
                        nativeOverlayManager?.hideOverlay()
                        lastBlockedPackage = null
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Native monitoring error", e)
            }

            monitorHandler?.postDelayed(this, MONITOR_INTERVAL_MS)
        }
    }

    // ==================== 倒计时恢复辅助方法 ====================

    /**
     * 从 DB 读取活跃会话的倒计时剩余秒数。
     *
     * 两条路径：
     *  Path 1（挂钟恢复，最高精度）：Flutter 侧已写入 countdownStartedAt + countdownTotalSeconds，
     *         按挂钟算术恢复剩余时间。
     *  Path 2（基于 session 估算，兜底）：Flutter 未持久化倒计时状态时（如进程被杀前未到倒计时阈值），
     *         根据 totalDurationSeconds + 自 lastActivityTime 以来的估算时间独立计算剩余时间。
     *
     * @return null = 无活跃倒计时；>0 = 剩余秒数；<=0 = 已过期，应触发强制休息。
     */
    private fun checkActiveCountdown(now: Long): Long? {
        val repo = nativeRuleRepository ?: return null
        val settings = repo.getContinuousUsageSettings()
        if (!settings.enabled) return null

        // 如果正在强制休息中，由步骤B的 forced_rest 分支处理
        val restRemaining = repo.getActiveRestRemainingSeconds()
        if (restRemaining > 0) return null

        val session = repo.getActiveContinuousSession() ?: return null

        // Path 1: 挂钟恢复（最高精度 - Flutter 成功持久化过的场景）
        val startedAt = session.countdownStartedAt
        val totalSec = session.countdownTotalSeconds
        if (startedAt != null && totalSec != null) {
            val endMs = startedAt + totalSec * 1000L
            return (endMs - now) / 1000L
        }

        // Path 2: 基于 session 数据的独立计算（Flutter 未持久化倒计时状态时的兜底）
        // 用 totalDurationSeconds + 自 lastActivityTime 以来的估算时间来计算剩余时间
        val lastActivity = session.lastActivityTime ?: return null
        // 服务重启后的时间间隔估算，上限为 resetAfterRestSeconds
        // （超过重置阈值时 session 本应被停用，不该再计时）
        val inactiveGapSeconds = ((now - lastActivity) / 1000L).coerceIn(0L, settings.resetAfterRestSeconds)
        val estimatedTotal = session.totalDurationSeconds + inactiveGapSeconds
        val remaining = settings.limitSeconds - estimatedTotal

        if (remaining <= 0) {
            // 使用时间已超限 → 触发强制休息
            return 0L
        }

        if (remaining <= 300 && remaining < settings.limitSeconds) {
            // 倒计时阈值内 → 持久化状态并返回剩余秒数
            // 持久化让后续步骤A用精确的挂钟 Path 1 维护
            persistCountdownState(now, remaining)
            return remaining
        }

        // 还有充足使用时间，不需要显示倒计时
        return null
    }

    /**
     * 显示原生倒计时悬浮窗并挂载 3/2 分钟提醒和结束回调。
     */
    private fun showNativeCountdown(remaining: Long) {
        val settings = nativeRuleRepository?.getContinuousUsageSettings()
        nativeOverlayManager?.showCountdownOverlayWithAlerts(
            remaining,
            onAlert3min = Runnable {
                try {
                    nativeOverlayManager?.showLockOverlay(
                        "连续使用还剩 3 分钟，请准备休息~", "", 0
                    )
                    monitorHandler?.postDelayed({
                        try { nativeOverlayManager?.hideOverlay() } catch (_: Exception) {}
                    }, 5000)
                } catch (e: Exception) {
                    Log.e(TAG, "3-min alert failed", e)
                }
            },
            onAlert2min = Runnable {
                try {
                    nativeOverlayManager?.showLockOverlay(
                        "连续使用还剩 2 分钟！请尽快结束！", "", 0
                    )
                    monitorHandler?.postDelayed({
                        try { nativeOverlayManager?.hideOverlay() } catch (_: Exception) {}
                    }, 5000)
                } catch (e: Exception) {
                    Log.e(TAG, "2-min alert failed", e)
                }
            },
            onEnded = Runnable {
                triggerNativeForcedRest(System.currentTimeMillis())
            }
        )
        Log.d(TAG, "Native countdown shown: remaining=${remaining}s, restSeconds=${settings?.restSeconds}")
    }

    /**
     * 原生触发强制休息：写 restEndTime、清空倒计时两列、显示锁屏覆盖层（带休息倒计时）。
     */
    private fun triggerNativeForcedRest(now: Long) {
        val repo = nativeRuleRepository ?: return
        val settings = repo.getContinuousUsageSettings()
        val session = repo.getActiveContinuousSession() ?: return
        val restEnd = now + settings.restSeconds * 1000L
        repo.updateContinuousSession(session.copy(
            totalDurationSeconds = settings.limitSeconds.coerceAtLeast(session.totalDurationSeconds),
            restEndTime = restEnd,
            countdownStartedAt = null,
            countdownTotalSeconds = null,
            updatedAt = now
        ))
        try {
            nativeOverlayManager?.showLockOverlay(
                "正在休息中，还需要 ${formatNativeRemainingTime(settings.restSeconds)}",
                "",
                settings.restSeconds.toInt()
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed to show forced rest lock overlay", e)
        }
        Log.d(TAG, "Native forced rest triggered: restEnd=$restEnd, restSeconds=${settings.restSeconds}")
    }

    private fun formatNativeRemainingTime(seconds: Long): String {
        val m = seconds / 60
        val s = seconds % 60
        return if (m > 0) "${m}分${s}秒" else "${s}秒"
    }

    /**
     * 将倒计时状态持久化到 DB（countdownStartedAt / countdownTotalSeconds）。
     * 让步骤 A 在后续轮询中能独立维护倒计时（不依赖前台 app 类型）。
     */
    private fun persistCountdownState(now: Long, remainingSeconds: Long) {
        val repo = nativeRuleRepository ?: return
        try {
            val session = repo.getActiveContinuousSession()
            if (session != null) {
                repo.updateContinuousSession(session.copy(
                    countdownStartedAt = now,
                    countdownTotalSeconds = remainingSeconds,
                    updatedAt = now
                ))
                Log.d(TAG, "Persisted countdown state: startedAt=$now, total=$remainingSeconds")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to persist countdown state", e)
        }
    }

    override fun onDestroy() {
        isRunning = false
        stopNativeMonitoring()
        Log.d(TAG, "Service destroyed")

        // 尝试重启服务
        try {
            // 1. 确保 WorkManager 保活任务在运行
            KeepAliveWorker.start(applicationContext)
            // 2. 发送重启广播（延迟执行）
            ServiceRestartReceiver.sendRestartBroadcast(applicationContext)
            Log.d(TAG, "Service restart triggered")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to trigger restart", e)
        }

        super.onDestroy()
    }

    /**
     * 当任务被移除时调用（用户在最近任务中滑掉App）
     *
     * MIUI force-stop 会取消 AlarmManager 闹钟，但 setAlarmClock 类型
     * 在某些 MIUI 版本上可能幸存。使用多种 PendingIntent 类型和
     * 多种闹钟调度方式增加幸存概率。
     */
    override fun onTaskRemoved(rootIntent: Intent?) {
        Log.d(TAG, "Task removed by user")

        // 1. 最先显示 AppLock（最重要，趁进程还活着）
        if (AppLockManager.isLockEnabled(applicationContext)) {
            Log.d(TAG, "App lock is enabled, showing overlay")
            try {
                AppLockOverlayActivity.start(applicationContext)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to show overlay", e)
            }
        }

        // 2. 尝试重启自身（趁进程还活着）
        try {
            val restartIntent = Intent(applicationContext, MonitorForegroundService::class.java)
            restartIntent.action = "START"
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                applicationContext.startForegroundService(restartIntent)
            } else {
                applicationContext.startService(restartIntent)
            }
            Log.d(TAG, "Service self-restart triggered")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to restart service", e)
        }

        // 3. 设置多种类型的冗余闹钟（增加幸存概率）
        try {
            scheduleRedundantAlarms(applicationContext)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to schedule redundant alarms", e)
        }

        super.onTaskRemoved(rootIntent)
    }

    /**
     * 设置多种类型的冗余闹钟
     *
     * MIUI 的 force-stop 取消闹钟行为因版本而异，使用多种 PendingIntent
     * 类型（Activity / ForegroundService）和多种调度方式
     * （setAlarmClock / setExactAndAllowWhileIdle）增加至少一种幸存概率。
     */
    private fun scheduleRedundantAlarms(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        // 类型 A: setAlarmClock + AlarmProxyActivity（当前主要方案）
        AlarmReceiver.setAlarm(context)
        AlarmReceiver.setQuickAlarm(context, 2000)

        // 类型 B: setExactAndAllowWhileIdle + ForegroundService（直接重启服务，无Activity开销）
        try {
            val fgIntent = Intent(context, MonitorForegroundService::class.java).apply {
                action = "START"
            }
            val fgPending = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                PendingIntent.getForegroundService(
                    context,
                    2001,
                    fgIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
            } else {
                PendingIntent.getService(
                    context,
                    2001,
                    fgIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP,
                    SystemClock.elapsedRealtime() + 5_000,
                    fgPending
                )
            } else {
                alarmManager.setExact(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP,
                    SystemClock.elapsedRealtime() + 5_000,
                    fgPending
                )
            }
            Log.d(TAG, "Redundant alarm (ForegroundService) set for 5s")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to set ForegroundService alarm", e)
        }

        // 类型 C: setExactAndAllowWhileIdle + AlarmProxyActivity（延迟稍长，防撞车）
        try {
            val proxyIntent = Intent(context, AlarmProxyActivity::class.java).apply {
                action = "REDUNDANT_KEEP_ALIVE"
            }
            val proxyPending = PendingIntent.getActivity(
                context,
                2002,
                proxyIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP,
                    SystemClock.elapsedRealtime() + 10_000,
                    proxyPending
                )
            } else {
                alarmManager.setExact(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP,
                    SystemClock.elapsedRealtime() + 10_000,
                    proxyPending
                )
            }
            Log.d(TAG, "Redundant alarm (AlarmProxyActivity) set for 10s")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to set ProxyActivity alarm", e)
        }
    }
}
