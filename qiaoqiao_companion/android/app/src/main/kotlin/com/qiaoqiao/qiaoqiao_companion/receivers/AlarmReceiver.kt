package com.qiaoqiao.qiaoqiao_companion.receivers

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import android.util.Log
import com.qiaoqiao.qiaoqiao_companion.services.GuardService
import com.qiaoqiao.qiaoqiao_companion.services.MonitorForegroundService

/**
 * 闹钟广播接收器
 * 作为最可靠的保活机制，即使进程被杀死也能唤醒
 *
 * 关键：使用 setAlarmClock() 设置闹钟，这是 Android 优先级最高的闹钟类型，
 * 即使 MIUI 等国产 ROM 也不会轻易取消这种闹钟
 */
class AlarmReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "AlarmReceiver"
        private const val REQUEST_CODE = 1001
        private const val ACTION_KEEP_ALIVE = "com.qiaoqiao.qiaoqiao_companion.KEEP_ALIVE"
        private const val ACTION_QUICK_RESTART = "com.qiaoqiao.qiaoqiao_companion.QUICK_RESTART"
        private const val INTERVAL_MS = 60_000L // 1分钟

        /**
         * 设置定期闹钟
         * 使用 setAlarmClock() + BroadcastReceiver PendingIntent
         *
         * 使用 BroadcastReceiver 而非 Activity，因为：
         * - Activity PendingIntent 每60秒启动 Activity 会导致屏幕闪烁
         * - MIUI force-stop 会取消所有闹钟（无论 Activity 还是 Broadcast），Activity 无额外优势
         * - BroadcastReceiver 在标准 Android 上正常工作
         */
        fun setAlarm(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

            // 使用 BroadcastReceiver PendingIntent — 无闪烁
            val alarmIntent = Intent(context, AlarmReceiver::class.java).apply {
                action = ACTION_KEEP_ALIVE
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                REQUEST_CODE,
                alarmIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            try {
                // setAlarmClock — 最高优先级，系统将其视为用户设置的闹钟
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    val showIntent = PendingIntent.getActivity(
                        context,
                        0,
                        Intent(context, Class.forName("com.qiaoqiao.qiaoqiao_companion.MainActivity")),
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    val alarmClockInfo = AlarmManager.AlarmClockInfo(
                        System.currentTimeMillis() + INTERVAL_MS,
                        showIntent
                    )
                    alarmManager.setAlarmClock(alarmClockInfo, pendingIntent)
                    Log.d(TAG, "Alarm set via setAlarmClock+Broadcast for ${INTERVAL_MS}ms")
                } else {
                    alarmManager.setExact(
                        AlarmManager.ELAPSED_REALTIME_WAKEUP,
                        SystemClock.elapsedRealtime() + INTERVAL_MS,
                        pendingIntent
                    )
                }
            } catch (e: Exception) {
                Log.e(TAG, "setAlarmClock failed, trying fallback", e)
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        alarmManager.setExactAndAllowWhileIdle(
                            AlarmManager.ELAPSED_REALTIME_WAKEUP,
                            SystemClock.elapsedRealtime() + INTERVAL_MS,
                            pendingIntent
                        )
                    } else {
                        alarmManager.setExact(
                            AlarmManager.ELAPSED_REALTIME_WAKEUP,
                            SystemClock.elapsedRealtime() + INTERVAL_MS,
                            pendingIntent
                        )
                    }
                } catch (e2: Exception) {
                    Log.e(TAG, "All alarm methods failed", e2)
                }
            }
        }

        /**
         * 设置快速重启闹钟（用于任务被移除时）
         * 使用 BroadcastReceiver 避免闪烁
         */
        fun setQuickAlarm(context: Context, delayMs: Long) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

            val alarmIntent = Intent(context, AlarmReceiver::class.java).apply {
                action = ACTION_QUICK_RESTART
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                REQUEST_CODE + 1,
                alarmIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    val showIntent = PendingIntent.getActivity(
                        context,
                        1,
                        Intent(context, Class.forName("com.qiaoqiao.qiaoqiao_companion.MainActivity")),
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    val alarmClockInfo = AlarmManager.AlarmClockInfo(
                        System.currentTimeMillis() + delayMs,
                        showIntent
                    )
                    alarmManager.setAlarmClock(alarmClockInfo, pendingIntent)
                } else {
                    alarmManager.setExact(
                        AlarmManager.ELAPSED_REALTIME_WAKEUP,
                        SystemClock.elapsedRealtime() + delayMs,
                        pendingIntent
                    )
                }
                Log.d(TAG, "Quick alarm set for ${delayMs}ms")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to set quick alarm", e)
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        alarmManager.setExactAndAllowWhileIdle(
                            AlarmManager.ELAPSED_REALTIME_WAKEUP,
                            SystemClock.elapsedRealtime() + delayMs,
                            pendingIntent
                        )
                    } else {
                        alarmManager.setExact(
                            AlarmManager.ELAPSED_REALTIME_WAKEUP,
                            SystemClock.elapsedRealtime() + delayMs,
                            pendingIntent
                        )
                    }
                } catch (e2: Exception) {
                    Log.e(TAG, "All quick alarm methods failed", e2)
                }
            }
        }

        /**
         * 取消闹钟
         */
        fun cancelAlarm(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

            // 取消 KEEP_ALIVE 闹钟
            val keepIntent = Intent(context, AlarmReceiver::class.java).apply {
                action = ACTION_KEEP_ALIVE
            }
            val keepPending = PendingIntent.getBroadcast(
                context,
                REQUEST_CODE,
                keepIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            // 取消 QUICK_RESTART 闹钟
            val quickIntent = Intent(context, AlarmReceiver::class.java).apply {
                action = ACTION_QUICK_RESTART
            }
            val quickPending = PendingIntent.getBroadcast(
                context,
                REQUEST_CODE + 1,
                quickIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            try {
                alarmManager.cancel(keepPending)
                alarmManager.cancel(quickPending)
                Log.d(TAG, "Alarms cancelled")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to cancel alarm", e)
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "Received alarm: ${intent.action}")

        when (intent.action) {
            ACTION_KEEP_ALIVE -> {
                handleKeepAlive(context)
            }
            ACTION_QUICK_RESTART -> {
                handleQuickRestart(context)
            }
        }
    }

    private fun handleKeepAlive(context: Context) {
        try {
            // 启动守护服务（如果没运行）
            if (!GuardService.isServiceRunning()) {
                Log.d(TAG, "Guard service not running, starting...")
                GuardService.start(context)
            }

            // 启动主监控服务（如果没运行）
            if (!MonitorForegroundService.isServiceRunning()) {
                Log.d(TAG, "Monitor service not running, starting...")
                MonitorForegroundService.start(context)
            }

            // 设置下一次闹钟
            setAlarm(context)

        } catch (e: Exception) {
            Log.e(TAG, "Error in keep alive", e)
        }
    }

    private fun handleQuickRestart(context: Context) {
        try {
            Log.d(TAG, "Quick restart triggered")

            // 启动守护服务
            GuardService.start(context)

            // 启动主监控服务
            MonitorForegroundService.start(context)

        } catch (e: Exception) {
            Log.e(TAG, "Error in quick restart", e)
        }
    }
}
