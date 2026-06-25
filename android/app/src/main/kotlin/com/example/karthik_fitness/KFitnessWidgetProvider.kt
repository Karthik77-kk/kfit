package com.example.karthik_fitness

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
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
 * Full-screen multi-region home-screen widget.
 *
 * Each region is drawn to its own Bitmap (capped at ≤720px longest side to
 * keep the RemoteViews Binder transaction under ~1 MB) and set into its own
 * ImageView, giving each section its own PendingIntent tap target.
 *
 * Layout (vertical weighted LinearLayout):
 *   widget_header  – "K FITNESS" / date                     → home
 *   widget_hero    – calorie squircle + protein bar + net    → food
 *   widget_tiles   – WATER / STEPS / BURN / GYM (4×horizontal) → water/home/workout/workout
 *   widget_chart   – weight sparkline                        → body
 *   widget_insight – insight strip                           → home
 *
 * Responsive: regions hide via setViewVisibility(GONE) as height shrinks.
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
        private val STRIP  = Color.parseColor("#141416")
        private val MUTED  = Color.parseColor("#8E8E93")
        private val WHITE  = Color.WHITE

        // Maximum pixels on the longest side of any single region bitmap.
        // Keeps the RemoteViews Binder transaction well under ~1 MB.
        private const val MAX_REGION_PX = 720

        fun updateWidget(context: Context, manager: AppWidgetManager, widgetId: Int) {
            val views = RemoteViews(context.packageName, R.layout.kfitness_widget)
            val prefs = HomeWidgetPlugin.getData(context)

            // ── Read all widget data ──────────────────────────────────────────
            val cal       = prefs.getInt("calories",    0)
            val calGoal   = prefs.getInt("calorieGoal", 1700)
            val prot      = prefs.getInt("protein",     0)
            val protGoal  = prefs.getInt("proteinGoal", 100)
            val water     = prefs.getInt("water",       0)
            val waterGoal = prefs.getInt("waterGoal",   2500)
            val steps     = prefs.getInt("steps",       0)
            val stepGoal  = prefs.getInt("stepGoal",    8000)

            val calPct   = prefs.getInt("calPct",  0).coerceAtLeast(0) / 100f
            val protPct  = prefs.getInt("protPct", 0).coerceAtLeast(0) / 100f
            val waterPct = prefs.getInt("waterPct",0).coerceAtLeast(0) / 100f
            val stepPct  = prefs.getInt("stepPct", 0).coerceAtLeast(0) / 100f

            val insightEmoji = prefs.getString("insightEmoji", "💡") ?: "💡"
            val insightTitle = prefs.getString("insightTitle", "Open K Fitness") ?: "Open K Fitness"
            val insight      = if (insightEmoji.isBlank()) insightTitle else "$insightEmoji  $insightTitle"

            val burned       = prefs.getInt("burned",      0)
            val net          = prefs.getInt("net",         0)
            val deficit      = prefs.getInt("deficit",     0)
            val workoutDone  = prefs.getBoolean("workoutDone", false)
            val workoutLabel = prefs.getString("workoutLabel", "—") ?: "—"
            val workoutBurn  = prefs.getInt("workoutBurn", 0)
            val weightSeries = prefs.getString("weightSeries", "") ?: ""
            // home_widget stores Dart `double` as Long bits (doubleToRawLongBits).
            // Read with getLong + longBitsToDouble; fall back to 0.0 if absent.
            val weight       = java.lang.Double.longBitsToDouble(prefs.getLong("weight",      0L)).toFloat()
            val weightDelta  = java.lang.Double.longBitsToDouble(prefs.getLong("weightDelta", 0L)).toFloat()

            // ── Widget dimensions from launcher ──────────────────────────────
            val opts = manager.getAppWidgetOptions(widgetId)
            val wDp  = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH,  250).coerceAtLeast(200)
            val hDp  = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 160).coerceAtLeast(110)
            val dp   = context.resources.displayMetrics.density
            val wPx  = (wDp * dp).toInt().coerceAtLeast(200)
            val hPx  = (hDp * dp).toInt().coerceAtLeast(110)

            // ── Responsive visibility thresholds (dp) ────────────────────────
            // very small (<190dp) : header + hero + insight only
            // medium    (190–270)  : + tiles row
            // large     (>270)     : + chart
            val showTiles = hDp >= 190
            val showChart = hDp >= 270

            if (showTiles) {
                views.setViewVisibility(R.id.widget_tiles,  View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.widget_tiles,  View.GONE)
            }
            if (showChart) {
                views.setViewVisibility(R.id.widget_chart,  View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.widget_chart,  View.GONE)
            }

            // ── Proportional region heights (pixels) ─────────────────────────
            // Weights: header 1.2, hero 3.2, tiles 2.2, chart 1.6, insight 1.2
            val totalWeight = 1.2f + 3.2f + (if (showTiles) 2.2f else 0f) +
                              (if (showChart) 1.6f else 0f) + 1.2f
            fun hFor(w: Float) = ((hPx * w / totalWeight).toInt()).coerceAtLeast(16)
            val hdrH    = hFor(1.2f)
            val heroH   = hFor(3.2f)
            val tilesH  = if (showTiles) hFor(2.2f) else 0
            val chartH  = if (showChart) hFor(1.6f) else 0
            val insH    = hFor(1.2f)

            // ── Build bitmaps ─────────────────────────────────────────────────
            views.setImageViewBitmap(R.id.widget_header,
                drawHeader(wPx, hdrH, dp))
            views.setImageViewBitmap(R.id.widget_hero,
                drawHero(wPx, heroH, dp, cal, calGoal, calPct, prot, protGoal, protPct, net, deficit))
            if (showTiles) {
                val tilePx = wPx / 4
                val waterBmp  = drawTile(tilePx, tilesH, dp, CYAN,   "WATER",  fmtWaterShort(water), waterPct, false)
                val stepsBmp  = drawTile(tilePx, tilesH, dp, ORANGE, "STEPS",  fmtStepsShort(steps), stepPct, false)
                val burnBmp   = drawTile(tilePx, tilesH, dp, RED,    "BURN",   "${burned} kc", 0f, false)
                val gymBmp    = drawTile(tilePx, tilesH, dp, GREEN,  "GYM",    if (workoutDone) "✓ $workoutLabel" else "—", if (workoutDone) 1f else 0f, false)
                views.setImageViewBitmap(R.id.widget_tile_water, waterBmp)
                views.setImageViewBitmap(R.id.widget_tile_steps, stepsBmp)
                views.setImageViewBitmap(R.id.widget_tile_burn,  burnBmp)
                views.setImageViewBitmap(R.id.widget_tile_gym,   gymBmp)
            }
            if (showChart) {
                views.setImageViewBitmap(R.id.widget_chart,
                    drawSparkline(wPx, chartH, dp, weightSeries, weight, weightDelta))
            }
            views.setImageViewBitmap(R.id.widget_insight,
                drawInsight(wPx, insH, dp, insight))

            // ── Per-region tap intents ────────────────────────────────────────
            views.setOnClickPendingIntent(R.id.widget_header,    routePI(context, "home"))
            views.setOnClickPendingIntent(R.id.widget_hero,      routePI(context, "food"))
            if (showTiles) {
                views.setOnClickPendingIntent(R.id.widget_tile_water, routePI(context, "water"))
                views.setOnClickPendingIntent(R.id.widget_tile_steps, routePI(context, "home"))
                views.setOnClickPendingIntent(R.id.widget_tile_burn,  routePI(context, "workout"))
                views.setOnClickPendingIntent(R.id.widget_tile_gym,   routePI(context, "workout"))
            }
            if (showChart) {
                views.setOnClickPendingIntent(R.id.widget_chart,  routePI(context, "body"))
            }
            views.setOnClickPendingIntent(R.id.widget_insight,   routePI(context, "home"))

            manager.updateAppWidget(widgetId, views)
        }

        // ── Route PendingIntent ───────────────────────────────────────────────

        /**
         * Builds a PendingIntent that opens MainActivity with the given kfit:// URI,
         * delegating to the home_widget library (handles the API-34/35 ActivityOptions
         * background-start flags for us).
         *
         * Each region passes a distinct route → distinct intent `data` URI, so the
         * resulting PendingIntents differ under Intent.filterEquals even though the
         * library uses requestCode=0 — no FLAG_UPDATE_CURRENT collision. Regions that
         * share a route ("home" for header/steps/insight) intentionally share one
         * PendingIntent (they all open Home).
         */
        private fun routePI(context: Context, route: String): PendingIntent =
            HomeWidgetLaunchIntent.getActivity(
                context, MainActivity::class.java, Uri.parse("kfit://$route"))

        // ── Region drawing functions ─────────────────────────────────────────

        /** Header: "K FITNESS"  ·  date right-aligned */
        private fun drawHeader(wPx: Int, hPx: Int, dp: Float): Bitmap {
            val (bmp, cv) = regionCanvas(wPx, hPx); val p = Paint(Paint.ANTI_ALIAS_FLAG)
            val pad = 10f * dp
            val cy  = hPx / 2f

            p.color = GREEN
            p.typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            p.textSize = (hPx * 0.48f).coerceIn(8f * dp, 14f * dp)
            cv.drawText("K FITNESS", pad, cy + p.textSize * 0.36f, p)

            p.color = MUTED
            p.typeface = Typeface.DEFAULT
            p.textSize = (hPx * 0.40f).coerceIn(7f * dp, 12f * dp)
            p.textAlign = Paint.Align.RIGHT
            cv.drawText(todayLabel(), wPx - pad, cy + p.textSize * 0.36f, p)
            p.textAlign = Paint.Align.LEFT

            // Separator line at bottom
            p.color = 0x1AFFFFFF; p.style = Paint.Style.STROKE; p.strokeWidth = 0.6f * dp
            cv.drawLine(pad, hPx - 1f, wPx - pad, hPx - 1f, p)
            return bmp
        }

        /**
         * Hero: large squircle (calorie pct) on the left, two bars + net line on the right.
         */
        private fun drawHero(
            wPx: Int, hPx: Int, dp: Float,
            cal: Int, calGoal: Int, calPct: Float,
            prot: Int, protGoal: Int, protPct: Float,
            net: Int, deficit: Int
        ): Bitmap {
            val (bmp, cv) = regionCanvas(wPx, hPx); val p = Paint(Paint.ANTI_ALIAS_FLAG)
            val pad   = 10f * dp

            // Squircle: sits in left square region, full height minus padding.
            val sqSize  = (hPx - pad * 2f).coerceAtLeast(16f)
            val sqL     = pad
            val sqT     = pad
            val sqRect  = RectF(sqL, sqT, sqL + sqSize, sqT + sqSize)
            val sqCorner= sqSize * 0.28f
            val strokeW = sqSize * 0.10f

            drawSquircle(cv, sqRect, sqCorner, calPct, RED, strokeW)

            // Calorie number centered inside the squircle, auto-shrunk to fit.
            p.color = WHITE
            p.typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            p.textAlign = Paint.Align.CENTER
            val cx = sqL + sqSize / 2f
            val cy = sqT + sqSize / 2f
            var cs = (sqSize * 0.30f).coerceIn(10f * dp, 22f * dp)
            p.textSize = cs
            val maxCalW = sqSize * 0.72f
            while (p.measureText("$cal") > maxCalW && cs > 8f * dp) { cs -= 1f; p.textSize = cs }
            cv.drawText("$cal", cx, cy + p.textSize * 0.35f, p)
            p.textAlign = Paint.Align.LEFT

            // Right section: two bars (Calories, Protein) + net line
            val metL   = sqL + sqSize + 8f * dp
            val metR   = wPx - pad
            val mW     = (metR - metL).coerceAtLeast(1f)
            val labelSz = (hPx * 0.090f).coerceIn(7f * dp, 11f * dp)
            val valueSz = (hPx * 0.110f).coerceIn(8f * dp, 13f * dp)
            val barH    = (hPx * 0.040f).coerceIn(2f * dp, 5f * dp)
            val rowH    = hPx / 2.5f

            data class Row(val color: Int, val label: String, val value: String, val pct: Float)
            val rows = listOf(
                Row(RED,   "CALORIES", "$cal / $calGoal",          calPct),
                Row(GREEN, "PROTEIN",  "${prot}g / ${protGoal}g",  protPct),
            )

            for ((i, row) in rows.withIndex()) {
                val rT   = pad + i * rowH
                val midY = rT + rowH * 0.28f

                p.color = row.color; p.style = Paint.Style.FILL
                cv.drawCircle(metL + 3.5f * dp, midY + labelSz * 0.35f, 3f * dp, p)

                p.textSize = labelSz; p.color = MUTED
                p.typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                cv.drawText(row.label, metL + 9f * dp, midY + labelSz * 0.70f, p)

                p.textSize = valueSz; p.color = WHITE
                p.typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                cv.drawText(row.value, metL + 9f * dp, midY + labelSz * 0.70f + valueSz + 1f * dp, p)

                val barT  = midY + labelSz * 0.70f + valueSz + 4f * dp
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

            // Net / deficit line — clamp so it never renders past the hero's bottom.
            val netY   = minOf(pad + 2f * rowH, hPx - labelSz - pad * 0.5f)
            val isDeficit = deficit >= 0
            val netColor  = if (isDeficit) GREEN else RED
            val netLabel  = if (isDeficit) "net −$deficit kcal deficit" else "net +${-deficit} kcal surplus"
            p.textSize = labelSz * 0.95f; p.color = netColor
            p.typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            cv.drawText(netLabel, metL, netY + labelSz, p)

            return bmp
        }

        /**
         * Single tile: squircle progress ring, label, value.
         * [ringFull] can be used to force a full ring (not currently used, false by default).
         */
        private fun drawTile(
            wPx: Int, hPx: Int, dp: Float,
            color: Int, label: String, value: String, pct: Float,
            @Suppress("SameParameterValue") ringFull: Boolean
        ): Bitmap {
            val (bmp, cv) = regionCanvas(wPx, hPx); val p = Paint(Paint.ANTI_ALIAS_FLAG)
            val pad     = 6f * dp
            // Reserve a label band at the bottom so the squircle never overlaps it;
            // the squircle fills (and is centered in) the area above the band.
            val labelSz = (hPx * 0.16f).coerceIn(7f * dp, 10f * dp)
            val labelH  = labelSz + 5f * dp
            val areaH   = (hPx - labelH).coerceAtLeast(12f)
            val size    = (minOf(wPx.toFloat(), areaH) - pad * 2f).coerceAtLeast(12f)
            val sqL     = (wPx - size) / 2f
            val sqT     = ((areaH - size) / 2f).coerceAtLeast(0f)
            val sqRect  = RectF(sqL, sqT, sqL + size, sqT + size)
            val sqCR    = size * 0.28f
            val strokeW = size * 0.10f
            val cx      = sqL + size / 2f
            val cy      = sqT + size / 2f

            drawSquircle(cv, sqRect, sqCR, if (ringFull) 1f else pct, color, strokeW)

            // Value centered in the squircle, auto-shrunk to fit inside the ring.
            p.color = WHITE
            p.typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            p.textAlign = Paint.Align.CENTER
            var vs = (size * 0.28f).coerceIn(8f * dp, 15f * dp)
            p.textSize = vs
            val maxValW = size * 0.74f
            while (p.measureText(value) > maxValW && vs > 7f * dp) { vs -= 1f; p.textSize = vs }
            cv.drawText(value, cx, cy + p.textSize * 0.35f, p)

            // Label centered in the reserved bottom band.
            p.color = MUTED
            p.textSize = labelSz
            cv.drawText(label, cx, hPx - labelH / 2f + labelSz * 0.35f, p)
            p.textAlign = Paint.Align.LEFT

            return bmp
        }

        /** Weight sparkline with label and delta annotation. */
        private fun drawSparkline(
            wPx: Int, hPx: Int, dp: Float,
            seriesStr: String, latestWeight: Float, weightDelta: Float
        ): Bitmap {
            val (bmp, cv) = regionCanvas(wPx, hPx); val p = Paint(Paint.ANTI_ALIAS_FLAG)
            val pad = 10f * dp

            // Top separator
            p.color = 0x1AFFFFFF; p.style = Paint.Style.STROKE; p.strokeWidth = 0.6f * dp
            cv.drawLine(pad, 0f, wPx - pad, 0f, p)
            p.style = Paint.Style.FILL

            val labelSz = (hPx * 0.22f).coerceIn(7f * dp, 10f * dp)

            // Parse series
            val pts = if (seriesStr.isBlank()) floatArrayOf() else
                seriesStr.split(',').mapNotNull { it.trim().toFloatOrNull() }.toFloatArray()

            // Label
            p.color = MUTED
            p.typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            p.textSize = labelSz
            val weightLabel = if (latestWeight > 0f) "WEIGHT  %.1f kg".format(latestWeight) else "WEIGHT  —"
            cv.drawText(weightLabel, pad, labelSz + pad * 0.5f, p)

            if (pts.size >= 2) {
                // Delta annotation
                val deltaStr = "%+.1f kg".format(weightDelta)
                val deltaColor = if (weightDelta <= 0f) GREEN else RED
                p.color = deltaColor
                p.textAlign = Paint.Align.RIGHT
                cv.drawText(deltaStr, wPx - pad, labelSz + pad * 0.5f, p)
                p.textAlign = Paint.Align.LEFT

                // Sparkline area (below label row)
                val lineT  = labelSz + pad * 1.5f
                val lineB  = hPx - pad * 0.5f
                val lineH  = (lineB - lineT).coerceAtLeast(1f)
                val lineW  = wPx - pad * 2f
                val minV   = pts.min()
                val maxV   = pts.max()
                val range  = (maxV - minV).takeIf { it > 0f } ?: 1f

                fun xFor(i: Int) = pad + i * lineW / (pts.size - 1)
                fun yFor(v: Float) = lineB - (v - minV) / range * lineH

                val path = Path()
                path.moveTo(xFor(0), yFor(pts[0]))
                for (i in 1 until pts.size) path.lineTo(xFor(i), yFor(pts[i]))

                p.style = Paint.Style.STROKE
                p.strokeWidth = 2f * dp
                p.color = CYAN
                p.strokeCap = Paint.Cap.ROUND
                p.strokeJoin = Paint.Join.ROUND
                cv.drawPath(path, p)
                p.style = Paint.Style.FILL

                // Latest dot
                p.color = WHITE
                cv.drawCircle(xFor(pts.size - 1), yFor(pts.last()), 3f * dp, p)
            } else {
                // No data — show dash
                p.color = MUTED; p.textSize = labelSz
            }

            return bmp
        }

        /** Insight strip — slightly lighter background, truncated insight text. */
        private fun drawInsight(wPx: Int, hPx: Int, dp: Float, insight: String): Bitmap {
            val (bmp, cv) = regionCanvas(wPx, hPx); val p = Paint(Paint.ANTI_ALIAS_FLAG)
            val pad = 10f * dp
            val rad = 18f * dp

            // Slightly-lighter background to visually separate from the widget body.
            val stripPath = Path().apply {
                addRoundRect(
                    RectF(0f, 0f, wPx.toFloat(), hPx.toFloat()),
                    floatArrayOf(0f, 0f, 0f, 0f, rad, rad, rad, rad),
                    Path.Direction.CW
                )
            }
            p.color = STRIP; p.style = Paint.Style.FILL
            cv.drawPath(stripPath, p)

            // Separator line at top
            p.color = 0x1AFFFFFF; p.style = Paint.Style.STROKE; p.strokeWidth = 0.6f * dp
            cv.drawLine(pad, 0f, wPx - pad, 0f, p)
            p.style = Paint.Style.FILL

            val textSz = (hPx * 0.42f).coerceIn(8f * dp, 11f * dp)
            p.textSize = textSz; p.color = 0xCCFFFFFF.toInt(); p.typeface = Typeface.DEFAULT
            cv.drawText(truncate(p, insight, wPx - pad * 2f), pad, hPx * 0.68f, p)

            return bmp
        }

        // ── Squircle progress ────────────────────────────────────────────────

        /**
         * Draws a rounded-rect (squircle) progress track + filled arc via PathMeasure.
         *
         * The path starts at the TOP-CENTER of the rect and proceeds clockwise by
         * rotating the canvas -90° around the rect's center before drawing, then
         * restoring. This ensures progress reads left→top→right→bottom starting from
         * top-center, matching Apple Watch / activity ring conventions.
         *
         * Overflow (pct > 1): full track in [color], then a second-lap segment in a
         * lighter blend of [color].
         */
        private fun drawSquircle(
            cv: Canvas, rect: RectF, cornerR: Float,
            pct: Float, color: Int, strokeW: Float
        ) {
            val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style      = Paint.Style.STROKE
                strokeWidth = strokeW
                strokeCap  = Paint.Cap.ROUND
            }

            // Build the rounded-rect path once (used for both track and progress).
            val cx = rect.centerX(); val cy = rect.centerY()

            // Rotate canvas so top-center is the 0° point (path starts at right-edge
            // in default orientation; rotating -90° moves that to the top).
            cv.save()
            cv.rotate(-90f, cx, cy)

            val trackPath = Path().apply { addRoundRect(rect, cornerR, cornerR, Path.Direction.CW) }
            val pm = PathMeasure(trackPath, false)
            val len = pm.length

            // Draw dim track
            paint.color     = dimColor(color)
            paint.strokeCap = Paint.Cap.ROUND
            cv.drawPath(trackPath, paint)

            if (pct > 0f) {
                val dst  = Path()
                val fill = pct.coerceIn(0f, 1f)
                if (pct <= 1f) {
                    // Normal progress segment
                    pm.getSegment(0f, len * fill, dst, true)
                    paint.color = color
                    cv.drawPath(dst, paint)
                } else {
                    // Full lap in solid color
                    pm.getSegment(0f, len, dst, true)
                    paint.color     = color
                    paint.strokeCap = Paint.Cap.BUTT
                    cv.drawPath(dst, paint)
                    // Overflow second lap in lighter blend
                    val dst2  = Path()
                    val extra = (pct - 1f).coerceIn(0f, 1f)
                    pm.getSegment(0f, len * extra, dst2, true)
                    paint.color     = blendWithWhite(color, 0.45f)
                    paint.strokeCap = Paint.Cap.ROUND
                    cv.drawPath(dst2, paint)
                }
            }

            cv.restore()
        }

        /** Returns the track color: full alpha stripped, then `0x2E` alpha applied. */
        private fun dimColor(color: Int): Int = (color and 0x00FFFFFF) or 0x2E000000

        // ── Helpers ──────────────────────────────────────────────────────────

        /**
         * Creates a region Bitmap clamped so its longest side ≤ [MAX_REGION_PX],
         * and returns a Canvas pre-scaled by the same factor so the drawing code
         * can keep using the logical [wPx]/[hPx] coordinates without clipping when
         * the on-screen region exceeds the cap. scaleType="fitXY" on the ImageView
         * upscales the smaller bitmap back to size, keeping the Binder payload small.
         *
         * (Previously the bitmap was downscaled but drawing still used full logical
         * coords, so on a large/full-screen widget the right & bottom were clipped.)
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

        private fun fmtWaterShort(ml: Int): String = "%.1f L".format(ml / 1000f)

        private fun fmtStepsShort(steps: Int): String =
            if (steps >= 1000) "%.1fk".format(steps / 1000f) else "$steps"

        fun triggerUpdate(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, KFitnessWidgetProvider::class.java)
            )
            if (ids.isNotEmpty()) KFitnessWidgetProvider().onUpdate(context, manager, ids)
        }
    }
}
