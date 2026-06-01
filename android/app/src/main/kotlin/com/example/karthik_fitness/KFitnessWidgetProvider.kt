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
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Typeface
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import java.util.Calendar

/**
 * Full-canvas home-screen widget. Every pixel is drawn by [drawWidget] onto a
 * single Bitmap so we have complete control over typography, colour, and layout —
 * no RemoteViews tinting limits, no platform ProgressBar colour issues.
 *
 * Layout (drawn at 280 × 120 dp logical, scaled to device density):
 *
 *  ┌─────────────────────────────────────────┐
 *  │  K FITNESS              SUN 01 JUN      │  ← header (green brand + muted date)
 *  ├────────────┬────────────────────────────┤
 *  │            │  ● CALORIES  1,200/1,700   │
 *  │  [RINGS]   │  ████████░░░ 71%           │
 *  │            │  ● PROTEIN    85 / 100 g   │
 *  │            │  ████████████ 85%          │
 *  │            │  ● WATER    1.8 / 2.5 L    │
 *  │            │  ████████░░░ 72%           │
 *  │            │  ● STEPS   4.2k / 8k       │
 *  │            │  ████░░░░░░░ 53%           │
 *  ├────────────┴────────────────────────────┤
 *  │  💡 Protein behind pace — add whey...   │  ← insight strip (darker bg)
 *  └─────────────────────────────────────────┘
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
        private val RED    = Color.parseColor("#FF453A")
        private val GREEN  = Color.parseColor("#30D158")
        private val CYAN   = Color.parseColor("#40C8E0")
        private val ORANGE = Color.parseColor("#FF9F0A")
        private val BG     = Color.parseColor("#1C1C1E")
        private val STRIP  = Color.parseColor("#141416")
        private val MUTED  = Color.parseColor("#8E8E93")
        private val WHITE  = Color.WHITE

        fun updateWidget(context: Context, manager: AppWidgetManager, widgetId: Int) {
            val views = RemoteViews(context.packageName, R.layout.kfitness_widget)
            val prefs = HomeWidgetPlugin.getData(context)

            val cal      = prefs.getInt("calories",    0)
            val calGoal  = prefs.getInt("calorieGoal", 1700)
            val prot     = prefs.getInt("protein",     0)
            val protGoal = prefs.getInt("proteinGoal", 100)
            val water    = prefs.getInt("water",       0)
            val waterGoal= prefs.getInt("waterGoal",   2500)
            val steps    = prefs.getInt("steps",       0)
            val stepGoal = prefs.getInt("stepGoal",    8000)

            val calPct   = prefs.getInt("calPct",  0).coerceAtLeast(0) / 100f
            val protPct  = prefs.getInt("protPct", 0).coerceAtLeast(0) / 100f
            val waterPct = prefs.getInt("waterPct",0).coerceAtLeast(0) / 100f
            val stepPct  = prefs.getInt("stepPct", 0).coerceAtLeast(0) / 100f

            val emoji  = prefs.getString("insightEmoji", "💡") ?: "💡"
            val title  = prefs.getString("insightTitle", "Open K Fitness") ?: "Open K Fitness"
            val insight = if (emoji.isBlank()) title else "$emoji  $title"

            views.setImageViewBitmap(
                R.id.widget_canvas,
                drawWidget(
                    context,
                    cal, calGoal, calPct,
                    prot, protGoal, protPct,
                    water, waterGoal, waterPct,
                    steps, stepGoal, stepPct,
                    insight
                )
            )

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

        private fun drawWidget(
            context: Context,
            cal: Int, calGoal: Int, calPct: Float,
            prot: Int, protGoal: Int, protPct: Float,
            water: Int, waterGoal: Int, waterPct: Float,
            steps: Int, stepGoal: Int, stepPct: Float,
            insight: String
        ): Bitmap {
            val dp = context.resources.displayMetrics.density
            val W  = (280 * dp).toInt().coerceAtLeast(1)
            val H  = (126 * dp).toInt().coerceAtLeast(1)
            val bmp = Bitmap.createBitmap(W, H, Bitmap.Config.ARGB_8888)
            val cv  = Canvas(bmp)
            val p   = Paint(Paint.ANTI_ALIAS_FLAG)

            val pad      = 12f * dp
            val r        = 18f * dp   // corner radius
            val headerH  = 20f * dp
            val stripH   = 24f * dp
            val contentT = pad + headerH + 3f * dp
            val contentB = H - stripH - 2f * dp
            val ringSize = contentB - contentT
            val metricsL = pad + ringSize + 10f * dp
            val metricsR = W - pad
            val mW       = metricsR - metricsL

            // ── Background ────────────────────────────────────────────────────
            p.color = BG; p.style = Paint.Style.FILL
            cv.drawRoundRect(RectF(0f, 0f, W.toFloat(), H.toFloat()), r, r, p)

            // ── Header ─────────────────────────────────────────────────────────
            p.color = GREEN
            p.textSize = 9.5f * dp
            p.typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            cv.drawText("K FITNESS", pad, pad + 14f * dp, p)

            p.color = MUTED
            p.textSize = 8.5f * dp
            p.typeface = Typeface.DEFAULT
            p.textAlign = Paint.Align.RIGHT
            cv.drawText(todayLabel(), W - pad, pad + 14f * dp, p)
            p.textAlign = Paint.Align.LEFT

            // thin divider
            p.color = 0x1AFFFFFF.toInt(); p.strokeWidth = 0.7f * dp; p.style = Paint.Style.STROKE
            cv.drawLine(pad, pad + headerH, W - pad, pad + headerH, p)
            p.style = Paint.Style.FILL

            // ── Rings ──────────────────────────────────────────────────────────
            drawRings(cv, pad, contentT, ringSize, calPct, protPct, waterPct)

            // ── Metrics ────────────────────────────────────────────────────────
            data class Row(val color: Int, val label: String, val value: String, val pct: Float)
            val rows = listOf(
                Row(RED,    "CALORIES", fmtCal(cal, calGoal),         calPct),
                Row(GREEN,  "PROTEIN",  "${prot}g / ${protGoal}g",    protPct),
                Row(CYAN,   "WATER",    fmtWater(water, waterGoal),   waterPct),
                Row(ORANGE, "STEPS",    fmtSteps(steps, stepGoal),    stepPct),
            )
            val rowH = ringSize / rows.size

            for ((i, row) in rows.withIndex()) {
                val rTop = contentT + i * rowH
                val midY = rTop + rowH * 0.38f

                // colour dot
                p.color = row.color
                cv.drawCircle(metricsL + 4f * dp, midY, 3.2f * dp, p)

                // label (muted, small caps)
                p.textSize  = 7f * dp
                p.color     = MUTED
                p.typeface  = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                cv.drawText(row.label, metricsL + 10f * dp, midY + 4f * dp, p)

                // value (white, monospace)
                p.textSize  = 9f * dp
                p.color     = WHITE
                p.typeface  = Typeface.create(Typeface.MONOSPACE, Typeface.BOLD)
                cv.drawText(row.value, metricsL + 10f * dp, midY + 14f * dp, p)

                // progress bar
                val barTop = midY + 17f * dp
                val barH2  = 2.8f * dp
                val barR   = barH2 / 2f

                p.typeface = Typeface.DEFAULT
                p.color = (row.color and 0x00FFFFFF) or 0x30000000
                cv.drawRoundRect(RectF(metricsL, barTop, metricsR, barTop + barH2), barR, barR, p)

                val fill = row.pct.coerceIn(0f, 1f) * mW
                if (fill > barR * 2) {
                    p.color = row.color
                    cv.drawRoundRect(RectF(metricsL, barTop, metricsL + fill, barTop + barH2), barR, barR, p)
                }
                // overflow sparkle: bright dot past the end when >100%
                if (row.pct > 1f) {
                    p.color = blendWithWhite(row.color, 0.55f)
                    cv.drawCircle(metricsR - 3f * dp, barTop + barH2 / 2f, 4f * dp, p)
                }
            }

            // ── Insight strip ──────────────────────────────────────────────────
            val stripTop = H.toFloat() - stripH
            val stripPath = Path().apply {
                addRoundRect(
                    RectF(0f, stripTop, W.toFloat(), H.toFloat()),
                    floatArrayOf(0f, 0f, 0f, 0f, r, r, r, r),
                    Path.Direction.CW
                )
            }
            p.color = STRIP
            cv.drawPath(stripPath, p)

            p.color = 0x1AFFFFFF.toInt(); p.style = Paint.Style.STROKE; p.strokeWidth = 0.7f * dp
            cv.drawLine(pad, stripTop, W - pad, stripTop, p)
            p.style = Paint.Style.FILL

            p.textSize = 9f * dp
            p.color    = 0xCCFFFFFF.toInt()
            p.typeface = Typeface.DEFAULT
            val maxTxtW = W - pad * 2
            val truncated = truncate(p, insight, maxTxtW)
            cv.drawText(truncated, pad, stripTop + stripH * 0.68f, p)

            return bmp
        }

        private fun drawRings(
            cv: Canvas,
            left: Float, top: Float, size: Float,
            calPct: Float, protPct: Float, waterPct: Float
        ) {
            val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE }
            val stroke = size * 0.092f
            val gap    = size * 0.128f
            val cx     = left + size / 2f
            val cy     = top  + size / 2f
            val rings  = listOf(Triple(RED, calPct, 0), Triple(GREEN, protPct, 1), Triple(CYAN, waterPct, 2))

            for ((color, pct, i) in rings) {
                val rr = size / 2f - stroke / 2f - i * gap
                if (rr <= 0f) continue
                val rect = RectF(cx - rr, cy - rr, cx + rr, cy + rr)
                paint.strokeWidth = stroke

                paint.color     = (color and 0x00FFFFFF) or 0x2E000000
                paint.strokeCap = Paint.Cap.ROUND
                cv.drawArc(rect, 0f, 360f, false, paint)

                if (pct <= 0f) continue
                if (pct <= 1f) {
                    paint.color = color; paint.strokeCap = Paint.Cap.ROUND
                    cv.drawArc(rect, -90f, 360f * pct, false, paint)
                } else {
                    paint.color = color; paint.strokeCap = Paint.Cap.BUTT
                    cv.drawArc(rect, -90f, 360f, false, paint)
                    val overSweep = 360f * (pct - 1f).coerceIn(0f, 1f)
                    paint.color = blendWithWhite(color, 0.45f); paint.strokeCap = Paint.Cap.ROUND
                    cv.drawArc(rect, -90f, overSweep, false, paint)
                }
            }
        }

        private fun blendWithWhite(color: Int, f: Float): Int {
            val r = (Color.red(color)   * (1 - f) + 255 * f).toInt().coerceIn(0, 255)
            val g = (Color.green(color) * (1 - f) + 255 * f).toInt().coerceIn(0, 255)
            val b = (Color.blue(color)  * (1 - f) + 255 * f).toInt().coerceIn(0, 255)
            return Color.argb(255, r, g, b)
        }

        private fun truncate(p: Paint, text: String, maxW: Float): String {
            if (p.measureText(text) <= maxW) return text
            val ellipsis = "…"
            val ew = p.measureText(ellipsis)
            var i = text.length
            while (i > 0 && p.measureText(text.substring(0, i)) + ew > maxW) i--
            return text.substring(0, i) + ellipsis
        }

        private fun todayLabel(): String {
            val cal   = Calendar.getInstance()
            val days  = arrayOf("SUN","MON","TUE","WED","THU","FRI","SAT")
            val months= arrayOf("JAN","FEB","MAR","APR","MAY","JUN","JUL","AUG","SEP","OCT","NOV","DEC")
            val dow   = days[cal.get(Calendar.DAY_OF_WEEK) - 1]
            val dom   = cal.get(Calendar.DAY_OF_MONTH)
            val mon   = months[cal.get(Calendar.MONTH)]
            return "$dow $dom $mon"
        }

        private fun fmtCal(cal: Int, goal: Int) = "$cal / $goal"

        private fun fmtWater(ml: Int, goal: Int): String {
            val l  = ml   / 1000f
            val gl = goal / 1000f
            return "%.1f / %.1fL".format(l, gl)
        }

        private fun fmtSteps(steps: Int, goal: Int): String {
            fun fmt(n: Int) = if (n >= 1000) "%.1fk".format(n / 1000f) else "$n"
            return "${fmt(steps)} / ${fmt(goal)}"
        }

        fun triggerUpdate(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, KFitnessWidgetProvider::class.java)
            )
            if (ids.isNotEmpty()) KFitnessWidgetProvider().onUpdate(context, manager, ids)
        }
    }
}
