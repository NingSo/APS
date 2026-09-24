package com.ningso.aps.ui

import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.ningso.aps.model.*
import kotlin.math.cos
import kotlin.math.sin

@Composable
internal fun OverviewScreen(
    settings: ProxySettings, runtime: RuntimeSnapshot, host: String?, animate: Boolean,
    onPower: () -> Unit, onCopy: () -> Unit, onConnect: () -> Unit,
    onEdit: (Protocol) -> Unit, onRisk: () -> Unit, onDiagnostics: () -> Unit,
) {
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp),
        verticalArrangement = Arrangement.spacedBy(15.dp)) {
        val title = when (runtime.phase) {
            SessionPhase.RUNNING -> "连接，就绪。"
            SessionPhase.STARTING -> "正在唤醒连接。"
            SessionPhase.STOPPING -> "正在结束会话。"
            SessionPhase.FAILED -> "连接，需要处理。"
            SessionPhase.STOPPED -> "让连接，发生。"
        }
        PageHeading("", title, "手机变代理。让局域网里的设备，共享连接。") { StatePill(runtime.phase) }
        Box(Modifier.fillMaxWidth().height(215.dp), contentAlignment = Alignment.Center) {
            SignalOrbit(runtime.phase, animate, onPower)
            Column(Modifier.align(Alignment.CenterStart), verticalArrangement = Arrangement.spacedBy(7.dp)) {
                Eyebrow("LOCAL", color = Signal.Muted)
                Text("LAN / IPv4", fontFamily = Signal.Mono, fontSize = 10.sp)
                HorizontalDivider(Modifier.width(44.dp), color = Signal.Border)
                Eyebrow("TCP ONLY", color = Signal.Muted)
            }
            Column(Modifier.align(Alignment.CenterEnd), horizontalAlignment = Alignment.End,
                verticalArrangement = Arrangement.spacedBy(7.dp)) {
                Eyebrow("SESSION", color = Signal.Muted)
                Text(duration(runtime.elapsedMillis), fontFamily = Signal.Mono, fontSize = 10.sp)
                HorizontalDivider(Modifier.width(44.dp), color = Signal.Border)
                Eyebrow("NO CLOUD", color = Signal.Muted)
            }
            Text(when (runtime.phase) {
                SessionPhase.RUNNING -> "✓  本地监听已通过自检"
                SessionPhase.STARTING -> "绑定端口 · 校验本地监听"
                SessionPhase.STOPPING -> "正在关闭活动连接"
                SessionPhase.FAILED -> "!  启动失败，请检查端口或系统限制"
                SessionPhase.STOPPED -> "开启后，其他设备可通过手机转发请求"
            }, Modifier.align(Alignment.BottomCenter), fontSize = 10.sp,
                color = if (runtime.phase == SessionPhase.FAILED) Signal.Error else Signal.Secondary)
        }
        if (runtime.phase == SessionPhase.FAILED) {
            SignalCard {
                Text(runtime.lastError ?: "请查看诊断和会话日志", color = Signal.Error, fontSize = 12.sp)
                SecondaryAction("查看诊断", Glyph.ACTIVITY, onDiagnostics, Modifier.fillMaxWidth())
            }
        }
        SignalCard {
            Row(horizontalArrangement = Arrangement.spacedBy(15.dp)) {
                SmallMetric("↓  接收速率", runtime.receiveBytesPerSecond, Modifier.weight(1f), true,
                    samples = runtime.samples)
                Box(Modifier.width(1.dp).height(60.dp).background(Signal.Border))
                SmallMetric("↑  发送速率", runtime.sendBytesPerSecond, Modifier.weight(1f), true,
                    samples = runtime.samples, sent = true)
            }
        }
        if (host != null) {
            Surface(shape = RoundedCornerShape(20.dp), color = Signal.Accent, contentColor = Signal.OnAccent) {
                Column(Modifier.fillMaxWidth().padding(start = 18.dp, end = 12.dp, top = 18.dp, bottom = 8.dp)) {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Eyebrow("YOUR LOCAL ADDRESS", color = Signal.OnAccent.copy(alpha = .7f))
                        Text("局域网 · IPv4", fontSize = 9.sp, color = Signal.OnAccent)
                    }
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(host, Modifier.weight(1f).testTag("local-address"), fontFamily = Signal.Mono, fontSize = 24.sp)
                        IconControl(Glyph.COPY, "复制地址", onCopy, color = Signal.OnAccent)
                    }
                    HorizontalDivider(color = Signal.OnAccent.copy(alpha = .2f))
                    Row(Modifier.fillMaxWidth().heightIn(min = 48.dp).clickable(onClick = onConnect),
                        verticalAlignment = Alignment.CenterVertically) {
                        Text("客户端填写此地址，不是 0.0.0.0", Modifier.weight(1f), fontSize = 10.sp, color = Signal.OnAccent)
                        Text("连接设备", fontSize = 11.sp, color = Signal.OnAccent)
                        Spacer(Modifier.width(6.dp)); SignalIcon(Glyph.ARROW, Modifier.size(17.dp), Signal.OnAccent)
                    }
                }
            }
        } else {
            SignalCard {
                Text("先找到局域网", fontSize = 20.sp)
                Text("请让手机与客户端接入同一可信局域网。没有地址时，不生成连接二维码。", color = Signal.Secondary, fontSize = 12.sp)
                SecondaryAction("检查连接", Glyph.LINK, onDiagnostics, Modifier.fillMaxWidth())
            }
        }
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Text("代理协议", fontSize = 12.sp)
            Eyebrow("${runtime.activeConnections} ACTIVE CONNECTIONS")
        }
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Protocol.entries.forEach { protocol ->
                SignalCard(Modifier.weight(1f).clickable(enabled = !runtime.busy) { onEdit(protocol) }) {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                        Text(protocol.title, fontSize = 13.sp)
                        Text(if (runtime.listening(protocol, settings)) "●  运行中" else if (settings.enabled(protocol)) "已选用" else "已关闭",
                            fontSize = 9.sp, color = if (runtime.listening(protocol, settings)) Signal.Accent else Signal.Secondary)
                    }
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text(":${settings.port(protocol)}", fontFamily = Signal.Mono, fontSize = 18.sp)
                        SignalIcon(Glyph.TUNE, Modifier.size(19.dp))
                    }
                }
            }
        }
        Row(Modifier.fillMaxWidth().heightIn(min = 48.dp).clickable(onClick = onRisk),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(7.dp)) {
            SignalIcon(Glyph.ALERT, Modifier.size(16.dp), Signal.Warning)
            Text("无密码鉴权，仅在可信局域网开启。了解风险", fontSize = 10.sp, color = Signal.Warning)
        }
        Spacer(Modifier.height(5.dp))
    }
}

@Composable
private fun SignalOrbit(phase: SessionPhase, animate: Boolean, onPower: () -> Unit) {
    val spinning = animate && (phase == SessionPhase.RUNNING || phase == SessionPhase.STARTING)
    val angle = if (spinning) {
        val transition = rememberInfiniteTransition(label = "signal-orbit")
        val rotation by transition.animateFloat(0f, 360f,
            infiniteRepeatable(tween(if (phase == SessionPhase.STARTING) 2_500 else 20_000, easing = LinearEasing)),
            label = "orbit-angle")
        rotation
    } else 0f
    val color = phaseColor(phase)
    Box(Modifier.size(206.dp).padding(bottom = 13.dp), contentAlignment = Alignment.Center) {
        Canvas(Modifier.fillMaxSize()) {
            val radius = size.minDimension / 2
            val middle = center
            drawCircle(Brush.radialGradient(listOf(color.copy(alpha = .06f), Color.Transparent), middle, radius), radius)
            repeat(60) { tick ->
                val a = Math.toRadians(tick * 6.0)
                val r = radius - 3.dp.toPx()
                val inner = r - if (tick % 5 == 0) 4.dp.toPx() else 1.5.dp.toPx()
                drawLine(color.copy(alpha = if (tick % 5 == 0) .42f else .18f),
                    middle + Offset((cos(a) * inner).toFloat(), (sin(a) * inner).toFloat()),
                    middle + Offset((cos(a) * r).toFloat(), (sin(a) * r).toFloat()), 1.dp.toPx())
            }
            val r = radius - 18.dp.toPx()
            drawCircle(color.copy(alpha = .25f), r, style = Stroke(1.dp.toPx()))
            drawCircle(color.copy(alpha = .13f), r - 10.dp.toPx(), style = Stroke(1.dp.toPx()))
            drawCircle(color.copy(alpha = .12f), r - 22.dp.toPx(), style = Stroke(1.dp.toPx()))
            if (phase != SessionPhase.STOPPED) {
                drawArc(color, angle - 95f, 115f, false,
                    middle - Offset(r, r), Size(r * 2, r * 2), style = Stroke(1.5.dp.toPx(), cap = StrokeCap.Round))
                val a = Math.toRadians((angle + 20).toDouble())
                val dot = middle + Offset((cos(a) * r).toFloat(), (sin(a) * r).toFloat())
                drawCircle(color.copy(alpha = .13f), 7.dp.toPx(), dot)
                drawCircle(color, 2.5.dp.toPx(), dot)
            }
        }
        val busy = phase == SessionPhase.STARTING || phase == SessionPhase.STOPPING
        val label = when (phase) {
            SessionPhase.RUNNING -> "停止代理"
            SessionPhase.STARTING -> "正在校验"
            SessionPhase.STOPPING -> "正在停止"
            SessionPhase.FAILED -> "重新启动"
            SessionPhase.STOPPED -> "启动代理"
        }
        Column(Modifier.size(124.dp).clip(CircleShape)
            .clickable(enabled = !busy, role = Role.Button, onClickLabel = label, onClick = onPower)
            .semantics { stateDescription = label }.testTag("power-control"),
            verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally) {
            SignalIcon(if (phase == SessionPhase.FAILED) Glyph.ALERT else Glyph.POWER, Modifier.size(26.dp), color)
            Spacer(Modifier.height(11.dp))
            Text(label, fontSize = 17.sp, color = color)
            Spacer(Modifier.height(7.dp))
            Eyebrow(if (phase == SessionPhase.RUNNING) "TAP TO STOP" else if (busy) "PLEASE WAIT" else "TAP TO START", color = Signal.Secondary)
        }
    }
}
