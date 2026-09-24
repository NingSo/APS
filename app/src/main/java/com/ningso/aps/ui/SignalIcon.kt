package com.ningso.aps.ui

import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.withTransform
import kotlin.math.cos
import kotlin.math.sin

internal enum class Glyph { LOGO, POWER, SETTINGS, LINK, ACTIVITY, COPY, ARROW, BACK, CLOSE, CHECK, QR, TUNE, DOWNLOAD, SEARCH, ALERT, GLOBE, INFO }

@Composable
internal fun SignalIcon(glyph: Glyph, modifier: Modifier, color: Color = Signal.Text) {
    Canvas(modifier) {
        withTransform({ scale(size.width / 24f, size.height / 24f, Offset.Zero) }) {
            val stroke = Stroke(1.5f, cap = StrokeCap.Round)
            fun line(x1: Float, y1: Float, x2: Float, y2: Float) =
                drawLine(color, Offset(x1, y1), Offset(x2, y2), strokeWidth = 1.5f, cap = StrokeCap.Round)
            fun box(x: Float, y: Float, w: Float, h: Float) =
                drawRoundRect(color, Offset(x, y), Size(w, h), CornerRadius(1.3f), style = stroke)
            when (glyph) {
                Glyph.LOGO -> {
                    val p = Path().apply { moveTo(4f, 20f); lineTo(12f, 4f); lineTo(20f, 20f) }
                    drawPath(p, color, style = stroke)
                    line(8f, 13f, 16f, 13f); line(9f, 20f, 15f, 20f)
                    drawCircle(color, 1.1f, Offset(19f, 4f))
                }
                Glyph.POWER -> {
                    drawArc(color, -48f, 276f, false, Offset(4f, 4f), Size(16f, 16f), style = stroke)
                    line(12f, 2f, 12f, 11f)
                }
                Glyph.SETTINGS -> {
                    drawCircle(color, 6.5f, Offset(12f, 12f), style = stroke)
                    drawCircle(color, 2.5f, Offset(12f, 12f), style = stroke)
                    repeat(8) { i ->
                        val a = i * Math.PI / 4
                        line((12 + cos(a) * 6.5).toFloat(), (12 + sin(a) * 6.5).toFloat(),
                            (12 + cos(a) * 9).toFloat(), (12 + sin(a) * 9).toFloat())
                    }
                }
                Glyph.LINK -> {
                    drawArc(color, 130f, 285f, false, Offset(10f, 2f), Size(11f, 11f), style = stroke)
                    drawArc(color, -50f, 285f, false, Offset(3f, 11f), Size(11f, 11f), style = stroke)
                    line(9f, 15f, 15f, 9f)
                }
                Glyph.ACTIVITY -> {
                    val p = Path().apply { moveTo(2f, 13f); lineTo(7f, 13f); lineTo(10f, 5f)
                        lineTo(14f, 20f); lineTo(17f, 10f); lineTo(22f, 10f) }
                    drawPath(p, color, style = stroke)
                }
                Glyph.COPY -> { box(8f, 7f, 11f, 14f); line(5f, 17f, 5f, 3f); line(5f, 3f, 15f, 3f) }
                Glyph.ARROW -> { line(4f, 12f, 20f, 12f); line(15f, 7f, 20f, 12f); line(20f, 12f, 15f, 17f) }
                Glyph.BACK -> { line(20f, 12f, 4f, 12f); line(9f, 7f, 4f, 12f); line(4f, 12f, 9f, 17f) }
                Glyph.CLOSE -> { line(6f, 6f, 18f, 18f); line(18f, 6f, 6f, 18f) }
                Glyph.CHECK -> { line(4f, 12f, 10f, 18f); line(10f, 18f, 20f, 6f) }
                Glyph.QR -> { box(3f, 3f, 6f, 6f); box(15f, 3f, 6f, 6f); box(3f, 15f, 6f, 6f)
                    box(14f, 14f, 3f, 3f); line(21f, 14f, 21f, 21f); line(14f, 21f, 17f, 21f) }
                Glyph.TUNE -> { line(3f, 7f, 21f, 7f); line(3f, 17f, 21f, 17f)
                    line(8f, 4f, 8f, 10f); line(16f, 14f, 16f, 20f) }
                Glyph.DOWNLOAD -> { line(12f, 3f, 12f, 15f); line(7f, 10f, 12f, 15f); line(12f, 15f, 17f, 10f)
                    line(4f, 16f, 4f, 21f); line(4f, 21f, 20f, 21f); line(20f, 21f, 20f, 16f) }
                Glyph.SEARCH -> { drawCircle(color, 6f, Offset(10f, 10f), style = stroke); line(15f, 15f, 21f, 21f) }
                Glyph.ALERT -> { val p = Path().apply { moveTo(12f, 3f); lineTo(22f, 21f); lineTo(2f, 21f); close() }
                    drawPath(p, color, style = stroke); line(12f, 9f, 12f, 14f); drawCircle(color, 0.9f, Offset(12f, 18f)) }
                Glyph.GLOBE -> { drawCircle(color, 9f, Offset(12f, 12f), style = stroke)
                    drawOval(color, Offset(8f, 3f), Size(8f, 18f), style = stroke); line(3f, 12f, 21f, 12f) }
                Glyph.INFO -> { drawCircle(color, 9f, Offset(12f, 12f), style = stroke)
                    line(12f, 11f, 12f, 17f); drawCircle(color, 0.9f, Offset(12f, 7f)) }
            }
        }
    }
}
