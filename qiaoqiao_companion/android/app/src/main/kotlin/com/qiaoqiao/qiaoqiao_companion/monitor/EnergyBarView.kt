package com.qiaoqiao.qiaoqiao_companion.monitor

import android.animation.ArgbEvaluator
import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.util.AttributeSet
import android.view.View

/**
 * 圆形外环能量条 — 连续使用 widget 的视觉形态。
 *
 * - 外环：显示剩余比例（电池样式），弧度 = 360 * (1 - progress)，从满环递减到空环。颜色用 [energyBarColor] 平滑过渡（绿→黄）。
 * - ≤5 分钟阶段：由 WidgetManager 通过 [overrideColor] 传入色阶（黄/橙/红），优先于 energyBarColor。
 * - 中央内容由外部父布局添加（百分比数字 + 可选 MM:SS 文字）。
 */
class EnergyBarView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : View(context, attrs, defStyleAttr) {

    private val ringPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 8f * resources.displayMetrics.density
        strokeCap = Paint.Cap.ROUND
    }
    private val bgRingPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 8f * resources.displayMetrics.density
        color = 0x33000000
    }
    private val rectF = RectF()
    private val density = resources.displayMetrics.density

    /** 已用比例 0~1（clamp），决定外环填充弧度与颜色 */
    var progress: Float = 0f
        set(value) {
            field = value.coerceIn(0f, 1f)
            invalidate()
        }

    /** ≤5 分钟阶段的覆盖色（由 WidgetManager 注入）；null 时用 energyBarColor */
    var overrideColor: Int? = null
        set(value) {
            field = value
            invalidate()
        }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        try {
            val padding = ringPaint.strokeWidth / 2
            rectF.set(padding, padding, width - padding, height - padding)
            // 背景环
            canvas.drawArc(rectF, 0f, 360f, false, bgRingPaint)
            // 前景环（剩余比例，电池样式：满环→空环递减）
            val sweep = 360f * (1f - progress)
            ringPaint.color = overrideColor ?: energyBarColor(progress)
            canvas.drawArc(rectF, -90f, sweep, false, ringPaint)
        } catch (e: Exception) {
            // 绘制失败时画一个空背景环，保证不崩
            canvas.drawArc(rectF, 0f, 360f, false, bgRingPaint)
        }
    }

    companion object {
        private const val GREEN = 0xFF4CAF50.toInt()
        private const val YELLOW = 0xFFFFC107.toInt()
        private val evaluator = ArgbEvaluator()

        /**
         * >5 分钟阶段的能量条颜色：progress 0~0.5 从绿平滑过渡到黄，0.5~1 保持黄。
         * 纯函数，便于单元测试。
         */
        fun energyBarColor(progress: Float): Int {
            val p = progress.coerceIn(0f, 1f)
            return if (p <= 0.5f) {
                evaluator.evaluate(p / 0.5f, GREEN, YELLOW) as Int
            } else {
                YELLOW
            }
        }
    }
}
