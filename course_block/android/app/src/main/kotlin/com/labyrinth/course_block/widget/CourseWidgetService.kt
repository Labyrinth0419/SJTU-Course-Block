package com.labyrinth.course_block.widget

import android.content.Intent
import android.widget.RemoteViewsService

/** 为桌面小组件的 ListView 提供 RemoteViewsFactory 的 Service。
 *  需在 AndroidManifest.xml 中声明，并添加 BIND_REMOTEVIEWS 权限。 */
class CourseWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return CourseWidgetFactory(applicationContext, intent)
    }
}
