package com.qiaoqiao.qiaoqiao_companion

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.qiaoqiao.qiaoqiao_companion.channels.UsageStatsChannel
import com.qiaoqiao.qiaoqiao_companion.channels.OverlayChannel
import com.qiaoqiao.qiaoqiao_companion.channels.ServiceChannel
import com.qiaoqiao.qiaoqiao_companion.channels.AppLockChannel
import com.qiaoqiao.qiaoqiao_companion.services.GuardService
import com.qiaoqiao.qiaoqiao_companion.services.MonitorForegroundService

class MainActivity : FlutterActivity() {

    companion object {
        private const val APP_CHANNEL = "com.qiaoqiao.qiaoqiao_companion/app"

        /** Flutter 引擎是否存活，供原生监控服务判断是否需要显示覆盖层 */
        @Volatile
        var isFlutterAlive = false
            private set
    }

    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                Intent.ACTION_SCREEN_ON -> {
                    // 屏幕开启时启动服务
                    GuardService.start(this@MainActivity)
                    MonitorForegroundService.start(this@MainActivity)
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // 关键：在 super.onCreate() 之前启动前台服务！
        // super.onCreate() 会初始化 Flutter 引擎，耗时 2.5 秒
        // MIUI 会在 ~70ms 内将进程标记为"后台"，导致之后的 startForegroundService 被静默拒绝
        try {
            MonitorForegroundService.start(applicationContext)
            android.util.Log.d("MainActivity", "MonitorService start requested (before super.onCreate)")
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Failed to start MonitorService", e)
        }

        try {
            GuardService.start(applicationContext)
            android.util.Log.d("MainActivity", "GuardService start requested (before super.onCreate)")
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Failed to start GuardService", e)
        }

        super.onCreate(savedInstanceState)

        // 注册屏幕状态广播接收器
        val filter = IntentFilter(Intent.ACTION_SCREEN_ON)
        registerReceiver(screenReceiver, filter)
    }

    override fun onResume() {
        super.onResume()
        // 延迟启动服务：等 Activity 完全进入前台状态后再启动
        // MIUI 需要时间将 UID 状态从 idle 更新为 foreground
        Handler(Looper.getMainLooper()).postDelayed({
            try {
                if (!MonitorForegroundService.isServiceRunning()) {
                    MonitorForegroundService.start(applicationContext)
                    Log.d("MainActivity", "MonitorService start requested from onResume(delayed)")
                }
                if (!GuardService.isServiceRunning()) {
                    GuardService.start(applicationContext)
                    Log.d("MainActivity", "GuardService start requested from onResume(delayed)")
                }
            } catch (e: Exception) {
                Log.e("MainActivity", "Failed to start services from onResume", e)
            }
        }, 500) // 500ms 延迟，让 MIUI 有时间更新进程状态
    }

    override fun onDestroy() {
        isFlutterAlive = false
        super.onDestroy()
        try {
            unregisterReceiver(screenReceiver)
        } catch (e: Exception) {
            // Ignore
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        isFlutterAlive = true

        // 注册使用统计通道
        val usageStatsChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            UsageStatsChannel.CHANNEL_NAME
        )
        usageStatsChannel.setMethodCallHandler(UsageStatsChannel(this))

        // 注册悬浮窗通道
        val overlayChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            OverlayChannel.CHANNEL_NAME
        )
        overlayChannel.setMethodCallHandler(OverlayChannel(this, overlayChannel))

        // 注册前台服务通道
        val serviceChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ServiceChannel.CHANNEL_NAME
        )
        serviceChannel.setMethodCallHandler(ServiceChannel(this))

        // 注册App锁通道
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            AppLockChannel.CHANNEL_NAME
        ).setMethodCallHandler(AppLockChannel(this).apply { init() })

        // 注册应用控制通道
        val appChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            APP_CHANNEL
        )
        appChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "moveToBackground" -> {
                    moveTaskToBack(true)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
