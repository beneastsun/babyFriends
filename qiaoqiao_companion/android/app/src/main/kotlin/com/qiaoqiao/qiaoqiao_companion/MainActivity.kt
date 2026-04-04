package com.qiaoqiao.qiaoqiao_companion

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.qiaoqiao.qiaoqiao_companion.channels.UsageStatsChannel
import com.qiaoqiao.qiaoqiao_companion.channels.OverlayChannel
import com.qiaoqiao.qiaoqiao_companion.channels.ServiceChannel
import com.qiaoqiao.qiaoqiao_companion.channels.AppLockChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val APP_CHANNEL = "com.qiaoqiao.qiaoqiao_companion/app"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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
