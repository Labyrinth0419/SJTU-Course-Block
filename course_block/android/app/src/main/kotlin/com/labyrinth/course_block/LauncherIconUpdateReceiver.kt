package com.labyrinth.course_block

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class LauncherIconUpdateReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_MY_PACKAGE_REPLACED) return
        try {
            LauncherIconController(context).restoreIcon()
        } catch (error: Exception) {
            Log.e("LauncherIcon", "Unable to restore launcher after upgrade", error)
        }
    }
}
