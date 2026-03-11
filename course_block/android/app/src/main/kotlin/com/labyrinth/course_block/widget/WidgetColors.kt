package com.labyrinth.course_block.widget

import android.graphics.Color
import kotlin.math.abs

/** 小组件课程颜色调板，按课程名 hash 稳定分配颜色。 */
object WidgetColors {

    private val PALETTE = intArrayOf(
        Color.parseColor("#E53935"), // 红
        Color.parseColor("#8E24AA"), // 紫
        Color.parseColor("#1E88E5"), // 蓝
        Color.parseColor("#00897B"), // 青绿
        Color.parseColor("#F4511E"), // 深橙
        Color.parseColor("#3949AB"), // 靛蓝
        Color.parseColor("#00ACC1"), // 青
        Color.parseColor("#E91E63"), // 粉
        Color.parseColor("#43A047"), // 绿
        Color.parseColor("#FB8C00"), // 琥珀
    )

    /** 根据课程名 hash 返回调板中的颜色，相同名称始终返回同一颜色。 */
    fun forCourse(name: String): Int = PALETTE[abs(name.hashCode()) % PALETTE.size]

    /** 返回指定 alpha (0-255) 的半透明版本。 */
    fun withAlpha(color: Int, alpha: Int): Int =
        Color.argb(alpha, Color.red(color), Color.green(color), Color.blue(color))
}
