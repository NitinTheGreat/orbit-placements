package com.nitin.orbit

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class OrbitWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val nameIds = intArrayOf(R.id.orbit_name_0, R.id.orbit_name_1)
        val lineIds = intArrayOf(R.id.orbit_line_0, R.id.orbit_line_1)
        val rowIds = intArrayOf(R.id.orbit_row_0, R.id.orbit_row_1)

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.orbit_widget).apply {
                setOnClickPendingIntent(
                    R.id.orbit_widget_root,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
                )

                setTextViewText(
                    R.id.orbit_headline,
                    widgetData.getString("headline", null) ?: "Orbit",
                )

                var shown = 0
                for (slot in nameIds.indices) {
                    val name = widgetData.getString("name$slot", null)
                    if (name.isNullOrBlank()) {
                        setViewVisibility(rowIds[slot], View.GONE)
                        continue
                    }
                    shown += 1
                    setViewVisibility(rowIds[slot], View.VISIBLE)
                    setTextViewText(nameIds[slot], name)
                    setTextViewText(
                        lineIds[slot],
                        widgetData.getString("line$slot", null) ?: "",
                    )
                }

                setViewVisibility(
                    R.id.orbit_empty,
                    if (shown == 0) View.VISIBLE else View.GONE,
                )
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
