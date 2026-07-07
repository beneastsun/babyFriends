package com.qiaoqiao.qiaoqiao_companion.monitor

import android.content.Context
import android.content.SharedPreferences
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

        // Flutter SharedPreferences fallback
        private const val FLUTTER_SHARED_PREFS_NAME = "FlutterSharedPreferences"
        private const val FLUTTER_KEY_PREFIX = "flutter."
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
        /** 倒计时开始时间戳（毫秒）。由 Flutter 侧在显示倒计时悬浮窗时写入。 */
        val countdownStartedAt: Long? = null,
        /** 倒计时总秒数（首次显示时的剩余秒数）。由 Flutter 侧在显示倒计时悬浮窗时写入。 */
        val countdownTotalSeconds: Long? = null,
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
                if (session.countdownStartedAt != null) {
                    put("countdown_started_at", session.countdownStartedAt)
                } else {
                    putNull("countdown_started_at")
                }
                if (session.countdownTotalSeconds != null) {
                    put("countdown_total_seconds", session.countdownTotalSeconds)
                } else {
                    putNull("countdown_total_seconds")
                }
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
                } else {
                    putNull("rest_end_time")
                }
                put("alerts_shown", session.alertsShown.joinToString(","))
                put("is_active", if (session.isActive) 1 else 0)
                if (session.countdownStartedAt != null) {
                    put("countdown_started_at", session.countdownStartedAt)
                } else {
                    putNull("countdown_started_at")
                }
                if (session.countdownTotalSeconds != null) {
                    put("countdown_total_seconds", session.countdownTotalSeconds)
                } else {
                    putNull("countdown_total_seconds")
                }
                put("updated_at", now)
            }
            val rows = database.update(
                "continuous_usage_sessions",
                values,
                "id = ?",
                arrayOf(session.id.toString())
            )
            Log.d(TAG, "Updated session: id=${session.id}, rows=$rows, duration=${session.totalDurationSeconds}s, countdownStartedAt=${session.countdownStartedAt}, countdownTotalSeconds=${session.countdownTotalSeconds}")
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

        // 对 v5 新增列使用 getColumnIndex（未升级的旧 DB 返回 -1），避免直接 getColumnIndexOrThrow 崩溃
        val countdownStartedAtIdx = cursor.getColumnIndex("countdown_started_at")
        val countdownTotalSecondsIdx = cursor.getColumnIndex("countdown_total_seconds")
        val countdownStartedAt: Long? =
            if (countdownStartedAtIdx < 0 || cursor.isNull(countdownStartedAtIdx)) null
            else cursor.getLong(countdownStartedAtIdx)
        val countdownTotalSeconds: Long? =
            if (countdownTotalSecondsIdx < 0 || cursor.isNull(countdownTotalSecondsIdx)) null
            else cursor.getLong(countdownTotalSecondsIdx)

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
            countdownStartedAt = countdownStartedAt,
            countdownTotalSeconds = countdownTotalSeconds,
            createdAt = cursor.getLong(cursor.getColumnIndexOrThrow("created_at")),
            updatedAt = cursor.getLong(cursor.getColumnIndexOrThrow("updated_at"))
        )
    }

    // ==================== 连续使用设置 ====================

    /**
     * 获取连续使用设置
     * 优先从 app_settings 表读取（Flutter 侧每次设置变更时写入），
     * 当 DB 缺少 key 或读取失败时，fallback 到 Flutter SharedPreferences。
     */
    fun getContinuousUsageSettings(): ContinuousUsageSettings {
        val database = openDatabase()

        if (database != null) {
            try {
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

                val dbSettings = ContinuousUsageSettings(
                    enabled = map[KEY_ENABLED]?.toBoolean() ?: DEFAULT_CONTINUOUS_ENABLED,
                    limitMinutes = map[KEY_LIMIT_MINUTES]?.toIntOrNull() ?: DEFAULT_LIMIT_MINUTES,
                    restMinutes = map[KEY_REST_MINUTES]?.toIntOrNull() ?: DEFAULT_REST_MINUTES,
                    resetAfterRestMinutes = map[KEY_RESET_AFTER_REST_MINUTES]?.toIntOrNull() ?: DEFAULT_RESET_AFTER_REST_MINUTES
                )

                // 如果 DB 中所有值都是默认值，尝试从 SharedPreferences fallback
                // 场景：DB 写入失败或原生服务先于 Flutter 引擎启动
                if (isAllDefaults(dbSettings, map)) {
                    val spSettings = readSettingsFromSharedPreferences()
                    val merged = mergeWithFallback(dbSettings, spSettings, map)
                    if (merged != dbSettings) {
                        Log.w(TAG, "Settings fallback: DB had defaults/missing, merged from SharedPreferences")
                    }
                    return merged
                }

                return dbSettings
            } catch (e: Exception) {
                Log.e(TAG, "Failed to read continuous usage settings from DB, falling back to SharedPreferences", e)
                return readSettingsFromSharedPreferences()
            }
        }

        // DB 打开失败，直接 fallback 到 SharedPreferences
        Log.w(TAG, "DB not available, reading settings from SharedPreferences")
        return readSettingsFromSharedPreferences()
    }

    /**
     * 检查 DB 读取的设置是否全部为默认值且 DB 中可能缺少 key
     * 当 map 中缺少某个 key 时，该字段使用了默认值，需要从 SP fallback
     */
    private fun isAllDefaults(settings: ContinuousUsageSettings, map: Map<String, String>): Boolean {
        return !map.containsKey(KEY_ENABLED) ||
               !map.containsKey(KEY_LIMIT_MINUTES) ||
               !map.containsKey(KEY_REST_MINUTES) ||
               !map.containsKey(KEY_RESET_AFTER_REST_MINUTES)
    }

    /**
     * 合并 DB 设置和 SharedPreferences 设置
     * DB 有值时优先使用 DB 值，DB 缺少 key 时使用 SP 值
     */
    private fun mergeWithFallback(
        dbSettings: ContinuousUsageSettings,
        spSettings: ContinuousUsageSettings,
        dbMap: Map<String, String>
    ): ContinuousUsageSettings {
        return ContinuousUsageSettings(
            enabled = if (dbMap.containsKey(KEY_ENABLED)) dbSettings.enabled else spSettings.enabled,
            limitMinutes = if (dbMap.containsKey(KEY_LIMIT_MINUTES)) dbSettings.limitMinutes else spSettings.limitMinutes,
            restMinutes = if (dbMap.containsKey(KEY_REST_MINUTES)) dbSettings.restMinutes else spSettings.restMinutes,
            resetAfterRestMinutes = if (dbMap.containsKey(KEY_RESET_AFTER_REST_MINUTES)) dbSettings.resetAfterRestMinutes else spSettings.resetAfterRestMinutes
        )
    }

    /**
     * 从 Flutter SharedPreferences 读取连续使用设置作为 fallback
     * Flutter SharedPreferences 文件名: "FlutterSharedPreferences"
     * Key 前缀: "flutter."（Flutter shared_preferences 包自动添加）
     * Int 类型存储为 Long
     */
    private fun readSettingsFromSharedPreferences(): ContinuousUsageSettings {
        return try {
            val prefs = context.getSharedPreferences(FLUTTER_SHARED_PREFS_NAME, Context.MODE_PRIVATE)

            ContinuousUsageSettings(
                enabled = prefs.getBoolean(FLUTTER_KEY_PREFIX + KEY_ENABLED, DEFAULT_CONTINUOUS_ENABLED),
                limitMinutes = prefs.getLong(FLUTTER_KEY_PREFIX + KEY_LIMIT_MINUTES, DEFAULT_LIMIT_MINUTES.toLong()).toInt(),
                restMinutes = prefs.getLong(FLUTTER_KEY_PREFIX + KEY_REST_MINUTES, DEFAULT_REST_MINUTES.toLong()).toInt(),
                resetAfterRestMinutes = prefs.getLong(FLUTTER_KEY_PREFIX + KEY_RESET_AFTER_REST_MINUTES, DEFAULT_RESET_AFTER_REST_MINUTES.toLong()).toInt()
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed to read settings from Flutter SharedPreferences", e)
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
     * 获取今日限额调整（分钟）
     * 正数=加时券增加，负数=任务惩罚扣减，0=无调整
     * 从 app_settings 表的 daily_adjustment_minutes key 读取
     */
    fun getDailyAdjustmentMinutes(): Int {
        val database = openDatabase() ?: return 0
        return try {
            val cursor = database.query(
                "app_settings",
                arrayOf("value"),
                "key = ?",
                arrayOf("daily_adjustment_minutes"),
                null, null, null
            )
            cursor.use {
                if (it.moveToFirst()) it.getString(0).toIntOrNull() ?: 0 else 0
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get daily adjustment minutes", e)
            0
        }
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
     * 判断今天是周几（Calendar 约定）
     * @return Calendar.SUNDAY(1) 到 Calendar.SATURDAY(7)，即 1=Sunday..7=Saturday
     */
    fun getDayOfWeek(): Int {
        return Calendar.getInstance().get(Calendar.DAY_OF_WEEK)
    }

    /**
     * 判断今天是周几（ISO 8601 约定，与 Flutter 侧 time_periods.days 一致）
     *
     * Flutter 侧 [TimePeriod.days] 使用 ISO 约定：1=周一(Monday), 7=周日(Sunday)，
     * 与 Dart 的 `DateTime.weekday` 一致。原生侧 [getDayOfWeek] 返回 Calendar 约定
     * (1=Sunday..7=Saturday)，直接比较会导致星期错位（例如周日被当作周一），
     * 因此时间段规则匹配必须使用本方法。
     *
     * @return 1=Monday, 2=Tuesday, ..., 7=Sunday
     */
    fun getIsoDayOfWeek(): Int {
        val calendarDay = Calendar.getInstance().get(Calendar.DAY_OF_WEEK)
        // Calendar: 1=Sunday..7=Saturday → ISO: 1=Monday..7=Sunday
        return (calendarDay + 5) % 7 + 1
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
