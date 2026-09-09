package com.example.flutter_app

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
                    val baseUrl = call.argument<String>("baseUrl") ?: "http://192.168.1.84:8000"
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
                else -> result.notImplemented()
            }
        }
    }
}

