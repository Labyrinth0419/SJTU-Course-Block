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
        private const val ADAPTER_VERSION = 2
        const val ACTION_REFRESH = "com.labyrinth.course_block.widget.WEEK_REFRESH"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_REFRESH) {
            Log.d(TAG, "ACTION_REFRESH received")
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, WeekWidgetProvider::class.java),
            )
            onUpdate(context, manager, ids, forceAdapterRefresh = true)
        } else {
            super.onReceive(context, intent)
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        onUpdate(context, appWidgetManager, appWidgetIds, forceAdapterRefresh = false)
    }

    private fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        forceAdapterRefresh: Boolean,
    ) {
        Log.d(TAG, "onUpdate ids=${appWidgetIds.joinToString()}")
        WidgetDataRefresher.refresh(context)
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val theme = WidgetColors.resolve(context, prefs)

        for (widgetId in appWidgetIds) {
            try {
                val weekPayload = prefs.getString("week_list", "[]").orEmpty()
                val payloadVersion = weekPayload.hashCode()
                val versionKey = "week_widget_payload_$widgetId"
                val adapterVersionKey = "week_widget_adapter_version_$widgetId"
                Log.d(TAG, "widget=$widgetId payloadHash=$payloadVersion payloadLength=${weekPayload.length}")
                val previousPayloadVersion = prefs.getInt(versionKey, Int.MIN_VALUE)
                val previousAdapterVersion = prefs.getInt(adapterVersionKey, Int.MIN_VALUE)
                val adapterChanged = forceAdapterRefresh ||
                    previousPayloadVersion != payloadVersion ||
                    previousAdapterVersion != ADAPTER_VERSION
                if (adapterChanged) {
                    Log.d(TAG, "widget=$widgetId adapter refresh required")
                } else {
                    Log.d(TAG, "widget=$widgetId payload unchanged; refresh metadata only")
                }
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
                // Keep the adapter stable when only metadata (for example the schedule
                // title) changed. Rebinding it can leave duplicate launcher-side adapters.
                if (adapterChanged) {
                    val serviceIntent = Intent(context, WeekWidgetService::class.java).apply {
                        putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                        data = Uri.parse("course-block://week/$widgetId")
                    }
                    Log.d(TAG, "widget=$widgetId binding stable WeekWidgetService adapter")
                    views.setRemoteAdapter(R.id.week_list_view, serviceIntent)
                }
                views.setPendingIntentTemplate(
                    R.id.week_list_view,
                    openPendingIntent(context, widgetId),
                )
                views.setOnClickPendingIntent(
                    R.id.tv_header,
                    refreshPendingIntent(context, widgetId),
                )
                appWidgetManager.updateAppWidget(widgetId, views)
                if (adapterChanged) {
                    appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.week_list_view)
                }
                prefs.edit()
                    .putInt(versionKey, payloadVersion)
                    .putInt(adapterVersionKey, ADAPTER_VERSION)
                    .apply()
                Log.d(TAG, "Widget $widgetId updated (five-column, adapterChanged=$adapterChanged)")
            } catch (exception: Exception) {
                Log.e(TAG, "Failed to update widget $widgetId", exception)
            }
        }
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val editor = prefs.edit()
        appWidgetIds.forEach { widgetId ->
            editor.remove("week_widget_payload_$widgetId")
            editor.remove("week_widget_adapter_version_$widgetId")
        }
        editor.apply()
        super.onDeleted(context, appWidgetIds)
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
