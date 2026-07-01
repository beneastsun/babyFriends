package com.qiaoqiao.qiaoqiao_companion

import android.app.Application
import android.content.Context
import android.os.Build
import android.os.PowerManager
import android.util.Log
import androidx.work.Configuration
import com.qiaoqiao.qiaoqiao_companion.services.GuardService
import com.qiaoqiao.qiaoqiao_companion.services.MonitorForegroundService
import com.qiaoqiao.qiaoqiao_companion.workers.KeepAliveWorker

/**
 * 应用 Application 类
 * 初始化后台保活组件
 */
class QiaoqiaoApplication : Application(), Configuration.Provider {

    companion object {
        private const val TAG = "QiaoqiaoApplication"
    }

    override val workManagerConfiguration: Configuration
        get() = Configuration.Builder()
            .setMinimumLoggingLevel(Log.DEBUG)
            .build()

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Application onCreate")

        // 启动后台保活任务
        KeepAliveWorker.start(this)
        Log.d(TAG, "Keep-alive worker initialized")
    }
}
