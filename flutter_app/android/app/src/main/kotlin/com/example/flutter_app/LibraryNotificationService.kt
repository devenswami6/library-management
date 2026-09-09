package com.example.flutter_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

class LibraryNotificationService : Service() {

    private val handler = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()
    private val shownNotifIds = mutableSetOf<Int>()
    private var isRunning = false

    companion object {
        const val CHANNEL_ID_FOREGROUND = "library_fg_service_channel"
        const val CHANNEL_ID_NOTIFS = "library_announcements_channel"
        const val NOTIF_ID_FOREGROUND = 9999
        const val PREFS_NAME = "LibraryNotifPrefs"
        const val KEY_USER_ID = "user_id"
        const val KEY_BASE_URL = "base_url"
        const val KEY_SHOWN_IDS = "shown_ids"

        fun startService(context: Context, userId: Int, baseUrl: String) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit()
                .putInt(KEY_USER_ID, userId)
                .putString(KEY_BASE_URL, baseUrl)
                .apply()

            val intent = Intent(context, LibraryNotificationService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stopService(context: Context) {
            val intent = Intent(context, LibraryNotificationService::class.java)
            context.stopService(intent)
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannels()
    }

    private fun getAppIconRes(): Int {
        val resId = resources.getIdentifier("ic_launcher", "mipmap", packageName)
        return if (resId != 0) resId else android.R.drawable.ic_dialog_info
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = NotificationCompat.Builder(this, CHANNEL_ID_FOREGROUND)
            .setContentTitle("Self-Study Library")
            .setContentText("Listening for notices...")
            .setSmallIcon(getAppIconRes())
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setOngoing(true)
            .build()

        startForeground(NOTIF_ID_FOREGROUND, notification)

        if (!isRunning) {
            isRunning = true
            loadShownIdsFromPrefs()
            startPollingLoop()
        }

        return START_STICKY
    }

    private fun loadShownIdsFromPrefs() {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val saved = prefs.getStringSet(KEY_SHOWN_IDS, emptySet()) ?: emptySet()
        shownNotifIds.clear()
        for (idStr in saved) {
            idStr.toIntOrNull()?.let { shownNotifIds.add(it) }
        }
    }

    private fun saveShownIdsToPrefs() {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val strSet = shownNotifIds.map { it.toString() }.toSet()
        prefs.edit().putStringSet(KEY_SHOWN_IDS, strSet).apply()
    }

    private fun startPollingLoop() {
        handler.post(object : Runnable {
            override fun run() {
                checkNotificationsInBackground()
                handler.postDelayed(this, 5000) // Check every 5 seconds for instant delivery
            }
        })
    }

    private fun checkNotificationsInBackground() {
        executor.execute {
            try {
                loadShownIdsFromPrefs()
                val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val userId = prefs.getInt(KEY_USER_ID, 0)
                val baseUrl = prefs.getString(KEY_BASE_URL, "http://10.84.90.50:8000") ?: "http://10.84.90.50:8000"

                if (userId <= 0) return@execute

                val urlString = "$baseUrl/api/json_student_actions.php?action=get_dashboard_data&user_id=$userId"
                val url = URL(urlString)
                val connection = url.openConnection() as HttpURLConnection
                connection.requestMethod = "GET"
                connection.connectTimeout = 4000
                connection.readTimeout = 4000

                if (connection.responseCode == 200) {
                    val responseText = connection.inputStream.bufferedReader().use { it.readText() }
                    val json = JSONObject(responseText)
                    if (json.optBoolean("success")) {
                        val notifs = json.optJSONArray("notifications")
                        if (notifs != null) {
                            for (i in 0 until notifs.length()) {
                                val item = notifs.getJSONObject(i)
                                val id = item.optInt("id", 0)
                                val rawTitle = item.optString("title", "New Notice")
                                val rawMsg = item.optString("message", item.optString("content", ""))
                                val title = if (rawTitle.isNotBlank()) rawTitle else "New Notice"
                                val body = if (rawMsg.isNotBlank()) rawMsg else title
                                val isRead = item.optInt("is_read", 0) == 1 || item.optBoolean("is_read", false)

                                if (id > 0 && !isRead) {
                                    if (!shownNotifIds.contains(id)) {
                                        shownNotifIds.add(id)
                                        saveShownIdsToPrefs()
                                        showHeadsUpNotification(id, title, body)
                                        markNotificationAsRead(baseUrl, userId, id)
                                    }
                                }
                            }
                        }
                    }
                }
                connection.disconnect()
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    private fun markNotificationAsRead(baseUrl: String, userId: Int, notifId: Int) {
        try {
            val markUrl = URL("$baseUrl/api/json_student_actions.php?action=mark_notification_read&user_id=$userId&notif_id=$notifId")
            val conn = markUrl.openConnection() as HttpURLConnection
            conn.requestMethod = "GET"
            conn.connectTimeout = 3000
            conn.readTimeout = 3000
            conn.responseCode
            conn.disconnect()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun showHeadsUpNotification(id: Int, title: String, message: String) {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(this, CHANNEL_ID_NOTIFS)
            .setContentTitle(title)
            .setContentText(message)
            .setSmallIcon(getAppIconRes())
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(false)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setStyle(NotificationCompat.BigTextStyle().bigText(message))

        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(id, builder.build())
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val fgChannel = NotificationChannel(
                CHANNEL_ID_FOREGROUND,
                "Library Sync Service",
                NotificationManager.IMPORTANCE_MIN
            )
            fgChannel.description = "Notice sync background service"

            val notifChannel = NotificationChannel(
                CHANNEL_ID_NOTIFS,
                "Library Notice Alerts",
                NotificationManager.IMPORTANCE_HIGH
            )
            notifChannel.description = "Important announcements from library admin"
            notifChannel.enableVibration(true)
            notifChannel.enableLights(true)

            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(fgChannel)
            manager.createNotificationChannel(notifChannel)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        handler.removeCallbacksAndMessages(null)
        executor.shutdown()
        isRunning = false
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
