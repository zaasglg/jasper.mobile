package com.jospar.app

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

object CallNativeBridge {
    var channel: MethodChannel? = null
    var pendingOpen = false
    var serviceResult: MethodChannel.Result? = null
}
class MainActivity : FlutterActivity() {
    private val engineKey = "jospar_call_engine"
    private var notificationPermissionResult: MethodChannel.Result? = null
    override fun provideFlutterEngine(context: Context): FlutterEngine? = FlutterEngineCache.getInstance().get(engineKey)
    override fun shouldDestroyEngineWithHost(): Boolean = !CallForegroundService.running
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        FlutterEngineCache.getInstance().put(engineKey, flutterEngine)
        IncomingCallBridge.attach(this, flutterEngine.dartExecutor.binaryMessenger)
        PushNotifications.attach(this, flutterEngine.dartExecutor.binaryMessenger)
        val app = applicationContext
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "jospar/call_lifecycle")
        CallNativeBridge.channel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "requestNotifications" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                        checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                        if (notificationPermissionResult != null) {
                            result.error("permission_request_pending", "Запрос разрешения уже открыт", null)
                        } else {
                            notificationPermissionResult = result
                            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 7182)
                        }
                    } else { result.success(true) }
                }
                "start" -> {
                    val camera = call.argument<Boolean>("camera") == true
                    if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED ||
                        (camera && checkSelfPermission(Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED)) {
                        result.error("permission_denied", "Разрешите микрофон и камеру", null)
                    } else {
                        try {
                            if (CallNativeBridge.serviceResult != null) {
                                result.error("service_start_pending", "Запуск сервиса уже выполняется", null)
                                return@setMethodCallHandler
                            }
                            CallNativeBridge.serviceResult = result
                            val service = Intent(app, CallForegroundService::class.java)
                                .putExtra("camera", camera)
                                .putExtra("screenShare", call.argument<Boolean>("screenShare") == true)
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) app.startForegroundService(service) else app.startService(service)
                        } catch (error: Exception) {
                            CallNativeBridge.serviceResult = null
                            result.error("call_service_unavailable", "Не удалось включить фоновый режим звонка", null)
                        }
                    }
                }
                "stop" -> { app.stopService(Intent(app, CallForegroundService::class.java)); result.success(null) }
                "consumePendingOpen" -> { result.success(CallNativeBridge.pendingOpen); CallNativeBridge.pendingOpen = false }
                else -> result.notImplemented()
            }
        }
        if (intent?.action == IncomingCallBridge.ANSWER) { IncomingCallBridge.handleAnswer(this, intent.getStringExtra("id")); intent.action = null }
        if (intent?.action == CallForegroundService.ACTION_OPEN) CallNativeBridge.pendingOpen = true
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 7182) {
            notificationPermissionResult?.success(grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED)
            notificationPermissionResult = null
        }
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        PushNotifications.handleIntent(intent)
        if (intent.action == IncomingCallBridge.ANSWER) { IncomingCallBridge.handleAnswer(this, intent.getStringExtra("id")); intent.action = null }
        if (intent.action == CallForegroundService.ACTION_OPEN) {
            CallNativeBridge.pendingOpen = true
            CallNativeBridge.channel?.invokeMethod("openCall", null)
        }
    }
    override fun onDestroy() {
        notificationPermissionResult?.success(false)
        notificationPermissionResult = null
        if (!CallForegroundService.running) {
            CallNativeBridge.channel = null
            FlutterEngineCache.getInstance().remove(engineKey)
        }
        super.onDestroy()
    }
}
