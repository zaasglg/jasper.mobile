package com.jospar.app

import android.Manifest
import android.app.*
import android.content.*
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.*
import io.flutter.plugin.common.MethodChannel

/** Presentation only: authenticated Flutter polling supplies incoming rooms. */
object IncomingCallBridge {
    const val CHANNEL = "jospar_incoming_call"
    const val NOTIFICATION = 7183
    const val ANSWER = "com.jospar.app.ANSWER_CALL"
    const val DECLINE = "com.jospar.app.DECLINE_CALL"
    private var channel: MethodChannel? = null
    var id: String? = null
        private set
    var name = "Jospar"
        private set
    var video = false
        private set
    private val handler = Handler(Looper.getMainLooper())
    private var timeout: Runnable? = null
    private var closeScreen: (() -> Unit)? = null

    fun attach(activity: MainActivity, messenger: io.flutter.plugin.common.BinaryMessenger) {
        val bridge = MethodChannel(messenger, "jospar/incoming_call")
        channel = bridge
        bridge.setMethodCallHandler { call, result ->
            val room = call.argument<String>("id") ?: ""
            when (call.method) {
                "show" -> {
                    try { result.success(show(activity, room, call.argument<String>("name") ?: "Jospar", call.argument<Boolean>("video") == true)) }
                    catch (_: Exception) { clear(activity); result.success(false) }
                }
                "end", "connected" -> { if (room == id) clear(activity); result.success(null) }
                "answer" -> {
                    if (room == id) {
                        emit("answer", room)
                        clear(activity)
                        result.success(null)
                    } else { result.error("call_gone", "Звонок завершён", null) }
                }
                "mute" -> result.success(null) // Android controls use the app's active-call screen.
                else -> result.notImplemented()
            }
        }
    }
    private fun show(context: Context, room: String, caller: String, isVideo: Boolean): Boolean {
        if (room.isEmpty()) return false
        if (room == id) return true
        if (id != null) return false
        val manager = context.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 24 && !manager.areNotificationsEnabled()) return false
        if (Build.VERSION.SDK_INT >= 33 && context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return false
        val ringtone = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
        if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(NotificationChannel(CHANNEL, "Входящие звонки", NotificationManager.IMPORTANCE_HIGH).apply {
            description = "Аудио- и видеозвонки Jospar"
            enableVibration(true)
            setSound(ringtone, AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE).build())
            lockscreenVisibility = Notification.VISIBILITY_PRIVATE
        })
        if (Build.VERSION.SDK_INT >= 26 && manager.getNotificationChannel(CHANNEL)?.importance == NotificationManager.IMPORTANCE_NONE) return false
        id = room; name = caller; video = isVideo
        val screen = PendingIntent.getActivity(context, 7183,
            Intent(context, IncomingCallActivity::class.java).putExtra("id", room)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        // Answer opens the app directly (no notification trampoline on Android 12+).
        val answer = PendingIntent.getActivity(context, 7184,
            Intent(context, MainActivity::class.java).setAction(ANSWER).putExtra("id", room)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val decline = PendingIntent.getBroadcast(context, 7185,
            Intent(context, IncomingCallReceiver::class.java).setAction(DECLINE).putExtra("id", room),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = (if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, CHANNEL) else Notification.Builder(context))
            .setSmallIcon(android.R.drawable.sym_action_call).setContentTitle(caller)
            .setContentText(if (isVideo) "Входящий видеозвонок" else "Входящий аудиозвонок")
            .setCategory(Notification.CATEGORY_CALL).setVisibility(Notification.VISIBILITY_PRIVATE)
            .setOngoing(true).setAutoCancel(false).setContentIntent(screen)
        if (Build.VERSION.SDK_INT >= 26) builder.setTimeoutAfter(45000)
        if (Build.VERSION.SDK_INT < 26) builder.setPriority(Notification.PRIORITY_MAX).setSound(ringtone).setVibrate(longArrayOf(0,500,500,500))
        if (Build.VERSION.SDK_INT >= 31) {
            builder.setStyle(Notification.CallStyle.forIncomingCall(
                Person.Builder().setName(caller).setImportant(true).build(), decline, answer).setIsVideo(isVideo))
        } else {
            builder.addAction(Notification.Action.Builder(android.R.drawable.ic_menu_close_clear_cancel, "Отклонить", decline).build())
            builder.addAction(Notification.Action.Builder(android.R.drawable.sym_action_call, "Ответить", answer).build())
        }
        if (Build.VERSION.SDK_INT < 34 || manager.canUseFullScreenIntent()) builder.setFullScreenIntent(screen, true)
        manager.notify(NOTIFICATION, builder.build())
        timeout = Runnable { if (id == room) { emit("timeout", room); clear(context) } }.also { handler.postDelayed(it, 45000) }
        return true
    }
    fun handleAnswer(context: Context, room: String?) {
        if (room != null && room == id) { emit("answer", room); clear(context) }
    }
    fun handleDecline(context: Context, room: String?) {
        if (room != null && room == id) { emit("decline", room); clear(context) }
    }
    private fun emit(action: String, room: String) { channel?.invokeMethod(action, mapOf("id" to room)) }
    fun observeScreen(close: (() -> Unit)?) { closeScreen = close }
    fun clear(context: Context) {
        timeout?.let { handler.removeCallbacks(it) }; timeout = null
        id = null
        context.getSystemService(NotificationManager::class.java).cancel(NOTIFICATION)
        closeScreen?.invoke(); closeScreen = null
    }
}

class IncomingCallReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == IncomingCallBridge.DECLINE) IncomingCallBridge.handleDecline(context, intent.getStringExtra("id"))
    }
}
