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
        window.statusBarColor = Color.rgb(32,44,51)
        window.navigationBarColor = Color.rgb(32,44,51)
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL; gravity = Gravity.CENTER
            setPadding(dp(28),dp(40),dp(28),dp(36)); setBackgroundColor(Color.rgb(32,44,51))
        }
        fun label(value: String, size: Float, color: Int) = TextView(this).apply {
            text = value; textSize = size; setTextColor(color); gravity = Gravity.CENTER
            setPadding(0,dp(10),0,dp(10))
        }
        root.addView(label("ЗВОНОК JOSPAR",14f,Color.WHITE))
        root.addView(Space(this),LinearLayout.LayoutParams(1,0,1f))
        root.addView(label(IncomingCallBridge.name,28f,Color.WHITE).apply { setTypeface(typeface,Typeface.BOLD) })
        root.addView(label(if (IncomingCallBridge.video) "Входящий видеозвонок" else "Входящий аудиозвонок",16f,Color.LTGRAY))
        root.addView(Space(this),LinearLayout.LayoutParams(1,0,1f))
        val initials = IncomingCallBridge.name.trim().split(Regex("\\s+"))
            .filter { it.isNotEmpty() }.take(2).joinToString("") { it.take(1).uppercase() }
        root.addView(label(initials,52f,Color.WHITE).apply {
            background = GradientDrawable().apply { shape = GradientDrawable.OVAL; setColor(Color.rgb(109,95,224)) }
        }, LinearLayout.LayoutParams(dp(160),dp(160)).apply { gravity = Gravity.CENTER_HORIZONTAL })
        root.addView(Space(this),LinearLayout.LayoutParams(1,0,1f))
        val actions = LinearLayout(this).apply { gravity = Gravity.CENTER }
        fun button(value: String, color: Int, decline: Boolean = false, action: () -> Unit) = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL; gravity = Gravity.CENTER
            addView(ImageButton(this@IncomingCallActivity).apply {
                contentDescription = value
                setImageResource(android.R.drawable.sym_action_call)
                imageTintList = android.content.res.ColorStateList.valueOf(Color.WHITE)
                if (decline) rotation = 135f
                background = GradientDrawable().apply { shape = GradientDrawable.OVAL; setColor(color) }
                setPadding(dp(20),dp(20),dp(20),dp(20))
                setOnClickListener { action() }
            },LinearLayout.LayoutParams(dp(72),dp(72)))
            addView(label(value,14f,Color.WHITE))
        }
        val params = LinearLayout.LayoutParams(0,-2,1f).apply { setMargins(dp(6),0,dp(6),0) }
        actions.addView(button("Отклонить", Color.rgb(255,59,48), true) { IncomingCallBridge.handleDecline(this,room); finish() },params)
        actions.addView(button("Принять", Color.rgb(37,211,102)) {
            startActivity(Intent(this,MainActivity::class.java).setAction(IncomingCallBridge.ANSWER).putExtra("id",room)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP))
            finish()
        },params)
        root.addView(actions,LinearLayout.LayoutParams(-1,-2))
        setContentView(root)
        IncomingCallBridge.observeScreen { runOnUiThread { finish() } }
    }
    override fun onDestroy() { IncomingCallBridge.observeScreen(null); super.onDestroy() }
    private fun dp(value: Int) = (value*resources.displayMetrics.density).toInt()
}
