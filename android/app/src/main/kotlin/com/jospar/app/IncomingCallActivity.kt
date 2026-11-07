package com.jospar.app

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.view.WindowManager
import android.widget.*

/** Lock-screen surface launched by the OS full-screen notification, when allowed. */
class IncomingCallActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val room = intent.getStringExtra("id")
        if (room == null || room != IncomingCallBridge.id) { finish(); return }
        if (Build.VERSION.SDK_INT >= 27) { setShowWhenLocked(true); setTurnScreenOn(true) }
        else window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        window.statusBarColor = Color.rgb(23,23,34)
        window.navigationBarColor = Color.rgb(23,23,34)
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL; gravity = Gravity.CENTER
            setPadding(dp(28),dp(40),dp(28),dp(36)); setBackgroundColor(Color.rgb(23,23,34))
        }
        fun label(value: String, size: Float, color: Int) = TextView(this).apply {
            text = value; textSize = size; setTextColor(color); gravity = Gravity.CENTER
            setPadding(0,dp(10),0,dp(10))
        }
        root.addView(label("JOSPAR",14f,Color.LTGRAY))
        root.addView(Space(this),LinearLayout.LayoutParams(1,0,1f))
        root.addView(label(IncomingCallBridge.name,28f,Color.WHITE).apply { setTypeface(typeface,Typeface.BOLD) })
        root.addView(label(if (IncomingCallBridge.video) "Входящий видеозвонок" else "Входящий аудиозвонок",16f,Color.LTGRAY))
        root.addView(Space(this),LinearLayout.LayoutParams(1,0,1f))
        val actions = LinearLayout(this).apply { gravity = Gravity.CENTER }
        fun button(value: String, color: Int, action: () -> Unit) = Button(this).apply {
            text = value; isAllCaps = false; textSize = 16f; setTextColor(Color.WHITE)
            background = GradientDrawable().apply { setColor(color); cornerRadius = dp(28).toFloat() }
            setOnClickListener { action() }
        }
        val params = LinearLayout.LayoutParams(0,dp(58),1f).apply { setMargins(dp(6),0,dp(6),0) }
        actions.addView(button("Отклонить", Color.rgb(192,45,45)) { IncomingCallBridge.handleDecline(this,room); finish() },params)
        actions.addView(button("Ответить", Color.rgb(32,142,82)) {
            startActivity(Intent(this,MainActivity::class.java).setAction(IncomingCallBridge.ANSWER).putExtra("id",room)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP))
            finish()
        },params)
        root.addView(actions,LinearLayout.LayoutParams(-1,dp(64)))
        setContentView(root)
        IncomingCallBridge.observeScreen { runOnUiThread { finish() } }
    }
    override fun onDestroy() { IncomingCallBridge.observeScreen(null); super.onDestroy() }
    private fun dp(value: Int) = (value*resources.displayMetrics.density).toInt()
}
