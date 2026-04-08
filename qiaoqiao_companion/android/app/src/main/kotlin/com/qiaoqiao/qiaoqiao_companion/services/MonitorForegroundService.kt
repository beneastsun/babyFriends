package com.qiaoqiao.qiaoqiao_companion.services

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
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import com.qiaoqiao.qiaoqiao_companion.MainActivity
import com.qiaoqiao.qiaoqiao_companion.R
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
    private var currentTitle = "纹纹守护中"
    private var currentMessage = "正在保护你的健康使用习惯"

    // 原生监控组件（Flutter 引擎死亡时仍能工作）
    private var monitorHandler: Handler? = null
    private val MONITOR_INTERVAL_MS = 5_000L // 5秒检查一次
    private var nativeRuleRepository: NativeRuleRepository? = null
    private var nativeRuleChecker: NativeRuleChecker? = null
    private var nativeOverlayManager: NativeOverlayManager? = null
    private var lastBlockedPackage: String? = null

    override fun onCreate() {
        super.onCreate()
        notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        createNotificationChannel()
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
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "保持纹纹小伙伴在后台运行"
                setShowBadge(false)
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
            .setPriority(NotificationCompat.PRIORITY_LOW)
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

            // 首次延迟 2 秒启动，避免与其他初始化竞争
            monitorHandler?.postDelayed(monitorRunnable, 2000)
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
     * 每 5 秒检测前台 App，检查规则，必要时显示锁定覆盖层
     */
    private val monitorRunnable = object : Runnable {
        override fun run() {
            try {
                val foregroundApp = UsageStatsHelper.getCurrentForegroundApp(
                    applicationContext, packageName
                )

                if (foregroundApp != null) {
                    val result = nativeRuleChecker!!.checkApp(foregroundApp)
                    if (result.blocked) {
                        nativeOverlayManager!!.showLockOverlay(result.reason, foregroundApp)
                        lastBlockedPackage = foregroundApp
                        Log.d(TAG, "Blocked $foregroundApp: ${result.reason}")
                    } else if (lastBlockedPackage == foregroundApp) {
                        // 之前被阻止的 App 现在合规了（例如时间过了），移除覆盖层
                        nativeOverlayManager!!.hideOverlay()
                        lastBlockedPackage = null
                    }
                } else {
                    // 不在前台或在自己 App 中，移除覆盖层
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
     */
    override fun onTaskRemoved(rootIntent: Intent?) {
        Log.d(TAG, "Task removed by user")

        // 始终尝试重启自身（不仅限于 AppLock 启用时）
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

        // 同时设置闹钟作为备份重启机制
        try {
            AlarmReceiver.setQuickAlarm(applicationContext, 2000)
            AlarmReceiver.setAlarm(applicationContext)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to set alarm backup", e)
        }

        // 如果启用了防关闭锁，显示覆盖界面
        if (AppLockManager.isLockEnabled(applicationContext)) {
            Log.d(TAG, "App lock is enabled, showing overlay")
            try {
                AppLockOverlayActivity.start(applicationContext)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to show overlay", e)
            }
        }

        super.onTaskRemoved(rootIntent)
    }
}
