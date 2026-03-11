package com.labyrinth.course_block.widget

import android.content.Intent
import android.widget.RemoteViewsService

/** 为【日视图】小组件的 ListView 提供数据，读取 day_list。 */
class DayWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        DayWidgetFactory(applicationContext, intent)
}
