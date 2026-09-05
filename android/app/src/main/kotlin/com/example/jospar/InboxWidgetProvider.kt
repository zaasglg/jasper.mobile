package com.example.jospar

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class InboxWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val count = widgetData.getInt("inbox_count", 0)
        val tasks = (1..3).map {
            widgetData.getString("inbox_task_$it", "").orEmpty()
        }

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.inbox_widget).apply {
                setTextViewText(R.id.inbox_widget_count, count.toString())
                bindTask(R.id.inbox_widget_task_1, tasks[0])
                bindTask(R.id.inbox_widget_task_2, tasks[1])
                bindTask(R.id.inbox_widget_task_3, tasks[2])

                val isEmpty = tasks.all(String::isEmpty)
                setViewVisibility(
                    R.id.inbox_widget_empty,
                    if (isEmpty) View.VISIBLE else View.GONE,
                )
                val openInbox = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("jospar://inbox?homeWidget"),
                )
                setOnClickPendingIntent(R.id.inbox_widget_root, openInbox)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun RemoteViews.bindTask(viewId: Int, title: String) {
        setTextViewText(viewId, if (title.isEmpty()) "" else "○  $title")
        setViewVisibility(viewId, if (title.isEmpty()) View.GONE else View.VISIBLE)
    }
}
