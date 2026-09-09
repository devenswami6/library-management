package com.example.flutter_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.location.Location
import android.location.LocationManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

class LibraryNotificationService : Service() {

    private val handler = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()
    private val shownNotifIds = mutableSetOf<Int>()
    private var isRunning = false
    private var lastAutoCheckoutTime: Long = 0

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
            .setContentText("Active Attendance & Geofence Guard")
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
                checkNotificationsAndGeofenceInBackground()
                handler.postDelayed(this, 8000) // Check every 8 seconds
            }
        })
    }

    private fun checkNotificationsAndGeofenceInBackground() {
        executor.execute {
            try {
                loadShownIdsFromPrefs()
                val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val userId = prefs.getInt(KEY_USER_ID, 0)
                val baseUrl = prefs.getString(KEY_BASE_URL, "https://library-management-hmwx.onrender.com") ?: "https://library-management-hmwx.onrender.com"

                if (userId <= 0) return@execute

                val urlString = "$baseUrl/api/json_student_actions.php?action=get_dashboard&user_id=$userId"
                val url = URL(urlString)
                val connection = url.openConnection() as HttpURLConnection
                connection.requestMethod = "GET"
                connection.connectTimeout = 4000
                connection.readTimeout = 4000

                if (connection.responseCode == 200) {
                    val responseText = connection.inputStream.bufferedReader().use { it.readText() }
                    val json = JSONObject(responseText)
                    if (json.optBoolean("success")) {
                        // 1. Process Announcements / Admin Notices
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

                        // 2. Check Background Geofence & Anti-Cheat GPS OFF
                        val todayAtt = json.optJSONObject("today_attendance")
                        val checkInTime = todayAtt?.optString("check_in_time") ?: ""
                        val checkOutTime = todayAtt?.optString("check_out_time") ?: ""
                        val isCheckedIn = checkInTime.isNotBlank() && (checkOutTime.isBlank() || checkOutTime == "null")

                        if (isCheckedIn && (System.currentTimeMillis() - lastAutoCheckoutTime > 30000)) {
                            checkBackgroundGeofenceStatus(baseUrl, userId)
                        }
                    }
                }
                connection.disconnect()
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    private fun checkBackgroundGeofenceStatus(baseUrl: String, userId: Int) {
        val locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val isGpsEnabled = locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
                           locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)

        if (!isGpsEnabled) {
            // Anti-Cheat: GPS is OFF while student is checked in!
            lastAutoCheckoutTime = System.currentTimeMillis()
            performAutoCheckout(baseUrl, userId, "GPS Location was turned OFF on your phone while checked-in.")
            return
        }

        // Fetch location and check 50m radius
        val location = getLastKnownLocation(locationManager)
        if (location != null) {
            val targetLat = 28.0087395
            val targetLng = 73.2924508
            val results = FloatArray(1)
            Location.distanceBetween(location.latitude, location.longitude, targetLat, targetLng, results)
            val distanceMeters = results[0]

            if (distanceMeters > 50.0f) {
                lastAutoCheckoutTime = System.currentTimeMillis()
                val distStr = if (distanceMeters > 1000) String.format("%.2f km", distanceMeters / 1000) else String.format("%.1f meters", distanceMeters)
                performAutoCheckout(baseUrl, userId, "You moved $distStr away from Keshav Library (50m limit).")
            }
        }
    }

    private fun getLastKnownLocation(locationManager: LocationManager): Location? {
        try {
            if (ContextCompat.checkSelfPermission(this, android.Manifest.permission.ACCESS_FINE_LOCATION) == android.content.pm.PackageManager.PERMISSION_GRANTED ||
                ContextCompat.checkSelfPermission(this, android.Manifest.permission.ACCESS_COARSE_LOCATION) == android.content.pm.PackageManager.PERMISSION_GRANTED) {

                val gpsLoc = locationManager.getLastKnownLocation(LocationManager.GPS_PROVIDER)
                val netLoc = locationManager.getLastKnownLocation(LocationManager.NETWORK_PROVIDER)

                if (gpsLoc != null && netLoc != null) {
                    return if (gpsLoc.time > netLoc.time) gpsLoc else netLoc
                }
                return gpsLoc ?: netLoc
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return null
    }

    private fun performAutoCheckout(baseUrl: String, userId: Int, reasonMessage: String) {
        try {
            val timeStr = java.text.SimpleDateFormat("HH:mm:ss", java.util.Locale.getDefault()).format(java.util.Date())
            val checkOutUrl = URL("$baseUrl/api/json_student_actions.php")
            val conn = checkOutUrl.openConnection() as HttpURLConnection
            conn.requestMethod = "POST"
            conn.doOutput = true
            conn.connectTimeout = 4000
            conn.readTimeout = 4000

            val postData = "action=checkout&user_id=$userId&device_time=$timeStr&auto_checkout=1"
            conn.outputStream.write(postData.toByteArray(Charsets.UTF_8))
            val code = conn.responseCode
            conn.disconnect()

            showHeadsUpNotification(9876, "Auto Checked-Out 🚪", reasonMessage)
        } catch (e: Exception) {
            e.printStackTrace()
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
