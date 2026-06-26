package com.qiaoqiao.qiaoqiao_companion.activities

import android.app.Activity
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import com.qiaoqiao.qiaoqiao_companion.R
import com.qiaoqiao.qiaoqiao_companion.features.parent_mode.data.ParentPasswordRepository
import com.qiaoqiao.qiaoqiao_companion.monitor.NativeOverlayManager

/**
 * 密码输入 Activity
 *
 * 替代在 TYPE_APPLICATION_OVERLAY 窗口中内嵌 EditText 的方案。
 * MIUI 的 WindowManager 在 TYPE_APPLICATION_OVERLAY + EditText + 软键盘时
 * 会进入 resize 循环，导致 overlay 闪缩。使用 Activity 处理密码输入
 * 可以避免此问题，因为 Activity 有正确的软键盘处理机制。
 */
class PasswordInputActivity : Activity() {

    companion object {
        private const val TAG = "PasswordInputActivity"

        /**
         * 密码验证成功后的回调。
         * 由 MonitorForegroundService 在创建 NativeOverlayManager 时设置。
         */
        var onPasswordVerified: (() -> Unit)? = null

        /**
         * 启动密码输入 Activity
         */
        fun start(context: android.content.Context) {
            val intent = android.content.Intent(context, PasswordInputActivity::class.java).apply {
                flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK or
                        android.content.Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS
            }
            context.startActivity(intent)
            Log.d(TAG, "PasswordInputActivity started")
        }
    }

    private lateinit var passwordRepository: ParentPasswordRepository
    private lateinit var etPassword: EditText
    private lateinit var tvError: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "onCreate")

        // 设置全屏 + 显示在锁屏上
        setupFullScreen()

        passwordRepository = ParentPasswordRepository(this)

        // 通知 overlay 密码输入已激活
        NativeOverlayManager.passwordInputActivityActive = true

        setContentView(createPasswordView())
        initViews()
    }

    private fun setupFullScreen() {
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
    }

    private fun createPasswordView(): View {
        val candyPurple = 0xFFB57EDC.toInt()
        val candyPeach = 0xFFFFAB91.toInt()
        val density = resources.displayMetrics.density

        // 半透明背景
        val container = FrameLayout(this).apply {
            setBackgroundColor(0xDD000000.toInt())
            isClickable = true
            isFocusable = true
        }

        // 密码卡片
        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            background = android.graphics.drawable.GradientDrawable(
                android.graphics.drawable.GradientDrawable.Orientation.TOP_BOTTOM,
                intArrayOf(candyPurple, candyPeach)
            ).apply {
                cornerRadius = 48f
            }
            setPadding(
                (32 * density).toInt(),
                (36 * density).toInt(),
                (32 * density).toInt(),
                (28 * density).toInt()
            )
        }

        // 标题
        val title = TextView(this).apply {
            text = "🔒  家长验证"
            textSize = 20f
            setTextColor(0xFFFFFFFF.toInt())
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, (16 * density).toInt())
            android.graphics.Typeface.DEFAULT_BOLD?.let { typeface = it }
        }

        // 错误提示
        val passwordError = TextView(this).apply {
            tag = "password_error"
            text = "密码错误"
            textSize = 12f
            setTextColor(0xFFFF6B6B.toInt())
            gravity = Gravity.CENTER
            visibility = View.GONE
            setPadding(0, (6 * density).toInt(), 0, 0)
        }

        // 密码输入框
        val passwordInput = EditText(this).apply {
            tag = "password_input"
            hint = "输入家长密码"
            inputType = android.text.InputType.TYPE_CLASS_NUMBER or android.text.InputType.TYPE_NUMBER_VARIATION_PASSWORD
            textSize = 20f
            setTextColor(0xFFFFFFFF.toInt())
            setHintTextColor(0xAAFFFFFF.toInt())
            gravity = Gravity.CENTER
            filters = arrayOf(android.text.InputFilter.LengthFilter(6))
            background = android.graphics.drawable.GradientDrawable().apply {
                setColor(0x44FFFFFF.toInt())
                cornerRadius = 16f
            }
            setPadding(
                (24 * density).toInt(),
                (14 * density).toInt(),
                (24 * density).toInt(),
                (14 * density).toInt()
            )
        }

        // Listener 在变量声明之后设置
        passwordInput.setOnEditorActionListener { _, actionId, _ ->
            if (actionId == android.view.inputmethod.EditorInfo.IME_ACTION_DONE) {
                attemptUnlock(passwordInput, passwordError)
                true
            } else false
        }

        // 按钮行
        val buttonRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            setPadding(0, (16 * density).toInt(), 0, 0)
        }

        val confirmBtn = TextView(this).apply {
            text = "确认"
            textSize = 14f
            setTextColor(0xFFFFFFFF.toInt())
            gravity = Gravity.CENTER
            setPadding(
                (28 * density).toInt(),
                (10 * density).toInt(),
                (28 * density).toInt(),
                (10 * density).toInt()
            )
            android.graphics.Typeface.DEFAULT_BOLD?.let { typeface = it }
            background = android.graphics.drawable.GradientDrawable().apply {
                setColor(0xFF8B5CF6.toInt())
                cornerRadius = 20f
            }
        }
        confirmBtn.setOnClickListener {
            attemptUnlock(passwordInput, passwordError)
        }

        val cancelBtn = TextView(this).apply {
            text = "取消"
            textSize = 14f
            setTextColor(0xCCFFFFFF.toInt())
            gravity = Gravity.CENTER
            setPadding(
                (28 * density).toInt(),
                (10 * density).toInt(),
                (28 * density).toInt(),
                (10 * density).toInt()
            )
            setOnClickListener {
                finish()
            }
        }

        buttonRow.addView(confirmBtn)
        buttonRow.addView(cancelBtn)

        card.addView(title)
        card.addView(passwordInput)
        card.addView(passwordError)
        card.addView(buttonRow)

        // 卡片布局参数
        val cardParams = FrameLayout.LayoutParams(
            (280 * density).toInt(),
            FrameLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            gravity = Gravity.CENTER
        }

        container.addView(card, cardParams)
        return container
    }

    @Suppress("UNCHECKED_CAST")
    private fun initViews() {
        // Activity 没有 findViewWithTag，需要通过 window.decorView 查找
        val decorView = window.decorView
        etPassword = decorView.findViewWithTag("password_input") as EditText
        tvError = decorView.findViewWithTag("password_error") as TextView

        // 自动弹出键盘
        etPassword.requestFocus()
        window.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_STATE_VISIBLE)
    }

    private fun attemptUnlock(passwordInput: EditText, passwordError: TextView) {
        val password = passwordInput.text.toString()
        if (password.isEmpty()) {
            passwordError.text = "请输入密码"
            passwordError.visibility = View.VISIBLE
            return
        }
        if (passwordRepository.verifyPassword(password)) {
            Log.d(TAG, "Password correct, unlocking")
            // 通知回调
            onPasswordVerified?.invoke()
            finish()
        } else {
            passwordError.text = "密码错误，请重试"
            passwordError.visibility = View.VISIBLE
            passwordInput.text?.clear()
        }
    }

    override fun finish() {
        NativeOverlayManager.passwordInputActivityActive = false
        super.finish()
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        // 允许取消（按返回键关闭）
        finish()
    }
}
