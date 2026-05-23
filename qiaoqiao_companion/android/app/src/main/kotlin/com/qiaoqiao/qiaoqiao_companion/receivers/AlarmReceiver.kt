package com.qiaoqiao.qiaoqiao_companion.receivers

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import android.util.Log
import com.qiaoqiao.qiaoqiao_companion.activities.AlarmProxyActivity
import com.qiaoqiao.qiaoqiao_companion.activities.AppLockOverlayActivity
import com.qiaoqiao.qiaoqiao_companion.managers.AppLockManager
import com.qiaoqiao.qiaoqiao_companion.services.GuardService
import com.qiaoqiao.qiaoqiao_companion.services.MonitorForegroundService

/**
 * 闹钟工具类
 * 作为最可靠的保活机制，即使进程被杀死也能唤醒
 *
 * 关键：使用 setAlarmClock() + AlarmProxyActivity 绕过 MIUI force-stop 限制。
 * 不直接使用 BroadcastReceiver 因为 MIUI force-stop 后 App 处于 stopped=true 状态，
 * BroadcastReceiver 无法接收广播，但 Activity PendingIntent 仍能被系统唤醒。
 *
 * 闹钟触发 → 系统启动 AlarmProxyActivity（透明） → 重启服务 → finish()
 */
class AlarmReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "AlarmReceiver"
        private const val REQUEST_CODE = 1001
        private const val ACTION_KEEP_ALIVE = "com.qiaoqiao.qiaoqiao_companion.KEEP_ALIVE"
        private const val ACTION_QUICK_RESTART = "com.qiaoqiao.qiaoqiao_companion.QUICK_RESTART"
        private const val INTERVAL_MS = 30_000L // 30秒（原60秒）

        /**
         * 设置定期闹钟
         * 使用 setAlarmClock() + AlarmProxyActivity (Activity PendingIntent)
         *
         * 使用 Activity 而非 BroadcastReceiver，因为：
         * - MIUI force-stop 会将 App 设为 stopped=true 状态
         * - stopped=true 时 BroadcastReceiver 无法接收任何广播
         * - 但 system_server 有权限启动 Activity，即使 App 处于 stopped 状态
         * - AlarmProxyActivity 是透明的，启动服务后立即 finish，不会闪烁
         */
        fun setAlarm(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

            // 使用 AlarmProxyActivity — 透明 Activity，可绕过 MIUI force-stop 的广播限制
            val alarmIntent = Intent(context, AlarmProxyActivity::class.java).apply {
                action = ACTION_KEEP_ALIVE
            }
            val pendingIntent = PendingIntent.getActivity(
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
                    Log.d(TAG, "Alarm set via setAlarmClock+ProxyActivity for ${INTERVAL_MS}ms")
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
         * 使用 AlarmProxyActivity 避免 BroadcastReceiver 在 force-stop 后失效
         */
        fun setQuickAlarm(context: Context, delayMs: Long) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

            val alarmIntent = Intent(context, AlarmProxyActivity::class.java).apply {
                action = ACTION_QUICK_RESTART
            }
            val pendingIntent = PendingIntent.getActivity(
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
            val keepIntent = Intent(context, AlarmProxyActivity::class.java).apply {
                action = ACTION_KEEP_ALIVE
            }
            val keepPending = PendingIntent.getActivity(
                context,
                REQUEST_CODE,
                keepIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            // 取消 QUICK_RESTART 闹钟
            val quickIntent = Intent(context, AlarmProxyActivity::class.java).apply {
                action = ACTION_QUICK_RESTART
            }
            val quickPending = PendingIntent.getActivity(
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

            // 检查是否需要显示 AppLock
            if (AppLockManager.shouldShowLock(context)) {
                AppLockOverlayActivity.start(context)
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

            // 检查是否需要显示 AppLock
            if (AppLockManager.shouldShowLock(context)) {
                AppLockOverlayActivity.start(context)
            }

        } catch (e: Exception) {
            Log.e(TAG, "Error in quick restart", e)
        }
    }
}
