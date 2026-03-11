package com.labyrinth.course_block.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import com.labyrinth.course_block.MainActivity
import com.labyrinth.course_block.R

/**
 * 【日视图】桌面小组件 Provider：展示今天所有课程（含已结束/进行中/待上）。
 * 与今日课程小组件的区别：显示全天完整时间表，已结束的课程以灰色标注。
 */
class DayWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val TAG = "DayWidgetProvider"
        const val ACTION_REFRESH = "com.labyrinth.course_block.widget.DAY_REFRESH"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_REFRESH) {
            Log.d(TAG, "ACTION_REFRESH received")
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, DayWidgetProvider::class.java))
            onUpdate(context, manager, ids)
            for (id in ids) manager.notifyAppWidgetViewDataChanged(id, R.id.widget_list_view)
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
                val views    = RemoteViews(context.packageName, R.layout.widget_today)
                val header   = prefs.getString("today_header",   "今日日程") ?: "今日日程"
                val subtitle = prefs.getString("today_subtitle", "")         ?: ""
                views.setTextViewText(R.id.tv_header,   header)
                views.setTextViewText(R.id.tv_subtitle, subtitle)

                val serviceIntent = Intent(context, DayWidgetService::class.java).apply {
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                    data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
                }
                views.setRemoteAdapter(R.id.widget_list_view, serviceIntent)
                views.setEmptyView(R.id.widget_list_view, R.id.tv_empty)

                // 刷新按钮
                val refreshPi = PendingIntent.getBroadcast(
                    context, widgetId,
                    Intent(context, DayWidgetProvider::class.java).apply { action = ACTION_REFRESH },
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
                appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.widget_list_view)
                Log.d(TAG, "Widget $widgetId updated")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to update widget $widgetId", e)
                try {
                    val fb = RemoteViews(context.packageName, R.layout.widget_today)
                    fb.setTextViewText(R.id.tv_header, "今日日程")
                    fb.setViewVisibility(R.id.tv_empty,         View.VISIBLE)
                    fb.setViewVisibility(R.id.widget_list_view, View.GONE)
                    appWidgetManager.updateAppWidget(widgetId, fb)
                } catch (_: Exception) {}
            }
        }
    }
}
