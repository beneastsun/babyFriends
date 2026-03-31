package com.qiaoqiao.qiaoqiao_companion.receivers

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.qiaoqiao.qiaoqiao_companion.services.MonitorForegroundService

/**
 * 开机自启动广播接收器
 * 监听系统启动完成广播，自动启动监控服务
 */
class BootReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "BootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "Received broadcast: ${intent.action}")

        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON" -> {
                // 启动前台服务
                startMonitorService(context)
            }
        }
    }

    /**
     * 启动监控服务
     */
    private fun startMonitorService(context: Context) {
        try {
            Log.d(TAG, "Starting monitor service on boot")
            MonitorForegroundService.start(context)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start monitor service on boot", e)
        }
    }
}
