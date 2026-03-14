package com.labyrinth.course_block.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import com.labyrinth.course_block.MainActivity
import com.labyrinth.course_block.R

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
            // 通知 ListView 数据已变更，触发 CourseWidgetFactory.onDataSetChanged
            for (id in ids) {
                manager.notifyAppWidgetViewDataChanged(id, R.id.widget_list_view)
            }
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
        val theme = WidgetColors.resolve(context, widgetData)

        val header   = widgetData.getString("today_header",   "今日课程") ?: "今日课程"
        val subtitle = widgetData.getString("today_subtitle", "")         ?: ""
        val listJson = widgetData.getString("today_list",     "[]")       ?: "[]"

        Log.d(TAG, "Widget data — header=$header  subtitle=$subtitle  list=$listJson")

        views.setInt(R.id.widget_root, "setBackgroundResource", theme.backgroundRes)
        views.setTextViewText(R.id.tv_header,   header)
        views.setTextViewText(R.id.tv_subtitle, subtitle)
        views.setTextColor(R.id.tv_header, theme.headerText)
        views.setTextColor(R.id.tv_subtitle, theme.subtitleText)
        views.setTextColor(R.id.tv_empty, theme.emptyText)
        views.setTextColor(R.id.btn_refresh, theme.accent)
        views.setTextColor(R.id.btn_open, theme.openText)
        views.setInt(R.id.divider_top, "setBackgroundColor", theme.divider)
        views.setInt(R.id.divider_bottom, "setBackgroundColor", theme.divider)

        // 绑定可滚动 ListView 适配器
        // 每个 widgetId 使用独立 URI，避免多实例时 PendingIntent 被复用
        val serviceIntent = Intent(context, CourseWidgetService::class.java).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
        }
        views.setRemoteAdapter(R.id.widget_list_view, serviceIntent)
        // 当列表为空时自动显示空状态视图
        views.setEmptyView(R.id.widget_list_view, R.id.tv_empty)

        attachOpenIntent(context, views)
        attachRefreshIntent(context, widgetId, views)

        appWidgetManager.updateAppWidget(widgetId, views)
        appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.widget_list_view)
        Log.d(TAG, "Widget $widgetId updated successfully")
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
            val prefs = context.getSharedPreferences(prefsName(context), Context.MODE_PRIVATE)
            val theme = WidgetColors.resolve(context, prefs)
            val fallback = RemoteViews(context.packageName, R.layout.widget_today)
            fallback.setInt(R.id.widget_root, "setBackgroundResource", theme.backgroundRes)
            fallback.setTextViewText(R.id.tv_header,   "课程表")
            fallback.setTextViewText(R.id.tv_subtitle, "点击刷新")
            fallback.setTextColor(R.id.tv_header, theme.headerText)
            fallback.setTextColor(R.id.tv_subtitle, theme.subtitleText)
            fallback.setTextColor(R.id.tv_empty, theme.emptyText)
            fallback.setTextColor(R.id.btn_refresh, theme.accent)
            fallback.setTextColor(R.id.btn_open, theme.openText)
            fallback.setInt(R.id.divider_top, "setBackgroundColor", theme.divider)
            fallback.setInt(R.id.divider_bottom, "setBackgroundColor", theme.divider)
            fallback.setViewVisibility(R.id.tv_empty,        View.VISIBLE)
            fallback.setViewVisibility(R.id.widget_list_view, View.GONE)
            attachOpenIntent(context, fallback)
            attachRefreshIntent(context, widgetId, fallback)
            appWidgetManager.updateAppWidget(widgetId, fallback)
        } catch (e: Exception) {
            Log.e(TAG, "Fallback update also failed for widget $widgetId", e)
        }
    }
}
