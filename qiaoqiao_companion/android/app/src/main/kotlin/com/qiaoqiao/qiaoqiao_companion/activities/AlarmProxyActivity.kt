package com.qiaoqiao.qiaoqiao_companion.activities

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.util.Log
import com.qiaoqiao.qiaoqiao_companion.receivers.AlarmReceiver
import com.qiaoqiao.qiaoqiao_companion.services.GuardService
import com.qiaoqiao.qiaoqiao_companion.services.MonitorForegroundService

/**
 * 透明闹钟代理 Activity
 *
 * 当 setAlarmClock 闹钟触发时，系统启动此 Activity。
 * 使用 Activity 而非 BroadcastReceiver 是因为：
 * - MIUI 的 SwipeUpClean 会将 App 设为 stopped=true
 * - stopped=true 状态下 BroadcastReceiver 无法接收广播
 * - 但系统（system_server）有权限启动 Activity，即使 App 处于 stopped 状态
 * - 这使得闹钟可以在 MIUI 强杀后仍然触发服务重启
 *
 * 此 Activity 是完全透明的，用户不可见，启动服务后立即 finish
 */
class AlarmProxyActivity : Activity() {

    companion object {
        private const val TAG = "AlarmProxy"
        const val ACTION_RESTART_SERVICES = "com.qiaoqiao.qiaoqiao_companion.RESTART_SERVICES"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "AlarmProxyActivity triggered, restarting services...")

        try {
            // 启动守护服务
            GuardService.start(applicationContext)
            Log.d(TAG, "GuardService start triggered")

            // 启动主监控服务
            MonitorForegroundService.start(applicationContext)
            Log.d(TAG, "MonitorService start triggered")

            // 设置下一次闹钟
            AlarmReceiver.setAlarm(applicationContext)
            Log.d(TAG, "Next alarm scheduled")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to restart services", e)
        }

        // 立即关闭此透明 Activity
        finish()
    }
}
