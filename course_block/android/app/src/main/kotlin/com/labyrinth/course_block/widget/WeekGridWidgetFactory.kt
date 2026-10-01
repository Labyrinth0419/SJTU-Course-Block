package com.labyrinth.course_block.widget

import android.content.Context
import android.content.Intent
import android.util.Log
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import com.labyrinth.course_block.R
import org.json.JSONArray

/** Supplies five vertically scrollable day columns to the weekly GridView. */
class WeekGridWidgetFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    companion object {
        private const val TAG = "WeekGridFactory"
    }

    private val instanceId = System.identityHashCode(this)
    private var lastLoggedCount = -1
    private data class Course(val name: String, val room: String, val time: String, val color: String)
    private data class Group(val label: String, val courses: List<Course>)

    private var cells: List<List<Group>> = emptyList()
    private lateinit var theme: WidgetColors.WidgetTheme

    override fun onCreate() {
        Log.d(TAG, "factory=$instanceId onCreate")
        loadData()
    }

    override fun onDataSetChanged() {
        Log.d(TAG, "factory=$instanceId onDataSetChanged")
        loadData()
    }

    override fun onDestroy() {
        Log.d(TAG, "factory=$instanceId onDestroy")
        cells = emptyList()
    }

    override fun getCount(): Int {
        val count = cells.size / 5
        if (count != lastLoggedCount) {
            Log.d(TAG, "factory=$instanceId getCount=$count cells=${cells.size}")
            lastLoggedCount = count
        }
        return count
    }
    override fun getItemId(position: Int) = position.toLong()
    override fun hasStableIds() = true
    override fun getViewTypeCount() = 1
    override fun getLoadingView(): RemoteViews? = null

    override fun getViewAt(position: Int): RemoteViews {
        Log.d(TAG, "factory=$instanceId getViewAt position=$position")
        val row = RemoteViews(context.packageName, R.layout.widget_week_row)
        val columnIds = intArrayOf(
            R.id.week_row_col_1, R.id.week_row_col_2, R.id.week_row_col_3,
            R.id.week_row_col_4, R.id.week_row_col_5,
        )
        for (day in 0 until 5) {
            val target = columnIds[day]
            // RemoteViews rows may be reused by the launcher; always rebuild each
            // column so an empty or shorter row cannot retain old children.
            row.removeAllViews(target)
            val group = cells.getOrNull(position * 5 + day)?.firstOrNull() ?: continue
            if (group.label.isNotEmpty()) {
                val header = RemoteViews(context.packageName, R.layout.widget_group_header_row)
                header.setTextViewText(R.id.row_header_label, group.label)
                header.setTextColor(R.id.row_header_label, theme.accent)
                header.setInt(R.id.row_header_divider, "setBackgroundColor", theme.divider)
                row.addView(target, header)
            }
            for (course in group.courses) {
                val card = RemoteViews(context.packageName, R.layout.widget_mini_card)
                val color = WidgetColors.forCourse(course.name, theme, course.color)
                card.setTextViewText(R.id.mini_name, course.name)
                card.setTextViewText(R.id.mini_info, listOf(course.time, course.room).filter { it.isNotEmpty() }.joinToString(" · "))
                card.setTextColor(R.id.mini_name, theme.courseTitle)
                card.setTextColor(R.id.mini_info, color)
                card.setInt(R.id.mini_bar, "setBackgroundColor", color)
                card.setOnClickFillInIntent(R.id.mini_root, Intent().putExtra("course_name", course.name))
                row.addView(target, card)
            }
        }
        return row
    }

    private fun loadData() {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val raw = prefs.getString("week_list", "[]").orEmpty()
        Log.d(TAG, "factory=$instanceId loadData rawHash=${raw.hashCode()} rawLength=${raw.length}")
        theme = WidgetColors.resolve(context, prefs)
        val groups = mutableListOf<Group>()
        try {
            val array = JSONArray(raw)
            var current: GroupBuilder? = null
            for (index in 0 until array.length()) {
                val item = array.getJSONObject(index)
                if (item.optString("t") == "header") {
                    current?.let { groups.add(it.build()) }
                    current = GroupBuilder(item.optString("label", ""))
                } else {
                    current?.courses?.add(Course(item.optString("name", "--"), item.optString("room", ""), item.optString("timeRange", ""), item.optString("color", "")))
                }
            }
            current?.let { groups.add(it.build()) }
        } catch (_: Exception) {
            cells = emptyList()
            return
        }
        // Defensive normalization: older snapshots could contain the same day/course
        // block more than once after switching schedules. Merge identical day headers
        // and remove duplicate course rows before building GridView cells.
        val normalizedGroups = groups
            .groupBy { it.label }
            .values
            .map { sameLabel ->
                val first = sameLabel.first()
                Group(
                    first.label,
                    sameLabel.flatMap { it.courses }
                        .distinctBy { Triple(it.name, it.time, it.room) },
                )
            }
        val dayChunks = List(5) { day ->
            normalizedGroups.filter { it.label.startsWith("周" + (day + 1).toChineseDay()) }
                .flatMap { group ->
                    if (group.courses.isEmpty()) listOf(group)
                    else group.courses.chunked(4).mapIndexed { index, chunk ->
                        Group(if (index == 0) group.label else "", chunk)
                    }
                }
        }
        val rowCount = dayChunks.maxOfOrNull { it.size } ?: 0
        cells = (0 until rowCount).flatMap { row ->
            Log.d(TAG, "factory=$instanceId normalizedGroups=${normalizedGroups.size} rowCount=$rowCount")
            (0 until 5).map { day -> listOfNotNull(dayChunks[day].getOrNull(row)) }
        }
    }

    private class GroupBuilder(private val label: String) {
        val courses = mutableListOf<Course>()
        fun build() = Group(label, courses.toList())
    }

    private fun Int.toChineseDay() = arrayOf("一", "二", "三", "四", "五")[this - 1]
}
