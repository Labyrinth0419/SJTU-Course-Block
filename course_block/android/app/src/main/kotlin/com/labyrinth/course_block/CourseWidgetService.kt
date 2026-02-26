package com.labyrinth.course_block

import android.content.Context
import android.content.Intent
import android.preference.PreferenceManager
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray

class CourseWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return Factory(applicationContext)
    }

    private class Factory(private val context: Context) : RemoteViewsFactory {
        private val items = mutableListOf<CourseItem>()

        init {
            loadItems()
        }

        private fun loadItems() {
            items.clear()
            val prefs = PreferenceManager.getDefaultSharedPreferences(context)
            val json = prefs.getString("today_courses", "[]") ?: "[]"
            try {
                val arr = JSONArray(json)
                for (i in 0 until arr.length()) {
                    val obj = arr.getJSONObject(i)
                    items.add(
                        CourseItem(
                            obj.optString("courseName"),
                            obj.optString("classRoom"),
                            obj.optInt("startNode"),
                            obj.optInt("step")
                        )
                    )
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        override fun onCreate() {}
        override fun onDataSetChanged() {
            loadItems()
        }
        override fun onDestroy() {
            items.clear()
        }
        override fun getCount(): Int = items.size
        override fun getViewAt(position: Int): RemoteViews {
            val item = items[position]
            val rv = RemoteViews(context.packageName, R.layout.widget_course_item)
            rv.setTextViewText(R.id.course_name, item.name)
            val info = "${item.classRoom} · ${item.startNode}-${item.startNode + item.step - 1}节"
            rv.setTextViewText(R.id.course_info, info)
            return rv
        }
        override fun getLoadingView(): RemoteViews? = null
        override fun getViewTypeCount(): Int = 1
        override fun getItemId(position: Int): Long = position.toLong()
        override fun hasStableIds(): Boolean = true
    }

    data class CourseItem(
        val name: String,
        val classRoom: String,
        val startNode: Int,
        val step: Int
    )
}