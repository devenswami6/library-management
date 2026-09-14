package com.example.flutter_app

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.flutter_app/notifications"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    val userId = call.argument<Int>("userId") ?: 0
                    val baseUrl = call.argument<String>("baseUrl") ?: "https://library-management-hmwx.onrender.com"
                    if (userId > 0) {
                        LibraryNotificationService.startService(context, userId, baseUrl)
                        requestPostNotificationsPermission()
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                "stopService" -> {
                    LibraryNotificationService.stopService(context)
                    result.success(true)
                }
                "launchUrl" -> {
                    val urlStr = call.argument<String>("url") ?: ""
                    if (urlStr.isNotEmpty()) {
                        try {
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(urlStr))
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("LAUNCH_FAILED", e.message, null)
                        }
                    } else {
                        result.error("INVALID_URL", "URL is empty", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun requestPostNotificationsPermission() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                if (ContextCompat.checkSelfPermission(this, android.Manifest.permission.POST_NOTIFICATIONS) != android.content.pm.PackageManager.PERMISSION_GRANTED) {
                    ActivityCompat.requestPermissions(this, arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 101)
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
