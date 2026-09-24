package com.ningso.aps.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.ningso.aps.model.*

@Composable
internal fun ActivityScreen(runtime: RuntimeSnapshot, onExport: () -> Unit) {
    var query by rememberSaveable { mutableStateOf("") }
    var filter by rememberSaveable { mutableIntStateOf(0) }
    val filtered = remember(runtime.log, query, filter) {
        runtime.log.filter { entry ->
            (filter == 0 || entry.level.ordinal == filter - 1) && entry.message.contains(query, ignoreCase = true)
        }.asReversed()
    }
    LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(start = 20.dp, end = 20.dp, bottom = 25.dp),
        verticalArrangement = Arrangement.spacedBy(15.dp)) {
        item {
            PageHeading("LIVE / IN THIS SESSION", "看见每次流动。", "仅展示当前会话，不上传、不建立云端历史。") {
                SignalIcon(Glyph.ACTIVITY, Modifier.size(24.dp))
            }
        }
        item {
            SignalCard {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text("传输速率", fontSize = 14.sp)
                    Eyebrow(if (runtime.running) "60s / LIVE" else "WAITING")
                }
                Row {
                    SmallMetric("●  接收", runtime.receiveBytesPerSecond, Modifier.weight(1f), true, Signal.Accent)
                    SmallMetric("●  发送", runtime.sendBytesPerSecond, Modifier.weight(1f), true, Signal.Mint)
                }
                Box(Modifier.fillMaxWidth().height(115.dp), contentAlignment = Alignment.Center) {
                    TrafficPlot(runtime.samples, Modifier.fillMaxSize())
                    if (runtime.samples.isEmpty()) Text("启动代理后显示真实流量", fontSize = 11.sp, color = Signal.Secondary)
                }
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Eyebrow("−60s", color = Signal.Muted)
                    Text("自适应刻度", fontSize = 9.sp, color = Signal.Muted)
                    Eyebrow("现在", color = Signal.Muted)
                }
            }
        }
        item {
            SignalCard {
                Row(horizontalArrangement = Arrangement.spacedBy(18.dp)) {
                    SmallMetric("本次累计接收", runtime.bytesReceived, Modifier.weight(1f))
                    SmallMetric("本次累计发送", runtime.bytesSent, Modifier.weight(1f))
                }
                HorizontalDivider(color = Signal.Border)
                Row(horizontalArrangement = Arrangement.spacedBy(18.dp)) {
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        Text("活动连接 · 不是设备数", fontSize = 10.sp, color = Signal.Secondary)
                        Text("${runtime.activeConnections} 条", fontFamily = Signal.Mono, fontSize = 22.sp)
                    }
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        Text("会话累计连接", fontSize = 10.sp, color = Signal.Secondary)
                        Text("${runtime.totalConnections} 次", fontFamily = Signal.Mono, fontSize = 22.sp)
                    }
                }
            }
        }
        item {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("会话日志", fontSize = 15.sp)
                Spacer(Modifier.width(10.dp))
                Text(runtime.log.size.toString(), Modifier.background(Signal.Raised, RoundedCornerShape(6.dp)).padding(5.dp),
                    fontFamily = Signal.Mono, fontSize = 10.sp, color = Signal.Secondary)
                Spacer(Modifier.weight(1f))
                IconControl(Glyph.DOWNLOAD, "导出日志", onExport, enabled = runtime.log.isNotEmpty())
            }
            OutlinedTextField(query, { query = it }, Modifier.fillMaxWidth(), singleLine = true,
                placeholder = { Text("搜索错误、协议或事件", fontSize = 12.sp) },
                leadingIcon = { SignalIcon(Glyph.SEARCH, Modifier.size(17.dp), Signal.Secondary) },
                shape = RoundedCornerShape(12.dp))
            ChoiceRow(listOf("全部", "信息", "提醒", "错误"), filter, { filter = it }, compact = true)
        }
        if (filtered.isEmpty()) {
            item {
                Text(if (runtime.log.isEmpty()) "尚无会话记录。启动服务后，生命周期事件会出现在这里。" else "没有匹配的日志。试试其他关键词或筛选条件。",
                    Modifier.padding(vertical = 20.dp), color = Signal.Secondary, fontSize = 12.sp, lineHeight = 21.sp)
            }
        }
        items(filtered, key = { it.id }) { entry ->
            Column(verticalArrangement = Arrangement.spacedBy(9.dp)) {
                HorizontalDivider(color = Signal.Border)
                Row(horizontalArrangement = Arrangement.spacedBy(9.dp), verticalAlignment = Alignment.Top) {
                    Text(entry.time, fontFamily = Signal.Mono, fontSize = 10.sp, color = Signal.Muted)
                    Text(entry.level.name, fontFamily = Signal.Mono, fontSize = 10.sp,
                        color = when (entry.level) { LogLevel.INFO -> Signal.Accent; LogLevel.WARN -> Signal.Warning; LogLevel.ERROR -> Signal.Error })
                    Text(entry.message, Modifier.weight(1f), fontSize = 11.sp, lineHeight = 18.sp)
                }
            }
        }
        item { Text("内存中最多保留 200 条记录。停止会话后清空统计和日志；重建监听时开始新会话。",
            color = Signal.Muted, fontSize = 10.sp, lineHeight = 18.sp) }
    }
}
