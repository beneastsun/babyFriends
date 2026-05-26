package com.qiaoqiao.qiaoqiao_companion.monitor

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
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
import android.view.animation.DecelerateInterpolator
import android.view.animation.LinearInterpolator
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
    private var countdownAnimator: ValueAnimator? = null
    private var countdownTextTime: TextView? = null
    private var countdownLayoutParams: WindowManager.LayoutParams? = null
    private var countdownCancelled = false
    private var onCountdownEnded: Runnable? = null

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
     */
    fun showLockOverlay(reason: String, packageName: String) {
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
            overlayView = createLockView(reason)

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

            Log.d(TAG, "Lock overlay shown for $packageName: $reason")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to show lock overlay", e)
        }
    }

    /**
     * 隐藏覆盖层（带动画）
     */
    fun hideOverlay() {
        if (!isShowing) return

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
    private fun createLockView(reason: String): View {
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

        // 返回按钮
        val backButton = TextView(context).apply {
            text = "回到纹纹小伙伴 🐻"
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
                setColor(candyRed)
                cornerRadius = 28f
            }
            setOnClickListener {
                hideOverlay()
                launchMainActivity()
            }
        }

        // 组装卡片
        card.addView(iconContainer)
        card.addView(titleView)
        card.addView(reasonContainer)
        card.addView(backButton)

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
     * 更新倒计时剩余时间
     * 每次 monitorRunnable 检查时调用，重新校准倒计时
     */
    fun updateCountdownTime(remainingSeconds: Long) {
        if (!isCountdownShowing) return
        countdownAnimator?.cancel()
        countdownCancelled = true
        startCountdownAnimation(remainingSeconds)
    }

    /**
     * 隐藏倒计时悬浮窗
     */
    fun hideCountdownOverlay() {
        countdownCancelled = true
        countdownAnimator?.cancel()
        countdownAnimator = null

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
     * 启动倒计时动画
     */
    private fun startCountdownAnimation(totalSeconds: Long) {
        countdownCancelled = false
        val startSeconds = totalSeconds.coerceAtLeast(0)

        countdownTextTime?.let { textView ->
            textView.text = formatCountdownTime(startSeconds)
        }

        countdownAnimator = ValueAnimator.ofInt(startSeconds.toInt(), 0).apply {
            duration = startSeconds * 1000L
            interpolator = LinearInterpolator()

            addUpdateListener { animation ->
                if (countdownCancelled) return@addUpdateListener
                val current = animation.animatedValue as Int
                countdownTextTime?.text = formatCountdownTime(current.coerceAtLeast(0).toLong())
            }

            addListener(object : AnimatorListenerAdapter() {
                override fun onAnimationCancel(animation: Animator) {
                    countdownCancelled = true
                }

                override fun onAnimationEnd(animation: Animator) {
                    if (countdownCancelled) return
                    onCountdownEnded?.run()
                    removeCountdownView()
                }
            })
        }
        countdownAnimator?.start()
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
        val view = countdownWidgetView
        countdownWidgetView = null
        isCountdownShowing = false
        countdownLayoutParams = null
        countdownTextTime = null
        countdownAnimator = null

        view?.let {
            try {
                it.animate().cancel()
                windowManager?.removeView(it)
            } catch (e: Exception) { }
        }
    }

    /**
     * 清理资源
     */
    fun destroy() {
        handler.removeCallbacksAndMessages(null)
        hideOverlayImmediate()
        hideCountdownOverlay()
        windowManager = null
    }
}
