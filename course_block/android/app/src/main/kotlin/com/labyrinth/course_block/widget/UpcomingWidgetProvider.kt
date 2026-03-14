package com.labyrinth.course_block.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.util.Log
import android.widget.RemoteViews
import com.labyrinth.course_block.MainActivity
import com.labyrinth.course_block.R
import org.json.JSONArray

/** 【近日课程】桌面小组件 Provider：双栏布局展示今天剩余 + 明天课程。 */
class UpcomingWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val TAG = "UpcomingWidgetProvider"
        const val ACTION_REFRESH = "com.labyrinth.course_block.widget.UPCOMING_REFRESH"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_REFRESH) {
            Log.d(TAG, "ACTION_REFRESH received")
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, UpcomingWidgetProvider::class.java))
            onUpdate(context, manager, ids)
        } else {
            super.onReceive(context, intent)
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val theme = WidgetColors.resolve(context, prefs)
        for (widgetId in appWidgetIds) {
            try {
                val views = RemoteViews(context.packageName, R.layout.widget_upcoming)
                val header = prefs.getString("today_header", "近日课程") ?: "近日课程"
                val subtitle = prefs.getString("today_subtitle", "") ?: ""
                views.setInt(R.id.widget_root, "setBackgroundResource", theme.backgroundRes)
                views.setTextViewText(R.id.tv_header, header)
                views.setTextViewText(R.id.tv_subtitle, subtitle)
                views.setTextColor(R.id.tv_header, theme.headerText)
                views.setTextColor(R.id.tv_subtitle, theme.subtitleText)
                views.setTextColor(R.id.lbl_today, theme.headerText)
                views.setTextColor(R.id.lbl_tmr, theme.subtitleText)
                views.setTextColor(R.id.btn_refresh, theme.accent)
                views.setTextColor(R.id.btn_open, theme.openText)
                views.setInt(R.id.divider_top, "setBackgroundColor", theme.divider)
                views.setInt(R.id.divider_center, "setBackgroundColor", theme.divider)
                views.setInt(R.id.divider_bottom, "setBackgroundColor", theme.divider)

                // RemoteViews.addView() appends into the existing container.
                // Clear dynamic content before rebuilding cards.
                views.removeAllViews(R.id.col_today_content)
                views.removeAllViews(R.id.col_tmr_content)

                // ── 解析 upcoming_list ──────────────────────────────────────────────
                val json = prefs.getString("upcoming_list", "[]") ?: "[]"
                val arr = JSONArray(json)

                data class CourseRow(
                    val name: String,
                    val room: String,
                    val timeRange: String,
                    val color: String,
                )

                data class Group(val label: String, val courses: MutableList<CourseRow> = mutableListOf())

                val groups = mutableListOf<Group>()
                for (i in 0 until arr.length()) {
                    val obj = arr.getJSONObject(i)
                    when (obj.optString("t")) {
                        "header" -> groups.add(Group(obj.optString("label", "")))
                        "course" -> groups.lastOrNull()?.courses?.add(
                            CourseRow(
                                obj.optString("name", "--"),
                                obj.optString("room", ""),
                                obj.optString("timeRange", ""),
                                obj.optString("color", ""),
                            )
                        )
                    }
                }

                // label 以 "Today" 开头 → 今天栏；以 "Tmr" 开头 → 明天栏
                val todayGroup = groups.find { it.label.startsWith("Today") }
                val tmrGroup = groups.find { it.label.startsWith("Tmr") }

                fun addCards(colId: Int, courses: List<CourseRow>) {
                    if (courses.isEmpty()) {
                        val rv = RemoteViews(context.packageName, R.layout.widget_mini_card)
                        rv.setTextViewText(R.id.mini_name, "暂无课程")
                        rv.setTextViewText(R.id.mini_info, "")
                        rv.setTextColor(R.id.mini_name, theme.emptyText)
                        rv.setTextColor(R.id.mini_info, theme.courseDetail)
                        rv.setInt(R.id.mini_bar, "setBackgroundColor", WidgetColors.withAlpha(theme.emptyText, 180))
                        views.addView(colId, rv)
                        return
                    }
                    for (c in courses) {
                        val rv = RemoteViews(context.packageName, R.layout.widget_mini_card)
                        val color = WidgetColors.forCourse(c.name, theme, c.color)
                        val info = listOf(c.room, c.timeRange)
                            .filter { it.isNotEmpty() }.joinToString(" ")
                        rv.setTextViewText(R.id.mini_name, c.name)
                        rv.setTextViewText(R.id.mini_info, info)
                        rv.setTextColor(R.id.mini_name, theme.courseTitle)
                        rv.setInt(R.id.mini_bar, "setBackgroundColor", color)
                        rv.setTextColor(R.id.mini_info, color)
                        views.addView(colId, rv)
                    }
                }

                addCards(R.id.col_today_content, todayGroup?.courses ?: emptyList())
                addCards(R.id.col_tmr_content, tmrGroup?.courses ?: emptyList())

                // 刷新按钮
                val refreshPi = PendingIntent.getBroadcast(
                    context, widgetId,
                    Intent(context, UpcomingWidgetProvider::class.java).apply { action = ACTION_REFRESH },
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.btn_refresh, refreshPi)

                // 打开 App
                val openPi = PendingIntent.getActivity(
                    context, 0,
                    Intent(context, MainActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    },
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.btn_open, openPi)

                appWidgetManager.updateAppWidget(widgetId, views)
                Log.d(TAG, "Widget $widgetId updated (two-column)")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to update widget $widgetId", e)
            }
        }
    }
}
