package com.qiaoqiao.qiaoqiao_companion.channels

import android.content.Context
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import com.qiaoqiao.qiaoqiao_companion.managers.AppLockManager
import com.qiaoqiao.qiaoqiao_companion.features.parent_mode.data.ParentPasswordRepository

/**
 * App锁通道
 * Flutter与原生锁屏功能的通信桥梁
 */
class AppLockChannel(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "AppLockChannel"
        const val CHANNEL_NAME = "com.qiaoqiao.qiaoqiao_companion/app_lock"
    }

    private lateinit var passwordRepository: ParentPasswordRepository

    fun init() {
        passwordRepository = ParentPasswordRepository(context)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isLockEnabled" -> {
                isLockEnabled(result)
            }
            "setLockEnabled" -> {
                val enabled = call.argument<Boolean>("enabled") ?: true
                setLockEnabled(enabled, result)
            }
            "verifyPassword" -> {
                val password = call.argument<String>("password")
                if (password != null) {
                    verifyPassword(password, result)
                } else {
                    result.error("INVALID_ARGUMENT", "Password is required", null)
                }
            }
            "getLastTriggerTime" -> {
                getLastTriggerTime(result)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun isLockEnabled(result: MethodChannel.Result) {
        try {
            val enabled = AppLockManager.isLockEnabled(context)
            result.success(enabled)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to check lock enabled", e)
            result.error("LOCK_ERROR", e.message, null)
        }
    }

    private fun setLockEnabled(enabled: Boolean, result: MethodChannel.Result) {
        try {
            AppLockManager.setLockEnabled(context, enabled)
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to set lock enabled", e)
            result.error("LOCK_ERROR", e.message, null)
        }
    }

    private fun verifyPassword(password: String, result: MethodChannel.Result) {
        try {
            val isValid = passwordRepository.verifyPassword(password)
            result.success(isValid)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to verify password", e)
            result.error("AUTH_ERROR", e.message, null)
        }
    }

    private fun getLastTriggerTime(result: MethodChannel.Result) {
        try {
            val time = AppLockManager.getLastTriggerTime(context)
            result.success(time)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get last trigger time", e)
            result.error("LOCK_ERROR", e.message, null)
        }
    }
}
