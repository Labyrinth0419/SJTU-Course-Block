package com.labyrinth.course_block

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.preference.PreferenceManager
import android.net.Uri
import android.util.Log
import android.view.View
import android.widget.LinearLayout
import android.app.PendingIntent
import android.widget.RemoteViews

class CourseWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        // try to read from FlutterSharedPreferences first (used by Flutter plugin),
        // then fall back to default shared preferences
        var json: String? = null
        try {
            val fPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            // log all keys to discover how Flutter stored the preference
            try {
                val all = fPrefs.all
                Log.d("CourseWidget", "FlutterSharedPreferences all=$all")
                // check common key patterns used by Flutter shared_preferences plugin
                val candidates = listOf(
                    "today_courses",
                    "flutter.today_courses",
                    "flutter.todayCourses",
                    "flutter.today_courses" // duplicate to be sure
                )
                for (cand in candidates) {
                    if (all.containsKey(cand)) {
                        val v = all[cand]
                        json = v as? String
                        Log.d("CourseWidget", "found candidate key $cand -> $v")
                        break
                    }
                }
                // fallback: any key containing today_courses
                if (json == null) {
                    for ((k, v) in all) {
                        if (k.contains("today_courses")) {
                            json = v as? String
                            Log.d("CourseWidget", "found key in FlutterSharedPreferences: $k -> $v")
                            break
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e("CourseWidget", "iterating FlutterSharedPreferences failed", e)
            }
        } catch (e: Exception) {
            Log.w("CourseWidget", "read FlutterSharedPreferences failed", e)
        }
        if (json == null) {
            val prefs = PreferenceManager.getDefaultSharedPreferences(context)
            json = prefs.getString("today_courses", "{}") ?: "{}"
            Log.d("CourseWidget", "read from default prefs json=$json")
        }

        // if still empty/default, try reading app-private file written by Flutter
        try {
            if (json == null || json.trim() == "{}") {
                val file = java.io.File(context.filesDir, "today_courses.json")
                if (file.exists()) {
                    val fileJson = file.readText()
                    if (!fileJson.isNullOrEmpty()) {
                        json = fileJson
                        Log.d("CourseWidget", "read from file=${file.path} json=$json")
                    }
                } else {
                    Log.d("CourseWidget", "today_courses.json not found at ${file.path}")
                }
            }
        } catch (e: Exception) {
            Log.e("CourseWidget", "read file fallback failed", e)
        }

        // iterate each widget id because options (size) may vary
        appWidgetIds.forEach { id ->
            Log.d("CourseWidget", "updating widget id=$id, json=$json")
            val rv = RemoteViews(context.packageName, R.layout.widget_course)

            val options = appWidgetManager.getAppWidgetOptions(id)
            val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
            if (minWidth >= 200) {
                rv.setInt(R.id.root_layout, "setOrientation", LinearLayout.HORIZONTAL)
            } else {
                rv.setInt(R.id.root_layout, "setOrientation", LinearLayout.VERTICAL)
            }

            // parse the JSON data
            var type = "none"
            var name = ""
            var room = ""
            try {
                val obj = org.json.JSONObject(json ?: "{}")
                type = obj.optString("type", "none")
                name = obj.optString("courseName", "")
                room = obj.optString("classRoom", "")
            } catch (e: Exception) {
                Log.e("CourseWidget", "JSON parse error", e)
            }

            Log.d("CourseWidget", "parsed type=$type name=$name room=$room")
            // for debugging: set the title to the raw JSON so we can see it on the widget
            try {
                rv.setTextViewText(R.id.widget_title, json ?: "")
            } catch (e: Exception) {
                Log.e("CourseWidget", "set widget_title failed", e)
            }

            when (type) {
                "course" -> {
                    rv.setViewVisibility(R.id.course_name, View.VISIBLE)
                    rv.setViewVisibility(R.id.course_room, View.VISIBLE)
                    rv.setViewVisibility(R.id.status_text, View.GONE)
                    rv.setTextViewText(R.id.course_name, name)
                    rv.setTextViewText(R.id.course_room, room)
                }
                "tomorrow" -> {
                    rv.setViewVisibility(R.id.course_name, View.GONE)
                    rv.setViewVisibility(R.id.course_room, View.GONE)
                    rv.setViewVisibility(R.id.status_text, View.VISIBLE)
                    rv.setTextViewText(R.id.status_text, "明天第一节：$name")
                }
                else -> {
                    rv.setViewVisibility(R.id.course_name, View.GONE)
                    rv.setViewVisibility(R.id.course_room, View.GONE)
                    rv.setViewVisibility(R.id.status_text, View.VISIBLE)
                    rv.setTextViewText(R.id.status_text, "今日无课")
                }
            }

            // clicking anywhere launches the main activity
            // prepare click intent to launch main activity
            val clickIntent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_MAIN
                addCategory(Intent.CATEGORY_LAUNCHER)
            }
            val pending = PendingIntent.getActivity(
                context,
                0,
                clickIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            rv.setOnClickPendingIntent(R.id.root_layout, pending)

            appWidgetManager.updateAppWidget(id, rv)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(ComponentName(context, CourseWidgetProvider::class.java))
            onUpdate(context, mgr, ids)
        }
    }
}