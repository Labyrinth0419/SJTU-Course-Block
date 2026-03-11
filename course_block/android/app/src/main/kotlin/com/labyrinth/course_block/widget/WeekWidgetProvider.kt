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

/** 【一周课程】桌面小组件 Provider：五栏网格展示本周工作日（Mon-Fri）课程。 */
class WeekWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val TAG = "WeekWidgetProvider"
        const val ACTION_REFRESH = "com.labyrinth.course_block.widget.WEEK_REFRESH"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_REFRESH) {
            Log.d(TAG, "ACTION_REFRESH received")
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, WeekWidgetProvider::class.java))
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
        for (widgetId in appWidgetIds) {
            try {
                val views   = RemoteViews(context.packageName, R.layout.widget_week)
                val header   = prefs.getString("today_header",   "一周课程") ?: "一周课程"
                val subtitle = prefs.getString("today_subtitle", "") ?: ""
                views.setTextViewText(R.id.tv_header,   header)
                views.setTextViewText(R.id.tv_subtitle, subtitle)

                // ── 解析 week_list ──────────────────────────────────────────────────────────
                val json = prefs.getString("week_list", "[]") ?: "[]"
                val arr  = JSONArray(json)

                data class CourseRow(val name: String, val room: String, val timeRange: String)
                data class Group(val label: String, val courses: MutableList<CourseRow> = mutableListOf())

                val groups = mutableListOf<Group>()
                for (i in 0 until arr.length()) {
                    val obj = arr.getJSONObject(i)
                    when (obj.optString("t")) {
                        "header" -> groups.add(Group(obj.optString("label", "")))
                        "course" -> groups.lastOrNull()?.courses?.add(
                            CourseRow(
                                obj.optString("name",      "--"),
                                obj.optString("room",      ""),
                                obj.optString("timeRange", "")
                            )
                        )
                    }
                }

                // label 前3字符确定所属栏：Mon→1, Tue→2, Wed→3, Thu→4, Fri→5，周末跳过
                fun columnId(label: String): Int = when {
                    label.startsWith("Mon") -> R.id.col_week_1
                    label.startsWith("Tue") -> R.id.col_week_2
                    label.startsWith("Wed") -> R.id.col_week_3
                    label.startsWith("Thu") -> R.id.col_week_4
                    label.startsWith("Fri") -> R.id.col_week_5
                    else -> -1 // Sat / Sun 跳过
                }

                for (group in groups) {
                    val colId = columnId(group.label)
                    if (colId == -1) continue

                    // 日期标题行
                    val headerRv = RemoteViews(context.packageName, R.layout.widget_group_header_row)
                    headerRv.setTextViewText(R.id.row_header_label, group.label)
                    views.addView(colId, headerRv)

                    // 课程卡片
                    for (c in group.courses) {
                        val rv    = RemoteViews(context.packageName, R.layout.widget_mini_card)
                        val color = WidgetColors.forCourse(c.name)
                        rv.setTextViewText(R.id.mini_name, c.name)
                        rv.setTextViewText(R.id.mini_info, c.timeRange)
                        rv.setInt(R.id.mini_bar, "setBackgroundColor", color)
                        rv.setTextColor(R.id.mini_info, color)
                        views.addView(colId, rv)
                    }
                }

                // 刷新按钮
                val refreshPi = PendingIntent.getBroadcast(
                    context, widgetId,
                    Intent(context, WeekWidgetProvider::class.java).apply { action = ACTION_REFRESH },
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
                Log.d(TAG, "Widget $widgetId updated (five-column)")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to update widget $widgetId", e)
            }
        }
    }
}
