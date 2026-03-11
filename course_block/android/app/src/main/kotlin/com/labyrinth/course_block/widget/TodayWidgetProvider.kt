package com.labyrinth.course_block.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import com.labyrinth.course_block.MainActivity
import com.labyrinth.course_block.R
import org.json.JSONArray

class TodayWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val TAG = "TodayWidgetProvider"
        const val ACTION_REFRESH = "com.labyrinth.course_block.widget.ACTION_REFRESH"

        /** home_widget Flutter 插件将数据写入此 SharedPreferences 文件
         *  注意：实际文件名是 "HomeWidgetPreferences"，不含包名前缀
         *  可通过 adb shell run-as <pkg> ls shared_prefs/ 验证 */
        private fun prefsName(@Suppress("UNUSED_PARAMETER") context: Context) =
            "HomeWidgetPreferences"
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 入口：系统触发 / Flutter 触发 / 刷新按钮触发
    // ──────────────────────────────────────────────────────────────────────────

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_REFRESH) {
            Log.d(TAG, "ACTION_REFRESH received — re-reading SharedPreferences")
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, TodayWidgetProvider::class.java)
            )
            onUpdate(context, manager, ids)
        } else {
            super.onReceive(context, intent)
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        Log.d(TAG, "onUpdate called for ${appWidgetIds.size} widget(s)")
        val widgetData = context.getSharedPreferences(prefsName(context), Context.MODE_PRIVATE)
        for (widgetId in appWidgetIds) {
            try {
                updateSingleWidget(context, appWidgetManager, widgetId, widgetData)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to update widget $widgetId", e)
                applyFallback(context, appWidgetManager, widgetId)
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 单个 Widget 更新逻辑
    // ──────────────────────────────────────────────────────────────────────────

    private fun updateSingleWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int,
        widgetData: SharedPreferences
    ) {
        val views = RemoteViews(context.packageName, R.layout.widget_today)

        val header   = widgetData.getString("today_header",   "今日课程") ?: "今日课程"
        val subtitle = widgetData.getString("today_subtitle", "")         ?: ""
        val listJson = widgetData.getString("today_list",     "[]")       ?: "[]"

        Log.d(TAG, "Widget data — header=$header  subtitle=$subtitle  list=$listJson")

        views.setTextViewText(R.id.tv_header,   header)
        views.setTextViewText(R.id.tv_subtitle, subtitle)

        applyList(listJson, views)
        attachOpenIntent(context, views)
        attachRefreshIntent(context, widgetId, views)

        appWidgetManager.updateAppWidget(widgetId, views)
        Log.d(TAG, "Widget $widgetId updated successfully")
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 课程列表填充
    // ──────────────────────────────────────────────────────────────────────────

    private val titleIds  = listOf(R.id.row1_title,  R.id.row2_title,  R.id.row3_title)
    private val detailIds = listOf(R.id.row1_detail, R.id.row2_detail, R.id.row3_detail)

    private fun applyList(listJson: String, views: RemoteViews) {
        val arr = try {
            JSONArray(listJson)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to parse today_list JSON: $listJson", e)
            JSONArray()
        }

        for (i in titleIds.indices) {
            if (i < arr.length()) {
                val obj        = arr.getJSONObject(i)
                val name       = obj.optString("name",      "")
                val room       = obj.optString("room",      "")
                val timeRange  = obj.optString("timeRange", "")

                val titleText = if (timeRange.isNotEmpty()) {
                    "$timeRange  $name"
                } else {
                    name.ifEmpty { "--" }
                }
                val detailText = if (room.isNotEmpty()) "@$room" else ""

                views.setTextViewText(titleIds[i],  titleText)
                views.setTextViewText(detailIds[i], detailText)
                views.setViewVisibility(titleIds[i],  View.VISIBLE)
                views.setViewVisibility(detailIds[i], View.VISIBLE)
            } else {
                views.setViewVisibility(titleIds[i],  View.GONE)
                views.setViewVisibility(detailIds[i], View.GONE)
            }
        }

        val isEmpty = arr.length() == 0
        views.setViewVisibility(R.id.tv_empty,        if (isEmpty) View.VISIBLE else View.GONE)
        views.setViewVisibility(R.id.list_container,  if (isEmpty) View.GONE    else View.VISIBLE)
    }

    // ──────────────────────────────────────────────────────────────────────────
    // PendingIntent 绑定
    // ──────────────────────────────────────────────────────────────────────────

    private fun attachOpenIntent(context: Context, views: RemoteViews) {
        try {
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pi = PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.btn_open, pi)
        } catch (e: Exception) {
            Log.e(TAG, "Could not create open PendingIntent", e)
        }
    }

    private fun attachRefreshIntent(context: Context, widgetId: Int, views: RemoteViews) {
        try {
            val intent = Intent(context, TodayWidgetProvider::class.java).apply {
                action = ACTION_REFRESH
            }
            // 用 widgetId 作 requestCode，避免多实例时 PendingIntent 互相覆盖
            val pi = PendingIntent.getBroadcast(
                context, widgetId, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.btn_refresh, pi)
        } catch (e: Exception) {
            Log.e(TAG, "Could not create refresh PendingIntent", e)
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 兜底：避免任何异常让 widget 永久空白
    // ──────────────────────────────────────────────────────────────────────────

    private fun applyFallback(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int
    ) {
        try {
            val fallback = RemoteViews(context.packageName, R.layout.widget_today)
            fallback.setTextViewText(R.id.tv_header,   "课程表")
            fallback.setTextViewText(R.id.tv_subtitle, "点击刷新或打开应用")
            fallback.setViewVisibility(R.id.list_container, View.GONE)
            fallback.setViewVisibility(R.id.tv_empty,       View.VISIBLE)
            attachOpenIntent(context, fallback)
            attachRefreshIntent(context, widgetId, fallback)
            appWidgetManager.updateAppWidget(widgetId, fallback)
        } catch (e: Exception) {
            Log.e(TAG, "Fallback update also failed for widget $widgetId", e)
        }
    }
}
