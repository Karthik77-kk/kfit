package com.example.karthik_fitness

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class KFitnessWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (widgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, widgetId)
        }
    }

    companion object {
        fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, widgetId: Int) {
            val prefs = HomeWidgetPlugin.getData(context)

            val calories    = prefs.getInt("calories", 0)
            val calorieGoal = prefs.getInt("calorieGoal", 1700)
            val protein     = prefs.getInt("protein", 0)
            val proteinGoal = prefs.getInt("proteinGoal", 100)
            val water       = prefs.getInt("water", 0)
            val waterGoal   = prefs.getInt("waterGoal", 2500)

            val calPct  = ((calories.toFloat()  / calorieGoal.coerceAtLeast(1)  * 100).toInt()).coerceIn(0, 100)
            val protPct = ((protein.toFloat()   / proteinGoal.coerceAtLeast(1)  * 100).toInt()).coerceIn(0, 100)
            val watPct  = ((water.toFloat()     / waterGoal.coerceAtLeast(1)    * 100).toInt()).coerceIn(0, 100)

            val views = RemoteViews(context.packageName, R.layout.kfitness_widget)

            views.setProgressBar(R.id.ring_calories, 100, calPct, false)
            views.setProgressBar(R.id.ring_protein,  100, protPct, false)
            views.setProgressBar(R.id.ring_water,    100, watPct, false)

            views.setTextViewText(R.id.label_calories, "$calories kcal")
            views.setTextViewText(R.id.label_protein,  "${protein}g")
            views.setTextViewText(R.id.label_water,    "$water ml")

            // Tap widget → open app
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pi = PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_title, pi)

            appWidgetManager.updateAppWidget(widgetId, views)
        }

        fun triggerUpdate(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, KFitnessWidgetProvider::class.java)
            )
            if (ids.isNotEmpty()) {
                val provider = KFitnessWidgetProvider()
                provider.onUpdate(context, manager, ids)
            }
        }
    }
}
