package com.labyrinth.course_block.widget

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent

/** Refreshes every placed widget immediately after the system clock context changes. */
class WidgetTimeChangeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (
            intent.action != Intent.ACTION_DATE_CHANGED &&
            intent.action != Intent.ACTION_TIME_CHANGED &&
            intent.action != Intent.ACTION_TIMEZONE_CHANGED
        ) {
            return
        }

        refreshProvider(context, TodayWidgetProvider::class.java)
        refreshProvider(context, DayWidgetProvider::class.java)
        refreshProvider(context, UpcomingWidgetProvider::class.java)
        refreshProvider(context, WeekWidgetProvider::class.java)
    }

    private fun refreshProvider(
        context: Context,
        providerClass: Class<out AppWidgetProvider>,
    ) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, providerClass))
        if (ids.isEmpty()) return

        context.sendBroadcast(
            Intent(context, providerClass).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            }
        )
    }
}
