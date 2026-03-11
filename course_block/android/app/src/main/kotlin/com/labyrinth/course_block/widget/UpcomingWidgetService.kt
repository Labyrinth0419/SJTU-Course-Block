package com.labyrinth.course_block.widget

import android.content.Intent
import android.widget.RemoteViewsService

/** 为【近日课程】小组件的 ListView 提供数据，读取 upcoming_list。 */
class UpcomingWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        ScrollGroupWidgetFactory(applicationContext, "upcoming_list")
}
