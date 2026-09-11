package com.asteriskpound.plugins.charts

import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import com.nativephp.mobile.ui.nativerender.NativeUINode
import org.json.JSONArray
import kotlin.math.cos
import kotlin.math.sin

private data class ChartSeries(val name: String, val color: Color, val values: List<Float?>)

/**
 * Renders `<native:chart>` as hand-drawn Canvas geometry — no Swift Charts /
 * third-party Compose charting library — so line, bar, and radar look
 * consistent with each other and with the iOS renderer (`ChartRenderer.swift`,
 * kept structurally parallel to this file). Radar in particular has no native
 * framework support on either platform, so a uniform hand-rolled approach
 * avoids a visual mismatch between chart kinds.
 *
 * Chrome is deliberately left to the app: titles, legends, and axis labels
 * are ordinary EDGE `native:text`/`native:row` elements composed around the
 * `<native:chart>` tag in Blade — this renderer only draws the plot area.
 */
object ChartRenderer {
    private val GRID_COLOR = Color(0x1F888888)
    private val DEFAULT_COLOR = Color(0xFF1DB954)

    @Composable
    fun Render(node: NativeUINode, modifier: Modifier) {
        val p = node.props
        val kind = p.getString("kind", "line")
        val labels = parseStrings(p.getString("labels", "[]"))
        val series = parseSeries(p.getString("series", "[]"))
        val explicitMax = p.getFloat("y_max", 0f)
        val yMax = if (explicitMax > 0f) explicitMax else autoMax(series)

        Canvas(modifier = modifier) {
            drawGrid(this)

            when (kind) {
                "bar" -> drawBars(this, series, yMax)
                "radar" -> drawRadar(this, labels, series, yMax)
                else -> drawLines(this, series, yMax)
            }
        }
    }

    private fun parseStrings(json: String): List<String> = try {
        val arr = JSONArray(json)
        (0 until arr.length()).map { arr.getString(it) }
    } catch (e: Exception) {
        emptyList()
    }

    private fun parseSeries(json: String): List<ChartSeries> = try {
        val arr = JSONArray(json)
        (0 until arr.length()).map { i ->
            val obj = arr.getJSONObject(i)
            val values = obj.optJSONArray("values") ?: JSONArray()

            ChartSeries(
                name = obj.optString("name", ""),
                color = parseColor(obj.optString("color", "")),
                values = (0 until values.length()).map { j ->
                    if (values.isNull(j)) null else values.getDouble(j).toFloat()
                },
            )
        }
    } catch (e: Exception) {
        emptyList()
    }

    private fun parseColor(hex: String): Color = try {
        if (hex.isBlank()) DEFAULT_COLOR else Color(android.graphics.Color.parseColor(hex))
    } catch (e: IllegalArgumentException) {
        DEFAULT_COLOR
    }

    private fun autoMax(series: List<ChartSeries>): Float {
        val max = series.flatMap { it.values }.filterNotNull().maxOrNull() ?: 1f
        return if (max <= 0f) 1f else max
    }

    private fun drawGrid(scope: DrawScope) {
        val steps = 4
        for (i in 0..steps) {
            val y = scope.size.height * i / steps
            scope.drawLine(GRID_COLOR, Offset(0f, y), Offset(scope.size.width, y), strokeWidth = 1f)
        }
    }

    private fun drawLines(scope: DrawScope, series: List<ChartSeries>, yMax: Float) {
        series.forEach { s ->
            val count = s.values.size
            if (count < 2) return@forEach

            val stepX = scope.size.width / (count - 1)
            // A null value ends the current segment (a gap in the data — the
            // corps sat out that show); the next non-null value starts a new
            // one, so a stroked path never bridges over a missing point.
            var path: Path? = null

            s.values.forEachIndexed { i, value ->
                if (value == null) {
                    path?.let { scope.drawPath(it, s.color, style = Stroke(width = 3f)) }
                    path = null
                    return@forEachIndexed
                }

                val point = Offset(i * stepX, scope.size.height * (1f - value / yMax))

                if (path == null) {
                    path = Path().apply { moveTo(point.x, point.y) }
                } else {
                    path!!.lineTo(point.x, point.y)
                }

                scope.drawCircle(s.color, radius = 3f, center = point)
            }

            path?.let { scope.drawPath(it, s.color, style = Stroke(width = 3f)) }
        }
    }

    private fun drawBars(scope: DrawScope, series: List<ChartSeries>, yMax: Float) {
        val groupCount = series.maxOfOrNull { it.values.size } ?: return
        if (groupCount == 0) return

        val groupWidth = scope.size.width / groupCount
        val barWidth = groupWidth / (series.size + 1)

        series.forEachIndexed { seriesIndex, s ->
            s.values.forEachIndexed { i, value ->
                if (value == null) return@forEachIndexed

                val barHeight = scope.size.height * (value / yMax)
                val x = i * groupWidth + barWidth * (seriesIndex + 0.5f)

                scope.drawRect(
                    color = s.color,
                    topLeft = Offset(x, scope.size.height - barHeight),
                    size = Size(barWidth * 0.8f, barHeight),
                )
            }
        }
    }

    private fun drawRadar(scope: DrawScope, labels: List<String>, series: List<ChartSeries>, yMax: Float) {
        val axisCount = labels.size
        if (axisCount < 3) return

        val center = Offset(scope.size.width / 2f, scope.size.height / 2f)
        val radius = minOf(scope.size.width, scope.size.height) / 2f * 0.85f

        // Axis spokes, starting straight up and going clockwise.
        for (i in 0 until axisCount) {
            val angle = -Math.PI / 2 + i * (2 * Math.PI / axisCount)
            val end = Offset(
                center.x + (radius * cos(angle)).toFloat(),
                center.y + (radius * sin(angle)).toFloat(),
            )
            scope.drawLine(GRID_COLOR, center, end, strokeWidth = 1f)
        }

        series.forEach { s ->
            val path = Path()

            for (i in 0 until axisCount) {
                val value = (s.values.getOrNull(i) ?: 0f).coerceIn(0f, yMax)
                val angle = -Math.PI / 2 + i * (2 * Math.PI / axisCount)
                val r = radius * (value / yMax)
                val point = Offset(
                    center.x + (r * cos(angle)).toFloat(),
                    center.y + (r * sin(angle)).toFloat(),
                )

                if (i == 0) path.moveTo(point.x, point.y) else path.lineTo(point.x, point.y)
            }

            path.close()
            scope.drawPath(path, s.color.copy(alpha = 0.25f))
            scope.drawPath(path, s.color, style = Stroke(width = 2f))
        }
    }
}
