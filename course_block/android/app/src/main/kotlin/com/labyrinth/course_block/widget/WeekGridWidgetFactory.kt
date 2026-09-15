package com.labyrinth.course_block.widget

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import com.labyrinth.course_block.R
import org.json.JSONArray

/** Supplies five vertically scrollable day columns to the weekly GridView. */
class WeekGridWidgetFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private data class Course(val name: String, val room: String, val time: String, val color: String)
    private data class Group(val label: String, val courses: List<Course>)

    private var cells: List<List<Group>> = emptyList()
    private lateinit var theme: WidgetColors.WidgetTheme

    override fun onCreate() = loadData()
    override fun onDataSetChanged() = loadData()
    override fun onDestroy() { cells = emptyList() }
    override fun getCount() = cells.size
    override fun getItemId(position: Int) = position.toLong()
    override fun hasStableIds() = true
    override fun getViewTypeCount() = 1
    override fun getLoadingView(): RemoteViews? = null

    override fun getViewAt(position: Int): RemoteViews {
        val view = RemoteViews(context.packageName, R.layout.widget_week_column)
        val dayGroups = cells.getOrNull(position).orEmpty()
        for (group in dayGroups) {
            val header = RemoteViews(context.packageName, R.layout.widget_group_header_row)
            header.setTextViewText(R.id.row_header_label, group.label)
            header.setTextColor(R.id.row_header_label, theme.accent)
            header.setInt(R.id.row_header_divider, "setBackgroundColor", theme.divider)
            view.addView(R.id.week_column_root, header)
            for (course in group.courses) {
                val card = RemoteViews(context.packageName, R.layout.widget_mini_card)
                val color = WidgetColors.forCourse(course.name, theme, course.color)
                card.setTextViewText(R.id.mini_name, course.name)
                card.setTextViewText(R.id.mini_info, listOf(course.time, course.room).filter { it.isNotEmpty() }.joinToString(" · "))
                card.setTextColor(R.id.mini_name, theme.courseTitle)
                card.setTextColor(R.id.mini_info, color)
                card.setInt(R.id.mini_bar, "setBackgroundColor", color)
                card.setOnClickFillInIntent(R.id.mini_root, Intent().putExtra("course_name", course.name))
                view.addView(R.id.week_column_root, card)
            }
        }
        return view
    }

    private fun loadData() {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        theme = WidgetColors.resolve(context, prefs)
        val groups = mutableListOf<Group>()
        try {
            val array = JSONArray(prefs.getString("week_list", "[]") ?: "[]")
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
            (0 until 5).map { day -> listOfNotNull(dayChunks[day].getOrNull(row)) }
        }
    }

    private class GroupBuilder(private val label: String) {
        val courses = mutableListOf<Course>()
        fun build() = Group(label, courses.toList())
    }

    private fun Int.toChineseDay() = arrayOf("一", "二", "三", "四", "五")[this - 1]
}
