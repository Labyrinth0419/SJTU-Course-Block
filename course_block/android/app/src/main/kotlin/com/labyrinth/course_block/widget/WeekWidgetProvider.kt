package com.labyrinth.course_block.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import android.widget.RemoteViews
import com.labyrinth.course_block.MainActivity
import com.labyrinth.course_block.R

/** 【一周课程】桌面小组件：使用 RemoteViewsService 展示本周分组课程。 */
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
            ids.forEach { manager.notifyAppWidgetViewDataChanged(it, R.id.widget_list_view) }
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
                views.setTextColor(R.id.tv_empty, theme.emptyText)
                views.setTextColor(R.id.btn_refresh, theme.accent)
                views.setTextColor(R.id.btn_open, theme.openText)
                views.setInt(R.id.divider_top, "setBackgroundColor", theme.divider)
                views.setInt(R.id.divider_bottom, "setBackgroundColor", theme.divider)

                val serviceIntent = Intent(context, WeekWidgetService::class.java).apply {
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                    data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
                }
                views.setRemoteAdapter(R.id.widget_list_view, serviceIntent)
                views.setPendingIntentTemplate(
                    R.id.widget_list_view,
                    courseClickPendingIntent(context, widgetId),
                )
                views.setEmptyView(R.id.widget_list_view, R.id.tv_empty)
                views.setOnClickPendingIntent(
                    R.id.btn_refresh,
                    refreshPendingIntent(context, widgetId),
                )
                views.setOnClickPendingIntent(R.id.btn_open, openPendingIntent(context))

                appWidgetManager.updateAppWidget(widgetId, views)
                appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.widget_list_view)
            } catch (exception: Exception) {
                Log.e(TAG, "Failed to update widget $widgetId", exception)
            }
        }
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

    private fun courseClickPendingIntent(context: Context, widgetId: Int): PendingIntent {
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

    private fun openPendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
