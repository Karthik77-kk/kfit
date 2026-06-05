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
 * single Bitmap using the ACTUAL widget dimensions from [AppWidgetManager.getAppWidgetOptions].
 * This prevents the bottom-crop issue caused by drawing a larger bitmap than the widget.
 *
 * Layout:
 *  ┌─────────────────────────────────────┐
 *  │  K FITNESS              MON 1 JUN  │  header
 *  ├─────────┬───────────────────────────┤
 *  │         │  ● CALORIES  800 / 1700  │
 *  │ [RINGS] │  ████████░░░ 47%         │
 *  │         │  ● PROTEIN   48g / 100g  │
 *  │         │  ████████░░░ 48%         │
 *  │         │  ● WATER   1.3 / 2.5L   │
 *  │         │  ████░░░░░░░ 52%         │
 *  │         │  ● STEPS   51 / 8k      │
 *  │         │  ████░░░░░░░ 1%          │
 *  ├─────────┴───────────────────────────┤
 *  │  💪  Muscle dipped 0.8 kg          │  insight strip
 *  └─────────────────────────────────────┘
 */
class KFitnessWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) updateWidget(context, appWidgetManager, id)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: android.os.Bundle
    ) {
        // Redraw when user resizes the widget so layout adapts.
        updateWidget(context, appWidgetManager, appWidgetId)
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
            val views  = RemoteViews(context.packageName, R.layout.kfitness_widget)
            val prefs  = HomeWidgetPlugin.getData(context)

            // ── Read widget data ─────────────────────────────────────────────
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

            val emoji   = prefs.getString("insightEmoji", "💡") ?: "💡"
            val title   = prefs.getString("insightTitle", "Open K Fitness") ?: "Open K Fitness"
            val insight = if (emoji.isBlank()) title else "$emoji  $title"

            // ── Actual widget dimensions from launcher ───────────────────────
            // Use OPTION_APPWIDGET_MIN_WIDTH/HEIGHT which are the guaranteed minimums.
            // At 0 they mean "not yet set by launcher" — fall back to XML defaults.
            val opts    = manager.getAppWidgetOptions(widgetId)
            val wDp     = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 250)
                .coerceAtLeast(200)
            val hDp     = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 160)
                .coerceAtLeast(140)

            views.setImageViewBitmap(
                R.id.widget_canvas,
                drawWidget(
                    context, wDp, hDp,
                    cal, calGoal, calPct,
                    prot, protGoal, protPct,
                    water, waterGoal, waterPct,
                    steps, stepGoal, stepPct,
                    insight
                )
            )

            // ── Tap → open app ───────────────────────────────────────────────
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

        // ── Drawing ──────────────────────────────────────────────────────────

        private fun drawWidget(
            context: Context,
            widthDp: Int, heightDp: Int,
            cal: Int, calGoal: Int, calPct: Float,
            prot: Int, protGoal: Int, protPct: Float,
            water: Int, waterGoal: Int, waterPct: Float,
            steps: Int, stepGoal: Int, stepPct: Float,
            insight: String
        ): Bitmap {
            val dp = context.resources.displayMetrics.density
            // Draw at actual widget dimensions so nothing is clipped.
            val W  = (widthDp  * dp).toInt().coerceAtLeast(200)
            val H  = (heightDp * dp).toInt().coerceAtLeast(120)
            val bmp = Bitmap.createBitmap(W, H, Bitmap.Config.ARGB_8888)
            val cv  = Canvas(bmp)
            val p   = Paint(Paint.ANTI_ALIAS_FLAG)

            // Proportional layout — all sizes relative to canvas H.
            val rad     = 18f * dp
            val pad     = 10f * dp
            val hdrH    = (H * 0.14f).coerceAtLeast(16f * dp)
            val stripH  = (H * 0.17f).coerceAtLeast(20f * dp)
            val contT   = pad + hdrH + 2f * dp
            val contB   = H  - stripH - 2f * dp
            val ringSize= contB - contT
            val metL    = pad + ringSize + 8f * dp
            val metR    = W   - pad
            val mW      = metR - metL

            // Scale font sizes with available height.
            val labelSz = (H * 0.058f).coerceIn(7f * dp, 10f * dp)
            val valueSz = (H * 0.072f).coerceIn(8f * dp, 12f * dp)
            val barH    = (H * 0.022f).coerceIn(2f * dp, 3.5f * dp)

            // ── Background ──────────────────────────────────────────────────
            p.color = BG; p.style = Paint.Style.FILL
            cv.drawRoundRect(RectF(0f, 0f, W.toFloat(), H.toFloat()), rad, rad, p)

            // ── Header ──────────────────────────────────────────────────────
            val hdrY = pad + hdrH * 0.72f
            p.textSize = (hdrH * 0.52f).coerceIn(8f * dp, 11f * dp)
            p.color = GREEN
            p.typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            cv.drawText("K FITNESS", pad, hdrY, p)

            p.textSize = (hdrH * 0.48f).coerceIn(7f * dp, 10f * dp)
            p.color = MUTED; p.typeface = Typeface.DEFAULT
            p.textAlign = Paint.Align.RIGHT
            cv.drawText(todayLabel(), W - pad, hdrY, p)
            p.textAlign = Paint.Align.LEFT

            p.color = 0x1AFFFFFF.toInt(); p.strokeWidth = 0.6f * dp; p.style = Paint.Style.STROKE
            cv.drawLine(pad, pad + hdrH, W - pad, pad + hdrH, p)
            p.style = Paint.Style.FILL

            // ── Rings ────────────────────────────────────────────────────────
            drawRings(cv, pad, contT, ringSize, calPct, protPct, waterPct)

            // ── Metric rows ──────────────────────────────────────────────────
            data class Row(val color: Int, val label: String, val value: String, val pct: Float)
            val rows = listOf(
                Row(RED,    "CALORIES", fmtCal(cal, calGoal),       calPct),
                Row(GREEN,  "PROTEIN",  "${prot}g / ${protGoal}g",  protPct),
                Row(CYAN,   "WATER",    fmtWater(water, waterGoal), waterPct),
                Row(ORANGE, "STEPS",    fmtSteps(steps, stepGoal),  stepPct),
            )
            val rowH = ringSize / rows.size
            // Draw section group labels: INTAKE (rows 0-1) / ACTIVITY (rows 2-3)
            val groupLabelSz = (6f * dp).coerceIn(6f, 9f)
            p.textSize = groupLabelSz
            p.typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            p.color = 0x55FFFFFF.toInt()
            // "INTAKE" sits just above row 0
            cv.drawText("INTAKE", metL, contT - 3f * dp, p)
            // "ACTIVITY" sits just above row 2
            cv.drawText("ACTIVITY", metL, contT + rowH * 2f - 3f * dp, p)
            // thin separator between intake and activity rows
            p.color = 0x18FFFFFF.toInt(); p.style = Paint.Style.STROKE; p.strokeWidth = 0.5f * dp
            val sepY = contT + rowH * 2f - groupLabelSz - 5f * dp
            cv.drawLine(metL, sepY, W - pad, sepY, p)
            p.style = Paint.Style.FILL

            for ((i, row) in rows.withIndex()) {
                val rT   = contT + i * rowH
                val midY = rT + rowH * 0.34f

                // dot
                p.color = row.color
                cv.drawCircle(metL + 3.5f * dp, midY, 3f * dp, p)

                // label
                p.textSize = labelSz; p.color = MUTED
                p.typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                cv.drawText(row.label, metL + 9f * dp, midY + labelSz * 0.35f, p)

                // value
                p.textSize = valueSz; p.color = WHITE
                p.typeface = Typeface.create(Typeface.MONOSPACE, Typeface.BOLD)
                cv.drawText(row.value, metL + 9f * dp, midY + labelSz * 0.35f + valueSz + 1f * dp, p)

                // progress bar
                val barT = midY + labelSz * 0.35f + valueSz + 4f * dp
                val barR2 = barH / 2f
                p.typeface = Typeface.DEFAULT

                p.color = (row.color and 0x00FFFFFF) or 0x2E000000
                cv.drawRoundRect(RectF(metL, barT, metR, barT + barH), barR2, barR2, p)

                val fill = row.pct.coerceIn(0f, 1f) * mW
                if (fill > barR2 * 2f) {
                    p.color = row.color
                    cv.drawRoundRect(RectF(metL, barT, metL + fill, barT + barH), barR2, barR2, p)
                }
                if (row.pct > 1f) {
                    p.color = blendWithWhite(row.color, 0.55f)
                    cv.drawCircle(metR - 3f * dp, barT + barH / 2f, 4f * dp, p)
                }
            }

            // ── Insight strip ─────────────────────────────────────────────────
            val stripTop = H.toFloat() - stripH
            val stripPath = Path().apply {
                addRoundRect(
                    RectF(0f, stripTop, W.toFloat(), H.toFloat()),
                    floatArrayOf(0f, 0f, 0f, 0f, rad, rad, rad, rad),
                    Path.Direction.CW
                )
            }
            p.color = STRIP
            cv.drawPath(stripPath, p)

            p.color = 0x1AFFFFFF.toInt(); p.style = Paint.Style.STROKE; p.strokeWidth = 0.6f * dp
            cv.drawLine(pad, stripTop, W - pad, stripTop, p)
            p.style = Paint.Style.FILL

            val insightSz = (stripH * 0.40f).coerceIn(8f * dp, 11f * dp)
            p.textSize = insightSz; p.color = 0xCCFFFFFF.toInt(); p.typeface = Typeface.DEFAULT
            val insightY = stripTop + stripH * 0.65f
            cv.drawText(truncate(p, insight, W - pad * 2), pad, insightY, p)

            return bmp
        }

        private fun drawRings(
            cv: Canvas, left: Float, top: Float, size: Float,
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
                    val over = 360f * (pct - 1f).coerceIn(0f, 1f)
                    paint.color = blendWithWhite(color, 0.45f); paint.strokeCap = Paint.Cap.ROUND
                    cv.drawArc(rect, -90f, over, false, paint)
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
            val ew = p.measureText("…")
            var i = text.length
            while (i > 0 && p.measureText(text.substring(0, i)) + ew > maxW) i--
            return text.substring(0, i) + "…"
        }

        private fun todayLabel(): String {
            val cal    = Calendar.getInstance()
            val days   = arrayOf("SUN","MON","TUE","WED","THU","FRI","SAT")
            val months = arrayOf("JAN","FEB","MAR","APR","MAY","JUN","JUL","AUG","SEP","OCT","NOV","DEC")
            return "${days[cal.get(Calendar.DAY_OF_WEEK) - 1]} ${cal.get(Calendar.DAY_OF_MONTH)} ${months[cal.get(Calendar.MONTH)]}"
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
