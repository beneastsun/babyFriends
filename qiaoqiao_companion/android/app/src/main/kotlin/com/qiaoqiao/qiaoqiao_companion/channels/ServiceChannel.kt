package com.qiaoqiao.qiaoqiao_companion.channels

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import com.qiaoqiao.qiaoqiao_companion.services.MonitorForegroundService
import com.qiaoqiao.qiaoqiao_companion.utils.RomUtils

/**
 * 前台服务通道
 * Flutter与原生服务通信的桥梁
 */
class ServiceChannel(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "com.qiaoqiao.qiaoqiao_companion/service"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startForegroundService" -> {
                startForegroundService(result)
            }
            "stopForegroundService" -> {
                stopForegroundService(result)
            }
            "isServiceRunning" -> {
                isServiceRunning(result)
            }
            "updateNotification" -> {
                val title = call.argument<String>("title")
                val message = call.argument<String>("message")
                updateNotification(title, message, result)
            }
            "checkAutoStartPermission" -> {
                checkAutoStartPermission(result)
            }
            "openAutoStartSettings" -> {
                openAutoStartSettings(result)
            }
            "getRomType" -> {
                getRomType(result)
            }
            "checkBatteryOptimization" -> {
                checkBatteryOptimization(result)
            }
            "openBatterySettings" -> {
                openBatterySettings(result)
            }
            "openPowerSavingSettings" -> {
                openPowerSavingSettings(result)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    /**
     * 启动前台服务
     */
    private fun startForegroundService(result: MethodChannel.Result) {
        try {
            MonitorForegroundService.start(context)
            result.success(true)
        } catch (e: Exception) {
            result.error("SERVICE_ERROR", e.message, null)
        }
    }

    /**
     * 停止前台服务
     */
    private fun stopForegroundService(result: MethodChannel.Result) {
        try {
            MonitorForegroundService.stop(context)
            result.success(true)
        } catch (e: Exception) {
            result.error("SERVICE_ERROR", e.message, null)
        }
    }

    /**
     * 检查服务是否正在运行
     */
    private fun isServiceRunning(result: MethodChannel.Result) {
        result.success(MonitorForegroundService.isServiceRunning())
    }

    /**
     * 更新通知内容
     */
    private fun updateNotification(
        title: String?,
        message: String?,
        result: MethodChannel.Result
    ) {
        try {
            if (title != null && message != null) {
                MonitorForegroundService.updateNotification(context, title, message)
            }
            result.success(true)
        } catch (e: Exception) {
            result.error("SERVICE_ERROR", e.message, null)
        }
    }

    /**
     * 检查是否需要自启动权限引导
     */
    private fun checkAutoStartPermission(result: MethodChannel.Result) {
        val romType = RomUtils.getRomType(context)
        val needsPermission = when (romType) {
            RomUtils.RomType.MIUI -> true
            RomUtils.RomType.EMUI -> true
            RomUtils.RomType.HARMONY -> true
            RomUtils.RomType.COLOR_OS -> true
            RomUtils.RomType.FUNTOUCH_OS -> true
            RomUtils.RomType.ORIGIN_OS -> true
            RomUtils.RomType.ONE_UI -> true
            else -> false
        }
        result.success(needsPermission)
    }

    /**
     * 打开自启动设置页面
     */
    private fun openAutoStartSettings(result: MethodChannel.Result) {
        try {
            val intent = RomUtils.getAutoStartSettingIntent(context)
            if (intent != null) {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
                result.success(true)
            } else {
                result.success(false)
            }
        } catch (e: Exception) {
            result.error("SETTINGS_ERROR", e.message, null)
        }
    }

    /**
     * 获取ROM类型
     */
    private fun getRomType(result: MethodChannel.Result) {
        val romType = RomUtils.getRomType(context)
        result.success(romType.name)
    }

    /**
     * 检查是否忽略电池优化
     */
    private fun checkBatteryOptimization(result: MethodChannel.Result) {
        val isIgnoring = RomUtils.isIgnoringBatteryOptimizations(context)
        result.success(isIgnoring)
    }

    /**
     * 打开电池优化设置
     */
    private fun openBatterySettings(result: MethodChannel.Result) {
        try {
            val intent = RomUtils.getBatteryOptimizationIntent(context)
            if (intent != null) {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
                result.success(true)
            } else {
                result.success(false)
            }
        } catch (e: Exception) {
            result.error("SETTINGS_ERROR", e.message, null)
        }
    }

    /**
     * 打开省电设置
     */
    private fun openPowerSavingSettings(result: MethodChannel.Result) {
        try {
            val intent = RomUtils.getPowerSavingSettingIntent(context)
            if (intent != null) {
                context.startActivity(intent)
                result.success(true)
            } else {
                result.success(false)
            }
        } catch (e: Exception) {
            result.error("SETTINGS_ERROR", e.message, null)
        }
    }
}
