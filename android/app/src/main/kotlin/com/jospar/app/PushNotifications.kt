package com.jospar.app

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import com.google.firebase.messaging.FirebaseMessaging
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

/** FCM notification/data reception does not require a running Flutter engine. */
class JosparMessagingService : FirebaseMessagingService() {
    override fun onNewToken(token: String) {
        PushNotifications.emit("tokenChanged", token)
    }
    override fun onMessageReceived(message: RemoteMessage) {
        val recipient = message.data["recipientId"]
        if (recipient != null && recipient != getSharedPreferences("jospar_push", Context.MODE_PRIVATE).getString("userId", null)) return
        val data = message.data.toMutableMap()
        data["messageId"] = message.messageId ?: data["messageId"] ?: java.util.UUID.randomUUID().toString()
        val title = message.notification?.title ?: data["title"] ?: "Jospar"
        val body = message.notification?.body ?: data["body"] ?: ""
        PushNotifications.emit("message", data)
        PushNotifications.show(this, title, body, data)
    }
}

object PushNotifications {
    const val CHANNEL = "jospar_messages"
    private const val EXTRA = "jospar_push_data"
    private var bridge: MethodChannel? = null
    private var pending: Map<String, String>? = null
    private val handler = Handler(Looper.getMainLooper())

    fun emit(method: String, value: Any?) {
        handler.post { bridge?.invokeMethod(method, value) }
    }
    fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= 26) {
            context.getSystemService(NotificationManager::class.java).createNotificationChannel(
                NotificationChannel(CHANNEL, "Сообщения и упоминания", NotificationManager.IMPORTANCE_HIGH).apply {
                    description = "Уведомления Jospar о сообщениях, задачах и упоминаниях"
                    enableVibration(true)
                }
            )
        }
    }
    fun attach(activity: MainActivity, messenger: BinaryMessenger) {
        createChannel(activity)
        val channel = MethodChannel(messenger, "jospar/push_notifications")
        bridge = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> {
                    val manager = activity.getSystemService(NotificationManager::class.java)
                    val allowed = manager.areNotificationsEnabled()
                    val enabled = Build.VERSION.SDK_INT < 26 || manager.getNotificationChannel(CHANNEL)?.importance != NotificationManager.IMPORTANCE_NONE
                    result.success(mapOf("authorized" to allowed, "channelEnabled" to enabled))
                }
                "token" -> FirebaseMessaging.getInstance().token.addOnCompleteListener { task ->
                    if (task.isSuccessful) result.success(task.result)
                    else result.error("fcm_token", "Не удалось получить токен Firebase. Проверьте Google Play Services и подключение к интернету.", null)
                }
                "bindAccount" -> {
                    val userId = call.argument<String>("userId")
                    if (userId.isNullOrBlank()) { result.error("invalid_account", "Не выбран аккаунт", null) }
                    else { activity.getSharedPreferences("jospar_push", Context.MODE_PRIVATE).edit().putString("userId", userId).apply(); result.success(null) }
                }
                "setPreferences" -> {
                    val userId = call.argument<String>("userId")
                    val preferences = call.argument<Map<String, Any>>("preferences")
                    if (userId.isNullOrBlank() || preferences == null) result.error("invalid_preferences", "Invalid preferences", null)
                    else {
                        val saved = activity.getSharedPreferences("jospar_push", Context.MODE_PRIVATE).edit()
                            .putString("preferences.$userId", JSONObject(preferences).toString()).commit()
                        if (saved) result.success(mapOf("timeZone" to java.util.TimeZone.getDefault().id)) else result.error("preferences_write", "Preferences not saved", null)
                    }
                }
                "clearAccount" -> { clearAccount(activity); result.success(null) }
                "deleteToken" -> {
                    pending = null
                    val manager = activity.getSystemService(NotificationManager::class.java)
                    if (Build.VERSION.SDK_INT >= 26) manager.activeNotifications.filter { it.notification.channelId == CHANNEL }.forEach { manager.cancel(it.id) }
                    FirebaseMessaging.getInstance().deleteToken().addOnCompleteListener { task ->
                        if (task.isSuccessful) result.success(null) else result.error("fcm_delete", "Не удалось сбросить push-токен.", null)
                    }
                }
                "initialMessage" -> { result.success(pending); pending = null }
                "settings" -> {
                    activity.startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        handleIntent(activity.intent)
    }
    fun handleIntent(intent: Intent?) {
        if (intent == null) return
        val data: Map<String, String> = try {
            val encoded = intent.getStringExtra(EXTRA)
            if (encoded != null) {
                val json = JSONObject(encoded)
                json.keys().asSequence().associateWith { json.optString(it) }
            } else if (intent.hasExtra("google.message_id")) {
                val extras = intent.extras
                val values = extras?.keySet()?.filter { !it.startsWith("google.") && !it.startsWith("gcm.") && it != "collapse_key" }?.mapNotNull { key ->
                    val value = extras.get(key)
                    if (value is String) key to value else null
                }?.toMap().orEmpty()
                values + ("messageId" to (intent.getStringExtra("google.message_id") ?: ""))
            } else return
        } catch (_: Exception) { return }
        pending = data
        emit("opened", data)
        intent.removeExtra(EXTRA)
        intent.removeExtra("google.message_id")
    }
    private fun clearAccount(context: Context) {
        context.getSharedPreferences("jospar_push", Context.MODE_PRIVATE).edit().remove("userId").apply()
        pending = null
        val manager = context.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) manager.activeNotifications.filter { it.notification.channelId == CHANNEL }.forEach { manager.cancel(it.tag, it.id) }
    }
    private fun allows(context: Context, type: String): Boolean {
        if (type == "call") return true
        val store = context.getSharedPreferences("jospar_push", Context.MODE_PRIVATE)
        val owner = store.getString("userId", null) ?: return false
        val raw = store.getString("preferences.$owner", null) ?: return true
        return try {
            val prefs = JSONObject(raw)
            val now = java.util.Calendar.getInstance()
            val minute = now.get(java.util.Calendar.HOUR_OF_DAY) * 60 + now.get(java.util.Calendar.MINUTE)
            val start = prefs.optInt("quietStart", 1320)
            val end = prefs.optInt("quietEnd", 480)
            val quiet = prefs.optBoolean("quietEnabled", false) &&
                (if (start == end) true else if (start < end) minute >= start && minute < end else minute >= start || minute < end)
            !quiet && when (type) {
                "message" -> prefs.optBoolean("messages", true)
                "mention" -> prefs.optBoolean("mentions", true)
                "deadline", "reminder", "planner" -> prefs.optBoolean("deadlines", true)
                else -> true
            }
        } catch (_: Exception) { true }
    }
    fun show(context: Context, title: String, body: String, data: Map<String, String>) {
        if (!allows(context, data["type"] ?: "")) return
        createChannel(context)
        val manager = context.getSystemService(NotificationManager::class.java)
        if (!manager.areNotificationsEnabled()) return
        if (Build.VERSION.SDK_INT >= 33 && context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return
        val id = (data["eventId"] ?: data["messageId"] ?: data.toString()).hashCode()
        val intent = Intent(context, MainActivity::class.java).setAction("com.jospar.app.OPEN_PUSH")
            .putExtra(EXTRA, JSONObject(data).toString()).addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val open = PendingIntent.getActivity(context, id, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, CHANNEL) else Notification.Builder(context)
        manager.notify(id, builder.setSmallIcon(R.drawable.ic_stat_notification).setContentTitle(title.take(200)).setContentText(body.take(2000))
            .setStyle(Notification.BigTextStyle().bigText(body.take(2000))).setContentIntent(open).setAutoCancel(true)
            .setVisibility(Notification.VISIBILITY_PRIVATE).build())
    }
}
