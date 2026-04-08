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

    /**
     * 清理资源
     */
    fun destroy() {
        handler.removeCallbacksAndMessages(null)
        hideOverlayImmediate()
        windowManager = null
    }
}
