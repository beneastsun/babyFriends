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
import com.qiaoqiao.qiaoqiao_companion.channels.OverlayChannel
import com.qiaoqiao.qiaoqiao_companion.managers.AppLockManager
import com.qiaoqiao.qiaoqiao_companion.monitor.EnforcementEngine
import com.qiaoqiao.qiaoqiao_companion.monitor.NativeContinuousUsageTracker
import com.qiaoqiao.qiaoqiao_companion.monitor.NativeOverlayManager
import com.qiaoqiao.qiaoqiao_companion.monitor.NativeRuleRepository
import com.qiaoqiao.qiaoqiao_companion.monitor.RuleEvaluator
import com.qiaoqiao.qiaoqiao_companion.monitor.WidgetManager
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

    // 原生监控引擎（Flutter 引擎死亡时仍能工作）
    private var monitorHandler: Handler? = null
    private val MONITOR_INTERVAL_MS = 5_000L // 5秒检查一次
    private val INITIAL_DELAY_MS = 1_000L // 首次延迟1秒
    private var engine: EnforcementEngine? = null

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
            // 清除 Flutter 侧 OverlayChannel 可能残留的旧 widget，
            // 防止与 EnforcementEngine 的新 widget 同时显示
            try {
                OverlayChannel.instance?.clearAllOverlays()
            } catch (e: Exception) {
                Log.w(TAG, "Failed to clear OverlayChannel overlays", e)
            }

            val repository = NativeRuleRepository(applicationContext)
            val ruleEvaluator = RuleEvaluator(repository)
            val usageTracker = NativeContinuousUsageTracker(repository)
            val overlayManager = NativeOverlayManager(applicationContext)
            overlayManager.clearAllOverlays()  // 清除可能残留的旧原生 overlay
            val widgetManager = WidgetManager(overlayManager)

            engine = EnforcementEngine(
                repository = repository,
                ruleEvaluator = ruleEvaluator,
                usageTracker = usageTracker,
                widgetManager = widgetManager,
                overlayManager = overlayManager
            )

            // 从 DB 恢复状态（进程被杀后重启时，可能存在活跃倒计时或休息中）
            engine!!.restoreFromDB(System.currentTimeMillis())

            monitorHandler = Handler(Looper.getMainLooper())

            // 首次延迟 1 秒启动（加快检测响应）
            monitorHandler?.postDelayed(monitorRunnable, INITIAL_DELAY_MS)
            Log.d(TAG, "Native monitoring started with EnforcementEngine")
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
        engine?.destroy()
        engine = null
        Log.d(TAG, "Native monitoring stopped")
    }

    /**
     * 原生监控轮询 Runnable
     * 每 5 秒检测前台 App，委托 EnforcementEngine 处理状态机逻辑
     */
    private val monitorRunnable = object : Runnable {
        override fun run() {
            try {
                val now = System.currentTimeMillis()
                val foregroundApp = UsageStatsHelper.getCurrentForegroundApp(
                    applicationContext, packageName
                )

                // 委托 EnforcementEngine 处理所有规则检查和 UI 决策
                engine?.onPoll(now, foregroundApp)
            } catch (e: Exception) {
                Log.e(TAG, "Native monitoring error", e)
            }

            monitorHandler?.postDelayed(this, MONITOR_INTERVAL_MS)
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

        // 0. 让引擎持久化内存状态（倒计时等），以便重启后能恢复
        engine?.persistStateBeforeDeath()

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
