package com.qiaoqiao.qiaoqiao_companion.features.parent_mode.data

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.util.Log
import java.io.File
import java.security.MessageDigest

/**
 * 家长密码仓库 (Kotlin版本)
 * 从 SQLite app_settings 表读取密码哈希和盐，与 Flutter 端保持一致
 * 哈希算法: SHA-256(password + salt)，与 Flutter 端 _hashPassword() 完全一致
 */
class ParentPasswordRepository(private val context: Context) {

    companion object {
        private const val TAG = "ParentPasswordRepository"
        private const val DB_NAME = "qiaoqiao_companion.db"
        private const val TABLE_NAME = "app_settings"
        private const val KEY_HASH = "parent_password_hash"
        private const val KEY_SALT = "parent_password_salt"
    }

    private var db: SQLiteDatabase? = null

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
                dbPath.absolutePath, null, SQLiteDatabase.OPEN_READONLY
            )
            db
        } catch (e: Exception) {
            Log.e(TAG, "Failed to open database", e)
            null
        }
    }

    /**
     * 检查是否已设置密码
     */
    fun hasPassword(): Boolean {
        val database = openDatabase() ?: return false
        return try {
            val cursor = database.query(
                TABLE_NAME, arrayOf("value"),
                "key = ?", arrayOf(KEY_HASH), null, null, null
            )
            cursor.use {
                if (it.moveToFirst()) {
                    val value = it.getString(0)
                    value.isNotEmpty()
                } else {
                    false
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to check password existence", e)
            false
        }
    }

    /**
     * 验证密码
     * 使用 SHA-256(password + salt) 与 Flutter 端保持一致
     */
    fun verifyPassword(password: String): Boolean {
        val database = openDatabase() ?: return false
        return try {
            val map = mutableMapOf<String, String>()
            val cursor = database.query(
                TABLE_NAME, arrayOf("key", "value"),
                "key IN (?, ?)", arrayOf(KEY_HASH, KEY_SALT), null, null, null
            )
            cursor.use {
                while (it.moveToNext()) {
                    map[it.getString(0)] = it.getString(1)
                }
            }
            val storedHash = map[KEY_HASH] ?: return false
            val salt = map[KEY_SALT] ?: return false

            if (storedHash.isEmpty() || salt.isEmpty()) return false

            val inputHash = hashPassword(password, salt)
            storedHash == inputHash
        } catch (e: Exception) {
            Log.e(TAG, "Failed to verify password", e)
            false
        }
    }

    /**
     * 哈希密码
     * SHA-256(password + salt)，与 Flutter 端 _hashPassword() 完全一致
     */
    private fun hashPassword(password: String, salt: String): String {
        val bytes = MessageDigest.getInstance("SHA-256")
            .digest((password + salt).toByteArray())
        return bytes.joinToString("") { "%02x".format(it) }
    }
}
