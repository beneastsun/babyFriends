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
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import com.qiaoqiao.qiaoqiao_companion.MainActivity
import com.qiaoqiao.qiaoqiao_companion.R
import com.qiaoqiao.qiaoqiao_companion.receivers.AlarmReceiver

/**
 * 守护服务 - 独立进程运行
 * 负责监控并重启主服务和应用
 *
 * 关键特性：
 * 1. 使用 :guard 进程独立运行
 * 2. 定期检查主服务状态
 * 3. 使用 WakeLock 确保检查执行
 * 4. 通过 AlarmManager 确保定时任务
 */
class GuardService : Service() {

    companion object {
        private const val TAG = "GuardService"
        private const val CHANNEL_ID = "qiaoqiao_guard_channel"
        private const val CHANNEL_NAME = "纹纹守护进程"
        private const val NOTIFICATION_ID = 1002
        private const val CHECK_INTERVAL_MS = 30_000L // 30秒检查一次

        @Volatile
        private var isRunning = false

        fun start(context: Context) {
            val intent = Intent(context, GuardService::class.java)
            intent.action = "START"
            try {
                // 先尝试 startService（MIUI 对 startForegroundService 有额外限制）
                // 服务在 onCreate 中会调用 startForeground() 提升为前台服务
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    try {
                        context.startService(intent)
                        Log.d(TAG, "Started via startService()")
                    } catch (e: Exception) {
                        Log.w(TAG, "startService failed, trying startForegroundService", e)
                        context.startForegroundService(intent)
                    }
                } else {
                    context.startService(intent)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start guard service", e)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, GuardService::class.java)
            intent.action = "STOP"
            try {
                context.startService(intent)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to stop guard service", e)
            }
        }

        /**
         * 获取守护服务运行状态
         */
        fun isServiceRunning(): Boolean = isRunning
    }

    private var notificationManager: NotificationManager? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private val handler = Handler(Looper.getMainLooper())

    private val checkRunnable = object : Runnable {
        override fun run() {
            checkAndRestart()
            // 继续下一次检查
            handler.postDelayed(this, CHECK_INTERVAL_MS)
        }
    }

    override fun onCreate() {
        super.onCreate()
        notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        createNotificationChannel()
        // 在 onCreate 中立即调用 startForeground，满足 Android 12+ 的要求
        startAsForeground()
        acquireWakeLock()
        Log.d(TAG, "Guard service created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "START" -> {
                // startForeground 已在 onCreate 中调用
                startPeriodicCheck()
            }
            "STOP" -> {
                stopGuardService()
            }
            "CHECK" -> {
                checkAndRestart()
            }
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_MIN
            ).apply {
                description = "守护纹纹小伙伴运行"
                setShowBadge(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            notificationManager?.createNotificationChannel(channel)
        }
    }

    private var statusText = "守护服务启动中..."
    private var checkCount = 0
    private var lastCheckTime = 0L

    private fun buildNotification(): Notification {
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // 获取进程信息
        val processInfo = "进程: ${android.os.Process.myPid()}"

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("纹纹守护中 [PID:${android.os.Process.myPid()}]")
            .setContentText("$statusText | 检查次数: $checkCount")
            .setSmallIcon(R.drawable.ic_notification)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setStyle(NotificationCompat.BigTextStyle()
                .bigText("$statusText\n$processInfo | 检查: $checkCount | 上次: ${if (lastCheckTime > 0) java.text.SimpleDateFormat("HH:mm:ss", java.util.Locale.getDefault()).format(java.util.Date(lastCheckTime)) else "无"}"))
            .build()
    }

    private fun updateStatusNotification() {
        if (isRunning) {
            notificationManager?.notify(NOTIFICATION_ID, buildNotification())
        }
    }

    private fun startAsForeground() {
        if (isRunning) {
            Log.d(TAG, "Guard service already running")
            return
        }

        val notification = buildNotification()

        try {
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
            Log.d(TAG, "Guard service started as foreground")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start foreground", e)
        }
    }

    private fun acquireWakeLock() {
        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "qiaoqiao::guard_wakelock"
            )
            wakeLock?.acquire(10 * 60 * 1000L) // 最多10分钟
        } catch (e: Exception) {
            Log.e(TAG, "Failed to acquire wake lock", e)
        }
    }

    private fun releaseWakeLock() {
        try {
            wakeLock?.let {
                if (it.isHeld) {
                    it.release()
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to release wake lock", e)
        }
    }

    private fun startPeriodicCheck() {
        handler.removeCallbacks(checkRunnable)
        handler.postDelayed(checkRunnable, CHECK_INTERVAL_MS)

        // 同时设置 AlarmManager 作为备份
        AlarmReceiver.setAlarm(applicationContext)

        Log.d(TAG, "Periodic check started")
    }

    private fun checkAndRestart() {
        Log.d(TAG, "Checking services...")

        // 更新状态
        checkCount++
        lastCheckTime = System.currentTimeMillis()
        statusText = "检查服务状态中..."
        updateStatusNotification()

        try {
            // 使用 ActivityManager 检查主监控服务是否实际运行（跨进程可靠检测）
            if (!isServiceActuallyRunning(MonitorForegroundService::class.java.name)) {
                Log.d(TAG, "Monitor service not running, restarting...")
                statusText = "重启监控服务中..."
                updateStatusNotification()
                MonitorForegroundService.start(applicationContext)
            } else {
                statusText = "监控服务正常运行"
            }

            // 更新最终状态
            updateStatusNotification()
        } catch (e: Exception) {
            Log.e(TAG, "Error during check", e)
            statusText = "检查出错: ${e.message}"
            updateStatusNotification()
        }
    }

    /**
     * 使用 ActivityManager 检查服务是否实际运行
     * 这是跨进程检测服务的可靠方法
     */
    @Suppress("DEPRECATION")
    private fun isServiceActuallyRunning(serviceClassName: String): Boolean {
        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager

        // 对于 Android O+ 使用 getRunningServices 仍然可以获取自己的服务
        try {
            val services = activityManager.getRunningServices(Int.MAX_VALUE)
            for (serviceInfo in services) {
                if (serviceInfo.service.className == serviceClassName) {
                    return true
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error checking service status", e)
        }

        return false
    }

    private fun stopGuardService() {
        handler.removeCallbacks(checkRunnable)
        releaseWakeLock()
        AlarmReceiver.cancelAlarm(applicationContext)
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
        isRunning = false
        Log.d(TAG, "Guard service stopped")
    }

    override fun onDestroy() {
        isRunning = false
        handler.removeCallbacks(checkRunnable)
        releaseWakeLock()

        // 尝试重启
        try {
            AlarmReceiver.setAlarm(applicationContext)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to set restart alarm", e)
        }

        Log.d(TAG, "Guard service destroyed")
        super.onDestroy()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        Log.d(TAG, "Task removed, attempting to restart...")

        // 1. 直接重启自身（最可靠的方式）
        try {
            val restartIntent = Intent(applicationContext, GuardService::class.java)
            restartIntent.action = "START"
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                applicationContext.startForegroundService(restartIntent)
            } else {
                applicationContext.startService(restartIntent)
            }
            Log.d(TAG, "Guard self-restart triggered")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to self-restart", e)
        }

        // 2. 设置闹钟作为备份重启机制
        try {
            AlarmReceiver.setQuickAlarm(applicationContext, 2000)
            AlarmReceiver.setAlarm(applicationContext)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to set alarm", e)
        }

        super.onTaskRemoved(rootIntent)
    }
}
