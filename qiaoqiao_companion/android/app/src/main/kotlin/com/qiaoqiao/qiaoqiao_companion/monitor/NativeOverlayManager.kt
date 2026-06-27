package com.qiaoqiao.qiaoqiao_companion.monitor

import android.animation.ValueAnimator
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.view.animation.AccelerateDecelerateInterpolator
import android.view.animation.DecelerateInterpolator
import android.widget.FrameLayout
import android.widget.GridLayout
import android.widget.LinearLayout
import android.widget.TextView
import com.qiaoqiao.qiaoqiao_companion.MainActivity

/**
 * 原生锁屏覆盖层管理器
 * 在 Flutter 引擎死亡时，由原生监控服务直接创建覆盖层阻止使用被限制的 App
 * 不依赖 MethodChannel，可独立运行
 */
class NativeOverlayManager(private val context: Context) {

    companion object {
        private const val TAG = "NativeOverlay"

        /**
         * PasswordInputActivity 是否正在显示。
         * EnforcementEngine 在 onPoll 中检查此标志，避免在密码输入期间
         * 因 foregroundApp 变化而隐藏/显示 overlay。
         */
        @Volatile
        var passwordInputActivityActive: Boolean = false
    }

    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var isShowing = false
    /** 标记 overlay 正在淡出动画中（避免 hideOverlay 重复调用导致动画重启 + showLockOverlay 误走 calibrate 路径） */
    private var isHiding = false
    private var currentBlockedPackage: String? = null
    private val handler = Handler(Looper.getMainLooper())

    // 倒计时悬浮窗
    private var countdownWidgetView: View? = null
    private var isCountdownShowing = false
    private var countdownRunnable: Runnable? = null
    private var countdownWallClockStartMs: Long = 0L
    private var countdownTotalMs: Long = 0L
    private var countdownTextTime: TextView? = null
    private var countdownLayoutParams: WindowManager.LayoutParams? = null
    private var countdownCancelled = false
    private var onCountdownEnded: Runnable? = null
    /** 倒计时归零回调（由外部注入，触发 REST；与 onCountdownEnded 互补，确保归零瞬间响应） */
    private var onCountdownZeroReached: Runnable? = null
    /**
     * 倒计时归零公共 hook，供 WidgetManager 注入（转发给 EnforcementEngine）。
     * 设置后会覆盖内部 onCountdownZeroReached，ticker 归零时统一回调此 hook。
     */
    var onCountdownZeroReachedHook: Runnable?
        get() = onCountdownZeroReached
        set(value) { onCountdownZeroReached = value }
    /** 倒计时结束时的墙上时钟时间戳（权威源）。remaining = (endTime - now)。 */
    private var countdownEndTimeMs: Long = 0L
    /** 当前剩余秒数（毫秒），用于颜色阈值判定，由 ticker 维护，避免外部轮询驱动 */
    private var countdownCurrentRemainingMs: Long = 0L

    // 阈值提醒回调（3分钟/2分钟）
    private var countdownAlert3min: Runnable? = null
    private var countdownAlert2min: Runnable? = null
    private var countdownAlert3minFired = false
    private var countdownAlert2minFired = false

    // 覆盖层内倒计时（用于锁屏视图上的休息倒计时）
    private var backButton: TextView? = null

    // 脉冲动画
    private var pulseAnimator: ValueAnimator? = null
    private var lockCountdownText: TextView? = null
    private var lockCountdownRunnable: Runnable? = null
    private var lockCountdownWallClockStartMs: Long = 0L
    private var lockCountdownTotalMs: Long = 0L
    private var lockCountdownCancelled = false
    private var isLockOverlayWithCountdown = false

    // Lock overlay dismissed callback — notifies EnforcementEngine when user clicks button
    var onLockOverlayDismissed: (() -> Unit)? = null

    // 家长入口回调 — 从倒计时widget点击家长入口
    var onParentEntryFromWidget: (() -> Unit)? = null
    // 家长密码验证成功回调 — 从lock overlay或密码弹窗验证成功
    var onParentPasswordVerified: (() -> Unit)? = null

    // 密码输入是否活跃（自定义数字键盘正在显示）
    // 用于告诉 EnforcementEngine 在此期间不要因 foregroundApp 变化而隐藏 overlay
    var isPasswordInputActive: Boolean = false
        internal set

    // 自定义数字键盘相关
    private var keypadView: View? = null
    private var isKeypadShowing = false
    private var keypadInput: StringBuilder = StringBuilder()
    private var keypadDots: List<TextView> = emptyList()
    private var keypadError: TextView? = null

    /**
     * 检查是否有悬浮窗权限
     */
    fun hasOverlayPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(context)
        } else {
            true
        }
    }

    /**
     * 显示锁定覆盖层
     *
     * @param reason 阻止原因
     * @param packageName 被阻止的应用包名
     * @param durationSeconds 可选：休息倒计时秒数（0=不显示倒计时）
     * @param violationType 违规类型："continuous"（连续使用）或 "time_period"（时间范围违规）
     */
    fun showLockOverlay(reason: String, packageName: String, durationSeconds: Int = 0, violationType: String = "continuous") {
        if (!hasOverlayPermission()) {
            Log.w(TAG, "No overlay permission, cannot show lock")
            return
        }

        // 如果正在淡出（hideOverlay 动画进行中），立即清除旧视图后再创建新的，
        // 否则 calibrate 路径会在即将被 remove 的 view 上重启动画，导致"弹窗不消失"
        if (isHiding) {
            Log.d(TAG, "showLockOverlay: was hiding, clearing stale view first")
            hideOverlayImmediate()
        }

        // 如果已经在显示同一个 App 的覆盖层，仅校准休息倒计时，不重建视图（避免每轮询重启动画导致跳秒/闪烁）
        if (isShowing && !isHiding && currentBlockedPackage == packageName) {
            updateReasonText(reason)
            if (durationSeconds > 0) {
                calibrateLockCountdown(System.currentTimeMillis() + durationSeconds * 1000L)
            }
            return
        }

        // 切换到不同 App —— 先隐藏旧 overlay，再走完整创建流程
        cancelLockCountdown()
        if (isShowing) {
            hideOverlayImmediate()
        }

        try {
            currentBlockedPackage = packageName
            windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            overlayView = createLockView(reason, durationSeconds, violationType)

            val flags = WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_FULLSCREEN or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON

            val layoutParams = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                } else {
                    @Suppress("DEPRECATION")
                    WindowManager.LayoutParams.TYPE_PHONE
                },
                flags,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.CENTER
                // 防止 MIUI 在软键盘弹出时 resize overlay 窗口导致闪缩
                softInputMode = WindowManager.LayoutParams.SOFT_INPUT_ADJUST_NOTHING
            }

            windowManager?.addView(overlayView, layoutParams)
            isShowing = true

            // 入场动画
            overlayView?.alpha = 0f
            overlayView?.animate()
                ?.alpha(1f)
                ?.setDuration(300)
                ?.setInterpolator(DecelerateInterpolator())
                ?.start()

            // 启动覆盖层自带的休息倒计时
            if (durationSeconds > 0) {
                isLockOverlayWithCountdown = true
                startLockCountdown(durationSeconds.toLong())
            }

            Log.d(TAG, "Lock overlay shown for $packageName: $reason (duration=$durationSeconds)")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to show lock overlay", e)
        }
    }

    /**
     * 隐藏覆盖层（带动画）
     * 幂等：如果已经在隐藏中（isHiding=true），直接返回，避免重复调用导致动画重启。
     */
    fun hideOverlay() {
        if (!isShowing) return
        if (isHiding) {
            Log.d(TAG, "hideOverlay: already hiding, skip duplicate call")
            return
        }
        isHiding = true
        cancelLockCountdown()
        isPasswordInputActive = false

        overlayView?.let { view ->
            try {
                view.animate()
                    .alpha(0f)
                    .setDuration(200)
                    .withEndAction {
                        try {
                            windowManager?.removeView(view)
                        } catch (e: Exception) {
                            // 忽略
                        }
                        overlayView = null
                        isShowing = false
                        isHiding = false
                        currentBlockedPackage = null
                    }
                    .start()
            } catch (e: Exception) {
                hideOverlayImmediate()
            }
        }
    }

    /**
     * 立即隐藏覆盖层（无动画）
     * public —— EnforcementEngine 在 dismiss 路径调用，避免 200ms 淡出动画期间
     * 与 poll / 按钮重复点击产生竞争导致"弹窗不消失"。
     */
    fun hideOverlayImmediate() {
        cancelLockCountdown()
        isPasswordInputActive = false
        try {
            overlayView?.let { windowManager?.removeView(it) }
        } catch (e: Exception) {
            // 忽略
        }
        overlayView = null
        isShowing = false
        isHiding = false
        currentBlockedPackage = null
    }

    /**
     * 更新原因文本
     */
    private fun updateReasonText(reason: String) {
        try {
            overlayView?.findViewWithTag<TextView>("reason_text")?.text = reason
        } catch (e: Exception) {
            // 忽略
        }
    }

    /**
     * 创建锁定视图
     * 使用与 OverlayChannel 相同的糖果主题配色
     * 包含锁定内容和密码输入两种模式，点击"家长入口"切换到密码输入模式
     */
    private fun createLockView(reason: String, durationSeconds: Int = 0, violationType: String = "continuous"): View {
        // 根据 violationType 选择主题色：时间范围违规用蓝色系，连续使用违规用原紫色糖果色
        val isTimePeriod = violationType == "time_period"
        val candyPurple = if (isTimePeriod) 0xFF5C6BC0.toInt() else 0xFFB57EDC.toInt() // 时间违规：靛蓝
        val candyPeach = if (isTimePeriod) 0xFF42A5F5.toInt() else 0xFFFFAB91.toInt()  // 时间违规：蓝色
        val candyRed = 0xFFFF6B6B.toInt() // 按钮红色保持一致

        val density = context.resources.displayMetrics.density

        // 外层容器 - 半透明黑色背景
        val container = FrameLayout(context).apply {
            setBackgroundColor(0xDD000000.toInt())
            isClickable = true
            isFocusable = true
        }

        // 锁定内容视图
        val lockContent = createLockContentView(reason, durationSeconds, candyPurple, candyPeach, candyRed, density, violationType)

        // 密码输入视图（初始隐藏）
        val passwordContent = createPasswordContentView(candyPurple, candyPeach, density)
        passwordContent.visibility = View.GONE

        container.addView(lockContent)
        container.addView(passwordContent)

        // 保存密码输入相关的 view 引用，供密码输入逻辑使用
        // 通过 tag 在 overlayView 中查找
        lockContent.tag = "lock_content"
        passwordContent.tag = "password_content"

        return container
    }

    /**
     * 创建锁定内容视图（锁定模式）
     */
    private fun createLockContentView(reason: String, durationSeconds: Int, candyPurple: Int, candyPeach: Int, candyRed: Int, density: Float, violationType: String = "continuous"): View {
        val isTimePeriod = violationType == "time_period"
        // 内容卡片 - 圆角渐变背景
        val card = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            background = android.graphics.drawable.GradientDrawable(
                android.graphics.drawable.GradientDrawable.Orientation.TOP_BOTTOM,
                intArrayOf(candyPurple, candyPeach)
            ).apply {
                cornerRadius = 48f
            }
            setPadding(
                (40 * density).toInt(),
                (48 * density).toInt(),
                (40 * density).toInt(),
                (40 * density).toInt()
            )
        }

        // 锁定图标容器
        val iconContainer = FrameLayout(context).apply {
            layoutParams = FrameLayout.LayoutParams(
                (140 * density).toInt(),
                (140 * density).toInt(),
                Gravity.CENTER_HORIZONTAL
            )
        }

        val iconBackground = android.widget.ImageView(context).apply {
            background = android.graphics.drawable.GradientDrawable().apply {
                setColor(0xFFFFFFFF.toInt())
                shape = android.graphics.drawable.GradientDrawable.OVAL
            }
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        }
        iconContainer.addView(iconBackground)

        val iconEmoji = TextView(context).apply {
            text = if (isTimePeriod) "🕐" else "🔒"
            textSize = 52f
            gravity = Gravity.CENTER
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        }
        iconContainer.addView(iconEmoji)

        // 标题
        val titleView = TextView(context).apply {
            text = if (isTimePeriod) "现在不是使用时间" else "使用时间到啦！"
            textSize = 22f
            setTextColor(0xFFFFFFFF.toInt())
            gravity = Gravity.CENTER
            setPadding(
                (20 * density).toInt(),
                (28 * density).toInt(),
                (20 * density).toInt(),
                (12 * density).toInt()
            )
            typeface = Typeface.DEFAULT_BOLD
            maxLines = Int.MAX_VALUE
            setSingleLine(false)
            setLineSpacing(4f, 1.2f)
        }

        // 原因容器
        val reasonContainer = FrameLayout(context).apply {
            setPadding(
                (20 * density).toInt(),
                (16 * density).toInt(),
                (20 * density).toInt(),
                (16 * density).toInt()
            )
            background = android.graphics.drawable.GradientDrawable().apply {
                setColor(0x44FFFFFF.toInt())
                cornerRadius = 24f
            }
        }

        val reasonView = TextView(context).apply {
            tag = "reason_text"
            text = reason
            textSize = 16f
            setTextColor(0xFF4A4A6A.toInt())
            gravity = Gravity.CENTER
            maxLines = Int.MAX_VALUE
            setSingleLine(false)
            setLineSpacing(6f, 1.2f)
        }
        reasonContainer.addView(reasonView)

        // 返回按钮
        this.backButton = null
        // 休息倒计时进行中时，按钮初始禁用 —— 必须等倒计时归零（markRestEnded）才可点击（恢复原有功能）
        val buttonResting = durationSeconds > 0
        val btn = TextView(context).apply {
            text = if (buttonResting) "休息中…" else "回到纹纹小伙伴 🐻"
            textSize = 16f
            setTextColor(0xFFFFFFFF.toInt())
            gravity = Gravity.CENTER
            setPadding(
                (40 * density).toInt(),
                (18 * density).toInt(),
                (40 * density).toInt(),
                (18 * density).toInt()
            )
            typeface = Typeface.DEFAULT_BOLD
            background = android.graphics.drawable.GradientDrawable().apply {
                setColor(if (buttonResting) 0xFFB0BEC5.toInt() else candyRed) // 休息中灰色，否则糖果红
                cornerRadius = 28f
            }
            isEnabled = !buttonResting // 有倒计时时禁用，倒计时归零后由 markRestEnded 恢复
            setOnClickListener {
                if (!isEnabled) return@setOnClickListener
                // 不直接调 hideOverlay() —— 由 onLockOverlayDismissed 回调统一驱动隐藏，
                // 避免按钮 hideOverlay + 回调 engine.onOverlayDismissed 再 hideOverlay 的双重调用
                // 导致动画重启、view 残留、弹窗不消失
                onLockOverlayDismissed?.invoke()
                launchMainActivity()
            }
        }
        this@NativeOverlayManager.backButton = btn

        // === 休息倒计时文本 ===
        val countdownTextView = TextView(context).apply {
            tag = "lock_countdown_text"
            text = ""
            textSize = 28f
            setTextColor(0xFFFFFFFF.toInt())
            gravity = Gravity.CENTER
            typeface = Typeface.DEFAULT_BOLD
            setPadding(0, (8 * density).toInt(), 0, (8 * density).toInt())
            visibility = if (durationSeconds > 0) View.VISIBLE else View.GONE
        }
        this.lockCountdownText = countdownTextView

        // === 家长入口区域 ===
        val parentEntryLink = TextView(context).apply {
            text = "家长入口"
            textSize = 13f
            setTextColor(0xCCFFFFFF.toInt())
            gravity = Gravity.CENTER
            setPadding(0, (12 * density).toInt(), 0, 0)
            setOnClickListener {
                // 切换到密码输入模式（在 overlay 内部切换，不创建新窗口）
                isPasswordInputActive = true
                switchToPasswordMode()
            }
        }

        // 组装卡片
        card.addView(iconContainer)
        card.addView(titleView)
        card.addView(reasonContainer)
        card.addView(countdownTextView)
        card.addView(btn)
        card.addView(parentEntryLink)

        // 卡片布局参数
        val screenWidth = context.resources.displayMetrics.widthPixels
        val cardMargin = (48 * density).toInt()
        val cardParams = FrameLayout.LayoutParams(
            screenWidth - cardMargin * 2,
            FrameLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            gravity = Gravity.CENTER
        }

        val wrapper = FrameLayout(context)
        wrapper.addView(card, cardParams)
        return wrapper
    }

    /**
     * 创建密码输入视图（密码模式）— 使用自定义数字键盘，无 EditText
     */
    private fun createPasswordContentView(candyPurple: Int, candyPeach: Int, density: Float): View {
        // 内容卡片 - 圆角渐变背景
        val card = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            background = android.graphics.drawable.GradientDrawable(
                android.graphics.drawable.GradientDrawable.Orientation.TOP_BOTTOM,
                intArrayOf(candyPurple, candyPeach)
            ).apply {
                cornerRadius = 48f
            }
            setPadding(
                (24 * density).toInt(),
                (36 * density).toInt(),
                (24 * density).toInt(),
                (28 * density).toInt()
            )
        }

        // 标题
        val title = TextView(context).apply {
            text = "🔒  家长验证"
            textSize = 20f
            setTextColor(0xFFFFFFFF.toInt())
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, (16 * density).toInt())
            typeface = Typeface.DEFAULT_BOLD
        }

        // 密码圆点显示区（6位）
        val dotsRow = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            tag = "keypad_dots_row"
            setPadding(0, (8 * density).toInt(), 0, (8 * density).toInt())
        }
        val dots = mutableListOf<TextView>()
        for (i in 0 until 6) {
            val dot = TextView(context).apply {
                text = "○"
                textSize = 24f
                setTextColor(0xFFFFFFFF.toInt())
                gravity = Gravity.CENTER
                setPadding((6 * density).toInt(), 0, (6 * density).toInt(), 0)
            }
            dots.add(dot)
            dotsRow.addView(dot)
        }
        keypadDots = dots

        // 错误提示
        val errorText = TextView(context).apply {
            tag = "keypad_error"
            text = "密码错误"
            textSize = 12f
            setTextColor(0xFFFF6B6B.toInt())
            gravity = Gravity.CENTER
            visibility = View.GONE
            setPadding(0, (4 * density).toInt(), 0, (4 * density).toInt())
        }
        keypadError = errorText

        // 数字键盘（3x4 网格）— 使用 weight 均分宽度，适配不同屏幕
        val grid = GridLayout(context).apply {
            columnCount = 3
            rowCount = 4
            alignmentMode = GridLayout.ALIGN_BOUNDS
            useDefaultMargins = false
            setPadding(0, (8 * density).toInt(), 0, 0)
        }

        val keys = listOf("1", "2", "3", "4", "5", "6", "7", "8", "9", "", "0", "⌫")
        for (key in keys) {
            if (key.isEmpty()) {
                val placeholder = TextView(context).apply { visibility = View.INVISIBLE }
                grid.addView(placeholder, GridLayout.LayoutParams().apply {
                    width = 0
                    height = (52 * density).toInt()
                    columnSpec = GridLayout.spec(GridLayout.UNDEFINED, 1f)
                    setMargins((4 * density).toInt(), (4 * density).toInt(), (4 * density).toInt(), (4 * density).toInt())
                })
                continue
            }
            val keyBtn = TextView(context).apply {
                text = key
                textSize = if (key == "⌫") 18f else 22f
                setTextColor(0xFFFFFFFF.toInt())
                gravity = Gravity.CENTER
                typeface = Typeface.DEFAULT_BOLD
                background = android.graphics.drawable.GradientDrawable().apply {
                    setColor(0x44FFFFFF.toInt())
                    cornerRadius = 16f
                }
                isClickable = true
                isFocusable = true
                setOnClickListener {
                    onKeypadKey(key)
                }
            }
            grid.addView(keyBtn, GridLayout.LayoutParams().apply {
                width = 0
                height = (52 * density).toInt()
                columnSpec = GridLayout.spec(GridLayout.UNDEFINED, 1f)
                setMargins((4 * density).toInt(), (4 * density).toInt(), (4 * density).toInt(), (4 * density).toInt())
            })
        }

        // 取消按钮
        val cancelBtn = TextView(context).apply {
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
                switchToLockMode()
            }
        }

        card.addView(title)
        card.addView(dotsRow)
        card.addView(errorText)
        card.addView(grid)
        card.addView(cancelBtn)

        // 卡片布局参数 — 宽度使用屏幕宽度自适应，确保键盘完整显示
        val screenWidth = context.resources.displayMetrics.widthPixels
        val cardMaxWidth = (300 * density).toInt()
        val cardMarginH = (24 * density).toInt()
        val cardParams = FrameLayout.LayoutParams(
            minOf(screenWidth - cardMarginH * 2, cardMaxWidth),
            FrameLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            gravity = Gravity.CENTER
        }

        val wrapper = FrameLayout(context)
        wrapper.addView(card, cardParams)
        return wrapper
    }

    /**
     * 切换到密码输入模式（在 lock overlay 内部切换）
     */
    private fun switchToPasswordMode() {
        keypadInput.clear()
        updateKeypadDots()
        keypadError?.visibility = View.GONE

        val lockContent = overlayView?.findViewWithTag<View>("lock_content")
        val passwordContent = overlayView?.findViewWithTag<View>("password_content")
        lockContent?.visibility = View.GONE
        passwordContent?.visibility = View.VISIBLE
        Log.d(TAG, "Switched to password mode")
    }

    /**
     * 切换回锁定模式
     */
    private fun switchToLockMode() {
        isPasswordInputActive = false
        keypadInput.clear()

        val lockContent = overlayView?.findViewWithTag<View>("lock_content")
        val passwordContent = overlayView?.findViewWithTag<View>("password_content")
        passwordContent?.visibility = View.GONE
        lockContent?.visibility = View.VISIBLE
        Log.d(TAG, "Switched back to lock mode")
    }

    /**
     * 启动主界面
     */
    private fun launchMainActivity() {
        try {
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            context.startActivity(intent)
            Log.d(TAG, "Launched MainActivity")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to launch MainActivity", e)
        }
    }

    // ==================== 倒计时悬浮窗 ====================

    /**
     * 显示倒计时悬浮窗
     * 位于屏幕右上角，可拖动，与 Flutter side 样式一致
     *
     * @param totalSeconds 倒计时总秒数
     * @param onEnded 倒计时结束的回调（widget 被移除后触发）
     * @param onZeroReached 倒计时归零瞬间触发的回调（在 widget 移除前触发，用于立刻衔接 REST）
     */
    fun showCountdownOverlay(totalSeconds: Long, onEnded: Runnable? = null, onZeroReached: Runnable? = null) {
        if (!hasOverlayPermission()) {
            Log.w(TAG, "No overlay permission, cannot show countdown")
            return
        }

        hideCountdownOverlay()
        this.onCountdownEnded = onEnded
        this.onCountdownZeroReached = onZeroReached

        try {
            windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            countdownWidgetView = createCountdownView(totalSeconds)
            countdownTextTime = countdownWidgetView?.findViewWithTag("countdown_time")

            countdownLayoutParams = WindowManager.LayoutParams(
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                } else {
                    @Suppress("DEPRECATION")
                    WindowManager.LayoutParams.TYPE_PHONE
                },
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                        WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.TOP or Gravity.END
                x = 32
                y = 100
            }

            windowManager?.addView(countdownWidgetView, countdownLayoutParams)
            isCountdownShowing = true

            // 监听系统回收悬浮窗（MIUI 等可能主动 detach）
            countdownWidgetView?.addOnAttachStateChangeListener(object : View.OnAttachStateChangeListener {
                override fun onViewDetachedFromWindow(v: View) {
                    Log.w(TAG, "Countdown widget detached by system — will rebuild on next poll")
                    isCountdownShowing = false
                }
                override fun onViewAttachedToWindow(v: View) {}
            })

            countdownWidgetView?.alpha = 0f
            countdownWidgetView?.animate()
                ?.alpha(1f)
                ?.setDuration(200)
                ?.setInterpolator(DecelerateInterpolator())
                ?.start()

            startCountdownAnimation(totalSeconds)
            Log.d(TAG, "Countdown overlay shown: ${totalSeconds}s")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to show countdown overlay", e)
        }
    }

    /**
     * 显示倒计时悬浮窗并挂载 3/2 分钟阈值提醒回调。
     *
     * 阈值检测已内置于 [startCountdownAnimation] 的挂钟 ticker 中，
     * 此处只需在调用 [showCountdownOverlay] 前设置回调字段。
     *
     * @param totalSeconds 倒计时剩余总秒数
     * @param onAlert3min 跨过 3 分钟阈值时触发（一次性）
     * @param onAlert2min 跨过 2 分钟阈值时触发（一次性）
     * @param onEnded 倒计时归零后触发（widget 移除后）
     * @param onZeroReached 倒计时归零瞬间触发（widget 移除前，用于立刻衔接 REST）
     */
    fun showCountdownOverlayWithAlerts(
        totalSeconds: Long,
        onAlert3min: Runnable? = null,
        onAlert2min: Runnable? = null,
        onEnded: Runnable? = null,
        onZeroReached: Runnable? = null
    ) {
        countdownAlert3min = onAlert3min
        countdownAlert2min = onAlert2min
        showCountdownOverlay(totalSeconds, onEnded, onZeroReached)
    }

    /**
     * 更新倒计时剩余时间 —— 不重启校准模式
     *
     * 关键改动：原实现会 removeCallbacks + startCountdownAnimation，导致每 5s 轮询校准时
     * 整秒对齐抖动、与原生自走倒计时不同步。现改为只更新 wall-clock 基准指向新的 endTime，
     * 不取消正在运行的 ticker，下一个 tick 自然读到新值，实现平滑校准。
     *
     * 每次 monitorRunnable 检查时调用，重新校准倒计时。
     */
    fun updateCountdownTime(remainingSeconds: Long) {
        if (!isCountdownShowing) return
        calibrateCountdown(System.currentTimeMillis() + remainingSeconds * 1000L)
    }

    /**
     * 校准倒计时到指定的墙上时钟结束时间，不取消 ticker、不重启动画。
     * 通过反推 startMs 使得 (startMs + totalMs) == endTimeMs，ticker 用 elapsed 公式继续自走。
     */
    private fun calibrateCountdown(endTimeMs: Long) {
        if (!isCountdownShowing) return
        countdownEndTimeMs = endTimeMs
        // 反推：使 ticker 的 remainingMs = countdownTotalMs - elapsed 始终等于 endTime - now
        val now = System.currentTimeMillis()
        countdownWallClockStartMs = now
        countdownTotalMs = (endTimeMs - now).coerceAtLeast(0)
        Log.d(TAG, "Countdown calibrated to endTime, remaining=${countdownTotalMs / 1000}s (no restart)")
    }

    /**
     * 隐藏倒计时悬浮窗
     */
    fun hideCountdownOverlay() {
        countdownCancelled = true
        countdownRunnable?.let { handler.removeCallbacks(it) }
        countdownRunnable = null
        countdownAlert3min = null
        countdownAlert2min = null
        // 注意：不清空 onCountdownZeroReached/onCountdownZeroReachedHook，
        // 它由 WidgetManager 注入，跨多次 show/hide 复用，仅在 destroy 时释放
        countdownEndTimeMs = 0L
        countdownCurrentRemainingMs = 0L
        stopPulseAnimation()

        val view = countdownWidgetView
        countdownWidgetView = null
        isCountdownShowing = false
        countdownLayoutParams = null
        countdownTextTime = null

        view?.let {
            try {
                it.animate().cancel()
                windowManager?.removeView(it)
            } catch (e: Exception) { }
        }
    }

    /**
     * 检查倒计时是否正在显示
     */
    fun isCountdownShowing(): Boolean = isCountdownShowing

    /**
     * 创建倒计时悬浮窗视图
     * @param initialSeconds 初始显示秒数（避免硬编码 "05:00" 导致首帧闪烁）
     */
    private fun createCountdownView(initialSeconds: Long = 300L): View {
        val density = context.resources.displayMetrics.density
        val candyPurple = 0xFFB57EDC.toInt()
        val candyPeach = 0xFFFFAB91.toInt()
        val cornerRadius = (20 * density).toFloat()

        val container = FrameLayout(context).apply {
            background = android.graphics.drawable.GradientDrawable(
                android.graphics.drawable.GradientDrawable.Orientation.LEFT_RIGHT,
                intArrayOf(candyPurple, candyPeach)
            ).apply {
                this.cornerRadius = cornerRadius
            }
            // 固定宽度（加宽以容纳家长入口图标）
            layoutParams = FrameLayout.LayoutParams(
                (155 * density).toInt(),
                FrameLayout.LayoutParams.WRAP_CONTENT
            )
            setPadding(
                (16 * density).toInt(),
                (10 * density).toInt(),
                (12 * density).toInt(),
                (10 * density).toInt()
            )
        }

        val contentLayout = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }

        val emojiView = TextView(context).apply {
            tag = "countdown_emoji"
            text = "🐻"
            textSize = 20f
            setPadding(0, 0, (10 * density).toInt(), 0)
        }

        val timeView = TextView(context).apply {
            tag = "countdown_time"
            text = formatCountdownTime(initialSeconds)
            textSize = 16f
            setTextColor(0xFFFFFFFF.toInt())
            typeface = Typeface.DEFAULT_BOLD
            setShadowLayer(2f, 1f, 1f, 0x40000000)
            // 固定宽度确保不随文字长度变化
            minWidth = (60 * density).toInt()
            gravity = Gravity.CENTER
        }

        // 家长入口图标（不显眼的小锁）
        val parentEntryIcon = TextView(context).apply {
            tag = "parent_entry"
            text = "🔒"
            textSize = 12f
            setPadding((6 * density).toInt(), 0, 0, 0)
            alpha = 0.6f
            setOnClickListener {
                onParentEntryFromWidget?.invoke()
            }
        }

        contentLayout.addView(emojiView)
        contentLayout.addView(timeView)
        contentLayout.addView(parentEntryIcon)
        container.addView(contentLayout)

        setupDragListener(container)
        return container
    }

    /**
     * 启动倒计时动画
     *
     * ticker 是唯一的倒计时驱动者。校准（[updateCountdownTime]）只修改 wall-clock 基准，
     * 不取消/重启 ticker，因此动画连续无抖动。
     * 归零时先触发 [onCountdownZeroReached]（立刻衔接 REST，消除 5s 空窗），
     * 再触发 [onCountdownEnded] 并移除视图。
     */
    private fun startCountdownAnimation(totalSeconds: Long) {
        countdownCancelled = false
        countdownAlert3minFired = false
        countdownAlert2minFired = false
        val startSeconds = totalSeconds.coerceAtLeast(0)

        countdownTextTime?.let { textView ->
            textView.text = formatCountdownTime(startSeconds)
        }

        val now = System.currentTimeMillis()
        countdownWallClockStartMs = now
        countdownTotalMs = startSeconds * 1000L
        countdownEndTimeMs = now + countdownTotalMs
        countdownCurrentRemainingMs = countdownTotalMs

        countdownRunnable?.let { handler.removeCallbacks(it) }
        val ticker = object : Runnable {
            override fun run() {
                if (countdownCancelled) return
                // 始终以 endTimeMs 为权威源反推 remaining，校准后自然连续
                val remainingMs = (countdownEndTimeMs - System.currentTimeMillis()).coerceAtLeast(0)
                val remainingSec = (remainingMs / 1000).toInt()
                countdownCurrentRemainingMs = remainingMs

                countdownTextTime?.text = formatCountdownTime(remainingSec.toLong())

                // 3分钟提醒：仅当总时长 > 3分钟时触发（避免短限制在开始时误触发）
                if (!countdownAlert3minFired && startSeconds > 180 && remainingSec <= 180 && remainingSec > 120) {
                    countdownAlert3minFired = true
                    try { countdownAlert3min?.run() } catch (e: Exception) {
                        Log.e(TAG, "onAlert3min failed", e)
                    }
                }
                // 2分钟提醒：仅当总时长 > 2分钟时触发
                if (!countdownAlert2minFired && startSeconds > 120 && remainingSec <= 120 && remainingSec > 60) {
                    countdownAlert2minFired = true
                    try { countdownAlert2min?.run() } catch (e: Exception) {
                        Log.e(TAG, "onAlert2min failed", e)
                    }
                }

                if (remainingSec > 0) {
                    val msUntilNextSec = (1000 - (remainingMs % 1000)).coerceAtLeast(100)
                    handler.postDelayed(this, msUntilNextSec)
                } else {
                    if (!countdownCancelled) {
                        // 归零瞬间先触发 REST 衔接，再走原有移除流程
                        try { onCountdownZeroReached?.run() } catch (e: Exception) {
                            Log.e(TAG, "onZeroReached failed", e)
                        }
                        onCountdownEnded?.run()
                        removeCountdownView()
                    }
                }
            }
        }
        countdownRunnable = ticker
        handler.post(ticker)
    }

    /**
     * 查询当前倒计时剩余毫秒（由 WidgetManager 用于颜色阈值判定，避免依赖外部轮询值）。
     */
    fun getCountdownRemainingMs(): Long = countdownCurrentRemainingMs

    /**
     * 启动锁屏覆盖层上的倒计时（休息倒计时）
     */
    /**
     * 锁屏休息倒计时结束时间戳（墙上时钟毫秒，权威源）。
     * remaining = (lockCountdownEndTimeMs - now)。
     */
    private var lockCountdownEndTimeMs: Long = 0L

    private fun startLockCountdown(totalSeconds: Long) {
        lockCountdownCancelled = false
        val startSec = totalSeconds.coerceAtLeast(0)

        lockCountdownText?.text = formatCountdownTime(startSec)

        val now = System.currentTimeMillis()
        lockCountdownWallClockStartMs = now
        lockCountdownTotalMs = startSec * 1000L
        lockCountdownEndTimeMs = now + lockCountdownTotalMs

        lockCountdownRunnable?.let { handler.removeCallbacks(it) }
        val ticker = object : Runnable {
            override fun run() {
                if (lockCountdownCancelled) return
                // 始终以 endTimeMs 为权威源反推，校准后自然连续
                val remainingMs = (lockCountdownEndTimeMs - System.currentTimeMillis()).coerceAtLeast(0)
                val remainingSec = (remainingMs / 1000).toInt()

                lockCountdownText?.text = formatCountdownTime(remainingSec.toLong())

                if (remainingSec > 0) {
                    val msUntilNextSec = (1000 - (remainingMs % 1000)).coerceAtLeast(100)
                    handler.postDelayed(this, msUntilNextSec)
                } else {
                    if (!lockCountdownCancelled) {
                        lockCountdownText?.text = "0秒"
                        // 休息倒计时结束：按钮变为"可以继续啦"绿色样式，让用户明确知道休息已结束、可手动关闭
                        markRestEnded()
                    }
                }
            }
        }
        lockCountdownRunnable = ticker
        handler.post(ticker)
    }

    /**
     * 校准锁屏休息倒计时到指定结束时间，不取消/重启 ticker。
     * 用于 [showLockOverlay] 在同一 overlay 已显示时避免每轮询重启动画导致跳秒/闪烁。
     */
    private fun calibrateLockCountdown(endTimeMs: Long) {
        if (!isLockOverlayWithCountdown && lockCountdownRunnable == null) {
            // ticker 未运行（例如此前已结束进入 markRestEnded 状态），重新启动
            val now = System.currentTimeMillis()
            val remainingSec = ((endTimeMs - now) / 1000L).toInt().coerceAtLeast(0)
            isLockOverlayWithCountdown = true
            startLockCountdown(remainingSec.toLong())
            return
        }
        val now = System.currentTimeMillis()
        lockCountdownWallClockStartMs = now
        lockCountdownTotalMs = (endTimeMs - now).coerceAtLeast(0)
        lockCountdownEndTimeMs = endTimeMs
        lockCountdownCancelled = false
        Log.d(TAG, "Lock countdown calibrated to endTime, remaining=${lockCountdownTotalMs / 1000}s (no restart)")
    }

    /**
     * 标记休息已结束：按钮文案/颜色转为"可继续"，提供明确的视觉反馈（解决⑥）。
     * 即使 ticker 已停，也可由外部 REST 状态机调用以更新按钮。
     */
    fun markRestEnded() {
        isLockOverlayWithCountdown = false
        lockCountdownText?.text = "休息结束"
        backButton?.let { btn ->
            btn.isEnabled = true
            btn.text = "可以继续啦 ✨"
            btn.background = android.graphics.drawable.GradientDrawable().apply {
                setColor(0xFF66BB6A.toInt()) // 薄荷绿，区别于倒计时进行中的糖果红
                cornerRadius = 28f
            }
        }
    }

    /**
     * 取消锁屏覆盖层倒计时
     */
    private fun cancelLockCountdown() {
        lockCountdownCancelled = true
        lockCountdownEndTimeMs = 0L
        lockCountdownRunnable?.let { handler.removeCallbacks(it) }
        lockCountdownRunnable = null
        isLockOverlayWithCountdown = false
    }

    /**
     * 格式化倒计时时间 MM:SS
     */
    private fun formatCountdownTime(seconds: Long): String {
        val sec = seconds.coerceAtLeast(0)
        val min = sec / 60
        val s = sec % 60
        return String.format("%02d:%02d", min, s)
    }

    /**
     * 设置拖动监听
     */
    private fun setupDragListener(view: View) {
        var initialX = 0
        var initialY = 0
        var initialTouchX = 0f
        var initialTouchY = 0f

        view.setOnTouchListener { v, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    countdownLayoutParams?.let { params ->
                        initialX = params.x
                        initialY = params.y
                    }
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    countdownLayoutParams?.let { params ->
                        params.x = initialX + (initialTouchX - event.rawX).toInt()
                        params.y = initialY + (event.rawY - initialTouchY).toInt()
                        windowManager?.updateViewLayout(view, params)
                    }
                    true
                }
                else -> false
            }
        }
    }

    private fun removeCountdownView() {
        countdownRunnable?.let { handler.removeCallbacks(it) }
        countdownRunnable = null
        countdownAlert3min = null
        countdownAlert2min = null
        stopPulseAnimation()

        val view = countdownWidgetView
        countdownWidgetView = null
        isCountdownShowing = false
        countdownLayoutParams = null
        countdownTextTime = null

        view?.let {
            try {
                it.animate().cancel()
                windowManager?.removeView(it)
            } catch (e: Exception) { }
        }
    }

    /**
     * 启动脉冲动画（呼吸效果）
     * @param periodMs 一个完整脉冲周期的毫秒数
     */
    private fun startPulseAnimation(periodMs: Long) {
        stopPulseAnimation()
        try {
            pulseAnimator = ValueAnimator.ofFloat(1f, 0.85f, 1f).apply {
                duration = periodMs
                repeatCount = ValueAnimator.INFINITE
                interpolator = AccelerateDecelerateInterpolator()
                addUpdateListener { animator ->
                    val scale = animator.animatedValue as Float
                    countdownWidgetView?.scaleX = scale
                    countdownWidgetView?.scaleY = scale
                }
                start()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start pulse animation", e)
        }
    }

    /**
     * 停止脉冲动画并恢复原始缩放
     */
    private fun stopPulseAnimation() {
        pulseAnimator?.cancel()
        pulseAnimator = null
        try {
            countdownWidgetView?.scaleX = 1f
            countdownWidgetView?.scaleY = 1f
        } catch (e: Exception) {
            // 视图可能已销毁
        }
    }

    /**
     * 设置倒计时悬浮窗颜色
     * 根据阈值切换渐变背景、emoji 和脉冲动画，保留圆角
     *
     * @param color Android Color int (e.g. Color.YELLOW, Color.RED)
     */
    fun setCountdownColor(color: Int) {
        if (!isCountdownShowing) return
        try {
            val density = context.resources.displayMetrics.density
            val cornerRadius = (20 * density).toFloat()

            // 根据传入颜色映射到渐变对 + emoji + 脉冲周期
            val (gradient, pulsePeriod) = when (color) {
                android.graphics.Color.YELLOW ->
                    Triple(0xFFFFB74D.toInt(), 0xFFFF9800.toInt(), "⏳") to 1500L  // 5min: 琥珀黄→暖橙
                0xFFFF9800.toInt() ->
                    Triple(0xFFFF7043.toInt(), 0xFFFF5722.toInt(), "⚠️") to 1000L  // 3min: 橙红→深橙
                android.graphics.Color.RED ->
                    Triple(0xFFEF5350.toInt(), 0xFFC62828.toInt(), "🔴") to 600L   // 2min: 红色→深红
                else -> return
            }
            val (startColor, endColor, emoji) = gradient

            // 保留圆角渐变背景，只是更换颜色
            countdownWidgetView?.background = android.graphics.drawable.GradientDrawable(
                android.graphics.drawable.GradientDrawable.Orientation.LEFT_RIGHT,
                intArrayOf(startColor, endColor)
            ).apply {
                this.cornerRadius = cornerRadius
            }

            // 更新 emoji
            countdownWidgetView?.findViewWithTag<TextView>("countdown_emoji")?.text = emoji

            // 启动脉冲动画
            startPulseAnimation(pulsePeriod)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to set countdown color", e)
        }
    }

    // ==================== 自定义数字键盘密码输入 ====================
    // 使用纯 TextView/Button 实现数字键盘，不使用 EditText，不触发软键盘。
    // 密码输入界面直接内嵌在 lock overlay 中（模式切换），不创建独立的 overlay 窗口。
    // 原因：
    // 1. TYPE_APPLICATION_OVERLAY + EditText + 软键盘 = MIUI resize 循环 = 闪缩
    // 2. 从 Service 启动 Activity = MIUI SmartPower 杀进程
    // 3. 独立 keypad overlay + lock overlay = 叠加问题（lock 覆盖 keypad）
    // 4. 在同一 overlay 内模式切换 = 无叠加问题 = 稳定

    /**
     * 切换到密码输入模式（在 lock overlay 内部切换，不创建新窗口）
     * 供 MonitorForegroundService 的 debug broadcast 和 countdown widget 的🔒图标调用
     */
    fun showPasswordKeypadPublic() {
        // 如果 lock overlay 正在显示，切换到密码模式
        if (isShowing) {
            switchToPasswordMode()
        } else {
            // lock overlay 未显示时（从 countdown widget 触发），显示独立的 keypad
            isPasswordInputActive = true
            showStandaloneKeypad()
        }
    }

    /**
     * 显示独立的数字键盘 overlay（用于 COUNTDOWN 状态下从 countdown widget 触发家长入口）
     * 仅在 lock overlay 未显示时使用
     */
    private fun showStandaloneKeypad() {
        if (isKeypadShowing) return

        try {
            keypadInput.clear()
            windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            keypadView = createStandaloneKeypadView()

            val flags = WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_FULLSCREEN or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON

            val layoutParams = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                } else {
                    @Suppress("DEPRECATION")
                    WindowManager.LayoutParams.TYPE_PHONE
                },
                flags,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.CENTER
                softInputMode = WindowManager.LayoutParams.SOFT_INPUT_ADJUST_NOTHING
            }

            windowManager?.addView(keypadView, layoutParams)
            isKeypadShowing = true

            keypadView?.alpha = 0f
            keypadView?.animate()
                ?.alpha(1f)
                ?.setDuration(200)
                ?.setInterpolator(DecelerateInterpolator())
                ?.start()

            Log.d(TAG, "Standalone password keypad shown")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to show standalone keypad", e)
            isPasswordInputActive = false
        }
    }

    /**
     * 隐藏独立的数字键盘 overlay
     */
    private fun hideStandaloneKeypad() {
        if (!isKeypadShowing) return

        isPasswordInputActive = false
        isKeypadShowing = false
        keypadInput.clear()

        val view = keypadView
        keypadView = null
        keypadDots = emptyList()
        keypadError = null

        view?.let {
            try {
                it.animate().cancel()
                windowManager?.removeView(it)
            } catch (e: Exception) {
                try { windowManager?.removeView(it) } catch (_: Exception) {}
            }
        }
        Log.d(TAG, "Standalone password keypad hidden")
    }

    /**
     * 创建独立的数字键盘视图（COUNTDOWN 状态下使用）
     */
    private fun createStandaloneKeypadView(): View {
        val candyPurple = 0xFFB57EDC.toInt()
        val candyPeach = 0xFFFFAB91.toInt()
        val density = context.resources.displayMetrics.density

        val container = FrameLayout(context).apply {
            setBackgroundColor(0xDD000000.toInt())
            isClickable = true
            isFocusable = true
        }

        val card = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            background = android.graphics.drawable.GradientDrawable(
                android.graphics.drawable.GradientDrawable.Orientation.TOP_BOTTOM,
                intArrayOf(candyPurple, candyPeach)
            ).apply {
                cornerRadius = 48f
            }
            setPadding(
                (24 * density).toInt(),
                (36 * density).toInt(),
                (24 * density).toInt(),
                (28 * density).toInt()
            )
        }

        val title = TextView(context).apply {
            text = "🔒  家长验证"
            textSize = 20f
            setTextColor(0xFFFFFFFF.toInt())
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, (16 * density).toInt())
            typeface = Typeface.DEFAULT_BOLD
        }

        val dotsRow = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            setPadding(0, (8 * density).toInt(), 0, (8 * density).toInt())
        }
        val dots = mutableListOf<TextView>()
        for (i in 0 until 6) {
            val dot = TextView(context).apply {
                text = "○"
                textSize = 24f
                setTextColor(0xFFFFFFFF.toInt())
                gravity = Gravity.CENTER
                setPadding((6 * density).toInt(), 0, (6 * density).toInt(), 0)
            }
            dots.add(dot)
            dotsRow.addView(dot)
        }
        keypadDots = dots

        val errorText = TextView(context).apply {
            tag = "keypad_error"
            text = "密码错误"
            textSize = 12f
            setTextColor(0xFFFF6B6B.toInt())
            gravity = Gravity.CENTER
            visibility = View.GONE
            setPadding(0, (4 * density).toInt(), 0, (4 * density).toInt())
        }
        keypadError = errorText

        val grid = GridLayout(context).apply {
            columnCount = 3
            rowCount = 4
            alignmentMode = GridLayout.ALIGN_BOUNDS
            useDefaultMargins = false
            setPadding(0, (8 * density).toInt(), 0, 0)
        }

        val keys = listOf("1", "2", "3", "4", "5", "6", "7", "8", "9", "", "0", "⌫")
        for (key in keys) {
            if (key.isEmpty()) {
                val placeholder = TextView(context).apply { visibility = View.INVISIBLE }
                grid.addView(placeholder, GridLayout.LayoutParams().apply {
                    width = 0
                    height = (52 * density).toInt()
                    columnSpec = GridLayout.spec(GridLayout.UNDEFINED, 1f)
                    setMargins((4 * density).toInt(), (4 * density).toInt(), (4 * density).toInt(), (4 * density).toInt())
                })
                continue
            }
            val keyBtn = TextView(context).apply {
                text = key
                textSize = if (key == "⌫") 18f else 22f
                setTextColor(0xFFFFFFFF.toInt())
                gravity = Gravity.CENTER
                typeface = Typeface.DEFAULT_BOLD
                background = android.graphics.drawable.GradientDrawable().apply {
                    setColor(0x44FFFFFF.toInt())
                    cornerRadius = 16f
                }
                isClickable = true
                isFocusable = true
                setOnClickListener {
                    onKeypadKey(key)
                }
            }
            grid.addView(keyBtn, GridLayout.LayoutParams().apply {
                width = 0
                height = (52 * density).toInt()
                columnSpec = GridLayout.spec(GridLayout.UNDEFINED, 1f)
                setMargins((4 * density).toInt(), (4 * density).toInt(), (4 * density).toInt(), (4 * density).toInt())
            })
        }

        val cancelBtn = TextView(context).apply {
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
                hideStandaloneKeypad()
            }
        }

        card.addView(title)
        card.addView(dotsRow)
        card.addView(errorText)
        card.addView(grid)
        card.addView(cancelBtn)

        val screenWidth = context.resources.displayMetrics.widthPixels
        val cardMaxWidth = (300 * density).toInt()
        val cardMarginH = (24 * density).toInt()
        val cardParams = FrameLayout.LayoutParams(
            minOf(screenWidth - cardMarginH * 2, cardMaxWidth),
            FrameLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            gravity = Gravity.CENTER
        }

        container.addView(card, cardParams)
        return container
    }

    /**
     * 处理数字键盘按键
     */
    private fun onKeypadKey(key: String) {
        if (key == "⌫") {
            if (keypadInput.isNotEmpty()) {
                keypadInput.deleteCharAt(keypadInput.length - 1)
                updateKeypadDots()
            }
            return
        }

        if (keypadInput.length >= 6) return

        keypadInput.append(key)
        updateKeypadDots()

        // 输入满6位自动验证
        if (keypadInput.length == 6) {
            handler.postDelayed({ attemptKeypadUnlock() }, 200)
        }
    }

    /**
     * 更新密码圆点显示
     */
    private fun updateKeypadDots() {
        keypadDots.forEachIndexed { i, dot ->
            dot.text = if (i < keypadInput.length) "●" else "○"
        }
    }

    /**
     * 验证密码
     */
    private fun attemptKeypadUnlock() {
        val password = keypadInput.toString()
        if (password.isEmpty()) return

        val repo = com.qiaoqiao.qiaoqiao_companion.features.parent_mode.data.ParentPasswordRepository(context)
        if (repo.verifyPassword(password)) {
            Log.d(TAG, "Password correct, unlocking")
            if (isKeypadShowing) {
                hideStandaloneKeypad()
            } else {
                switchToLockMode()
            }
            onParentPasswordVerified?.invoke()
        } else {
            Log.d(TAG, "Password incorrect")
            keypadError?.text = "密码错误，请重试"
            keypadError?.visibility = View.VISIBLE
            keypadInput.clear()
            updateKeypadDots()
            // 1.5秒后隐藏错误提示
            handler.postDelayed({
                keypadError?.visibility = View.GONE
            }, 1500)
        }
    }

    /**
     * 清除所有 overlay（倒计时 widget + 锁定覆盖层）
     * 在 EnforcementEngine 启动前调用，确保没有残留的旧 widget
     */
    fun clearAllOverlays() {
        isPasswordInputActive = false
        passwordInputActivityActive = false
        hideStandaloneKeypad()
        hideCountdownOverlay()
        hideOverlayImmediate()
        Log.d(TAG, "All overlays cleared")
    }

    /**
     * 清理资源
     */
    fun destroy() {
        isPasswordInputActive = false
        passwordInputActivityActive = false
        handler.removeCallbacksAndMessages(null)
        stopPulseAnimation()
        cancelLockCountdown()
        hideStandaloneKeypad()
        hideOverlayImmediate()
        hideCountdownOverlay()
        windowManager = null
    }
}
