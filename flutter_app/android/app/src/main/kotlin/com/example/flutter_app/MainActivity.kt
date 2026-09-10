package com.example.flutter_app

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

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
}

