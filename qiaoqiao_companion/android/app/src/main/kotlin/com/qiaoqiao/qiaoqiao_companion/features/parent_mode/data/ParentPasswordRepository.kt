package com.qiaoqiao.qiaoqiao_companion.features.parent_mode.data

import android.content.Context
import android.util.Log
import java.security.MessageDigest

/**
 * 家长密码仓库 (Kotlin版本)
 * 用于Native端密码验证
 * 与Flutter端使用相同的SharedPreferences存储
 */
class ParentPasswordRepository(private val context: Context) {

    companion object {
        private const val TAG = "ParentPasswordRepository"
        private const val PREFS_NAME = "parent_auth_prefs"
        private const val KEY_PASSWORD_HASH = "password_hash"
    }

    /**
     * 检查是否已设置密码
     */
    fun hasPassword(): Boolean {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.contains(KEY_PASSWORD_HASH)
    }

    /**
     * 验证密码
     * 使用SHA-256哈希与Flutter端保持一致
     */
    fun verifyPassword(password: String): Boolean {
        if (!hasPassword()) {
            Log.w(TAG, "No password set")
            return false
        }

        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val storedHash = prefs.getString(KEY_PASSWORD_HASH, null) ?: return false

        val inputHash = hashPassword(password)
        return storedHash == inputHash
    }

    /**
     * 哈希密码
     * 使用SHA-256算法
     */
    private fun hashPassword(password: String): String {
        val bytes = MessageDigest.getInstance("SHA-256").digest(password.toByteArray())
        return bytes.joinToString("") { "%02x".format(it) }
    }
}
