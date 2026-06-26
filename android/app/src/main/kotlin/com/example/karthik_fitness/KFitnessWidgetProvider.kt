package com.example.karthik_fitness

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PathMeasure
import android.graphics.RectF
import android.graphics.Typeface
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import java.util.Calendar

/**
 * Modern full-screen home-screen widget on a translucent panel.
 *
 * Each region is drawn to its own Bitmap (capped at ≤720px longest side so the
 * RemoteViews Binder transaction stays under ~1 MB) and set into its own
 * ImageView, giving each section its own PendingIntent tap target.
 *
 * Layout (see kfitness_widget.xml):
 *   widget_header  – date (right-aligned)                         → home
 *   row: widget_rings  – cal/protein/water concentric squircles   → home
 *        widget_water  – water tile                               → water
 *   widget_steps   – elongated live-steps card                    → home
 *   widget_notifs  – top-3 notifications                          → home
 *
 * Responsive: lower regions hide via setViewVisibility(GONE) as height shrinks.
 */
class KFitnessWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        // Guard each widget independently so one bad render can't crash the
        // provider (which would surface as "Problem loading widget" on the launcher).
        for (id in appWidgetIds) {
            try {
                updateWidget(context, appWidgetManager, id)
            } catch (_: Throwable) {
            }
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: android.os.Bundle
    ) {
        try {
            updateWidget(context, appWidgetManager, appWidgetId)
        } catch (_: Throwable) {
        }
    }

    companion object {
        private val RED    = Color.parseColor("#FF453A")
        private val GREEN  = Color.parseColor("#30D158")
        private val CYAN   = Color.parseColor("#40C8E0")
        private val ORANGE = Color.parseColor("#FF9F0A")
        private val MUTED  = Color.parseColor("#9A9AA0")
        private val WHITE  = Color.WHITE
        // Subtle translucent fill for the "cards" (steps + notifications) so they
        // read as panels over the mostly-transparent widget background.
        private const val CARD_FILL = 0x24FFFFFF

        // Cap on the longest side of any region bitmap — keeps the RemoteViews
        // Binder transaction well under ~1 MB on large/full-screen widgets.
        private const val MAX_REGION_PX = 720

        fun updateWidget(context: Context, manager: AppWidgetManager, widgetId: Int) {
            val views = RemoteViews(context.packageName, R.layout.kfitness_widget)
            val prefs = HomeWidgetPlugin.getData(context)

            // ── Read widget data ──────────────────────────────────────────────
            val cal      = prefs.getInt("calories", 0)
            val prot     = prefs.getInt("protein",  0)
            val water    = prefs.getInt("water",    0)
            val steps    = prefs.getInt("steps",    0)
            val stepGoal = prefs.getInt("stepGoal", 8000)

            val calPct   = prefs.getInt("calPct",  0).coerceAtLeast(0) / 100f
            val protPct  = prefs.getInt("protPct", 0).coerceAtLeast(0) / 100f
            val waterPct = prefs.getInt("waterPct",0).coerceAtLeast(0) / 100f
            val stepPct  = prefs.getInt("stepPct", 0).coerceAtLeast(0) / 100f

            // Top-3 notifications (emoji + title), pushed from the provider.
            val notifs = ArrayList<Pair<String, String>>(3)
            for (i in 1..3) {
                val t = prefs.getString("notif${i}Title", "") ?: ""
                if (t.isNotBlank()) {
                    notifs.add(Pair(prefs.getString("notif${i}Emoji", "") ?: "", t))
                }
            }

            // ── Widget dimensions from launcher ──────────────────────────────
            val opts = manager.getAppWidgetOptions(widgetId)
            val wDp  = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH,  250).coerceAtLeast(180)
            val hDp  = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 220).coerceAtLeast(110)
            val dp   = context.resources.displayMetrics.density
            val wPx  = (wDp * dp).toInt().coerceAtLeast(180)
            val hPx  = (hDp * dp).toInt().coerceAtLeast(110)

            // ── Responsive visibility ────────────────────────────────────────
            // small (<200dp): top row only.  medium: + steps.  large: + notifs.
            val showSteps  = hDp >= 200
            val showNotifs = hDp >= 290
            views.setViewVisibility(R.id.widget_steps,  if (showSteps)  View.VISIBLE else View.GONE)
            views.setViewVisibility(R.id.widget_notifs, if (showNotifs) View.VISIBLE else View.GONE)

            // ── Region heights from weights ──────────────────────────────────
            // header 0.55, topRow 3.1, steps 1.05, notifs 2.3
            val totalWeight = 0.55f + 3.1f +
                (if (showSteps) 1.05f else 0f) + (if (showNotifs) 2.3f else 0f)
            fun hFor(w: Float) = (hPx * w / totalWeight).toInt().coerceAtLeast(12)
            val hdrH   = hFor(0.55f)
            val rowH   = hFor(3.1f)
            val stepsH = if (showSteps)  hFor(1.05f) else 0
            val notifH = if (showNotifs) hFor(2.3f)  else 0

            // Top row is split into two ImageViews (rings | water).
            val ringsW = (wPx * 0.56f).toInt().coerceAtLeast(60)
            val waterW = (wPx - ringsW).coerceAtLeast(60)

            // ── Render regions ───────────────────────────────────────────────
            views.setImageViewBitmap(R.id.widget_header, drawHeader(wPx, hdrH, dp))
            views.setImageViewBitmap(R.id.widget_rings,
                drawRingsSquare(ringsW, rowH, dp, cal, prot, water, calPct, protPct, waterPct))
            views.setImageViewBitmap(R.id.widget_water,
                drawWaterTile(waterW, rowH, dp, water, waterPct))
            if (showSteps) {
                views.setImageViewBitmap(R.id.widget_steps,
                    drawStepsCard(wPx, stepsH, dp, steps, stepGoal, stepPct))
            }
            if (showNotifs) {
                views.setImageViewBitmap(R.id.widget_notifs,
                    drawNotifs(wPx, notifH, dp, notifs))
            }

            // ── Per-region tap intents ───────────────────────────────────────
            views.setOnClickPendingIntent(R.id.widget_header, routePI(context, "home"))
            views.setOnClickPendingIntent(R.id.widget_rings,  routePI(context, "home"))
            views.setOnClickPendingIntent(R.id.widget_water,  routePI(context, "water"))
            if (showSteps)  views.setOnClickPendingIntent(R.id.widget_steps,  routePI(context, "home"))
            if (showNotifs) views.setOnClickPendingIntent(R.id.widget_notifs, routePI(context, "home"))

            manager.updateAppWidget(widgetId, views)
        }

        // ── Route PendingIntent ───────────────────────────────────────────────

        /**
         * PendingIntent that opens MainActivity with a kfit://<route> URI, delegating
         * to the home_widget library. Distinct routes have distinct intent `data`, so
         * the PendingIntents differ under Intent.filterEquals even though the library
         * uses requestCode=0; regions sharing a route share one PendingIntent.
         */
        private fun routePI(context: Context, route: String): PendingIntent =
            HomeWidgetLaunchIntent.getActivity(
                context, MainActivity::class.java, Uri.parse("kfit://$route"))

        // ── Header (date only) ────────────────────────────────────────────────

        private fun drawHeader(wPx: Int, hPx: Int, dp: Float): Bitmap {
            val (bmp, cv) = regionCanvas(wPx, hPx); val p = Paint(Paint.ANTI_ALIAS_FLAG)
            p.color = MUTED
            p.typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            p.textSize = (hPx * 0.52f).coerceIn(8f * dp, 13f * dp)
            p.textAlign = Paint.Align.RIGHT
            cv.drawText(todayLabel(), wPx - 12f * dp, hPx * 0.72f, p)
            return bmp
        }

        // ── Rings square: cal / protein / water concentric squircles ──────────

        private fun drawRingsSquare(
            wPx: Int, hPx: Int, dp: Float,
            cal: Int, prot: Int, water: Int,
            calPct: Float, protPct: Float, waterPct: Float
        ): Bitmap {
            val (bmp, cv) = regionCanvas(wPx, hPx); val p = Paint(Paint.ANTI_ALIAS_FLAG)
            val pad     = 8f * dp
            val legendH = (hPx * 0.16f).coerceIn(10f * dp, 22f * dp)
            val areaH   = (hPx - legendH).coerceAtLeast(20f)
            val size    = (minOf(wPx.toFloat(), areaH) - pad * 2f).coerceAtLeast(20f)
            val cx      = wPx / 2f
            val cy      = areaH / 2f

            // 3 concentric squircles: outer cal, middle protein, inner water.
            val stroke  = size * 0.085f
            val spacing = size * 0.035f
            val rings = listOf(Triple(RED, calPct, 0), Triple(GREEN, protPct, 1), Triple(CYAN, waterPct, 2))
            for ((color, pct, i) in rings) {
                val inset = stroke / 2f + i * (stroke + spacing)
                val half  = size / 2f - inset
                if (half <= stroke) continue
                val rect  = RectF(cx - half, cy - half, cx + half, cy + half)
                drawSquircle(cv, rect, half * 0.5f, pct, color, stroke)
            }

            // Centre: big calorie number + "KCAL".
            p.color = WHITE
            p.typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            p.textAlign = Paint.Align.CENTER
            // Clear space inside the innermost (water) ring = centreline diameter
            // minus its stroke; keep the number within it so it never overlaps.
            val innerW = (size / 2f - (stroke / 2f + 2 * (stroke + spacing))) * 2f
            var ns = (size * 0.22f).coerceIn(11f * dp, 24f * dp)
            p.textSize = ns
            val maxW = ((innerW - stroke) * 0.95f).coerceAtLeast(8f * dp)
            while (p.measureText("$cal") > maxW && ns > 8f * dp) { ns -= 1f; p.textSize = ns }
            cv.drawText("$cal", cx, cy + ns * 0.18f, p)
            p.color = MUTED
            p.textSize = (ns * 0.42f).coerceAtLeast(6f * dp)
            cv.drawText("KCAL", cx, cy + ns * 0.78f, p)

            // Legend row: protein (green) · water (cyan) values.
            val legY = hPx - legendH * 0.32f
            val legSz = (legendH * 0.50f).coerceIn(7f * dp, 11f * dp)
            p.typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            p.textSize = legSz
            drawLegendItem(cv, p, dp, wPx * 0.30f, legY, GREEN, "${prot}g")
            drawLegendItem(cv, p, dp, wPx * 0.70f, legY, CYAN, fmtWaterShort(water))
            return bmp
        }

        private fun drawLegendItem(
            cv: Canvas, p: Paint, dp: Float, cx: Float, cy: Float, color: Int, text: String
        ) {
            p.textAlign = Paint.Align.LEFT
            val tw = p.measureText(text)
            val dot = 3f * dp
            val startX = cx - (tw + dot * 3f) / 2f
            p.color = color
            cv.drawCircle(startX + dot, cy - p.textSize * 0.30f, dot, p)
            p.color = WHITE
            cv.drawText(text, startX + dot * 3f, cy, p)
        }

        // ── Water tile ────────────────────────────────────────────────────────

        private fun drawWaterTile(
            wPx: Int, hPx: Int, dp: Float, water: Int, waterPct: Float
        ): Bitmap {
            val (bmp, cv) = regionCanvas(wPx, hPx); val p = Paint(Paint.ANTI_ALIAS_FLAG)
            val pad     = 8f * dp
            val labelH  = (hPx * 0.16f).coerceIn(10f * dp, 22f * dp)
            val areaH   = (hPx - labelH).coerceAtLeast(20f)
            val size    = (minOf(wPx.toFloat(), areaH) - pad * 2f).coerceAtLeast(20f)
            val cx      = wPx / 2f
            val cy      = areaH / 2f
            val rect    = RectF(cx - size / 2f, cy - size / 2f, cx + size / 2f, cy + size / 2f)
            val stroke  = size * 0.10f
            drawSquircle(cv, rect, size * 0.28f, waterPct, CYAN, stroke)

            // Centre value "1.5 L".
            p.color = WHITE
            p.typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            p.textAlign = Paint.Align.CENTER
            var vs = (size * 0.24f).coerceIn(10f * dp, 20f * dp)
            p.textSize = vs
            val maxW = size * 0.66f
            val value = fmtWaterShort(water)
            while (p.measureText(value) > maxW && vs > 8f * dp) { vs -= 1f; p.textSize = vs }
            cv.drawText(value, cx, cy + vs * 0.35f, p)

            // Label band: "WATER · 60%".
            p.color = MUTED
            p.textSize = (labelH * 0.50f).coerceIn(7f * dp, 11f * dp)
            val pct = (waterPct * 100f).toInt().coerceAtLeast(0)
            cv.drawText("WATER · ${pct}%", cx, hPx - labelH * 0.32f, p)
            return bmp
        }

        // ── Elongated live-steps card ─────────────────────────────────────────

        private fun drawStepsCard(
            wPx: Int, hPx: Int, dp: Float, steps: Int, stepGoal: Int, stepPct: Float
        ): Bitmap {
            val (bmp, cv) = regionCanvas(wPx, hPx); val p = Paint(Paint.ANTI_ALIAS_FLAG)
            val mx   = 8f * dp
            val my   = 4f * dp
            val card = RectF(mx, my, wPx - mx, hPx - my)
            val rad  = (card.height() * 0.42f).coerceAtMost(card.height() / 2f)

            // Card background.
            p.color = CARD_FILL; p.style = Paint.Style.FILL
            cv.drawRoundRect(card, rad, rad, p)

            val padL = card.left + 14f * dp
            val padR = card.right - 14f * dp

            // Label + value.
            p.color = ORANGE
            p.typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            p.textSize = (hPx * 0.18f).coerceIn(8f * dp, 12f * dp)
            p.textAlign = Paint.Align.LEFT
            cv.drawText("STEPS", padL, card.top + card.height() * 0.34f, p)

            p.color = WHITE
            p.textSize = (hPx * 0.30f).coerceIn(11f * dp, 20f * dp)
            cv.drawText("%,d".format(steps), padL, card.top + card.height() * 0.74f, p)

            p.color = MUTED
            p.textSize = (hPx * 0.17f).coerceIn(7f * dp, 11f * dp)
            p.textAlign = Paint.Align.RIGHT
            cv.drawText("/ %,d".format(stepGoal), padR, card.top + card.height() * 0.34f, p)
            cv.drawText("${(stepPct * 100).toInt()}%", padR, card.top + card.height() * 0.74f, p)
            p.textAlign = Paint.Align.LEFT

            // Progress bar along the bottom of the card.
            val barH = (hPx * 0.07f).coerceIn(2f * dp, 4f * dp)
            val barT = card.bottom - my - barH - 2f * dp
            val barR = barH / 2f
            p.color = dimColor(ORANGE)
            cv.drawRoundRect(RectF(padL, barT, padR, barT + barH), barR, barR, p)
            val fill = stepPct.coerceIn(0f, 1f) * (padR - padL)
            if (fill > barR * 2f) {
                p.color = ORANGE
                cv.drawRoundRect(RectF(padL, barT, padL + fill, barT + barH), barR, barR, p)
            }
            return bmp
        }

        // ── Top-3 notifications ───────────────────────────────────────────────

        private fun drawNotifs(
            wPx: Int, hPx: Int, dp: Float, notifs: List<Pair<String, String>>
        ): Bitmap {
            val (bmp, cv) = regionCanvas(wPx, hPx); val p = Paint(Paint.ANTI_ALIAS_FLAG)
            val mx = 8f * dp
            if (notifs.isEmpty()) {
                p.color = MUTED
                p.typeface = Typeface.DEFAULT
                p.textSize = (hPx * 0.16f).coerceIn(8f * dp, 12f * dp)
                cv.drawText("All caught up — no new insights", mx + 6f * dp, hPx * 0.5f, p)
                return bmp
            }

            val n      = notifs.size.coerceAtMost(3)
            val gap    = 5f * dp
            val cardH  = ((hPx - gap * (n - 1)) / n).coerceAtLeast(16f)
            val rad    = (cardH * 0.34f).coerceAtMost(cardH / 2f)
            for (i in 0 until n) {
                val top  = i * (cardH + gap)
                val card = RectF(mx, top, wPx - mx, top + cardH)
                p.color = CARD_FILL; p.style = Paint.Style.FILL
                cv.drawRoundRect(card, rad, rad, p)

                val (emoji, title) = notifs[i]
                val cy = card.top + cardH * 0.64f
                var x  = card.left + 12f * dp
                p.textAlign = Paint.Align.LEFT
                p.typeface = Typeface.DEFAULT
                if (emoji.isNotBlank()) {
                    p.color = WHITE
                    p.textSize = (cardH * 0.42f).coerceIn(9f * dp, 15f * dp)
                    cv.drawText(emoji, x, cy, p)
                    x += p.measureText(emoji) + 8f * dp
                }
                p.color = 0xE8FFFFFF.toInt()
                p.textSize = (cardH * 0.36f).coerceIn(8f * dp, 13f * dp)
                cv.drawText(truncate(p, title, card.right - x - 10f * dp), x, cy, p)
            }
            return bmp
        }

        // ── Squircle progress ────────────────────────────────────────────────

        /**
         * Rounded-rect (squircle) progress: dim full track + a progress arc drawn
         * via PathMeasure, starting top-centre and going clockwise. Overflow (pct>1)
         * draws a full lap then a lighter second-lap segment.
         */
        private fun drawSquircle(
            cv: Canvas, rect: RectF, cornerR: Float, pct: Float, color: Int, strokeW: Float
        ) {
            val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.STROKE; strokeWidth = strokeW; strokeCap = Paint.Cap.ROUND
            }
            val cx = rect.centerX(); val cy = rect.centerY()
            cv.save()
            cv.rotate(-90f, cx, cy)
            val trackPath = Path().apply { addRoundRect(rect, cornerR, cornerR, Path.Direction.CW) }
            val pm  = PathMeasure(trackPath, false)
            val len = pm.length

            paint.color = dimColor(color)
            cv.drawPath(trackPath, paint)

            if (pct > 0f) {
                val dst = Path()
                if (pct <= 1f) {
                    pm.getSegment(0f, len * pct.coerceIn(0f, 1f), dst, true)
                    paint.color = color
                    cv.drawPath(dst, paint)
                } else {
                    pm.getSegment(0f, len, dst, true)
                    paint.color = color; paint.strokeCap = Paint.Cap.BUTT
                    cv.drawPath(dst, paint)
                    val dst2 = Path()
                    pm.getSegment(0f, len * (pct - 1f).coerceIn(0f, 1f), dst2, true)
                    paint.color = blendWithWhite(color, 0.45f); paint.strokeCap = Paint.Cap.ROUND
                    cv.drawPath(dst2, paint)
                }
            }
            cv.restore()
        }

        private fun dimColor(color: Int): Int = (color and 0x00FFFFFF) or 0x33000000

        // ── Helpers ──────────────────────────────────────────────────────────

        /**
         * Region Bitmap clamped so its longest side ≤ MAX_REGION_PX, with a Canvas
         * pre-scaled by the same factor so drawing code keeps using logical wPx/hPx
         * coordinates without clipping on large widgets. fitXY on the ImageView
         * upscales the smaller bitmap, keeping the Binder payload small.
         */
        private fun regionCanvas(wPx: Int, hPx: Int): Pair<Bitmap, Canvas> {
            val scale = (MAX_REGION_PX.toFloat() / maxOf(wPx, hPx)).coerceAtMost(1f)
            val bw    = (wPx * scale).toInt().coerceAtLeast(1)
            val bh    = (hPx * scale).toInt().coerceAtLeast(1)
            val bmp   = Bitmap.createBitmap(bw, bh, Bitmap.Config.ARGB_8888)
            val cv    = Canvas(bmp)
            if (scale < 1f) cv.scale(scale, scale)
            return Pair(bmp, cv)
        }

        private fun blendWithWhite(color: Int, f: Float): Int {
            val r = (Color.red(color)   * (1 - f) + 255 * f).toInt().coerceIn(0, 255)
            val g = (Color.green(color) * (1 - f) + 255 * f).toInt().coerceIn(0, 255)
            val b = (Color.blue(color)  * (1 - f) + 255 * f).toInt().coerceIn(0, 255)
            return Color.argb(255, r, g, b)
        }

        private fun truncate(p: Paint, text: String, maxW: Float): String {
            if (maxW <= 0f) return ""
            if (p.measureText(text) <= maxW) return text
            val ew = p.measureText("…")
            var i = text.length
            while (i > 0 && p.measureText(text.substring(0, i)) + ew > maxW) i--
            return text.substring(0, i) + "…"
        }

        private fun fmtWaterShort(ml: Int): String = "%.1f L".format(ml / 1000f)

        private fun todayLabel(): String {
            val c      = Calendar.getInstance()
            val days   = arrayOf("SUN","MON","TUE","WED","THU","FRI","SAT")
            val months = arrayOf("JAN","FEB","MAR","APR","MAY","JUN","JUL","AUG","SEP","OCT","NOV","DEC")
            return "${days[c.get(Calendar.DAY_OF_WEEK) - 1]} ${c.get(Calendar.DAY_OF_MONTH)} ${months[c.get(Calendar.MONTH)]}"
        }

        fun triggerUpdate(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, KFitnessWidgetProvider::class.java))
            if (ids.isNotEmpty()) KFitnessWidgetProvider().onUpdate(context, manager, ids)
        }
    }
}
