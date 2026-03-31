package com.qiaoqiao.qiaoqiao_companion.channels

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.ValueAnimator
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.view.Gravity
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.view.animation.DecelerateInterpolator
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * 悬浮窗通道
 * 用于显示提醒和锁定界面
 */
class OverlayChannel(private val context: Context, private val channel: MethodChannel) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "com.qiaoqiao.companion/overlay"

        /**
         * 检查是否有悬浮窗权限
         */
        fun hasOverlayPermission(context: Context): Boolean {
            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                Settings.canDrawOverlays(context)
            } else {
                true
            }
        }

        /**
         * 打开悬浮窗权限设置页面
         */
        fun openOverlaySettings(context: Context) {
            val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:${context.packageName}")
                ).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
            } else {
                Intent(Settings.ACTION_APPLICATION_SETTINGS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
            }
            context.startActivity(intent)
        }
    }

    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var isOverlayShowing = false
    private var currentPackageName: String = ""
    private var isDismissible: Boolean = true

    // 倒计时悬浮窗相关
    private var countdownWidgetView: View? = null
    private var isCountdownWidgetShowing = false
    private var countdownAnimator: ValueAnimator? = null
    private var countdownWidgetLayoutParams: WindowManager.LayoutParams? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasPermission" -> {
                result.success(hasOverlayPermission(context))
            }

            "requestPermission" -> {
                openOverlaySettings(context)
                result.success(null)
            }

            "showOverlay" -> {
                val title = call.argument<String>("title") ?: ""
                val message = call.argument<String>("message") ?: ""
                val type = call.argument<String>("type") ?: "reminder"
                val durationSeconds = call.argument<Int>("durationSeconds") ?: 0
                val dismissible = call.argument<Boolean>("dismissible") ?: true
                val packageName = call.argument<String>("packageName") ?: ""
                val dismissDelaySeconds = call.argument<Int>("dismissDelaySeconds") ?: 0
                val remainingDismissSeconds = call.argument<Int>("remainingDismissSeconds") ?: 0
                showOverlay(title, message, type, durationSeconds, dismissible, packageName, dismissDelaySeconds, remainingDismissSeconds, result)
            }

            "hideOverlay" -> {
                hideOverlay()
                result.success(null)
            }

            "isOverlayShowing" -> {
                result.success(isOverlayShowing)
            }

            "showCountdownWidget" -> {
                val totalSeconds = call.argument<Int>("totalSeconds") ?: 300
                showCountdownWidget(totalSeconds, result)
            }

            "hideCountdownWidget" -> {
                hideCountdownWidget()
                result.success(null)
            }

            "isCountdownWidgetShowing" -> {
                result.success(isCountdownWidgetShowing)
            }

            else -> {
                result.notImplemented()
            }
        }
    }

    /**
     * 显示悬浮窗
     */
    private fun showOverlay(
        title: String,
        message: String,
        type: String,
        durationSeconds: Int,
        dismissible: Boolean,
        packageName: String,
        dismissDelaySeconds: Int,
        remainingDismissSeconds: Int,
        result: MethodChannel.Result
    ) {
        if (!hasOverlayPermission(context)) {
            result.error("NO_PERMISSION", "没有悬浮窗权限", null)
            return
        }

        if (isOverlayShowing) {
            hideOverlay()
        }

        // 保存状态
        currentPackageName = packageName
        isDismissible = dismissible

        try {
            windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager

            // 创建悬浮窗视图
            overlayView = createOverlayView(title, message, type, durationSeconds, dismissible, dismissDelaySeconds, remainingDismissSeconds)

            // 设置窗口参数
            // 对于 lock 类型或 forbidden_locked 类型，需要真正阻止用户操作，不允许触摸穿透
            // 对于其他类型（提醒），允许触摸穿透但要确保显示在最上层
            val isLockType = type == "lock" || type == "forbidden_locked"

            val flags = if (isLockType) {
                // 锁定类型：完全阻止用户操作
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                        WindowManager.LayoutParams.FLAG_FULLSCREEN or
                        WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            } else {
                // 提醒类型：允许窗口外触摸穿透，但窗口内按钮仍可点击
                // 添加 FLAG_LAYOUT_IN_SCREEN 确保全屏时也能显示在上层
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                        WindowManager.LayoutParams.FLAG_LOCAL_FOCUS_MODE
            }

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
            isOverlayShowing = true

            // 入场动画
            overlayView?.alpha = 0f
            overlayView?.animate()
                ?.alpha(1f)
                ?.setDuration(300)
                ?.setInterpolator(DecelerateInterpolator())
                ?.start()

            result.success(null)
        } catch (e: Exception) {
            result.error("OVERLAY_ERROR", e.message, null)
        }
    }

    /**
     * 创建悬浮窗视图 - 糖果风格配色
     */
    private fun createOverlayView(
        title: String,
        message: String,
        type: String,
        durationSeconds: Int,
        dismissible: Boolean,
        dismissDelaySeconds: Int,
        remainingDismissSeconds: Int
    ): View {
        // 糖果主题配色
        val candyPurple = 0xFFB57EDC.toInt()  // 薰衣草紫
        val candyPeach = 0xFFFFAB91.toInt()    // 蜜桃粉
        val candySuccess = 0xFF81C784.toInt()  // 薄荷绿
        val candyWarning = 0xFFFFB74D.toInt()  // 蜜桃橙
        val candyError = 0xFFFF6B6B.toInt()    // 糖果红

        // 根据 type 获取强调色
        val accentColor = when (type) {
            "reminder", "forbidden_dismissible" -> candySuccess
            "warning" -> candyWarning
            "serious" -> candyPeach
            "lock", "forbidden_locked" -> candyError
            else -> candySuccess
        }

        // 创建容器
        val container = FrameLayout(context).apply {
            setBackgroundColor(0xCC000000.toInt()) // 半透明黑色背景
            isClickable = true
            isFocusable = true
        }

        // 内容卡片 - 圆角渐变背景
        val card = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            // 使用渐变背景：薰衣草紫 -> 蜜桃粉
            background = android.graphics.drawable.GradientDrawable(
                android.graphics.drawable.GradientDrawable.Orientation.TOP_BOTTOM,
                intArrayOf(candyPurple, candyPeach)
            ).apply {
                cornerRadius = 48f // 大圆角
            }
            setPadding(48, 56, 48, 48)
        }

        // 巧巧形象容器（圆形背景 + 表情）
        val avatarContainer = FrameLayout(context).apply {
            layoutParams = FrameLayout.LayoutParams(160, 160, Gravity.CENTER_HORIZONTAL)
        }

        val avatarBackground = android.widget.ImageView(context).apply {
            // 白色圆形背景
            background = android.graphics.drawable.GradientDrawable().apply {
                setColor(0xFFFFFFFF.toInt())
                shape = android.graphics.drawable.GradientDrawable.OVAL
            }
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        }
        avatarContainer.addView(avatarBackground)

        // 巧巧表情 - 使用小熊 emoji
        val avatarEmoji = TextView(context).apply {
            text = when (type) {
                "reminder", "forbidden_dismissible" -> "🐻"
                "warning" -> "🐻"
                "serious" -> "🐻"
                "lock", "forbidden_locked" -> "🐻"
                else -> "🐻"
            }
            textSize = 56f
            gravity = Gravity.CENTER
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        }
        avatarContainer.addView(avatarEmoji)

        // 标题 - 白色文字（自适应宽度）
        val titleView = TextView(context).apply {
            text = title
            textSize = 22f
            setTextColor(0xFFFFFFFF.toInt())
            gravity = Gravity.CENTER
            setPadding(24, 32, 24, 16)
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            // 自适应：自动换行，无行数限制
            maxLines = Int.MAX_VALUE
            setSingleLine(false)
            setLineSpacing(4f, 1.2f)
        }

        // 消息容器 - 白色半透明背景
        val messageContainer = android.widget.FrameLayout(context).apply {
            setPadding(24, 20, 24, 20)
            background = android.graphics.drawable.GradientDrawable().apply {
                setColor(0x44FFFFFF.toInt())
                cornerRadius = 24f
            }
        }

        val messageView = TextView(context).apply {
            text = message
            textSize = 16f
            setTextColor(0xFF4A4A6A.toInt())
            gravity = Gravity.CENTER
            // 自适应：自动换行，无行数限制
            maxLines = Int.MAX_VALUE
            setSingleLine(false)
            setLineSpacing(6f, 1.2f)
        }
        messageContainer.addView(messageView)

        // 倒计时（如果有）- 白色容器
        var countdownTextView: TextView? = null
        val countdownView = if (durationSeconds > 0) {
            android.widget.FrameLayout(context).apply {
                setPadding(32, 16, 32, 16)
                background = android.graphics.drawable.GradientDrawable().apply {
                    setColor(0x66FFFFFF.toInt())
                    cornerRadius = 28f
                }
            }.apply {
                val contentLayout = LinearLayout(context).apply {
                    orientation = LinearLayout.HORIZONTAL
                    gravity = Gravity.CENTER
                }

                val timerIcon = TextView(context).apply {
                    text = "⏰"
                    textSize = 24f
                    setPadding(0, 0, 12, 0)
                }

                countdownTextView = TextView(context).apply {
                    text = "${durationSeconds}秒"
                    textSize = 28f
                    setTextColor(0xFFFFFFFF.toInt())
                    typeface = android.graphics.Typeface.DEFAULT_BOLD
                }

                contentLayout.addView(timerIcon)
                contentLayout.addView(countdownTextView)
                addView(contentLayout)
            }
        } else null

        // 添加到卡片
        card.addView(avatarContainer)
        card.addView(titleView)
        card.addView(messageContainer)
        countdownView?.let {
            val params = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                topMargin = 24
                gravity = Gravity.CENTER_HORIZONTAL
            }
            it.layoutParams = params
            card.addView(it)
        }

        // 关闭按钮（如果可关闭或有延迟关闭时间）
        if (dismissible || dismissDelaySeconds > 0) {
            val closeButton = TextView(context).apply {
                textSize = 16f
                setTextColor(0xFFFFFFFF.toInt())
                gravity = Gravity.CENTER
                setPadding(48, 20, 48, 20)
                typeface = android.graphics.Typeface.DEFAULT_BOLD

                if (dismissDelaySeconds > 0) {
                    // 延迟关闭模式
                    val initialSeconds = if (remainingDismissSeconds > 0) remainingDismissSeconds else dismissDelaySeconds
                    isEnabled = remainingDismissSeconds <= 0
                    text = if (isEnabled) "知道了 ✨" else "${initialSeconds}秒后可关闭"
                    background = android.graphics.drawable.GradientDrawable().apply {
                        setColor(if (isEnabled) accentColor else 0xFF999999.toInt())
                        cornerRadius = 28f
                    }
                } else {
                    // 立即可关闭
                    text = "知道了 ✨"
                    background = android.graphics.drawable.GradientDrawable().apply {
                        setColor(accentColor)
                        cornerRadius = 28f
                    }
                }

                setOnClickListener {
                    if (isEnabled) {
                        // 通知 Flutter 用户关闭了 overlay
                        notifyDismissed()
                        hideOverlay()
                        // 启动巧巧app，将禁用的app推到后台
                        launchMainActivity()
                    }
                }
            }
            card.addView(closeButton)

            // 如果有延迟关闭时间且还未启用，启动倒计时
            if (dismissDelaySeconds > 0 && remainingDismissSeconds <= 0) {
                startDismissCountdown(closeButton, dismissDelaySeconds)
            } else if (remainingDismissSeconds > 0) {
                // 使用剩余秒数启动倒计时
                startDismissCountdown(closeButton, remainingDismissSeconds)
            }
        }

        // 设置卡片布局参数 - 使用MATCH_PARENT确保宽度自适应
        val displayMetrics = context.resources.displayMetrics
        val screenWidth = displayMetrics.widthPixels
        // 卡片宽度 = 屏幕宽度 - 左右边距(各48dp)
        val cardMargin = (48 * displayMetrics.density).toInt()
        val cardParams = FrameLayout.LayoutParams(
            screenWidth - cardMargin * 2,
            FrameLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            gravity = Gravity.CENTER
            leftMargin = cardMargin
            rightMargin = cardMargin
        }

        container.addView(card, cardParams)

        // 如果有倒计时，启动倒计时动画
        if (durationSeconds > 0 && countdownTextView != null) {
            startCountdown(countdownTextView!!, durationSeconds)
        }

        return container
    }

    /**
     * 通知 Flutter overlay 被关闭
     */
    private fun notifyDismissed() {
        channel.invokeMethod("onOverlayDismissed", mapOf(
            "packageName" to currentPackageName
        ))
    }

    /**
     * 启动倒计时
     */
    private fun startCountdown(textView: TextView, seconds: Int) {
        var remaining = seconds
        val animator = ValueAnimator.ofInt(seconds, 0).apply {
            duration = seconds * 1000L
            interpolator = DecelerateInterpolator()

            addUpdateListener { animation ->
                val current = animation.animatedValue as Int
                if (current != remaining) {
                    remaining = current
                    textView.text = "${remaining}秒"
                }
            }

            addListener(object : AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: Animator) {
                    textView.text = "0秒"
                }
            })
        }
        animator.start()
    }

    /**
     * 启动关闭按钮倒计时
     */
    private fun startDismissCountdown(button: TextView, seconds: Int) {
        var remaining = seconds
        button.tag = "countdown_active"  // 标记倒计时正在进行
        val handler = android.os.Handler(android.os.Looper.getMainLooper())
        val runnable = object : Runnable {
            override fun run() {
                // 检查按钮是否还有效（视图可能已被移除）
                if (button.tag != "countdown_active") return

                remaining--
                if (remaining > 0) {
                    button.text = "${remaining}秒后可关闭"
                    handler.postDelayed(this, 1000)
                } else {
                    // 倒计时结束，启用按钮
                    button.tag = "countdown_done"
                    button.text = "知道了"
                    button.isEnabled = true
                    button.isClickable = true
                    button.setBackgroundColor(0xFF4CAF50.toInt())
                }
            }
        }
        handler.postDelayed(runnable, 1000)
    }

    /**
     * 隐藏悬浮窗
     */
    private fun hideOverlay() {
        overlayView?.let { view ->
            view.animate()
                .alpha(0f)
                .setDuration(200)
                .setListener(object : AnimatorListenerAdapter() {
                    override fun onAnimationEnd(animation: Animator) {
                        try {
                            windowManager?.removeView(view)
                        } catch (e: Exception) {
                            // 忽略移除失败
                        }
                        overlayView = null
                        isOverlayShowing = false
                    }
                })
                .start()
        }
    }

    /**
     * 启动巧巧app主界面，将当前禁用的app推到后台
     */
    private fun launchMainActivity() {
        try {
            val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (intent != null) {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                context.startActivity(intent)
            }
        } catch (e: Exception) {
            // 忽略启动失败
        }
    }

    // ==================== 倒计时悬浮窗相关方法 ====================

    /**
     * 显示倒计时悬浮窗
     * 位于屏幕右上角，可拖动，不可关闭
     */
    private fun showCountdownWidget(totalSeconds: Int, result: MethodChannel.Result) {
        if (!hasOverlayPermission(context)) {
            result.error("NO_PERMISSION", "没有悬浮窗权限", null)
            return
        }

        // 如果已经在显示，先隐藏
        if (isCountdownWidgetShowing) {
            hideCountdownWidget()
        }

        try {
            windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager

            // 创建倒计时悬浮窗视图
            countdownWidgetView = createCountdownWidgetView(totalSeconds)

            // 设置窗口参数 - 小型悬浮窗，可触摸拖动
            countdownWidgetLayoutParams = WindowManager.LayoutParams(
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
                // 初始位置：右上角
                gravity = Gravity.TOP or Gravity.END
                x = 32  // 距离右边 32dp 对应的像素
                y = 100 // 距离顶部 100dp 对应的像素（状态栏下方）
            }

            windowManager?.addView(countdownWidgetView, countdownWidgetLayoutParams)
            isCountdownWidgetShowing = true

            // 入场动画
            countdownWidgetView?.alpha = 0f
            countdownWidgetView?.animate()
                ?.alpha(1f)
                ?.setDuration(200)
                ?.setInterpolator(DecelerateInterpolator())
                ?.start()

            result.success(null)
        } catch (e: Exception) {
            result.error("COUNTDOWN_WIDGET_ERROR", e.message, null)
        }
    }

    /**
     * 创建倒计时悬浮窗视图
     */
    private fun createCountdownWidgetView(totalSeconds: Int): View {
        val density = context.resources.displayMetrics.density

        // 糖果主题配色
        val candyPurple = 0xFFB57EDC.toInt()  // 薰衣草紫
        val candyPeach = 0xFFFFAB91.toInt()    // 蜜桃粉

        // 创建容器 - 渐变圆角背景
        val container = FrameLayout(context).apply {
            // 渐变背景：薰衣草紫 -> 蜜桃粉
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

        // 内容布局
        val contentLayout = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }

        // 小熊 emoji 图标
        val emojiView = TextView(context).apply {
            text = "🐻"
            textSize = 20f
            setPadding(0, 0, (10 * density).toInt(), 0)
        }

        // 倒计时文字
        val countdownText = TextView(context).apply {
            id = View.generateViewId()
            text = formatCountdownTime(totalSeconds)
            textSize = 16f
            setTextColor(0xFFFFFFFF.toInt())
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            setShadowLayer(2f, 1f, 1f, 0x40000000)
        }

        contentLayout.addView(emojiView)
        contentLayout.addView(countdownText)

        container.addView(contentLayout)

        // 启动倒计时动画
        startCountdownWidgetAnimation(countdownText, totalSeconds)

        // 设置拖动监听
        setupDragListener(container)

        return container
    }

    /**
     * 启动倒计时动画
     */
    private var notified3min = false
    private var notified2min = false

    private fun startCountdownWidgetAnimation(textView: TextView, totalSeconds: Int) {
        countdownAnimator?.cancel() // 取消之前的动画

        // 重置通知标记
        notified3min = false
        notified2min = false

        countdownAnimator = ValueAnimator.ofInt(totalSeconds, 0).apply {
            duration = totalSeconds * 1000L
            // 使用线性插值器，确保倒计时均匀递减
            interpolator = android.view.animation.LinearInterpolator()

            addUpdateListener { animation ->
                val current = animation.animatedValue as Int
                textView.text = formatCountdownTime(current)

                // 在3分钟时通知 Flutter
                if (current <= 180 && current > 120 && !notified3min) {
                    notified3min = true
                    notifyCountdownAlert("3min")
                }
                // 在2分钟时通知 Flutter
                if (current <= 120 && current > 60 && !notified2min) {
                    notified2min = true
                    notifyCountdownAlert("2min")
                }
            }

            addListener(object : AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: Animator) {
                    textView.text = formatCountdownTime(0)
                    // 倒计时结束，通知 Flutter
                    notifyCountdownEnded()
                    // 隐藏倒计时窗口
                    hideCountdownWidget()
                }
            })
        }
        countdownAnimator?.start()
    }

    /**
     * 格式化倒计时时间
     */
    private fun formatCountdownTime(seconds: Int): String {
        val min = seconds / 60
        val sec = seconds % 60
        return String.format("%02d:%02d", min, sec)
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
                    countdownWidgetLayoutParams?.let { params ->
                        initialX = params.x
                        initialY = params.y
                    }
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    countdownWidgetLayoutParams?.let { params ->
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
     * 通知 Flutter 倒计时结束
     */
    private fun notifyCountdownEnded() {
        channel.invokeMethod("onCountdownEnded", null)
    }

    /**
     * 通知 Flutter 倒计时达到特定时刻（3分钟、2分钟）
     */
    private fun notifyCountdownAlert(alertType: String) {
        channel.invokeMethod("onCountdownAlert", mapOf("alertType" to alertType))
    }

    /**
     * 隐藏倒计时悬浮窗
     */
    private fun hideCountdownWidget() {
        // 取消动画
        countdownAnimator?.cancel()
        countdownAnimator = null

        countdownWidgetView?.let { view ->
            view.animate()
                .alpha(0f)
                .setDuration(200)
                .setListener(object : AnimatorListenerAdapter() {
                    override fun onAnimationEnd(animation: Animator) {
                        try {
                            windowManager?.removeView(view)
                        } catch (e: Exception) {
                            // 忽略移除失败
                        }
                        countdownWidgetView = null
                        isCountdownWidgetShowing = false
                    }
                })
                .start()
        }
    }
}
