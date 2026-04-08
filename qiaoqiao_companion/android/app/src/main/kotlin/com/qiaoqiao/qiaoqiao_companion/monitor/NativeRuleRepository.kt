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
                if (it.moveToFirst()) it.getLong(0) else 0L
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
                if (it.moveToFirst()) it.getLong(0) else 0L
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to query app usage for $packageName", e)
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
