package com.labyrinth.course_block.widget

import android.content.Intent
import android.widget.RemoteViewsService

/** 为【一周课程】小组件的 ListView 提供数据，读取 week_list。 */
class WeekWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        ScrollGroupWidgetFactory(applicationContext, "week_list")
}
