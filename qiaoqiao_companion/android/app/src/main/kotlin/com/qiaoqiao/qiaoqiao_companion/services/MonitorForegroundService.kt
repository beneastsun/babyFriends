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
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import com.qiaoqiao.qiaoqiao_companion.MainActivity
import com.qiaoqiao.qiaoqiao_companion.R
import com.qiaoqiao.qiaoqiao_companion.receivers.ServiceRestartReceiver
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
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
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

    override fun onCreate() {
        super.onCreate()
        notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        createNotificationChannel()
        Log.d(TAG, "Service created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "START" -> {
                startAsForeground()
            }
            "STOP" -> {
                stopForegroundService()
            }
            "UPDATE" -> {
                currentTitle = intent.getStringExtra("title") ?: currentTitle
                currentMessage = intent.getStringExtra("message") ?: currentMessage
                updateNotification()
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
            .setContentTitle(currentTitle)
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

    override fun onDestroy() {
        isRunning = false
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
}
