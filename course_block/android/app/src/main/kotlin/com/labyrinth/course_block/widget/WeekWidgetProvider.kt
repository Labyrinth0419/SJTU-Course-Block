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
                val serviceIntent = Intent(context, WeekWidgetService::class.java).apply {
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                    data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
                }
                views.setRemoteAdapter(R.id.week_grid, serviceIntent)
                views.setPendingIntentTemplate(
                    R.id.week_grid,
                    openPendingIntent(context, widgetId),
                )
                views.setOnClickPendingIntent(
                    R.id.tv_header,
                    refreshPendingIntent(context, widgetId),
                )
                appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.week_grid)

                appWidgetManager.updateAppWidget(widgetId, views)
                Log.d(TAG, "Widget $widgetId updated (five-column)")
            } catch (exception: Exception) {
                Log.e(TAG, "Failed to update widget $widgetId", exception)
            }
        }
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

}
