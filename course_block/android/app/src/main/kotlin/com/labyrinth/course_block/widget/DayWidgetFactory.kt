package com.labyrinth.course_block.widget

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.util.Log
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import com.labyrinth.course_block.R
import org.json.JSONArray

/**
 * 【日视图】Factory：展示今天所有课程并根据状态着色。
 * 读取 SharedPreferences 中的 day_list，每项携带 status 字段：
 *   "done"     → 灰色（已结束）
 *   "current"  → 红色（正在上课）
 *   "upcoming" → 默认色（待上）
 */
class DayWidgetFactory(
    private val context: Context,
    intent: Intent
) : RemoteViewsService.RemoteViewsFactory {

    private data class CourseItem(
        val timeRange: String,
        val name: String,
        val room: String,
        val status: String,
        val color: String,
    )

    private var items: List<CourseItem> = emptyList()
    private lateinit var theme: WidgetColors.WidgetTheme

    override fun onCreate()         { loadData() }
    override fun onDataSetChanged() { loadData() }
    override fun onDestroy()        { items = emptyList() }

    private fun loadData() {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val json  = prefs.getString("day_list", "[]") ?: "[]"
        theme = WidgetColors.resolve(context, prefs)
        items = try {
            val arr = JSONArray(json)
            (0 until arr.length()).map { i ->
                val obj = arr.getJSONObject(i)
                CourseItem(
                    obj.optString("timeRange", ""),
                    obj.optString("name",      "--"),
                    obj.optString("room",      ""),
                    obj.optString("status",    "upcoming"),
                    obj.optString("color",     ""),
                )
            }
        } catch (e: Exception) {
            Log.w("DayWidgetFactory", "Failed to parse day_list", e)
            emptyList()
        }
    }

    override fun getCount()                     = items.size
    override fun getItemId(position: Int)       = position.toLong()
    override fun hasStableIds()                 = true
    override fun getViewTypeCount()             = 1
    override fun getLoadingView(): RemoteViews? = null

    override fun getViewAt(position: Int): RemoteViews {
        val item  = items.getOrNull(position) ?: CourseItem("", "--", "", "upcoming", "")
        val rv    = RemoteViews(context.packageName, R.layout.widget_day_card)
        val color = WidgetColors.forCourse(item.name, theme, item.color)
        val info  = listOf(item.room, item.timeRange).filter { it.isNotEmpty() }.joinToString("  ")

        rv.setTextViewText(R.id.day_card_name, item.name)
        rv.setTextViewText(R.id.day_card_info, info)

        when (item.status) {
            "done" -> {
                val doneText = WidgetColors.doneText(theme)
                rv.setInt(
                    R.id.day_card_root,
                    "setBackgroundColor",
                    WidgetColors.doneBackground(theme)
                )
                rv.setTextColor(R.id.day_card_name, doneText)
                rv.setTextColor(R.id.day_card_info, doneText)
            }
            "current" -> {
                rv.setInt(R.id.day_card_root, "setBackgroundColor", color)
                rv.setTextColor(R.id.day_card_name, Color.WHITE)
                rv.setTextColor(R.id.day_card_info, Color.argb(200, 255, 255, 255))
            }
            else -> { // upcoming
                rv.setInt(
                    R.id.day_card_root,
                    "setBackgroundColor",
                    WidgetColors.upcomingFill(theme, color)
                )
                rv.setTextColor(R.id.day_card_name, color)
                rv.setTextColor(
                    R.id.day_card_info,
                    WidgetColors.withAlpha(color, if (theme.isDark) 220 else 180)
                )
            }
        }

        return rv
    }
}
