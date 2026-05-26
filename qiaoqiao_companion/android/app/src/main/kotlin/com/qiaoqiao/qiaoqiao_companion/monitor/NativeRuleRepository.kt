package com.qiaoqiao.qiaoqiao_companion.monitor

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.util.Log
import java.io.File
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/**
 * 原生规则数据仓库
 * 直接读取 Flutter sqflite 创建的 SQLite 数据库，查询监控规则和使用数据
 */
class NativeRuleRepository(private val context: Context) {

    companion object {
        private const val TAG = "NativeRuleRepo"
        private const val DB_NAME = "qiaoqiao_companion.db"

        // SharedPreferences keys（与 Flutter 侧保持一致）
        private const val KEY_ENABLED = "continuous_usage_limit_enabled"
        private const val KEY_LIMIT_MINUTES = "continuous_usage_limit_minutes"
        private const val KEY_REST_MINUTES = "continuous_rest_minutes"
        private const val KEY_RESET_AFTER_REST_MINUTES = "continuous_reset_after_rest_minutes"

        // 默认值
        private const val DEFAULT_CONTINUOUS_ENABLED = false
        private const val DEFAULT_LIMIT_MINUTES = 30
        private const val DEFAULT_REST_MINUTES = 10
        private const val DEFAULT_RESET_AFTER_REST_MINUTES = 1
    }

    private var db: SQLiteDatabase? = null

    /**
     * 受监控应用信息
     */
    data class MonitoredApp(
        val packageName: String,
        val dailyLimitMinutes: Int?
    )

    /**
     * 时间段规则
     */
    data class TimePeriod(
        val mode: String,       // "blocked" 或 "allowed"
        val timeStart: String,  // "HH:mm" 格式
        val timeEnd: String,    // "HH:mm" 格式
        val days: String        // JSON 数组，如 "[1,2,3,4,5]" 表示周一到周五
    )

    /**
     * 总时间规则
     */
    data class TotalTimeRule(
        val weekdayLimit: Int?,  // 周一到周五限制（分钟）
        val weekendLimit: Int?   // 周六到周日限制（分钟）
    )

    /**
     * 规则检查结果
     */
    data class CheckResult(
        val blocked: Boolean,
        val reason: String
    )

    /**
     * 连续使用会话
     */
    data class ContinuousSession(
        val id: Long? = null,
        val sessionDate: String,
        val startTime: Long,
        var totalDurationSeconds: Long = 0L,
        val lastActivityTime: Long? = null,
        val restEndTime: Long? = null,
        val alertsShown: Set<String> = emptySet(),
        val isActive: Boolean = true,
        val createdAt: Long = System.currentTimeMillis(),
        val updatedAt: Long = System.currentTimeMillis()
    )

    /**
     * 连续使用设置
     */
    data class ContinuousUsageSettings(
        val enabled: Boolean = DEFAULT_CONTINUOUS_ENABLED,
        val limitMinutes: Int = DEFAULT_LIMIT_MINUTES,
        val restMinutes: Int = DEFAULT_REST_MINUTES,
        val resetAfterRestMinutes: Int = DEFAULT_RESET_AFTER_REST_MINUTES
    ) {
        val limitSeconds: Long get() = limitMinutes * 60L
        val restSeconds: Long get() = restMinutes * 60L
        val resetAfterRestSeconds: Long get() = resetAfterRestMinutes * 60L
    }

    /**
     * 打开数据库（只读）
     */
    private fun openDatabase(): SQLiteDatabase? {
        if (db != null && db!!.isOpen) return db

        return try {
            val dbPath = File(context.filesDir.parentFile, "databases/$DB_NAME")
            if (!dbPath.exists()) {
                Log.w(TAG, "Database file not found: ${dbPath.absolutePath}")
                return null
            }
            db = SQLiteDatabase.openDatabase(
                dbPath.absolutePath,
                null,
                SQLiteDatabase.OPEN_READONLY
            )
            db
        } catch (e: Exception) {
            Log.e(TAG, "Failed to open database", e)
            null
        }
    }

    /**
     * 打开数据库（读写）
     */
    private fun openWritableDatabase(): SQLiteDatabase? {
        if (db != null && db!!.isOpen) {
            if (!db!!.isReadOnly) return db
            db!!.close()
        }

        return try {
            val dbPath = File(context.filesDir.parentFile, "databases/$DB_NAME")
            if (!dbPath.exists()) {
                Log.w(TAG, "Database file not found: ${dbPath.absolutePath}")
                return null
            }
            db = SQLiteDatabase.openDatabase(
                dbPath.absolutePath,
                null,
                SQLiteDatabase.OPEN_READWRITE
            )
            db
        } catch (e: Exception) {
            Log.e(TAG, "Failed to open writable database", e)
            null
        }
    }

    // ==================== 连续使用会话 CRUD ====================

    /**
     * 获取今日活跃的连续使用会话
     */
    fun getActiveContinuousSession(): ContinuousSession? {
        val database = openDatabase() ?: return null
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())

        return try {
            val cursor = database.query(
                "continuous_usage_sessions",
                null,
                "session_date = ? AND is_active = 1",
                arrayOf(today),
                null,
                null,
                "start_time DESC"
            )
            cursor.use {
                if (it.moveToFirst()) parseContinuousSession(it) else null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to query active session", e)
            null
        }
    }

    /**
     * 获取今日处于休息状态的会话（有 rest_end_time 且未过期）
     */
    fun getRestingSession(): ContinuousSession? {
        val database = openDatabase() ?: return null
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
        val now = System.currentTimeMillis()

        return try {
            val cursor = database.query(
                "continuous_usage_sessions",
                null,
                "session_date = ? AND is_active = 1 AND rest_end_time IS NOT NULL AND rest_end_time > ?",
                arrayOf(today, now.toString()), null, null, null, "1"
            )
            cursor.use {
                if (it.moveToFirst()) parseContinuousSession(it) else null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to query resting session", e)
            null
        }
    }

    /**
     * 插入连续使用会话
     */
    fun insertContinuousSession(session: ContinuousSession): Long? {
        val database = openWritableDatabase() ?: return null
        val now = System.currentTimeMillis()

        return try {
            val values = android.content.ContentValues().apply {
                put("session_date", session.sessionDate)
                put("start_time", session.startTime)
                put("total_duration_seconds", session.totalDurationSeconds)
                put("last_activity_time", session.lastActivityTime ?: now)
                put("alerts_shown", session.alertsShown.joinToString(","))
                put("is_active", if (session.isActive) 1 else 0)
                put("created_at", session.createdAt)
                put("updated_at", now)
            }
            val id = database.insertOrThrow("continuous_usage_sessions", null, values)
            Log.d(TAG, "Inserted session: id=$id, date=${session.sessionDate}")
            id
        } catch (e: Exception) {
            Log.e(TAG, "Failed to insert session", e)
            null
        }
    }

    /**
     * 更新连续使用会话
     */
    fun updateContinuousSession(session: ContinuousSession): Boolean {
        val database = openWritableDatabase() ?: return false
        val now = System.currentTimeMillis()

        return try {
            val values = android.content.ContentValues().apply {
                put("total_duration_seconds", session.totalDurationSeconds)
                put("last_activity_time", session.lastActivityTime ?: now)
                if (session.restEndTime != null) {
                    put("rest_end_time", session.restEndTime)
                }
                put("alerts_shown", session.alertsShown.joinToString(","))
                put("is_active", if (session.isActive) 1 else 0)
                put("updated_at", now)
            }
            val rows = database.update(
                "continuous_usage_sessions",
                values,
                "id = ?",
                arrayOf(session.id.toString())
            )
            Log.d(TAG, "Updated session: id=${session.id}, rows=$rows, duration=${session.totalDurationSeconds}s")
            rows > 0
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update session", e)
            false
        }
    }

    /**
     * 停用连续使用会话
     */
    fun deactivateContinuousSession(id: Long): Boolean {
        val database = openWritableDatabase() ?: return false

        return try {
            val values = android.content.ContentValues().apply {
                put("is_active", 0)
                put("updated_at", System.currentTimeMillis())
            }
            val rows = database.update(
                "continuous_usage_sessions",
                values,
                "id = ?",
                arrayOf(id.toString())
            )
            Log.d(TAG, "Deactivated session: id=$id, rows=$rows")
            rows > 0
        } catch (e: Exception) {
            Log.e(TAG, "Failed to deactivate session", e)
            false
        }
    }

    /**
     * 从游标解析连续使用会话
     */
    private fun parseContinuousSession(cursor: android.database.Cursor): ContinuousSession {
        val alertsStr = if (cursor.isNull(cursor.getColumnIndexOrThrow("alerts_shown"))) {
            ""
        } else {
            cursor.getString(cursor.getColumnIndexOrThrow("alerts_shown"))
        }

        return ContinuousSession(
            id = cursor.getLong(cursor.getColumnIndexOrThrow("id")),
            sessionDate = cursor.getString(cursor.getColumnIndexOrThrow("session_date")),
            startTime = cursor.getLong(cursor.getColumnIndexOrThrow("start_time")),
            totalDurationSeconds = cursor.getLong(cursor.getColumnIndexOrThrow("total_duration_seconds")),
            lastActivityTime = if (cursor.isNull(cursor.getColumnIndexOrThrow("last_activity_time"))) null
                else cursor.getLong(cursor.getColumnIndexOrThrow("last_activity_time")),
            restEndTime = if (cursor.isNull(cursor.getColumnIndexOrThrow("rest_end_time"))) null
                else cursor.getLong(cursor.getColumnIndexOrThrow("rest_end_time")),
            alertsShown = if (alertsStr.isEmpty()) emptySet() else alertsStr.split(",").filter { it.isNotEmpty() }.toSet(),
            isActive = cursor.getInt(cursor.getColumnIndexOrThrow("is_active")) == 1,
            createdAt = cursor.getLong(cursor.getColumnIndexOrThrow("created_at")),
            updatedAt = cursor.getLong(cursor.getColumnIndexOrThrow("updated_at"))
        )
    }

    // ==================== 连续使用设置 ====================

    /**
     * 获取连续使用设置
     * 从 app_settings 表读取（Flutter 侧每次设置变更时写入），
     * 不依赖 SharedPreferences，原生侧始终可读。
     */
    fun getContinuousUsageSettings(): ContinuousUsageSettings {
        val database = openDatabase() ?: return ContinuousUsageSettings()

        return try {
            // 批量读取 4 个设置 key
            val cursor = database.query(
                "app_settings",
                arrayOf("key", "value"),
                "key IN (?, ?, ?, ?)",
                arrayOf(KEY_ENABLED, KEY_LIMIT_MINUTES, KEY_REST_MINUTES, KEY_RESET_AFTER_REST_MINUTES),
                null, null, null
            )
            val map = mutableMapOf<String, String>()
            cursor.use {
                while (it.moveToNext()) {
                    map[it.getString(0)] = it.getString(1)
                }
            }

            ContinuousUsageSettings(
                enabled = map[KEY_ENABLED]?.toBoolean() ?: DEFAULT_CONTINUOUS_ENABLED,
                limitMinutes = map[KEY_LIMIT_MINUTES]?.toIntOrNull() ?: DEFAULT_LIMIT_MINUTES,
                restMinutes = map[KEY_REST_MINUTES]?.toIntOrNull() ?: DEFAULT_REST_MINUTES,
                resetAfterRestMinutes = map[KEY_RESET_AFTER_REST_MINUTES]?.toIntOrNull() ?: DEFAULT_RESET_AFTER_REST_MINUTES
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed to read continuous usage settings from DB", e)
            ContinuousUsageSettings()
        }
    }

    /**
     * 关闭数据库
     */
    fun close() {
        try {
            db?.close()
        } catch (e: Exception) {
            Log.e(TAG, "Error closing database", e)
        }
        db = null
    }

    /**
     * 获取所有已启用的受监控应用
     */
    fun getMonitoredApps(): List<MonitoredApp> {
        val database = openDatabase() ?: return emptyList()
        val apps = mutableListOf<MonitoredApp>()

        try {
            val cursor = database.query(
                "monitored_apps",
                arrayOf("package_name", "daily_limit_minutes"),
                "enabled = 1",
                null, null, null, null
            )
            cursor.use {
                while (it.moveToNext()) {
                    val packageName = it.getString(0)
                    val dailyLimit = if (it.isNull(1)) null else it.getInt(1)
                    apps.add(MonitoredApp(packageName, dailyLimit))
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to query monitored_apps", e)
        }

        Log.d(TAG, "Monitored apps: ${apps.map { it.packageName }}")
        return apps
    }

    /**
     * 检查指定包名是否在监控列表中
     */
    fun isMonitored(packageName: String): Boolean {
        val database = openDatabase() ?: return false

        return try {
            val cursor = database.query(
                "monitored_apps",
                arrayOf("package_name"),
                "package_name = ? AND enabled = 1",
                arrayOf(packageName), null, null, null
            )
            cursor.use { it.count > 0 }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to check if monitored", e)
            false
        }
    }

    /**
     * 获取指定应用的每日限制（分钟）
     */
    fun getDailyLimitMinutes(packageName: String): Int? {
        val database = openDatabase() ?: return null

        return try {
            val cursor = database.query(
                "monitored_apps",
                arrayOf("daily_limit_minutes"),
                "package_name = ? AND enabled = 1",
                arrayOf(packageName), null, null, null
            )
            cursor.use {
                if (it.moveToFirst() && !it.isNull(0)) it.getInt(0) else null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get daily limit", e)
            null
        }
    }

    /**
     * 获取所有已启用的时间段规则
     */
    fun getTimePeriods(): List<TimePeriod> {
        val database = openDatabase() ?: return emptyList()
        val periods = mutableListOf<TimePeriod>()

        try {
            val cursor = database.query(
                "time_periods",
                arrayOf("mode", "time_start", "time_end", "days"),
                "enabled = 1",
                null, null, null, null
            )
            cursor.use {
                while (it.moveToNext()) {
                    periods.add(TimePeriod(
                        mode = it.getString(0),
                        timeStart = it.getString(1),
                        timeEnd = it.getString(2),
                        days = it.getString(3)
                    ))
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to query time_periods", e)
        }

        return periods
    }

    /**
     * 获取总时间规则
     */
    fun getTotalTimeRule(): TotalTimeRule? {
        val database = openDatabase() ?: return null

        return try {
            val cursor = database.query(
                "rules",
                arrayOf("weekday_limit", "weekend_limit"),
                "rule_type = 'total_time' AND enabled = 1",
                null, null, null, null
            )
            cursor.use {
                if (it.moveToFirst()) {
                    TotalTimeRule(
                        weekdayLimit = if (it.isNull(0)) null else it.getInt(0),
                        weekendLimit = if (it.isNull(1)) null else it.getInt(1)
                    )
                } else null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to query total_time rule", e)
            null
        }
    }

    /**
     * 获取今日所有受监控应用的总使用时间（毫秒）
     */
    fun getTodayTotalUsageMs(monitoredPackages: Set<String>): Long {
        if (monitoredPackages.isEmpty()) return 0L
        val database = openDatabase() ?: return 0L
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())

        return try {
            val placeholders = monitoredPackages.map { "?" }.joinToString(",")
            val cursor = database.rawQuery(
                "SELECT COALESCE(SUM(duration), 0) FROM app_usage_records WHERE date = ? AND package_name IN ($placeholders)",
                arrayOf(today, *monitoredPackages.toTypedArray())
            )
            cursor.use {
                if (it.moveToFirst()) it.getLong(0) * 1000L else 0L
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to query total usage", e)
            0L
        }
    }

    /**
     * 获取今日指定应用的使用时间（毫秒）
     */
    fun getTodayAppUsageMs(packageName: String): Long {
        val database = openDatabase() ?: return 0L
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())

        return try {
            val cursor = database.rawQuery(
                "SELECT COALESCE(SUM(duration), 0) FROM app_usage_records WHERE date = ? AND package_name = ?",
                arrayOf(today, packageName)
            )
            cursor.use {
                if (it.moveToFirst()) it.getLong(0) * 1000L else 0L
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to query app usage for $packageName", e)
            0L
        }
    }

    /**
     * 获取当前强制休息剩余时间（秒）
     */
    fun getActiveRestRemainingSeconds(): Long {
        val database = openDatabase() ?: return 0L
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
        val now = System.currentTimeMillis()

        return try {
            val cursor = database.rawQuery(
                "SELECT rest_end_time FROM continuous_usage_sessions WHERE session_date = ? AND is_active = 1 AND rest_end_time IS NOT NULL AND rest_end_time > ? ORDER BY rest_end_time DESC LIMIT 1",
                arrayOf(today, now.toString())
            )
            cursor.use {
                if (it.moveToFirst()) ((it.getLong(0) - now) / 1000L).coerceAtLeast(0L) else 0L
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to query active rest", e)
            0L
        }
    }

    /**
     * 判断今天是周几
     * @return Calendar.SUNDAY(1) 到 Calendar.SATURDAY(7)
     */
    fun getDayOfWeek(): Int {
        return Calendar.getInstance().get(Calendar.DAY_OF_WEEK)
    }

    /**
     * 判断今天是否是周末
     */
    fun isWeekend(): Boolean {
        val dayOfWeek = getDayOfWeek()
        return dayOfWeek == Calendar.SUNDAY || dayOfWeek == Calendar.SATURDAY
    }

    /**
     * 获取当前时间（HH:mm 格式）
     */
    fun getCurrentTimeStr(): String {
        return SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date())
    }
}
