package com.qiaoqiao.qiaoqiao_companion.monitor

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
import android.view.animation.DecelerateInterpolator
import android.widget.FrameLayout
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
    }

    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var isShowing = false
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

    // 阈值提醒回调（3分钟/2分钟）
    private var countdownAlert3min: Runnable? = null
    private var countdownAlert2min: Runnable? = null
    private var countdownAlert3minFired = false
    private var countdownAlert2minFired = false

    // 秒表悬浮窗
    private var stopwatchWidgetView: View? = null
    private var stopwatchTextTime: TextView? = null
    private var stopwatchLayoutParams: WindowManager.LayoutParams? = null
    private var isStopwatchShowing = false

    // 覆盖层内倒计时（用于锁屏视图上的休息倒计时）
    private var backButton: TextView? = null
    private var lockCountdownText: TextView? = null
    private var lockCountdownRunnable: Runnable? = null
    private var lockCountdownWallClockStartMs: Long = 0L
    private var lockCountdownTotalMs: Long = 0L
    private var lockCountdownCancelled = false
    private var isLockOverlayWithCountdown = false

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
     */
    fun showLockOverlay(reason: String, packageName: String, durationSeconds: Int = 0) {
        cancelLockCountdown()

        if (!hasOverlayPermission()) {
            Log.w(TAG, "No overlay permission, cannot show lock")
            return
        }

        // 如果已经在显示同一个 App 的覆盖层，更新原因即可
        if (isShowing && currentBlockedPackage == packageName) {
            updateReasonText(reason)
            return
        }

        // 如果在显示其他 App 的覆盖层，先隐藏
        if (isShowing) {
            hideOverlayImmediate()
        }

        try {
            currentBlockedPackage = packageName
            windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            overlayView = createLockView(reason, durationSeconds)

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
     */
    fun hideOverlay() {
        if (!isShowing) return
        cancelLockCountdown()

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
     */
    private fun hideOverlayImmediate() {
        cancelLockCountdown()
        try {
            overlayView?.let { windowManager?.removeView(it) }
        } catch (e: Exception) {
            // 忽略
        }
        overlayView = null
        isShowing = false
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
     */
    private fun createLockView(reason: String, durationSeconds: Int = 0): View {
        val candyPurple = 0xFFB57EDC.toInt()
        val candyPeach = 0xFFFFAB91.toInt()
        val candyRed = 0xFFFF6B6B.toInt()

        val density = context.resources.displayMetrics.density

        // 外层容器 - 半透明黑色背景
        val container = FrameLayout(context).apply {
            setBackgroundColor(0xDD000000.toInt())
            isClickable = true
            isFocusable = true
        }

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
            text = "🔒"
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
            text = "使用时间到啦！"
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

        // 覆盖层休息倒计时（durationSeconds > 0 时显示）
        val countdownView = if (durationSeconds > 0) {
            FrameLayout(context).apply {
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    gravity = Gravity.CENTER_HORIZONTAL
                    topMargin = 16
                }
                setPadding(
                    (32 * density).toInt(),
                    (12 * density).toInt(),
                    (32 * density).toInt(),
                    (12 * density).toInt()
                )
                background = android.graphics.drawable.GradientDrawable().apply {
                    setColor(0x66FFFFFF.toInt())
                    cornerRadius = 28f
                }

                val innerLayout = LinearLayout(context).apply {
                    orientation = LinearLayout.HORIZONTAL
                    gravity = Gravity.CENTER
                }

                val timerIcon = TextView(context).apply {
                    text = "⏰"
                    textSize = 20f
                    setPadding(0, 0, (8 * density).toInt(), 0)
                }

                val timeText = TextView(context).apply {
                    text = formatCountdownTime(durationSeconds.toLong())
                    textSize = 26f
                    setTextColor(0xFFFFFFFF.toInt())
                    typeface = Typeface.DEFAULT_BOLD
                }
                lockCountdownText = timeText

                innerLayout.addView(timerIcon)
                innerLayout.addView(timeText)
                addView(innerLayout)
            }
        } else null

        // 返回按钮（有倒计时时初始禁用）
        this.backButton = null
        val btn = TextView(context).apply {
            text = if (durationSeconds > 0) "回到纹纹小伙伴 🐻" else "回到纹纹小伙伴 🐻"
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
            if (durationSeconds > 0) {
                isEnabled = false
                background = android.graphics.drawable.GradientDrawable().apply {
                    setColor(0xFF999999.toInt())
                    cornerRadius = 28f
                }
            } else {
                background = android.graphics.drawable.GradientDrawable().apply {
                    setColor(candyRed)
                    cornerRadius = 28f
                }
            }
            setOnClickListener {
                if (isEnabled) {
                    cancelLockCountdown()
                    hideOverlay()
                    launchMainActivity()
                }
            }
        }
        this@NativeOverlayManager.backButton = btn

        // 组装卡片
        card.addView(iconContainer)
        card.addView(titleView)
        card.addView(reasonContainer)
        countdownView?.let { card.addView(it) }
        card.addView(btn)

        // 卡片布局参数
        val screenWidth = context.resources.displayMetrics.widthPixels
        val cardMargin = (48 * density).toInt()
        val cardParams = FrameLayout.LayoutParams(
            screenWidth - cardMargin * 2,
            FrameLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            gravity = Gravity.CENTER
        }

        container.addView(card, cardParams)
        return container
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
     * @param onEnded 倒计时结束的回调
     */
    fun showCountdownOverlay(totalSeconds: Long, onEnded: Runnable? = null) {
        if (!hasOverlayPermission()) {
            Log.w(TAG, "No overlay permission, cannot show countdown")
            return
        }

        hideCountdownOverlay()
        this.onCountdownEnded = onEnded

        try {
            windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            countdownWidgetView = createCountdownView()
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
     * @param onEnded 倒计时归零时触发
     */
    fun showCountdownOverlayWithAlerts(
        totalSeconds: Long,
        onAlert3min: Runnable? = null,
        onAlert2min: Runnable? = null,
        onEnded: Runnable? = null
    ) {
        countdownAlert3min = onAlert3min
        countdownAlert2min = onAlert2min
        showCountdownOverlay(totalSeconds, onEnded)
    }

    /**
     * 更新倒计时剩余时间
     * 每次 monitorRunnable 检查时调用，重新校准倒计时
     */
    fun updateCountdownTime(remainingSeconds: Long) {
        if (!isCountdownShowing) return
        countdownRunnable?.let { handler.removeCallbacks(it) }
        countdownCancelled = true
        startCountdownAnimation(remainingSeconds)
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
     */
    private fun createCountdownView(): View {
        val density = context.resources.displayMetrics.density
        val candyPurple = 0xFFB57EDC.toInt()
        val candyPeach = 0xFFFFAB91.toInt()

        val container = FrameLayout(context).apply {
            val cornerRadius = (20 * density).toInt()
            background = android.graphics.drawable.GradientDrawable(
                android.graphics.drawable.GradientDrawable.Orientation.LEFT_RIGHT,
                intArrayOf(candyPurple, candyPeach)
            ).apply {
                this.cornerRadius = cornerRadius.toFloat()
            }
            setPadding(
                (16 * density).toInt(),
                (10 * density).toInt(),
                (16 * density).toInt(),
                (10 * density).toInt()
            )
        }

        val contentLayout = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }

        val emojiView = TextView(context).apply {
            text = "🐻"
            textSize = 20f
            setPadding(0, 0, (10 * density).toInt(), 0)
        }

        val timeView = TextView(context).apply {
            tag = "countdown_time"
            text = formatCountdownTime(300)
            textSize = 16f
            setTextColor(0xFFFFFFFF.toInt())
            typeface = Typeface.DEFAULT_BOLD
            setShadowLayer(2f, 1f, 1f, 0x40000000)
        }

        contentLayout.addView(emojiView)
        contentLayout.addView(timeView)
        container.addView(contentLayout)

        setupDragListener(container)
        return container
    }

    /**
     * 创建秒表悬浮窗视图
     * 显示 "已用 MM:SS" 格式，半透明深色背景
     */
    private fun createStopwatchView(usedSeconds: Long): View {
        val density = context.resources.displayMetrics.density

        val container = FrameLayout(context).apply {
            val cornerRadius = (20 * density).toInt()
            background = android.graphics.drawable.GradientDrawable().apply {
                setColor(0xCC000000.toInt())
                this.cornerRadius = cornerRadius.toFloat()
            }
            setPadding(
                (16 * density).toInt(),
                (10 * density).toInt(),
                (16 * density).toInt(),
                (10 * density).toInt()
            )
        }

        val contentLayout = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }

        val labelView = TextView(context).apply {
            text = "已用"
            textSize = 14f
            setTextColor(0xFFCCCCCC.toInt())
            setPadding(0, 0, (6 * density).toInt(), 0)
        }

        val timeView = TextView(context).apply {
            tag = "stopwatch_time"
            text = formatStopwatchTime(usedSeconds)
            textSize = 16f
            setTextColor(0xFFFFFFFF.toInt())
            typeface = Typeface.DEFAULT_BOLD
            setShadowLayer(2f, 1f, 1f, 0x40000000)
        }

        contentLayout.addView(labelView)
        contentLayout.addView(timeView)
        container.addView(contentLayout)

        setupStopwatchDragListener(container)
        return container
    }

    /**
     * 格式化秒表时间 "MM:SS"
     */
    private fun formatStopwatchTime(seconds: Long): String {
        val sec = seconds.coerceAtLeast(0)
        val min = sec / 60
        val s = sec % 60
        return String.format("%02d:%02d", min, s)
    }

    /**
     * 设置秒表悬浮窗拖动监听
     */
    private fun setupStopwatchDragListener(view: View) {
        var initialX = 0
        var initialY = 0
        var initialTouchX = 0f
        var initialTouchY = 0f

        view.setOnTouchListener { v, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    stopwatchLayoutParams?.let { params ->
                        initialX = params.x
                        initialY = params.y
                    }
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    stopwatchLayoutParams?.let { params ->
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

    /**
     * 启动倒计时动画
     */
    private fun startCountdownAnimation(totalSeconds: Long) {
        countdownCancelled = false
        countdownAlert3minFired = false
        countdownAlert2minFired = false
        val startSeconds = totalSeconds.coerceAtLeast(0)

        countdownTextTime?.let { textView ->
            textView.text = formatCountdownTime(startSeconds)
        }

        countdownWallClockStartMs = System.currentTimeMillis()
        countdownTotalMs = startSeconds * 1000L

        countdownRunnable?.let { handler.removeCallbacks(it) }
        val ticker = object : Runnable {
            override fun run() {
                if (countdownCancelled) return
                val elapsed = System.currentTimeMillis() - countdownWallClockStartMs
                val remainingMs = (countdownTotalMs - elapsed).coerceAtLeast(0)
                val remainingSec = (remainingMs / 1000).toInt()

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
     * 启动锁屏覆盖层上的倒计时（休息倒计时）
     */
    private fun startLockCountdown(totalSeconds: Long) {
        lockCountdownCancelled = false
        val startSec = totalSeconds.coerceAtLeast(0)

        lockCountdownText?.text = formatCountdownTime(startSec)

        lockCountdownWallClockStartMs = System.currentTimeMillis()
        lockCountdownTotalMs = startSec * 1000L

        lockCountdownRunnable?.let { handler.removeCallbacks(it) }
        val ticker = object : Runnable {
            override fun run() {
                if (lockCountdownCancelled) return
                val elapsed = System.currentTimeMillis() - lockCountdownWallClockStartMs
                val remainingMs = (lockCountdownTotalMs - elapsed).coerceAtLeast(0)
                val remainingSec = (remainingMs / 1000).toInt()

                lockCountdownText?.text = formatCountdownTime(remainingSec.toLong())

                if (remainingSec > 0) {
                    val msUntilNextSec = (1000 - (remainingMs % 1000)).coerceAtLeast(100)
                    handler.postDelayed(this, msUntilNextSec)
                } else {
                    if (!lockCountdownCancelled) {
                        lockCountdownText?.text = "0秒"
                        backButton?.let { btn ->
                            btn.isEnabled = true
                            btn.background = android.graphics.drawable.GradientDrawable().apply {
                                setColor(0xFFFF6B6B.toInt())
                                cornerRadius = 28f
                            }
                        }
                        isLockOverlayWithCountdown = false
                    }
                }
            }
        }
        lockCountdownRunnable = ticker
        handler.post(ticker)
    }

    /**
     * 取消锁屏覆盖层倒计时
     */
    private fun cancelLockCountdown() {
        lockCountdownCancelled = true
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

    // ==================== 秒表悬浮窗（WidgetManager 使用） ====================

    /**
     * 显示秒表悬浮窗
     * 由 WidgetManager 调用，在监控阶段显示已使用时间
     *
     * @param usedSeconds 已使用秒数
     */
    fun showStopwatchWidget(usedSeconds: Long) {
        if (!hasOverlayPermission()) {
            Log.w(TAG, "No overlay permission, cannot show stopwatch")
            return
        }

        // 如果已经在显示，只更新时间
        if (isStopwatchShowing && stopwatchWidgetView != null) {
            updateStopwatchTime(usedSeconds)
            return
        }

        hideStopwatchWidget()

        try {
            windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            stopwatchWidgetView = createStopwatchView(usedSeconds)
            stopwatchTextTime = stopwatchWidgetView?.findViewWithTag("stopwatch_time")

            stopwatchLayoutParams = WindowManager.LayoutParams(
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                } else {
                    @Suppress("DEPRECATION")
                    WindowManager.LayoutParams.TYPE_PHONE
                },
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                        WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.TOP or Gravity.END
                x = 32
                y = 100
            }

            windowManager?.addView(stopwatchWidgetView, stopwatchLayoutParams)
            isStopwatchShowing = true

            stopwatchWidgetView?.alpha = 0f
            stopwatchWidgetView?.animate()
                ?.alpha(1f)
                ?.setDuration(200)
                ?.setInterpolator(DecelerateInterpolator())
                ?.start()

            Log.d(TAG, "Stopwatch widget shown: ${usedSeconds}s used")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to show stopwatch widget", e)
        }
    }

    /**
     * 更新秒表已使用时间
     *
     * @param usedSeconds 已使用秒数
     */
    fun updateStopwatchTime(usedSeconds: Long) {
        if (!isStopwatchShowing) return
        try {
            stopwatchTextTime?.text = formatStopwatchTime(usedSeconds)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update stopwatch time", e)
        }
    }

    /**
     * 隐藏秒表悬浮窗
     */
    fun hideStopwatchWidget() {
        val view = stopwatchWidgetView
        stopwatchWidgetView = null
        isStopwatchShowing = false
        stopwatchLayoutParams = null
        stopwatchTextTime = null

        view?.let {
            try {
                it.animate().cancel()
                windowManager?.removeView(it)
            } catch (e: Exception) {
                // 视图可能已被系统移除
            }
        }
    }

    /**
     * 设置倒计时悬浮窗颜色
     *
     * @param color Android Color int (e.g. Color.YELLOW, Color.RED)
     */
    fun setCountdownColor(color: Int) {
        if (!isCountdownShowing) return
        try {
            countdownWidgetView?.setBackgroundColor(color)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to set countdown color", e)
        }
    }

    /**
     * 清理资源
     */
    fun destroy() {
        handler.removeCallbacksAndMessages(null)
        cancelLockCountdown()
        hideOverlayImmediate()
        hideCountdownOverlay()
        hideStopwatchWidget()
        windowManager = null
    }
}
