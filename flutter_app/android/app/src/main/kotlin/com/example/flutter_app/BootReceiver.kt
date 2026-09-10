package com.example.flutter_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED || intent.action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            try {
                val prefs = context.getSharedPreferences(LibraryNotificationService.PREFS_NAME, Context.MODE_PRIVATE)
                val userId = prefs.getInt(LibraryNotificationService.KEY_USER_ID, 0)
                val baseUrl = prefs.getString(LibraryNotificationService.KEY_BASE_URL, "") ?: ""
                if (userId > 0 && baseUrl.isNotEmpty()) {
                    LibraryNotificationService.startService(context, userId, baseUrl)
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
}
