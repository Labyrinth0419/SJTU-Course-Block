package com.labyrinth.course_block.widget

import android.appwidget.AppWidgetManager
import android.content.Intent
import android.util.Log
import android.widget.RemoteViewsService

/** 为【一周课程】小组件的 ListView 提供数据，读取 week_list。 */
class WeekWidgetService : RemoteViewsService() {
    override fun onCreate() {
        super.onCreate()
        Log.d("WeekWidgetService", "onCreate")
    }

    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        Log.d(
            "WeekWidgetService",
            "onGetViewFactory widgetId=${intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, -1)} data=${intent.data}",
        )
        return WeekGridWidgetFactory(applicationContext)
    }
}
