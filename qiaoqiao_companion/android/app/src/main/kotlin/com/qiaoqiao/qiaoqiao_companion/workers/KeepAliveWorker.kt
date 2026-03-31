package com.qiaoqiao.qiaoqiao_companion.workers

import android.content.Context
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import com.qiaoqiao.qiaoqiao_companion.services.MonitorForegroundService
import java.util.concurrent.TimeUnit

/**
 * 后台保活 Worker
 * 定期检查并重启前台服务
 */
class KeepAliveWorker(
    context: Context,
    workerParams: WorkerParameters
) : CoroutineWorker(context, workerParams) {

    companion object {
        private const val TAG = "KeepAliveWorker"
        private const val WORK_NAME = "qiaoqiao_keep_alive_work"
        private const val INTERVAL_MINUTES = 15L // 每15分钟检查一次

        /**
         * 启动定期保活任务
         */
        fun start(context: Context) {
            val workRequest = PeriodicWorkRequestBuilder<KeepAliveWorker>(
                INTERVAL_MINUTES,
                TimeUnit.MINUTES
            )
                .setInitialDelay(1, TimeUnit.MINUTES)
                .build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WORK_NAME,
                ExistingPeriodicWorkPolicy.KEEP,
                workRequest
            )
            Log.d(TAG, "Keep-alive worker scheduled")
        }

        /**
         * 停止保活任务
         */
        fun stop(context: Context) {
            WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
            Log.d(TAG, "Keep-alive worker cancelled")
        }
    }

    override suspend fun doWork(): Result {
        Log.d(TAG, "Checking service status...")

        return try {
            // 检查服务是否在运行
            if (!MonitorForegroundService.isServiceRunning()) {
                Log.d(TAG, "Service not running, attempting to restart...")
                // 尝试重启服务
                MonitorForegroundService.start(applicationContext)
                Log.d(TAG, "Service restart triggered")
            } else {
                Log.d(TAG, "Service is running normally")
            }
            Result.success()
        } catch (e: Exception) {
            Log.e(TAG, "Error checking/restarting service", e)
            // 即使失败也返回 success，下次还会重试
            Result.success()
        }
    }
}
