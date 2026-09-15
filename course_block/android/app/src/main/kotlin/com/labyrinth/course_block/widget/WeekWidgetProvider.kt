package com.labyrinth.course_block.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.util.Log
import android.widget.RemoteViews
import com.labyrinth.course_block.MainActivity
import com.labyrinth.course_block.R
import org.json.JSONArray

/** 【一周课程】桌面小组件：按周一至周五分栏展示本周课程。 */
class WeekWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val TAG = "WeekWidgetProvider"
        const val ACTION_REFRESH = "com.labyrinth.course_block.widget.WEEK_REFRESH"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_REFRESH) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, WeekWidgetProvider::class.java),
            )
            onUpdate(context, manager, ids)
        } else {
            super.onReceive(context, intent)
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        WidgetDataRefresher.refresh(context)
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val theme = WidgetColors.resolve(context, prefs)

        for (widgetId in appWidgetIds) {
            try {
                val views = RemoteViews(context.packageName, R.layout.widget_week)
                views.setInt(R.id.widget_root, "setBackgroundResource", theme.backgroundRes)
                views.setTextViewText(
                    R.id.tv_header,
                    prefs.getString("today_header", "一周课程") ?: "一周课程",
                )
                views.setTextViewText(
                    R.id.tv_subtitle,
                    prefs.getString("today_subtitle", "") ?: "",
                )
                views.setTextColor(R.id.tv_header, theme.headerText)
                views.setTextColor(R.id.tv_subtitle, theme.subtitleText)
                views.setInt(R.id.divider_top, "setBackgroundColor", theme.divider)
                views.setInt(R.id.divider_v1, "setBackgroundColor", theme.divider)
                views.setInt(R.id.divider_v2, "setBackgroundColor", theme.divider)
                views.setInt(R.id.divider_v3, "setBackgroundColor", theme.divider)
                views.setInt(R.id.divider_v4, "setBackgroundColor", theme.divider)

                val columns = listOf(
                    R.id.col_week_1,
                    R.id.col_week_2,
                    R.id.col_week_3,
                    R.id.col_week_4,
                    R.id.col_week_5,
                )
                columns.forEach { views.removeAllViews(it) }
                addWeekColumns(context, views, prefs, theme, columns, widgetId)

                views.setOnClickPendingIntent(
                    R.id.widget_root,
                    openPendingIntent(context, widgetId),
                )
                views.setOnClickPendingIntent(
                    R.id.tv_header,
                    refreshPendingIntent(context, widgetId),
                )

                appWidgetManager.updateAppWidget(widgetId, views)
                Log.d(TAG, "Widget $widgetId updated (five-column)")
            } catch (exception: Exception) {
                Log.e(TAG, "Failed to update widget $widgetId", exception)
            }
        }
    }

    private fun addWeekColumns(
        context: Context,
        views: RemoteViews,
        prefs: android.content.SharedPreferences,
        theme: WidgetColors.WidgetTheme,
        columns: List<Int>,
        widgetId: Int,
    ) {
        val groups = parseGroups(prefs.getString("week_list", "[]") ?: "[]")
        val openIntent = openPendingIntent(context, widgetId)

        for (group in groups) {
            val columnIndex = when {
                group.label.startsWith("周一") -> 0
                group.label.startsWith("周二") -> 1
                group.label.startsWith("周三") -> 2
                group.label.startsWith("周四") -> 3
                group.label.startsWith("周五") -> 4
                else -> -1
            }
            if (columnIndex < 0) continue

            val header = RemoteViews(context.packageName, R.layout.widget_group_header_row)
            header.setTextViewText(R.id.row_header_label, group.label)
            header.setTextColor(R.id.row_header_label, theme.accent)
            header.setInt(R.id.row_header_divider, "setBackgroundColor", theme.divider)
            views.addView(columns[columnIndex], header)

            for (course in group.courses) {
                val card = RemoteViews(context.packageName, R.layout.widget_mini_card)
                val color = WidgetColors.forCourse(course.name, theme, course.color)
                card.setTextViewText(R.id.mini_name, course.name)
                card.setTextViewText(
                    R.id.mini_info,
                    listOf(course.timeRange, course.room)
                        .filter { it.isNotEmpty() }
                        .joinToString(" · "),
                )
                card.setTextColor(R.id.mini_name, theme.courseTitle)
                card.setTextColor(R.id.mini_info, color)
                card.setInt(R.id.mini_bar, "setBackgroundColor", color)
                card.setOnClickPendingIntent(R.id.mini_root, openIntent)
                views.addView(columns[columnIndex], card)
            }
        }
    }

    private fun parseGroups(json: String): List<Group> = try {
        val array = JSONArray(json)
        val groups = mutableListOf<Group>()
        for (index in 0 until array.length()) {
            val objectValue = array.getJSONObject(index)
            when (objectValue.optString("t")) {
                "header" -> groups.add(Group(objectValue.optString("label", "")))
                "course" -> groups.lastOrNull()?.courses?.add(
                    CourseRow(
                        name = objectValue.optString("name", "--"),
                        room = objectValue.optString("room", ""),
                        timeRange = objectValue.optString("timeRange", ""),
                        color = objectValue.optString("color", ""),
                    ),
                )
            }
        }
        groups
    } catch (exception: Exception) {
        Log.w(TAG, "Failed to parse week_list", exception)
        emptyList()
    }

    private fun openPendingIntent(context: Context, widgetId: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            context,
            widgetId + 10_000,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun refreshPendingIntent(context: Context, widgetId: Int): PendingIntent {
        val intent = Intent(context, WeekWidgetProvider::class.java).apply {
            action = ACTION_REFRESH
        }
        return PendingIntent.getBroadcast(
            context,
            widgetId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private data class Group(
        val label: String,
        val courses: MutableList<CourseRow> = mutableListOf(),
    )

    private data class CourseRow(
        val name: String,
        val room: String,
        val timeRange: String,
        val color: String,
    )
}
