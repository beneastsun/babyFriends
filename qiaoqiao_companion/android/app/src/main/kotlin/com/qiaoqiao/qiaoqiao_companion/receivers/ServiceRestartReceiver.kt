package com.qiaoqiao.qiaoqiao_companion.receivers

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.qiaoqiao.qiaoqiao_companion.services.MonitorForegroundService
import com.qiaoqiao.qiaoqiao_companion.workers.KeepAliveWorker

/**
 * 服务重启广播接收器
 * 监听服务被销毁的广播并尝试重启
 */
class ServiceRestartReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "ServiceRestartReceiver"
        const val ACTION_RESTART_SERVICE = "com.qiaoqiao.qiaoqiao_companion.RESTART_SERVICE"

        /**
         * 发送重启服务的广播
         */
        fun sendRestartBroadcast(context: Context) {
            val intent = Intent(ACTION_RESTART_SERVICE)
            intent.setPackage(context.packageName)
            context.sendBroadcast(intent)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "Received broadcast: ${intent.action}")

        when (intent.action) {
            ACTION_RESTART_SERVICE -> {
                try {
                    Log.d(TAG, "Restarting service...")
                    // 重启前台服务
                    MonitorForegroundService.start(context)
                    // 确保 WorkManager 也在运行
                    KeepAliveWorker.start(context)
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to restart service", e)
                }
            }
        }
    }
}
