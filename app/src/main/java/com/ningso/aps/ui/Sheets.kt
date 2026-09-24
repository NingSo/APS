package com.ningso.aps.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.ningso.aps.model.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SignalSheet(onDismiss: () -> Unit, content: @Composable ColumnScope.() -> Unit) {
    ModalBottomSheet(onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = Signal.Surface, contentColor = Signal.Text,
        shape = RoundedCornerShape(topStart = 27.dp, topEnd = 27.dp)) {
        Column(Modifier.fillMaxWidth().imePadding().verticalScroll(rememberScrollState()).padding(horizontal = 22.dp)
            .padding(bottom = 25.dp), verticalArrangement = Arrangement.spacedBy(17.dp), content = content)
    }
}

@Composable
internal fun ConsentSheet(host: String?, onDismiss: () -> Unit, onStart: () -> Unit) {
    var trusted by rememberSaveable { mutableStateOf(false) }
    SignalSheet(onDismiss) {
        Eyebrow("BEFORE YOU START", color = Signal.Warning)
        Text("只在可信网络中开启。", fontSize = 25.sp)
        Text("代理监听所有本地接口，没有用户名和密码。可访问手机端口的设备能够使用代理；请勿在不可信网络中开启，或将端口映射到公网。",
            color = Signal.Secondary, fontSize = 13.sp, lineHeight = 23.sp)
        Text("当前连接地址：${host ?: "未发现"}", fontFamily = Signal.Mono, fontSize = 12.sp)
        Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).clickable { trusted = !trusted }, verticalAlignment = Alignment.CenterVertically) {
            Checkbox(trusted, { trusted = it }, Modifier.testTag("trust-network"))
            Text("我确认当前网络可信，并了解无鉴权风险。", Modifier.weight(1f), fontSize = 13.sp)
        }
        PrimaryAction("确认并启动", onStart, Modifier.testTag("confirm-start"), trusted && host != null)
        TextButton(onClick = onDismiss, Modifier.fillMaxWidth()) { Text("暂不开启", color = Signal.Secondary) }
    }
}

@Composable
internal fun StopSheet(runtime: RuntimeSnapshot, onDismiss: () -> Unit, onStop: () -> Unit) {
    SignalSheet(onDismiss) {
        Eyebrow("END THIS SESSION", color = Signal.Warning)
        Text("结束本次连接？", fontSize = 25.sp)
        Text("${runtime.activeConnections} 条活动连接将关闭。当前会话统计和日志会被清空；协议偏好与端口仍会保留。需要保留日志时，请先取消并前往活动页导出。",
            color = Signal.Secondary, fontSize = 13.sp, lineHeight = 23.sp)
        PrimaryAction("停止并清空会话", onStop, Modifier.testTag("confirm-stop"))
        TextButton(onClick = onDismiss, Modifier.fillMaxWidth()) { Text("继续运行", color = Signal.Secondary) }
    }
}

@Composable
internal fun PortSheet(protocol: Protocol, settings: ProxySettings, runtime: RuntimeSnapshot,
    onDismiss: () -> Unit, onSave: (Int, Boolean) -> Unit) {
    var port by rememberSaveable(protocol) { mutableStateOf(settings.port(protocol).toString()) }
    var enabled by rememberSaveable(protocol) { mutableStateOf(settings.enabled(protocol)) }
    val other = settings.port(if (protocol == Protocol.HTTP) Protocol.SOCKS5 else Protocol.HTTP)
    val problem = portProblem(port, other)
    val changed = port.toIntOrNull() != settings.port(protocol) || enabled != settings.enabled(protocol)
    SignalSheet(onDismiss) {
        Eyebrow("LISTENER CONFIGURATION")
        Text("${protocol.title} 监听配置", fontSize = 25.sp)
        Text(if (protocol == Protocol.HTTP) "HTTP 转发与 HTTPS CONNECT 隧道。" else "SOCKS5 TCP CONNECT；不支持 UDP 或 BIND。",
            fontSize = 12.sp, color = Signal.Secondary, lineHeight = 21.sp)
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Text("选用此协议", Modifier.weight(1f), fontSize = 14.sp)
            Switch(enabled, { enabled = it }, Modifier.testTag("protocol-enabled"))
        }
        OutlinedTextField(port, { port = it.take(12) }, Modifier.fillMaxWidth().testTag("port-input"),
            label = { Text("端口 / PORT") }, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
            textStyle = androidx.compose.ui.text.TextStyle(fontFamily = Signal.Mono, fontSize = 32.sp),
            singleLine = true, isError = problem != null,
            supportingText = { Text(problem ?: "范围 1–65535；两个协议必须使用不同端口", fontSize = 11.sp) },
            shape = RoundedCornerShape(14.dp))
        if ((port.toIntOrNull() ?: 65535) in 1..1023) {
            Text("低位端口可能受到系统限制；格式有效不代表能够成功绑定。", color = Signal.Warning, fontSize = 12.sp)
        }
        if (runtime.running) {
            Text("保存会重建整个代理服务，${runtime.activeConnections} 条现有连接可能中断，统计从零开始。若两个协议都关闭，则停止服务。",
                color = Signal.Warning, fontSize = 12.sp, lineHeight = 21.sp)
        }
        PrimaryAction(if (runtime.running) "保存并重建服务" else "保存配置",
            { port.toIntOrNull()?.let { onSave(it, enabled) } }, Modifier.testTag("save-port"),
            enabled = problem == null && changed && !runtime.busy)
        TextButton(onClick = onDismiss, Modifier.fillMaxWidth()) { Text("取消", color = Signal.Secondary) }
    }
}

@Composable
internal fun ShareSheet(host: String, settings: ProxySettings, protocol: Protocol,
    onDismiss: () -> Unit, onCopy: (String) -> Unit, onShare: (String) -> Unit) {
    val payload = remember(host, settings, protocol) { configText(host, settings, protocol) }
    SignalSheet(onDismiss) {
        Eyebrow("PASS THE CONNECTION")
        Text("把连接交给下一台。", fontSize = 25.sp)
        QrCode(payload, Modifier.size(240.dp).align(Alignment.CenterHorizontally))
        Text("${protocol.title} / $host:${settings.port(protocol)}", Modifier.align(Alignment.CenterHorizontally),
            fontFamily = Signal.Mono, fontSize = 13.sp)
        Text("二维码是纯文本配置，需要手动填入客户端。无鉴权，仅限可信局域网；分享给谁，由你决定。",
            fontSize = 12.sp, lineHeight = 21.sp, color = Signal.Secondary)
        PrimaryAction("分享配置文本", { onShare(payload) })
        SecondaryAction("复制配置", Glyph.COPY, { onCopy(payload) }, Modifier.fillMaxWidth())
    }
}

internal enum class InfoKind { RISK, ROUTE, ABOUT, EXPORT }

@Composable
internal fun InfoSheet(kind: InfoKind, onDismiss: () -> Unit, onExport: () -> Unit) {
    val context = LocalContext.current
    SignalSheet(onDismiss) {
        Eyebrow("APS / SIGNAL")
        Text(when (kind) {
            InfoKind.RISK -> "明确边界，放心使用。"
            InfoKind.ROUTE -> "出站，跟随系统。"
            InfoKind.ABOUT -> "更少干扰，更多连接。"
            InfoKind.EXPORT -> "导出这次会话？"
        }, fontSize = 25.sp)
        val text = when (kind) {
            InfoKind.RISK -> "这是局域网代理服务器，不是 VPN 客户端。服务监听所有本地接口且不提供用户名密码认证。HTTPS CONNECT 不等于所有代理流量都加密。请只在可信局域网运行，不要将监听端口映射到公网。停止服务可关闭现有转发连接。"
            InfoKind.ROUTE -> "APS 不创建 VpnService 或占用 VPN 槽位。出站连接遵循 Android 当前默认路由；其他 VPN 的按应用分流等策略可能影响结果。本应用不显示未经验证的 VPN 名称、出口地址或访问目标的连通性。改变 VPN 状态后，可停止并重新启动代理验证。"
            InfoKind.ABOUT -> "APS / SIGNAL\n基于 hect0x7 的 Android Proxy Server，采用 Apache License 2.0。代理内核保留上游实现，界面与服务交互按 SIGNAL 设计重建。\n\n没有账号、广告、遥测或自动上传。以下为随安装包附带的开源声明与许可证。"
            InfoKind.EXPORT -> "日志可能包含网络地址及错误细节。导出前请确认内容；导出文件由你选择保存位置，停止服务不会删除已经导出的副本。此操作不会上传到应用服务器。"
        }
        Text(text, color = Signal.Secondary, fontSize = 13.sp, lineHeight = 23.sp)
        if (kind == InfoKind.ABOUT) {
            val license by produceState("正在读取许可证") {
                value = withContext(Dispatchers.IO) {
                    runCatching { context.assets.open("open_source.txt").bufferedReader().use { it.readText() } }
                        .getOrDefault("许可证包含在源码仓库的 LICENSE / NOTICE 文件中。")
                }
            }
            Text(license, fontSize = 11.sp, lineHeight = 19.sp, fontFamily = Signal.Mono, color = Signal.Secondary)
        }
        if (kind == InfoKind.EXPORT) PrimaryAction("选择保存位置", onExport, Modifier.testTag("confirm-export"))
        TextButton(onClick = onDismiss, Modifier.fillMaxWidth()) { Text("返回", color = Signal.Accent) }
    }
}
