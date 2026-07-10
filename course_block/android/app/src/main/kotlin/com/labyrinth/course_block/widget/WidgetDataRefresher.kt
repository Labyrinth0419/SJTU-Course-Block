package com.labyrinth.course_block.widget

import android.content.Context
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar
import java.util.GregorianCalendar
import java.util.TimeZone

/** Rebuilds time-sensitive widget payloads from the snapshot written by Flutter. */
object WidgetDataRefresher {
    private const val TAG = "WidgetDataRefresher"
    private const val PREFERENCES_NAME = "HomeWidgetPreferences"
    private const val SNAPSHOT_KEY = "widget_schedule_snapshot"
    private const val SNAPSHOT_VERSION = 1
    private const val MILLIS_PER_DAY = 86_400_000L

    private val weekdaysShort = arrayOf("", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")
    private val utc = TimeZone.getTimeZone("UTC")

    private data class ScheduleSnapshot(
        val name: String,
        val startEpochDay: Long,
        val totalWeeks: Int,
    )

    private data class CourseSnapshot(
        val name: String,
        val room: String,
        val color: String,
        val startWeek: Int,
        val endWeek: Int,
        val dayOfWeek: Int,
        val isOddWeek: Boolean,
        val isEvenWeek: Boolean,
        val weekCode: String,
        val startMinutes: Int,
        val endMinutes: Int,
        val timeRange: String,
    )

    private data class DateParts(
        val month: Int,
        val day: Int,
        val weekday: Int,
    )

    /**
     * Returns true when a versioned snapshot was found and applied. Invalid or
     * missing snapshots leave the last Flutter-generated payload untouched.
     */
    fun refresh(context: Context, now: Calendar = Calendar.getInstance()): Boolean {
        val preferences = context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
        val snapshotJson = preferences.getString(SNAPSHOT_KEY, null) ?: return false

        return try {
            val root = JSONObject(snapshotJson)
            if (root.optInt("version") != SNAPSHOT_VERSION) return false

            val scheduleObject = root.optJSONObject("schedule")
            if (scheduleObject == null) {
                preferences.edit()
                    .putString("today_header", "课程表")
                    .putString("today_subtitle", "")
                    .putString("today_list", "[]")
                    .putString("day_list", "[]")
                    .putString("upcoming_list", "[]")
                    .putString("week_list", "[]")
                    .apply()
                return true
            }

            val schedule = ScheduleSnapshot(
                name = scheduleObject.optString("name", "课程表"),
                startEpochDay = scheduleObject.getLong("startEpochDay"),
                totalWeeks = scheduleObject.optInt("totalWeeks", 20).coerceAtLeast(1),
            )
            val courses = parseCourses(root.optJSONArray("courses") ?: JSONArray())
            val payloads = buildPayloads(schedule, courses, now)

            preferences.edit()
                .putString("today_header", schedule.name)
                .putString("today_subtitle", payloads.subtitle)
                .putString("today_list", payloads.today.toString())
                .putString("day_list", payloads.day.toString())
                .putString("upcoming_list", payloads.upcoming.toString())
                .putString("week_list", payloads.week.toString())
                .apply()
            true
        } catch (exception: Exception) {
            Log.w(TAG, "Unable to rebuild widget data from snapshot", exception)
            false
        }
    }

    private data class WidgetPayloads(
        val subtitle: String,
        val today: JSONArray,
        val day: JSONArray,
        val upcoming: JSONArray,
        val week: JSONArray,
    )

    private fun buildPayloads(
        schedule: ScheduleSnapshot,
        courses: List<CourseSnapshot>,
        now: Calendar,
    ): WidgetPayloads {
        val todayEpochDay = localEpochDay(now)
        val todayParts = dateParts(todayEpochDay)
        val nowMillisOfDay =
            now.get(Calendar.HOUR_OF_DAY) * 3_600_000 +
                now.get(Calendar.MINUTE) * 60_000 +
                now.get(Calendar.SECOND) * 1_000 +
                now.get(Calendar.MILLISECOND)
        val currentWeek = weekForDate(todayEpochDay, schedule)

        val todayCourses = courses
            .filter { isCourseInWeek(it, currentWeek) }
            .filter { it.dayOfWeek == todayParts.weekday }
            .filter { it.endMinutes * 60_000 > nowMillisOfDay }
            .sortedBy { it.startMinutes }
        val todayPayload = JSONArray()
        todayCourses.forEach { todayPayload.put(coursePayload(it)) }

        val dayPayload = JSONArray()
        courses
            .filter { isCourseInWeek(it, currentWeek) }
            .filter { it.dayOfWeek == todayParts.weekday }
            .sortedBy { it.startMinutes }
            .forEach { course ->
                val status = when {
                    nowMillisOfDay > course.endMinutes * 60_000 -> "done"
                    nowMillisOfDay > course.startMinutes * 60_000 -> "current"
                    else -> "upcoming"
                }
                dayPayload.put(coursePayload(course).put("status", status))
            }

        val upcomingPayload = JSONArray()
        for (offset in 0..2) {
            val epochDay = todayEpochDay + offset
            val parts = dateParts(epochDay)
            val week = weekForDate(epochDay, schedule)
            val dayCourses = courses
                .filter { isCourseInWeek(it, week) }
                .filter { it.dayOfWeek == parts.weekday }
                .filter { offset != 0 || it.endMinutes * 60_000 > nowMillisOfDay }
                .sortedBy { it.startMinutes }
            if (dayCourses.isEmpty()) continue

            val label = when (offset) {
                0 -> "Today ${parts.month}.${parts.day}"
                1 -> "Tmr ${parts.month}.${parts.day}"
                else -> "${weekdaysShort[parts.weekday]} ${parts.month}.${parts.day}"
            }
            upcomingPayload.put(JSONObject().put("t", "header").put("label", label))
            dayCourses.forEach {
                upcomingPayload.put(coursePayload(it).put("t", "course"))
            }
        }

        val weekPayload = JSONArray()
        val mondayEpochDay = todayEpochDay - (todayParts.weekday - 1)
        for (dayIndex in 0..6) {
            val epochDay = mondayEpochDay + dayIndex
            val parts = dateParts(epochDay)
            val week = weekForDate(epochDay, schedule)
            val dayCourses = courses
                .filter { isCourseInWeek(it, week) }
                .filter { it.dayOfWeek == parts.weekday }
                .sortedBy { it.startMinutes }
            if (dayCourses.isEmpty()) continue

            val todayMarker = if (epochDay == todayEpochDay) " ●" else ""
            val label = "${weekdaysShort[parts.weekday]}$todayMarker ${parts.month}.${parts.day}"
            weekPayload.put(JSONObject().put("t", "header").put("label", label))
            dayCourses.forEach {
                weekPayload.put(coursePayload(it).put("t", "course"))
            }
        }

        return WidgetPayloads(
            subtitle = "${todayParts.month}.${todayParts.day}  ${weekdaysShort[todayParts.weekday]}",
            today = todayPayload,
            day = dayPayload,
            upcoming = upcomingPayload,
            week = weekPayload,
        )
    }

    private fun parseCourses(array: JSONArray): List<CourseSnapshot> {
        val courses = mutableListOf<CourseSnapshot>()
        for (index in 0 until array.length()) {
            try {
                val item = array.getJSONObject(index)
                courses.add(
                    CourseSnapshot(
                        name = item.optString("name", "--"),
                        room = item.optString("room", ""),
                        color = item.optString("color", ""),
                        startWeek = item.optInt("startWeek", 1),
                        endWeek = item.optInt("endWeek", 20),
                        dayOfWeek = item.getInt("dayOfWeek"),
                        isOddWeek = item.optBoolean("isOddWeek", false),
                        isEvenWeek = item.optBoolean("isEvenWeek", false),
                        weekCode = item.optString("weekCode", ""),
                        startMinutes = item.getInt("startMinutes"),
                        endMinutes = item.getInt("endMinutes"),
                        timeRange = item.optString("timeRange", ""),
                    )
                )
            } catch (exception: Exception) {
                Log.w(TAG, "Skipping invalid course snapshot at index $index", exception)
            }
        }
        return courses
    }

    private fun coursePayload(course: CourseSnapshot) = JSONObject()
        .put("name", course.name)
        .put("room", course.room)
        .put("timeRange", course.timeRange)
        .put("color", course.color)

    private fun isCourseInWeek(course: CourseSnapshot, week: Int): Boolean {
        if (course.weekCode.isNotEmpty()) {
            return week in 1..course.weekCode.length && course.weekCode[week - 1] == '1'
        }
        if (week < course.startWeek || week > course.endWeek) return false
        if (course.isOddWeek && week % 2 == 0) return false
        if (course.isEvenWeek && week % 2 != 0) return false
        return true
    }

    private fun weekForDate(epochDay: Long, schedule: ScheduleSnapshot): Int {
        val week = Math.floorDiv(epochDay - schedule.startEpochDay, 7L) + 1L
        return week.coerceIn(1L, schedule.totalWeeks.toLong()).toInt()
    }

    /** Converts the device-local calendar date to a timezone-independent epoch day. */
    private fun localEpochDay(calendar: Calendar): Long {
        val utcCalendar = GregorianCalendar(utc).apply {
            clear()
            set(
                calendar.get(Calendar.YEAR),
                calendar.get(Calendar.MONTH),
                calendar.get(Calendar.DAY_OF_MONTH),
            )
        }
        return Math.floorDiv(utcCalendar.timeInMillis, MILLIS_PER_DAY)
    }

    private fun dateParts(epochDay: Long): DateParts {
        val calendar = GregorianCalendar(utc).apply {
            timeInMillis = epochDay * MILLIS_PER_DAY
        }
        val weekday = (calendar.get(Calendar.DAY_OF_WEEK) + 5) % 7 + 1
        return DateParts(
            month = calendar.get(Calendar.MONTH) + 1,
            day = calendar.get(Calendar.DAY_OF_MONTH),
            weekday = weekday,
        )
    }
}
