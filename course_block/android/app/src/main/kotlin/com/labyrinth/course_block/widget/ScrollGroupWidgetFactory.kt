package com.labyrinth.course_block.widget

import android.content.Context
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import com.labyrinth.course_block.R
import org.json.JSONArray

/**
 * 通用"分组列表" Factory，支持两种行类型：
 *   - Header 行（日期标题）→ widget_group_header_row.xml
 *   - Course 行（课程信息）→ widget_course_row.xml
 *
 * 通过 [prefsKey] 指定从 HomeWidgetPreferences 读取的 JSON 键。
 * JSON 格式：[{"t":"header","label":"3.11 Tue"}, {"t":"course","name":"...","room":"...","timeRange":"..."}, ...]
 */
class ScrollGroupWidgetFactory(
    private val context: Context,
    private val prefsKey: String
) : RemoteViewsService.RemoteViewsFactory {

    private sealed class Row {
        data class Header(val label: String) : Row()
        data class Course(
            val timeRange: String,
            val name: String,
            val room: String,
            val color: String,
        ) : Row()
    }

    private var rows: List<Row> = emptyList()
    private lateinit var theme: WidgetColors.WidgetTheme

    override fun onCreate() {
        loadData()
    }

    override fun onDataSetChanged() {
        loadData()
    }

    override fun onDestroy() {
        rows = emptyList()
    }

    private fun loadData() {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        theme = WidgetColors.resolve(context, prefs)
        val json = prefs.getString(prefsKey, "[]") ?: "[]"
        rows = try {
            val arr = JSONArray(json)
            (0 until arr.length()).map { i ->
                val obj = arr.getJSONObject(i)
                if (obj.optString("t") == "header") {
                    Row.Header(obj.optString("label", ""))
                } else {
                    Row.Course(
                        obj.optString("timeRange", ""),
                        obj.optString("name", "--"),
                        obj.optString("room", ""),
                        obj.optString("color", ""),
                    )
                }
            }
        } catch (e: Exception) {
            Log.w("ScrollGroupFactory", "Failed to parse $prefsKey", e)
            emptyList()
        }
    }

    override fun getCount() = rows.size
    override fun getItemId(position: Int) = position.toLong()
    override fun hasStableIds() = true
    override fun getViewTypeCount() = 2
    override fun getLoadingView(): RemoteViews? = null

    override fun getViewAt(position: Int): RemoteViews {
        return when (val row = rows.getOrNull(position)) {
            is Row.Header -> {
                val rv = RemoteViews(context.packageName, R.layout.widget_group_header_row)
                rv.setTextViewText(R.id.row_header_label, row.label)
                rv.setTextColor(R.id.row_header_label, theme.accent)
                rv.setInt(R.id.row_header_divider, "setBackgroundColor", theme.divider)
                rv
            }

            is Row.Course -> {
                val rv = RemoteViews(context.packageName, R.layout.widget_course_row)
                val color = WidgetColors.forCourse(row.name, theme, row.color)
                rv.setTextViewText(R.id.row_title, row.name)
                rv.setTextViewText(R.id.row_detail, if (row.room.isNotEmpty()) "📍 ${row.room}" else "")
                rv.setTextViewText(R.id.row_time, row.timeRange)
                rv.setTextColor(R.id.row_title, theme.courseTitle)
                rv.setTextColor(R.id.row_detail, theme.courseDetail)
                rv.setInt(R.id.row_bar, "setBackgroundColor", color)
                rv.setTextColor(R.id.row_time, color)
                rv.setViewVisibility(R.id.row_detail, if (row.room.isEmpty()) View.GONE else View.VISIBLE)
                rv.setViewVisibility(R.id.row_time, if (row.timeRange.isEmpty()) View.GONE else View.VISIBLE)
                rv
            }

            null -> RemoteViews(context.packageName, R.layout.widget_course_row)
        }
    }
}
