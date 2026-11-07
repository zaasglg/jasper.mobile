package com.jospar.app

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager

class CallForegroundService : Service() {
    companion object {
        const val CHANNEL_ID = "jospar_active_call"
        const val NOTIFICATION_ID = 7182
        const val ACTION_OPEN = "com.jospar.app.OPEN_CALL"
        const val ACTION_END = "com.jospar.app.END_CALL"
        @Volatile var running = false
            private set
    }
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onCreate() {
        super.onCreate()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            getSystemService(NotificationManager::class.java).createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Текущий звонок", NotificationManager.IMPORTANCE_LOW).apply {
                    description = "Управление текущим звонком Jospar"
                    setSound(null, null)
                }
            )
        }
    }
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_END) {
            CallNativeBridge.channel?.invokeMethod("hangUp", null)
            if (CallNativeBridge.channel == null) stopSelf()
            return START_NOT_STICKY
        }
        val camera = intent?.getBooleanExtra("camera", false) == true
        val screenShare = intent?.getBooleanExtra("screenShare", false) == true
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED ||
            (camera && checkSelfPermission(Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED)) {
            CallNativeBridge.serviceResult?.error("permission_denied", "Разрешите микрофон и камеру", null)
            CallNativeBridge.serviceResult = null
            stopSelf()
            return START_NOT_STICKY
        }
        val open = PendingIntent.getActivity(this, 0,
            Intent(this, MainActivity::class.java).setAction(ACTION_OPEN).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val end = PendingIntent.getService(this, 1,
            Intent(this, CallForegroundService::class.java).setAction(ACTION_END),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) Notification.Builder(this, CHANNEL_ID) else Notification.Builder(this)
        val notification = builder
            .setSmallIcon(android.R.drawable.sym_action_call)
            .setContentTitle(if (screenShare) "Демонстрация экрана Jospar" else if (camera) "Видеозвонок Jospar" else "Звонок Jospar")
            .setContentText("Нажмите, чтобы вернуться к разговору")
            .setContentIntent(open).setOngoing(true).setCategory(Notification.CATEGORY_CALL)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .addAction(Notification.Action.Builder(android.R.drawable.ic_menu_close_clear_cancel, "Завершить", end).build())
            .build()
        try {
          if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val types = ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE or
                (if (camera) ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA else 0) or
                (if (screenShare) ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION else 0)
            startForeground(NOTIFICATION_ID, notification, types)
          } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && screenShare) {
              startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
          } else { startForeground(NOTIFICATION_ID, notification) }
        } catch (error: SecurityException) {
            CallNativeBridge.serviceResult?.error("service_start_failed", "Не удалось включить трансляцию", null)
            CallNativeBridge.serviceResult = null
            CallNativeBridge.channel?.invokeMethod("serviceUnavailable", null)
            stopSelf()
            return START_NOT_STICKY
        }
        running = true
        CallNativeBridge.serviceResult?.success(null)
        CallNativeBridge.serviceResult = null
        if (wakeLock == null) {
            wakeLock = (getSystemService(POWER_SERVICE) as PowerManager).newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK, "jospar:active-call").apply { acquire(2 * 60 * 60 * 1000L) }
        }
        return START_NOT_STICKY
    }
    override fun onDestroy() {
        running = false
        CallNativeBridge.serviceResult?.error("service_stopped", "Сервис звонка остановлен", null)
        CallNativeBridge.serviceResult = null
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }
    override fun onBind(intent: Intent?): IBinder? = null
}
