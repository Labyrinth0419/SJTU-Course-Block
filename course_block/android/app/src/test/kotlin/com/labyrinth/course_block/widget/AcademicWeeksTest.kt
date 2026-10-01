package com.labyrinth.course_block.widget

import java.time.LocalDate
import java.util.Calendar
import java.util.GregorianCalendar
import java.util.TimeZone
import org.junit.Assert.assertEquals
import org.junit.Test

class AcademicWeeksTest {
    private val startEpochDay = LocalDate.of(2026, 3, 4).toEpochDay() // Wednesday

    @Test
    fun mondayAnchoredDatesAndOutOfTermDates() {
        val fixtures = listOf(
            1 to null,
            2 to 1,
            8 to 1,
            9 to 2,
            15 to 2,
            16 to null,
        )
        for ((day, expected) in fixtures) {
            val epochDay = LocalDate.of(2026, 3, day).toEpochDay()
            assertEquals("March $day", expected, academicWeekForEpochDay(startEpochDay, epochDay, 2))
        }
    }

    @Test
    fun localCivilDaysIgnoreSpringDstAndNegativeEpochDays() {
        val newYork = TimeZone.getTimeZone("America/New_York")
        fun localDate(day: Int, hour: Int): Calendar = GregorianCalendar(newYork).apply {
            clear()
            set(2026, Calendar.MARCH, day, hour, 30)
        }
        val sunday = LocalDate.of(2026, 3, 8).toEpochDay()
        assertEquals(sunday, localEpochDay(localDate(8, 1)))
        assertEquals(sunday, localEpochDay(localDate(8, 3)))
        val monday = localEpochDay(localDate(9, 1))
        assertEquals(sunday + 1, monday)
        assertEquals(2, academicWeekForEpochDay(startEpochDay, monday, 2))
        assertEquals(-1L, localEpochDay(GregorianCalendar(TimeZone.getTimeZone("UTC")).apply {
            clear()
            set(1969, Calendar.DECEMBER, 31)
        }))
    }
}
