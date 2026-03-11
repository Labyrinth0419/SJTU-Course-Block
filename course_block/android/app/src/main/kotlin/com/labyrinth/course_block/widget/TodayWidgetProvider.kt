package com.labyrinth.course_block.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import com.labyrinth.course_block.MainActivity
import com.labyrinth.course_block.R
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray

class TodayWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_today)

            // Force baseline text so we can see rendering even if data is missing/blocked
            val header = widgetData.getString("today_header", "今日课程 (占位)") ?: "今日课程 (占位)"
            val subtitle = widgetData.getString("today_subtitle", "第1周 (占位)") ?: "第1周 (占位)"
            val listJson = widgetData.getString("today_list", "[{'name':'占位课程','room':'测试教室','startNode':1,'step':2}]".replace("'", "\""))
                ?: "[]"

            views.setTextViewText(R.id.tv_header, header)
            views.setTextViewText(R.id.tv_subtitle, subtitle)

            applyList(listJson, views)

            val pendingIntent: PendingIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java
            )
            views.setOnClickPendingIntent(R.id.btn_open, pendingIntent)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun applyList(listJson: String, views: RemoteViews) {
        val arr = try {
            JSONArray(listJson)
        } catch (_: Exception) {
            JSONArray()
        }

        val rows = listOf(R.id.row1, R.id.row2, R.id.row3)
        for (i in rows.indices) {
            if (i < arr.length()) {
                val obj = arr.getJSONObject(i)
                val name = obj.optString("name", "")
                val room = obj.optString("room", "")
                val start = obj.optInt("startNode", 0)
                val step = obj.optInt("step", 1)
                val text = if (name.isNotEmpty()) {
                    val timeRange = formatNodeRange(start, step)
                    "$timeRange $name @${room.ifEmpty { "--" }}"
                } else {
                    "--"
                }
                views.setTextViewText(rows[i], text)
                views.setViewVisibility(rows[i], android.view.View.VISIBLE)
            } else {
                views.setViewVisibility(rows[i], android.view.View.GONE)
            }
        }

        if (arr.length() == 0) {
            views.setViewVisibility(R.id.tv_empty, android.view.View.VISIBLE)
            views.setViewVisibility(R.id.list_container, android.view.View.GONE)
        } else {
            views.setViewVisibility(R.id.tv_empty, android.view.View.GONE)
            views.setViewVisibility(R.id.list_container, android.view.View.VISIBLE)
        }
    }

    private fun formatNodeRange(start: Int, step: Int): String {
        if (start <= 0) return "--节";
        val end = (start + step - 1).coerceAtLeast(start)
        return if (start == end) "第${start}节" else "${start}-${end}节"
    }
}