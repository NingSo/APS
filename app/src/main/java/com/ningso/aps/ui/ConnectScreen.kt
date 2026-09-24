package com.ningso.aps.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.ningso.aps.model.*

@Composable
internal fun ChoiceRow(labels: List<String>, selected: Int, onSelect: (Int) -> Unit, modifier: Modifier = Modifier,
    compact: Boolean = false) {
    if (compact) {
        Row(modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(7.dp)) {
            labels.forEachIndexed { index, label ->
                FilterChip(selected == index, { onSelect(index) }, label = { Text(label, fontSize = 11.sp) },
                    modifier = Modifier.heightIn(min = 48.dp), shape = RoundedCornerShape(9.dp),
                    colors = FilterChipDefaults.filterChipColors(selectedContainerColor = Signal.Raised, selectedLabelColor = Signal.Accent))
            }
        }
    } else {
        Surface(modifier.fillMaxWidth(), color = Signal.Background, shape = RoundedCornerShape(14.dp),
            border = BorderStroke(1.dp, Signal.Border)) {
            Row(Modifier.padding(4.dp)) {
                labels.forEachIndexed { index, label ->
                    Box(Modifier.weight(1f).heightIn(min = 48.dp)
                        .background(if (selected == index) Signal.Raised else Signal.Background, RoundedCornerShape(10.dp))
                        .selectable(selected == index, role = Role.Tab) { onSelect(index) }, contentAlignment = Alignment.Center) {
                        Text(label, Modifier.padding(8.dp), fontSize = 12.sp,
                            color = if (selected == index) Signal.Text else Signal.Secondary)
                    }
                }
            }
        }
    }
}

@Composable
internal fun ConnectScreen(
    settings: ProxySettings, runtime: RuntimeSnapshot, host: String?, addresses: List<String>,
    onAddress: (String) -> Unit, onCopy: (String) -> Unit, onShare: (Protocol) -> Unit,
    onDiagnostics: () -> Unit, onEdit: (Protocol) -> Unit,
) {
    var protocol by rememberSaveable { mutableStateOf(Protocol.HTTP) }
    var client by rememberSaveable { mutableIntStateOf(0) }
    var addressMenu by remember { mutableStateOf(false) }
    val active = runtime.listening(protocol, settings)
    val selected = settings.enabled(protocol)
    val payload = host?.let { configText(it, settings, protocol) }
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp),
        verticalArrangement = Arrangement.spacedBy(15.dp)) {
        PageHeading("MAKE THE CONNECTION", "下一台，连接。", "让客户端与手机处于同一可信局域网。") {
            SignalIcon(Glyph.LINK, Modifier.size(24.dp))
        }
        ChoiceRow(Protocol.entries.map { it.title + if (runtime.listening(it, settings)) " ●" else "" }, protocol.ordinal,
            { protocol = Protocol.entries[it] })
        if (host != null && payload != null) {
            Surface(color = Signal.Accent, contentColor = Signal.OnAccent, shape = RoundedCornerShape(22.dp)) {
                Column(Modifier.fillMaxWidth().padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Column(verticalArrangement = Arrangement.spacedBy(5.dp)) {
                            Eyebrow("CONNECTION PASS", color = Signal.OnAccent.copy(alpha = .6f))
                            Text("${protocol.title} / TCP", fontFamily = Signal.Mono, fontSize = 22.sp)
                        }
                        SignalIcon(Glyph.GLOBE, Modifier.size(24.dp), Signal.OnAccent)
                    }
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            Text("主机地址 / HOST", fontSize = 10.sp, color = Signal.OnAccent.copy(alpha = .65f))
                            Text(host, fontSize = 21.sp, fontFamily = Signal.Mono)
                            Row(horizontalArrangement = Arrangement.spacedBy(26.dp)) {
                                Column {
                                    Text("端口 / PORT", fontSize = 9.sp, color = Signal.OnAccent.copy(alpha = .65f))
                                    Text(settings.port(protocol).toString(), fontSize = 19.sp, fontFamily = Signal.Mono)
                                }
                                Column {
                                    Text("身份认证 / AUTH", fontSize = 9.sp, color = Signal.OnAccent.copy(alpha = .65f))
                                    Text("无", fontSize = 19.sp)
                                }
                            }
                        }
                        Box(Modifier.size(70.dp).clickable(onClickLabel = "展开二维码") { onShare(protocol) }) {
                            QrCode(payload, Modifier.fillMaxSize())
                        }
                    }
                    HorizontalDivider(color = Signal.OnAccent.copy(alpha = .25f))
                    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                        Text(when { active -> "本地监听中 · 请手动配置客户端"; !selected -> "此协议未选用，请先启用"; else -> "尚未监听 · 启动后可连接" },
                            Modifier.weight(1f), fontSize = 10.sp)
                        IconControl(Glyph.COPY, "复制配置", { onCopy(payload) }, color = Signal.OnAccent)
                    }
                }
            }
        } else {
            SignalCard {
                Text("还没有局域网地址", fontSize = 21.sp)
                Text("接入可信网络后，连接卡与二维码会根据实际地址生成。", color = Signal.Secondary)
                SecondaryAction("检查网络", Glyph.ACTIVITY, onDiagnostics, Modifier.fillMaxWidth())
            }
        }
        if (addresses.size > 1) {
            Box {
                TextButton(onClick = { addressMenu = true }, Modifier.heightIn(min = 48.dp)) {
                    Text("多个本机地址 · 选择客户端可达的地址", fontSize = 12.sp)
                }
                DropdownMenu(addressMenu, { addressMenu = false }) {
                    addresses.forEach { address ->
                        DropdownMenuItem(text = { Text(address, fontFamily = Signal.Mono) },
                            onClick = { onAddress(address); addressMenu = false })
                    }
                }
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            SecondaryAction("二维码分享", Glyph.QR, { onShare(protocol) }, Modifier.weight(1f), enabled = payload != null)
            SecondaryAction("连接诊断", Glyph.ACTIVITY, onDiagnostics, Modifier.weight(1f))
        }
        if (!selected) SecondaryAction("启用 ${protocol.title}", Glyph.TUNE, { onEdit(protocol) }, Modifier.fillMaxWidth())
        SignalCard {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text("在客户端上配置", fontSize = 15.sp)
                Eyebrow("3 STEPS")
            }
            ChoiceRow(listOf("Windows", "macOS", "Android", "命令行"), client, { client = it }, compact = true)
            val address = host ?: "手机显示的局域网 IP"
            val port = settings.port(protocol)
            val steps = when {
                client == 3 -> listOf("先确认客户端可以访问手机的局域网地址。", "执行下方命令；Windows PowerShell 请将 curl 改为 curl.exe。", "检查响应；命令需要在另一台客户端执行，不能在代理手机上执行。")
                protocol == Protocol.SOCKS5 && client != 1 -> listOf("系统的普通 HTTP 代理输入项不等于 SOCKS5。", "使用明确支持 SOCKS5 的客户端或应用，选择 SOCKS5 协议。", "填写 $address 和 $port，不设置用户名或密码。")
                client == 0 -> listOf("打开「设置 → 网络和 Internet → 代理」。", "在手动设置代理中，开启「使用代理服务器」。", "填写 $address 和 $port，保存。")
                client == 1 -> listOf("打开「系统设置 → 网络 → 当前网络 → 详细信息 → 代理」。", if (protocol == Protocol.HTTP) "选择网页代理（HTTP）；HTTPS 通过 CONNECT 转发。" else "选择 SOCKS 代理。", "填写 $address 和 $port，不启用身份认证。")
                else -> listOf("打开当前 Wi-Fi 的网络详情，编辑代理设置。", "选择「手动」，填写 $address 和 $port。", "保存后测试；不是所有 Android 应用都会遵从系统代理。")
            }
            steps.forEachIndexed { index, text ->
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text("${index + 1}", fontFamily = Signal.Mono, color = Signal.Accent, fontSize = 11.sp)
                    Text(text, color = Signal.Secondary, fontSize = 12.sp, lineHeight = 21.sp)
                }
            }
            if (client == 3 && host != null) {
                val command = curlCommand(host, settings, protocol)
                Surface(color = Signal.Background, shape = RoundedCornerShape(10.dp)) {
                    Column(Modifier.padding(12.dp)) {
                        Text(command, fontFamily = Signal.Mono, fontSize = 11.sp, lineHeight = 18.sp)
                        TextButton(onClick = { onCopy(command) }) { Text("复制命令", fontSize = 12.sp) }
                    }
                }
            }
        }
        Text("二维码只包含配置文本，不会自动设置系统代理。无身份鉴权，请勿将端口直接暴露到互联网。",
            color = Signal.Secondary, fontSize = 11.sp, lineHeight = 19.sp)
        Spacer(Modifier.height(15.dp))
    }
}
