package com.jospar.app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent

class AssistantWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.assistant_widget)
            views.setOnClickPendingIntent(R.id.assistant_widget_root,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java,
                    Uri.parse("jospar://assistant?homeWidget&keyboard=true")))
            manager.updateAppWidget(id, views)
        }
    }
}
