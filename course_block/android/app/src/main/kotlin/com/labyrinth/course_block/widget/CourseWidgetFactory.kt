package com.labyrinth.course_block.widget

import android.content.Context
import android.content.Intent
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import com.labyrinth.course_block.R
import org.json.JSONArray

/** 为小组件 ListView 提供行数据的 Factory。
 *  onDataSetChanged 在 notifyAppWidgetViewDataChanged 被调用时触发，
 *  届时从 SharedPreferences 重新读取最新课程列表。 */
class CourseWidgetFactory(
    private val context: Context,
    intent: Intent
) : RemoteViewsService.RemoteViewsFactory {

    companion object {
        private const val TAG = "CourseWidgetFactory"
    }

    private data class CourseItem(val timeRange: String, val name: String, val room: String)

    private var items: List<CourseItem> = emptyList()

    // ──────────────────────────────────────────────────────────────────────────
    // Factory 生命周期
    // ──────────────────────────────────────────────────────────────────────────

    override fun onCreate() {
        loadData()
    }

    override fun onDataSetChanged() {
        // 由 notifyAppWidgetViewDataChanged 触发，重新加载最新数据
        loadData()
    }

    override fun onDestroy() {
        items = emptyList()
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 数据加载
    // ──────────────────────────────────────────────────────────────────────────

    private fun loadData() {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val listJson = prefs.getString("today_list", "[]") ?: "[]"
        Log.d(TAG, "loadData: $listJson")

        items = try {
            val arr = JSONArray(listJson)
            (0 until arr.length()).map { i ->
                val obj       = arr.getJSONObject(i)
                val name      = obj.optString("name",      "")
                val room      = obj.optString("room",      "")
                val timeRange = obj.optString("timeRange", "")
                CourseItem(timeRange, name.ifEmpty { "--" }, room)
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to parse today_list", e)
            emptyList()
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // RemoteViewsFactory 接口
    // ──────────────────────────────────────────────────────────────────────────

    override fun getCount(): Int = items.size

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = true

    override fun getViewTypeCount(): Int = 1

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewAt(position: Int): RemoteViews {
        val item  = items.getOrNull(position) ?: CourseItem("", "--", "")
        val rv    = RemoteViews(context.packageName, R.layout.widget_course_row)
        val color = WidgetColors.forCourse(item.name)

        rv.setTextViewText(R.id.row_title,  item.name)
        rv.setTextViewText(R.id.row_detail, if (item.room.isNotEmpty()) "📍 ${item.room}" else "")
        rv.setTextViewText(R.id.row_time,   item.timeRange)
        rv.setInt(R.id.row_bar,  "setBackgroundColor", color)
        rv.setTextColor(R.id.row_time, color)
        rv.setViewVisibility(R.id.row_detail, if (item.room.isEmpty())      View.GONE else View.VISIBLE)
        rv.setViewVisibility(R.id.row_time,   if (item.timeRange.isEmpty()) View.GONE else View.VISIBLE)
        return rv
    }
}
