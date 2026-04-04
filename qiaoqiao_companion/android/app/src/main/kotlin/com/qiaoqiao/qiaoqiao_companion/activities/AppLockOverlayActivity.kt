package com.qiaoqiao.qiaoqiao_companion.activities

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
import androidx.appcompat.app.AppCompatActivity
import com.qiaoqiao.qiaoqiao_companion.MainActivity
import com.qiaoqiao.qiaoqiao_companion.R
import com.qiaoqiao.qiaoqiao_companion.features.parent_mode.data.ParentPasswordRepository
import com.qiaoqiao.qiaoqiao_companion.managers.AppLockManager

/**
 * App锁屏覆盖Activity
 * 当用户尝试滑掉App时显示，需要家长密码才能解除
 */
class AppLockOverlayActivity : AppCompatActivity() {

    companion object {
        private const val TAG = "AppLockOverlayActivity"

        /**
         * 启动锁屏覆盖
         */
        fun start(context: Context) {
            // 记录触发时间
            AppLockManager.setLastTriggerTime(context, System.currentTimeMillis())

            val intent = Intent(context, AppLockOverlayActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TASK or
                        Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS
            }
            context.startActivity(intent)
        }
    }

    private lateinit var passwordRepository: ParentPasswordRepository
    private lateinit var etPassword: EditText
    private lateinit var tvError: TextView
    private lateinit var btnUnlock: Button
    private lateinit var btnReopen: Button

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 设置全屏
        setupFullScreen()

        setContentView(R.layout.activity_app_lock_overlay)

        passwordRepository = ParentPasswordRepository(this)

        initViews()
        setupListeners()
    }

    /**
     * 设置全屏显示
     */
    private fun setupFullScreen() {
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
    }
}
