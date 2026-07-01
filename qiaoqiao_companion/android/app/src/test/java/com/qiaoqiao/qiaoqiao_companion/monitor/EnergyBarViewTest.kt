package com.qiaoqiao.qiaoqiao_companion.monitor

import android.graphics.Color
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class EnergyBarViewTest {

    @Test
    fun `energyBarColor at progress 0 returns green`() {
        val color = EnergyBarView.energyBarColor(0.0f)
        assertEquals(0xFF4CAF50.toInt(), color)
    }

    @Test
    fun `energyBarColor at progress 0_5 returns yellow`() {
        val color = EnergyBarView.energyBarColor(0.5f)
        assertEquals(0xFFFFC107.toInt(), color)
    }

    @Test
    fun `energyBarColor at progress 0_25 is between green and yellow`() {
        val color = EnergyBarView.energyBarColor(0.25f)
        val green = 0xFF4CAF50.toInt()
        val yellow = 0xFFFFC107.toInt()
        // 不是端点本身
        assertTrue(color != green && color != yellow)
        // R 介于绿和黄之间（绿 R=76, 黄 R=255）
        val r = Color.red(color)
        assertTrue(r > 76 && r < 255)
    }

    @Test
    fun `energyBarColor at progress 1 returns yellow clamped`() {
        val color = EnergyBarView.energyBarColor(1.0f)
        assertEquals(0xFFFFC107.toInt(), color)
    }

    @Test
    fun `energyBarColor clamps progress above 1`() {
        val color = EnergyBarView.energyBarColor(1.5f)
        assertEquals(0xFFFFC107.toInt(), color)
    }
}
