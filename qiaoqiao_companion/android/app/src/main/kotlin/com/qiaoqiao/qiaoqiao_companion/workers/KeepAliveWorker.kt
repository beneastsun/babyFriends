package com.qiaoqiao.qiaoqiao_companion.workers

import android.content.Context
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import com.qiaoqiao.qiaoqiao_companion.activities.AppLockOverlayActivity
import com.qiaoqiao.qiaoqiao_companion.managers.AppLockManager
import com.qiaoqiao.qiaoqiao_companion.receivers.AlarmReceiver
import com.qiaoqiao.qiaoqiao_companion.services.GuardService
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
            // 检查并启动守护服务
            if (!GuardService.isServiceRunning()) {
                Log.d(TAG, "Guard service not running, starting...")
                GuardService.start(applicationContext)
            }

            // 检查并启动主监控服务
            if (!MonitorForegroundService.isServiceRunning()) {
                Log.d(TAG, "Monitor service not running, starting...")
                MonitorForegroundService.start(applicationContext)
            }

            // 确保 AlarmManager 闹钟在运行
            AlarmReceiver.setAlarm(applicationContext)

            // 检查是否需要显示 AppLock
            if (AppLockManager.shouldShowLock(applicationContext)) {
                AppLockOverlayActivity.start(applicationContext)
            }

            Log.d(TAG, "Keep-alive check completed")
            Result.success()
        } catch (e: Exception) {
            Log.e(TAG, "Error checking/restarting service", e)
            Result.success()
        }
    }
}
