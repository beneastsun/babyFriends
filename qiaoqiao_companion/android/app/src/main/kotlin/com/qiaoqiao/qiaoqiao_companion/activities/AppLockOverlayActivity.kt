package com.qiaoqiao.qiaoqiao_companion.activities

import android.app.Activity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.EditText
import android.widget.TextView
import androidx.core.app.NotificationCompat
import com.qiaoqiao.qiaoqiao_companion.MainActivity
import com.qiaoqiao.qiaoqiao_companion.R
import com.qiaoqiao.qiaoqiao_companion.features.parent_mode.data.ParentPasswordRepository
import com.qiaoqiao.qiaoqiao_companion.managers.AppLockManager

/**
 * App锁屏覆盖Activity
 * 当用户尝试滑掉App时显示，需要家长密码才能解除
 */
class AppLockOverlayActivity : Activity() {

    companion object {
        private const val TAG = "AppLockOverlayActivity"
        private const val CHANNEL_ID = "app_lock_channel"
        private const val NOTIFICATION_ID = 9999

        /**
         * 启动锁屏覆盖
         * Android 10+ 使用全屏通知（后台 startActivity 受限，会闪退）
         * Android 9 及以下直接启动 Activity
         */
        fun start(context: Context) {
            Log.d(TAG, "start() called - preparing to show lock overlay")

            // 记录触发时间
            AppLockManager.setLastTriggerTime(context, System.currentTimeMillis())

            // Android 10+ 后台启动 Activity 受限，直接使用全屏通知
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                Log.d(TAG, "Android 10+, using full-screen notification")
                showFullScreenNotification(context)
                return
            }

            // Android 9 及以下：直接尝试启动Activity
            try {
                val intent = Intent(context, AppLockOverlayActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_CLEAR_TASK or
                            Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS or
                            Intent.FLAG_ACTIVITY_BROUGHT_TO_FRONT
                }
                context.startActivity(intent)
                Log.d(TAG, "Direct startActivity called")
            } catch (e: Exception) {
                Log.e(TAG, "Direct startActivity failed, trying notification method", e)
                showFullScreenNotification(context)
            }
        }

        /**
         * 使用全屏通知启动Activity (Android 10+ 后台启动限制的解决方案)
         */
        private fun showFullScreenNotification(context: Context) {
            Log.d(TAG, "showFullScreenNotification() called")

            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            // 创建通知渠道
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    "App锁提醒",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "当App被尝试关闭时显示提醒"
                    enableLights(true)
                    enableVibration(true)
                    lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
                }
                notificationManager.createNotificationChannel(channel)
            }

            // 创建启动Activity的Intent
            val intent = Intent(context, AppLockOverlayActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TASK or
                        Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS
            }

            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            // 创建全屏通知
            val notification = NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_notification)
                .setContentTitle("纹纹小伙伴正在运行中")
                .setContentText("点击返回应用")
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setCategory(NotificationCompat.CATEGORY_ALARM)
                .setFullScreenIntent(pendingIntent, true)
                .setAutoCancel(true)
                .build()

            notificationManager.notify(NOTIFICATION_ID, notification)
            Log.d(TAG, "Full-screen notification shown")
        }
    }

    private lateinit var passwordRepository: ParentPasswordRepository
    private lateinit var etPassword: EditText
    private lateinit var tvError: TextView
    private lateinit var btnUnlock: Button
    private lateinit var btnReopen: Button

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "onCreate called - App lock overlay is showing")

        // 设置全屏
        setupFullScreen()

        try {
            setContentView(R.layout.activity_app_lock_overlay)
            Log.d(TAG, "Layout set successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to set content view", e)
            finish()
            return
        }

        passwordRepository = ParentPasswordRepository(this)

        initViews()
        setupListeners()
        Log.d(TAG, "App lock overlay initialized successfully")
    }

    /**
     * 设置全屏显示
     */
    private fun setupFullScreen() {
        // 添加显示在锁屏上的标志
        window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED)
        window.addFlags(WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        window.addFlags(WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.setDecorFitsSystemWindows(false)
            window.insetsController?.let { controller ->
                controller.hide(android.view.WindowInsets.Type.statusBars() or android.view.WindowInsets.Type.navigationBars())
                controller.systemBarsBehavior = android.view.WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            }
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = (
                View.SYSTEM_UI_FLAG_FULLSCREEN or
                View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE or
                View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
                View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
            )
        }

        // 防止截屏
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)

        Log.d(TAG, "setupFullScreen completed")
    }

    /**
     * 初始化视图
     */
    private fun initViews() {
        etPassword = findViewById(R.id.etPassword)
        tvError = findViewById(R.id.tvError)
        btnUnlock = findViewById(R.id.btnUnlock)
        btnReopen = findViewById(R.id.btnReopen)
    }

    /**
     * 设置监听器
     */
    private fun setupListeners() {
        btnUnlock.setOnClickListener {
            attemptUnlock()
        }

        btnReopen.setOnClickListener {
            reopenApp()
        }

        // 密码输入时隐藏错误
        etPassword.setOnEditorActionListener { _, _, _ ->
            attemptUnlock()
            true
        }
    }

    /**
     * 尝试解锁
     */
    private fun attemptUnlock() {
        val password = etPassword.text.toString()

        if (password.isEmpty()) {
            showError("请输入密码")
            return
        }

        if (passwordRepository.verifyPassword(password)) {
            // 密码正确，关闭锁屏
            Log.d(TAG, "Password correct, unlocking")
            // 取消通知
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.cancel(NOTIFICATION_ID)
            finish()
        } else {
            // 密码错误
            showError("密码错误，请重试")
            etPassword.text?.clear()
        }
    }

    /**
     * 显示错误信息
     */
    private fun showError(message: String) {
        tvError.text = message
        tvError.visibility = View.VISIBLE
    }

    /**
     * 重新打开App
     */
    private fun reopenApp() {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        startActivity(intent)
        finish()
    }

    /**
     * 禁用返回键
     */
    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        // 不执行任何操作，阻止返回
        Log.d(TAG, "Back button pressed - ignoring")
    }
}
