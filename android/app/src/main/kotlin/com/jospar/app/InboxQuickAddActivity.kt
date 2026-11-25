package com.jospar.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode

/** Isolated capture window; finishing it reveals the launcher underneath. */
class InboxQuickAddActivity : FlutterActivity() {
    override fun getDartEntrypointFunctionName(): String = "inboxWidgetMain"
    override fun getBackgroundMode(): BackgroundMode = BackgroundMode.transparent
}
