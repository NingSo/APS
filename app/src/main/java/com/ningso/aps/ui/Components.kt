package com.ningso.aps.ui

import android.graphics.Bitmap
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.ningso.aps.model.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

@Composable
internal fun SignalCard(
    modifier: Modifier = Modifier,
    color: Color = Signal.Surface,
    content: @Composable ColumnScope.() -> Unit,
) {
    Surface(modifier.fillMaxWidth(), shape = RoundedCornerShape(20.dp), color = color,
        border = BorderStroke(1.dp, Signal.Border)) {
        Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(12.dp), content = content)
    }
}

@Composable
internal fun Eyebrow(text: String, modifier: Modifier = Modifier, color: Color = Signal.Secondary) {
    Text(text, modifier, color = color, fontFamily = Signal.Mono, fontSize = 9.sp, letterSpacing = 1.5.sp)
}

@Composable
internal fun PageHeading(eyebrow: String, title: String, subtitle: String, trailing: (@Composable () -> Unit)? = null) {
    Column(verticalArrangement = Arrangement.spacedBy(7.dp)) {
        if (eyebrow.isNotEmpty()) Eyebrow(eyebrow)
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(title, Modifier.weight(1f), style = MaterialTheme.typography.headlineLarge)
            trailing?.invoke()
        }
        Text(subtitle, color = Signal.Secondary, style = MaterialTheme.typography.bodyMedium)
    }
}

@Composable
internal fun IconControl(glyph: Glyph, label: String, onClick: () -> Unit, modifier: Modifier = Modifier,
    color: Color = Signal.Text, enabled: Boolean = true) {
    IconButton(onClick, modifier.sizeIn(minWidth = 48.dp, minHeight = 48.dp).testTag(label)
        .semantics { contentDescription = label }, enabled = enabled) {
        SignalIcon(glyph, Modifier.size(21.dp), if (enabled) color else Signal.Muted)
    }
}

@Composable
internal fun PrimaryAction(text: String, onClick: () -> Unit, modifier: Modifier = Modifier, enabled: Boolean = true) {
    Button(onClick, modifier.fillMaxWidth().heightIn(min = 50.dp), enabled = enabled,
        shape = RoundedCornerShape(14.dp),
        colors = ButtonDefaults.buttonColors(containerColor = Signal.Accent, contentColor = Signal.OnAccent)) {
        Text(text, fontSize = 14.sp, fontWeight = FontWeight.Medium)
    }
}

@Composable
internal fun SecondaryAction(text: String, glyph: Glyph, onClick: () -> Unit,
    modifier: Modifier = Modifier, enabled: Boolean = true) {
    OutlinedButton(onClick, modifier.heightIn(min = 48.dp), enabled = enabled,
        shape = RoundedCornerShape(14.dp), border = BorderStroke(1.dp, Signal.Border),
        colors = ButtonDefaults.outlinedButtonColors(contentColor = Signal.Text, containerColor = Signal.Raised),
        contentPadding = PaddingValues(horizontal = 14.dp, vertical = 10.dp)) {
        SignalIcon(glyph, Modifier.size(18.dp), if (enabled) Signal.Text else Signal.Muted)
        Spacer(Modifier.width(9.dp))
        Text(text, fontSize = 12.sp)
    }
}

@Composable
internal fun StatePill(phase: SessionPhase) {
    val color = phaseColor(phase)
    val label = when (phase) {
        SessionPhase.RUNNING -> "RUNNING"
        SessionPhase.STARTING -> "VERIFYING"
        SessionPhase.STOPPING -> "STOPPING"
        SessionPhase.FAILED -> "FAILED"
        SessionPhase.STOPPED -> "STANDBY"
    }
    Surface(color = color.copy(alpha = .08f), shape = RoundedCornerShape(7.dp), border = BorderStroke(1.dp, color.copy(alpha = .25f))) {
        Row(Modifier.padding(horizontal = 8.dp, vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(5.dp).background(color, RoundedCornerShape(50)))
            Spacer(Modifier.width(5.dp))
            Text(label, fontFamily = Signal.Mono, fontSize = 9.sp, color = color)
        }
    }
}

internal fun phaseColor(phase: SessionPhase): Color = when (phase) {
    SessionPhase.RUNNING -> Signal.Accent
    SessionPhase.STARTING, SessionPhase.STOPPING -> Signal.Warning
    SessionPhase.FAILED -> Signal.Error
    SessionPhase.STOPPED -> Signal.Secondary
}

@Composable
internal fun SmallMetric(label: String, value: Long, modifier: Modifier = Modifier, rate: Boolean = false,
    color: Color = Signal.Text, samples: List<RateSample> = emptyList(), sent: Boolean = false) {
    val formatted = amount(value, rate)
    Column(modifier, verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(label, fontSize = 10.sp, color = Signal.Secondary)
        Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
            Text(formatted.value, fontSize = 25.sp, fontFamily = Signal.Mono, color = color)
            Text(formatted.unit, fontSize = 9.sp, color = Signal.Secondary, modifier = Modifier.padding(bottom = 4.dp))
        }
        if (samples.isNotEmpty()) TrafficPlot(samples, Modifier.fillMaxWidth().height(17.dp), onlySent = sent, compact = true)
    }
}

/** Plots real monotonic samples in a fixed 60-second window; empty data remains empty. */
@Composable
internal fun TrafficPlot(samples: List<RateSample>, modifier: Modifier, onlySent: Boolean = false, compact: Boolean = false) {
    Canvas(modifier) {
        if (!compact) repeat(4) { i ->
            val y = size.height * i / 3
            drawLine(Signal.Border, Offset(0f, y), Offset(size.width, y), 1f,
                pathEffect = PathEffect.dashPathEffect(floatArrayOf(2f, 7f)))
        }
        if (samples.isEmpty()) {
            if (compact) drawLine(Signal.Border, Offset(0f, size.height / 2), Offset(size.width, size.height / 2), 1f)
            return@Canvas
        }
        val last = samples.last().atMillis
        val maximum = samples.maxOf { maxOf(it.received, it.sent) }.coerceAtLeast(1).toFloat() * 1.15f
        fun path(sent: Boolean): Path = Path().apply {
            samples.forEachIndexed { index, point ->
                val x = ((point.atMillis - last + 60_000).toFloat() / 60_000).coerceIn(0f, 1f) * size.width
                val y = size.height - (if (sent) point.sent else point.received) / maximum * size.height
                if (index == 0) moveTo(x, y) else lineTo(x, y)
            }
        }
        if (!compact) {
            val area = path(false).apply {
                lineTo(size.width, size.height)
                val firstX = ((samples.first().atMillis - last + 60_000).toFloat() / 60_000).coerceIn(0f, 1f) * size.width
                lineTo(firstX, size.height); close()
            }
            drawPath(area, Brush.verticalGradient(listOf(Signal.Accent.copy(alpha = .16f), Color.Transparent)))
        }
        if (!onlySent) drawPath(path(false), Signal.Accent, style = Stroke(1.7.dp.toPx(), cap = StrokeCap.Round))
        if (!compact || onlySent) drawPath(path(true), Signal.Mint, style = Stroke(1.2.dp.toPx(), cap = StrokeCap.Round,
            pathEffect = if (compact) null else PathEffect.dashPathEffect(floatArrayOf(4f, 5f))))
        val tip = if (onlySent) samples.last().sent else samples.last().received
        drawCircle(if (onlySent) Signal.Mint else Signal.Accent, 2.dp.toPx(), Offset(size.width, size.height - tip / maximum * size.height))
    }
}

private sealed interface QrResult {
    data object Loading : QrResult
    data object Failed : QrResult
    data class Ready(val bitmap: ImageBitmap) : QrResult
}

@Composable
internal fun QrCode(text: String, modifier: Modifier = Modifier) {
    val result by produceState<QrResult>(QrResult.Loading, text) {
        value = QrResult.Loading
        value = withContext(Dispatchers.Default) {
            runCatching {
                val matrix = qrMatrix(text)
                val pixels = IntArray(matrix.width * matrix.height) { index ->
                    if (matrix[index % matrix.width, index / matrix.width]) android.graphics.Color.BLACK else android.graphics.Color.WHITE
                }
                QrResult.Ready(Bitmap.createBitmap(pixels, matrix.width, matrix.height, Bitmap.Config.ARGB_8888).asImageBitmap())
            }.getOrElse { QrResult.Failed }
        }
    }
    Box(modifier.clip(RoundedCornerShape(12.dp)).background(Color.White).padding(6.dp), contentAlignment = Alignment.Center) {
        when (val current = result) {
            is QrResult.Ready -> Image(current.bitmap, "当前代理配置二维码", Modifier.fillMaxSize(), filterQuality = FilterQuality.None)
            QrResult.Failed -> Text("请复制配置", color = Color.Black, fontSize = 10.sp)
            QrResult.Loading -> CircularProgressIndicator(Modifier.size(18.dp), color = Signal.OnAccent, strokeWidth = 2.dp)
        }
    }
}
