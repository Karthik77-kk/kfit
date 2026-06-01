package com.example.karthik_fitness

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * Home-screen widget that draws three concentric activity rings (calories / protein
 * / water) natively to a Bitmap and shows the smartest insight underneath.
 *
 * Everything is plain RemoteViews + a Canvas-drawn Bitmap — no Flutter engine, no
 * renderFlutterWidget, no file URIs — so it can never crash the app or the launcher
 * and it renders correctly even when the app is closed.
 */
class KFitnessWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) updateWidget(context, appWidgetManager, id)
    }

    companion object {
        private const val RED = 0xFFFF453A.toInt()
        private const val GREEN = 0xFF30D158.toInt()
        private const val CYAN = 0xFF40C8E0.toInt()

        fun updateWidget(context: Context, manager: AppWidgetManager, widgetId: Int) {
            val views = RemoteViews(context.packageName, R.layout.kfitness_widget)
            val prefs = HomeWidgetPlugin.getData(context)

            val cal = prefs.getInt("calories", 0)
            val calGoal = prefs.getInt("calorieGoal", 1700)
            val prot = prefs.getInt("protein", 0)
            val protGoal = prefs.getInt("proteinGoal", 100)
            val water = prefs.getInt("water", 0)
            val waterGoal = prefs.getInt("waterGoal", 2500)

            // Raw unclamped ratios — can be >1f so drawRings can show overflow laps.
            val calPct = prefs.getInt("calPct", 0).coerceAtLeast(0) / 100f
            val protPct = prefs.getInt("protPct", 0).coerceAtLeast(0) / 100f
            val waterPct = prefs.getInt("waterPct", 0).coerceAtLeast(0) / 100f

            val emoji = prefs.getString("insightEmoji", "") ?: ""
            val title = prefs.getString("insightTitle", "Open K Fitness") ?: "Open K Fitness"

            // Draw the rings bitmap.
            views.setImageViewBitmap(R.id.widget_rings, drawRings(context, calPct, protPct, waterPct))

            views.setTextViewText(R.id.widget_cal, "Calories  $cal/$calGoal  ${(calPct * 100).toInt()}%")
            views.setTextViewText(R.id.widget_prot, "Protein  ${prot}/${protGoal}g  ${(protPct * 100).toInt()}%")
            views.setTextViewText(R.id.widget_water, "Water  $water/$waterGoal  ${(waterPct * 100).toInt()}%")
            views.setTextViewText(R.id.widget_insight, if (emoji.isEmpty()) title else "$emoji  $title")

            // Tap → open the app.
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pi = PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pi)

            manager.updateAppWidget(widgetId, views)
        }

        private fun blendWithWhite(color: Int, fraction: Float): Int {
            val r = (Color.red(color)   * (1 - fraction) + 255 * fraction).toInt().coerceIn(0, 255)
            val g = (Color.green(color) * (1 - fraction) + 255 * fraction).toInt().coerceIn(0, 255)
            val b = (Color.blue(color)  * (1 - fraction) + 255 * fraction).toInt().coerceIn(0, 255)
            return Color.argb(255, r, g, b)
        }

        private fun drawRings(context: Context, calPct: Float, protPct: Float, waterPct: Float): Bitmap {
            val density = context.resources.displayMetrics.density
            val size = (84 * density).toInt().coerceAtLeast(120)
            val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)

            val stroke = size * 0.10f
            val gap = size * 0.135f
            val cx = size / 2f
            val cy = size / 2f

            val rings = listOf(Triple(RED, calPct, 0), Triple(GREEN, protPct, 1), Triple(CYAN, waterPct, 2))
            val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.STROKE
                strokeWidth = stroke
            }
            for ((color, pct, i) in rings) {
                val r = size / 2f - stroke / 2f - i * gap
                if (r <= 0) continue
                val rect = RectF(cx - r, cy - r, cx + r, cy + r)

                // Background track
                paint.color = (color and 0x00FFFFFF) or 0x30000000
                paint.strokeCap = Paint.Cap.ROUND
                canvas.drawArc(rect, 0f, 360f, false, paint)

                if (pct <= 0f) continue

                if (pct <= 1f) {
                    // Normal fill with round caps
                    paint.color = color
                    paint.strokeCap = Paint.Cap.ROUND
                    canvas.drawArc(rect, -90f, 360f * pct, false, paint)
                } else {
                    // Over goal: full ring with flat join so the overflow arc sits cleanly on top
                    paint.color = color
                    paint.strokeCap = Paint.Cap.BUTT
                    canvas.drawArc(rect, -90f, 360f, false, paint)
                    // Overflow lap in a lighter shade — same Apple Watch lapping effect
                    val overflowSweep = 360f * (pct - 1f).coerceIn(0f, 1f)
                    paint.color = blendWithWhite(color, 0.45f)
                    paint.strokeCap = Paint.Cap.ROUND
                    canvas.drawArc(rect, -90f, overflowSweep, false, paint)
                }
            }
            return bitmap
        }

        fun triggerUpdate(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, KFitnessWidgetProvider::class.java))
            if (ids.isNotEmpty()) KFitnessWidgetProvider().onUpdate(context, manager, ids)
        }
    }
}
