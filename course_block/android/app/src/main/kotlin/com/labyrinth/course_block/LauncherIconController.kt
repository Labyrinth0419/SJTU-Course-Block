package com.labyrinth.course_block

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build

class LauncherIconController(private val context: Context) {
    private val packageName = context.packageName
    private val mainActivity = "$packageName.MainActivity"
    private val defaultAlias = "$packageName.DefaultLauncher"
    private val preferences = context.getSharedPreferences("launcher_icon_state", Context.MODE_PRIVATE)

    @Suppress("DEPRECATION")
    private fun components(): List<IconComponent> {
        val info = context.packageManager.getPackageInfo(
            packageName,
            PackageManager.GET_ACTIVITIES or PackageManager.MATCH_DISABLED_COMPONENTS,
        )
        return info.activities.orEmpty()
            .filter { it.targetActivity == null || it.targetActivity == mainActivity }
            .map { activity ->
                IconComponent(
                    activity.name,
                    activity.targetActivity == mainActivity,
                    context.packageManager.getComponentEnabledSetting(ComponentName(packageName, activity.name)),
                )
            }
    }

    fun restoreIcon(): String? {
        val legacy = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val saved = if (preferences.contains("selected_icon")) {
            preferences.getString("selected_icon", "")
        } else {
            // The update receiver must recover the old choice before Dart has started.
            try { legacy.getString("flutter.app_icon_choice", null) } catch (_: ClassCastException) { null }
        }
        val available = components().filter { it.alias }.map { it.name }
        val name = saved?.takeIf { it.isNotEmpty() && "$packageName.$it" in available }
        setIcon(name)
        return name
    }

    fun setIcon(name: String?) {
        val components = components()
        val chosen = if (name == null) defaultAlias else "$packageName.$name"
        val changes = LauncherIconPolicy.changes(mainActivity, defaultAlias, chosen, components)
        val previous = preferences.getString("selected_icon", null)
        // Some OEM launchers restart the app despite DONT_KILL_APP.
        check(preferences.edit().putString("selected_icon", name ?: "").commit())
        try {
            val pm = context.packageManager
            if (changes.isNotEmpty() && Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                pm.setComponentEnabledSettings(changes.map { (component, state) ->
                    PackageManager.ComponentEnabledSetting(
                        ComponentName(packageName, component), state, PackageManager.DONT_KILL_APP,
                    )
                })
            } else {
                for ((component, state) in changes) {
                    pm.setComponentEnabledSetting(
                        ComponentName(packageName, component), state, PackageManager.DONT_KILL_APP,
                    )
                }
            }
        } catch (error: Exception) {
            val editor = preferences.edit()
            if (previous == null) editor.remove("selected_icon") else editor.putString("selected_icon", previous)
            editor.commit()
            throw error
        }
    }
}
