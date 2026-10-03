package com.labyrinth.course_block

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class LauncherIconPolicyTest {
    private val main = "app.MainActivity"
    private val default = "app.DefaultLauncher"
    private val alternate = "app.an_an"
    private val crop = "crop.Activity"

    private fun components(mainState: Int = 0, cropState: Int = 0) = listOf(
        IconComponent(main, false, mainState),
        IconComponent(default, true, 0),
        IconComponent(alternate, true, 0),
        IconComponent(crop, false, cropState),
    )

    @Test fun selectingAliasNeverDisablesRealActivities() {
        val changes = LauncherIconPolicy.changes(main, default, alternate, components())
        assertEquals(1, changes[main])
        assertEquals(1, changes[alternate])
        assertEquals(2, changes[default])
        assertFalse(changes.containsKey(crop))
    }

    @Test fun upgradeRepairsLegacyDisabledActivitiesAndKeepsChosenAlias() {
        val changes = LauncherIconPolicy.changes(main, default, alternate, components(2, 2))
        assertEquals(1, changes[main])
        assertEquals(0, changes[crop])
        assertEquals(1, changes[alternate])
        assertEquals(2, changes[default])
    }

    @Test fun defaultIconIsAnAliasNotTheMainActivity() {
        val changes = LauncherIconPolicy.changes(main, default, default, components())
        assertEquals(1, changes[main])
        assertEquals(1, changes[default])
        assertEquals(2, changes[alternate])
    }

    @Test(expected = IllegalArgumentException::class)
    fun unknownIconRejectedBeforeChangingComponents() {
        LauncherIconPolicy.changes(main, default, "app.unknown", components())
    }
}
