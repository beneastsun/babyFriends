package com.qiaoqiao.qiaoqiao_companion.services

import android.accessibilityservice.AccessibilityService
import android.util.Log
import android.view.accessibility.AccessibilityEvent

/**
 * 前台应用监听服务 — AccessibilityService 方案
 *
 * 在 MIUI 等系统上，UsageStatsManager.queryEvents() 可能返回空结果，
 * 导致原生监控引擎无法检测前台 app。
 * 此服务通过监听 TYPE_WINDOW_STATE_CHANGED 事件实时记录前台 app，
 * 作为 UsageStatsHelper 的二级 fallback。
 *
 * 使用方式：
 * - 在系统设置中开启本服务的无障碍权限
 * - UsageStatsHelper.getCurrentForegroundApp() 会自动调用 getLastForegroundApp()
 */
class ForegroundAppWatcher : AccessibilityService() {

    companion object {
        private const val TAG = "ForegroundAppWatcher"

        // 最近检测到的前台 app 包名
        @Volatile
        private var lastForegroundPackage: String? = null

        // 最近检测到的前台 app 时间戳
        @Volatile
        private var lastForegroundTime: Long = 0L

        // 服务是否已连接
        @Volatile
        private var isConnected: Boolean = false

        /**
         * 获取最近检测到的前台 app 包名。
         * 如果超过 30 秒没有更新，返回 null（app 可能已不在前台）。
         *
         * @param excludePackage 要排除的包名（通常是自身包名）
         * @return 前台 app 包名，或 null
         */
        fun getLastForegroundApp(excludePackage: String? = null): String? {
            if (!isConnected) return null

            val pkg = lastForegroundPackage
            val time = lastForegroundTime

            if (pkg == null) return null
            if (pkg == excludePackage) return null

            // 30 秒内有更新才认为有效
            val age = System.currentTimeMillis() - time
            if (age > 30_000L) {
                Log.d(TAG, "getLastForegroundApp: stale (age=${age}ms), returning null")
                return null
            }

            return pkg
        }

        /**
         * 检查服务是否已连接（无障碍权限已开启）
         */
        fun isServiceConnected(): Boolean = isConnected
    }

    override fun onServiceConnected() {
        isConnected = true
        Log.d(TAG, "AccessibilityService connected — foreground app monitoring active")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        val eventType = event.eventType
        if (eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            val packageName = event.packageName?.toString() ?: return

            // 过滤系统 UI
            if (isSystemUiApp(packageName)) return

            lastForegroundPackage = packageName
            lastForegroundTime = System.currentTimeMillis()

            Log.d(TAG, "Foreground changed: $packageName")
        }
    }

    override fun onInterrupt() {
        Log.w(TAG, "AccessibilityService interrupted")
    }

    override fun onDestroy() {
        isConnected = false
        lastForegroundPackage = null
        Log.d(TAG, "AccessibilityService destroyed")
        super.onDestroy()
    }

    private fun isSystemUiApp(packageName: String): Boolean {
        return packageName == "com.android.systemui" ||
                packageName == "com.miui.home" ||
                packageName == "com.android.launcher" ||
                packageName.contains("launcher", ignoreCase = true) ||
                packageName == "com.android.packageinstaller" ||
                packageName == "com.miui.securitycenter" ||
                packageName == "com.lbe.security.miui"
    }
}
