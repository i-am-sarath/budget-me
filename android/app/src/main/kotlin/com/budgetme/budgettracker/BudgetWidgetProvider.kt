package com.budgetme.budgettracker

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home-screen quick-add widget. A single tap launches the app straight into
 * voice recording via the `budgetme://voice` deep link, handled in main.dart.
 *
 * Optionally shows today's spend if the Flutter side has written a
 * "today_total" value through the home_widget plugin.
 */
class BudgetWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.budget_widget).apply {
                val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("budgetme://voice")
                )
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)

                val todayTotal = widgetData.getString("today_total", null)
                if (!todayTotal.isNullOrEmpty()) {
                    setTextViewText(R.id.widget_amount, todayTotal)
                }
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
