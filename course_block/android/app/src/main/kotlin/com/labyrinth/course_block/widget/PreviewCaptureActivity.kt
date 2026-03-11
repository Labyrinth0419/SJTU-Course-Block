package com.labyrinth.course_block.widget

import android.app.Activity
import android.os.Bundle
import android.view.View
import android.view.WindowManager
import com.labyrinth.course_block.R

/**
 * 临时 Activity：全屏渲染 widget_preview.xml，供 adb screencap 截图生成 previewImage。
 * 截图完成后可将此 Activity 及其 Manifest 条目删除。
 */
class PreviewCaptureActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 全屏，隐藏状态栏和导航栏
        window.setFlags(
            WindowManager.LayoutParams.FLAG_FULLSCREEN,
            WindowManager.LayoutParams.FLAG_FULLSCREEN
        )
        @Suppress("DEPRECATION")
        window.decorView.systemUiVisibility = (
            View.SYSTEM_UI_FLAG_LAYOUT_STABLE or
            View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or
            View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
            View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
            View.SYSTEM_UI_FLAG_FULLSCREEN or
            View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
        )

        setContentView(R.layout.activity_widget_capture)
    }
}
