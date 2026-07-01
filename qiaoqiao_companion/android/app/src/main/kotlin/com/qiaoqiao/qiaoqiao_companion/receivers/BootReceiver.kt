package com.qiaoqiao.qiaoqiao_companion.receivers

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import com.qiaoqiao.qiaoqiao_companion.services.GuardService
import com.qiaoqiao.qiaoqiao_companion.services.MonitorForegroundService
import com.qiaoqiao.qiaoqiao_companion.workers.KeepAliveWorker

/**
 * 开机自启动广播接收器
 * 监听系统启动完成广播，自动启动所有服务和保活机制
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
                // 启动所有服务和保活机制
                startAllServices(context)
            }
        }
    }

    /**
     * 启动所有服务和保活机制
     */
    private fun startAllServices(context: Context) {
        try {
            Log.d(TAG, "Starting all services on boot...")

            // 1. 启动守护服务（独立进程）
            GuardService.start(context)

            // 2. 启动主监控服务
            MonitorForegroundService.start(context)

            // 3. 启动 WorkManager 保活任务
            KeepAliveWorker.start(context)

            Log.d(TAG, "All services started successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start services on boot", e)
        }
    }
}
