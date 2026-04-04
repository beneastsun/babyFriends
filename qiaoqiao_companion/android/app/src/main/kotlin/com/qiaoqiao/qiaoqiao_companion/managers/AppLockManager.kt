package com.qiaoqiao.qiaoqiao_companion.managers

import android.content.Context

/**
 * App锁管理器
 * 管理防关闭锁屏的启用状态
 */
object AppLockManager {

    private const val PREFS_NAME = "app_lock_prefs"
    private const val KEY_LOCK_ENABLED = "lock_enabled"
    private const val KEY_LAST_TRIGGER_TIME = "last_trigger_time"

    /**
     * 检查锁屏是否启用
     */
    fun isLockEnabled(context: Context): Boolean {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getBoolean(KEY_LOCK_ENABLED, true) // 默认启用
    }

    /**
     * 设置锁屏启用状态
     */
    fun setLockEnabled(context: Context, enabled: Boolean) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putBoolean(KEY_LOCK_ENABLED, enabled).apply()
    }

    /**
     * 记录上次触发时间
     */
    fun setLastTriggerTime(context: Context, time: Long) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putLong(KEY_LAST_TRIGGER_TIME, time).apply()
    }

    /**
     * 获取上次触发时间
     */
    fun getLastTriggerTime(context: Context): Long {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getLong(KEY_LAST_TRIGGER_TIME, 0)
    }
}
