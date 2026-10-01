package com.labyrinth.course_block.widget

import java.util.Calendar
import java.util.GregorianCalendar
import java.util.TimeZone

/** Returns a term week only when the civil date is inside its Monday-anchored bounds. */
internal fun academicWeekForEpochDay(startEpochDay: Long, epochDay: Long, totalWeeks: Int): Int? {
    // 1970-01-01 (epoch day 0) was Thursday: its Monday is epoch day -3.
    val firstMonday = startEpochDay - Math.floorMod(startEpochDay + 3L, 7L)
    val week = Math.floorDiv(epochDay - firstMonday, 7L) + 1L
    return if (week in 1L..totalWeeks.toLong()) week.toInt() else null
}

/** Converts the device-local calendar date to a timezone-independent epoch day. */
internal fun localEpochDay(calendar: Calendar): Long {
    val utcCalendar = GregorianCalendar(TimeZone.getTimeZone("UTC")).apply {
        clear()
        set(
            calendar.get(Calendar.YEAR),
            calendar.get(Calendar.MONTH),
            calendar.get(Calendar.DAY_OF_MONTH),
        )
    }
    return Math.floorDiv(utcCalendar.timeInMillis, 86_400_000L)
}
