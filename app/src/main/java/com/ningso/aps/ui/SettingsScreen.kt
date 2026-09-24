package com.ningso.aps.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.ningso.aps.BuildConfig
import com.ningso.aps.SystemStatus
import com.ningso.aps.model.*

@Composable
internal fun SettingsScreen(settings: ProxySettings, system: SystemStatus,
    onEdit: (Protocol) -> Unit, onBackground: () -> Unit, onSystemSettings: () -> Unit,
    onReduceMotion: (Boolean) -> Unit, onDiagnostics: () -> Unit, onRoute: () -> Unit, onAbout: () -> Unit) {
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp),
        verticalArrangement = Arrangement.spacedBy(17.dp)) {
        PageHeading("FINE-TUNE YOUR SIGNAL", "少一点干扰。", "只保留与你的连接有关的设置。")
        Eyebrow("PROTOCOLS / 代理协议")
        SignalCard {
            Protocol.entries.forEachIndexed { index, protocol ->
                SettingsRow(protocol.title, ":${settings.port(protocol)} · ${if (settings.enabled(protocol)) "已选用" else "已关闭"}",
                    Glyph.TUNE, { onEdit(protocol) })
                if (index == 0) HorizontalDivider(color = Signal.Border)
            }
        }
        Eyebrow("STAY AVAILABLE / 后台运行")
        SignalCard {
            SettingsRow("电池优化", if (system.batteryUnrestricted) "已允许忽略电池优化" else "允许后，锁屏运行更可靠", Glyph.POWER, onBackground)
            HorizontalDivider(color = Signal.Border)
            SettingsRow("服务通知", if (system.notificationsAllowed) "通知已允许 · 可从通知停止代理" else "通知未允许 · 点击前往系统设置", Glyph.INFO, onSystemSettings)
            Text("不同厂商仍可能限制后台活动；这里的设置不能保证系统永不终止服务。", fontSize = 11.sp, color = Signal.Secondary, lineHeight = 19.sp)
        }
        Eyebrow("NETWORK / 网络")
        SignalCard {
            SettingsRow("出站路由", "遵循 Android 当前默认路由", Glyph.GLOBE, onRoute)
            HorizontalDivider(color = Signal.Border)
            SettingsRow("连接诊断", "逐层检查，不把监听成功当作外网连通", Glyph.ACTIVITY, onDiagnostics)
        }
        Eyebrow("APPEARANCE / 显示")
        SignalCard {
            Row(Modifier.fillMaxWidth().heightIn(min = 48.dp), verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text("减少动态效果", fontSize = 14.sp)
                    Text(if (system.motionDisabled) "系统已关闭动画" else "停止信号轨道循环动画", fontSize = 11.sp, color = Signal.Secondary)
                }
                Switch(settings.reducedMotion, onReduceMotion)
            }
            HorizontalDivider(color = Signal.Border)
            Text("SIGNAL / 夜航", fontFamily = Signal.Mono, color = Signal.Accent, fontSize = 14.sp)
            Text("黑曜石 × 荧光绿 · 跟随系统字体缩放", color = Signal.Secondary, fontSize = 11.sp)
        }
        SignalCard {
            Text("你的连接，留在你的设备。", fontSize = 17.sp)
            Text("没有账号、广告、遥测或云端历史。配置保存在应用私有存储；会话数据仅保存在内存。复制、分享和导出由你主动发起。",
                color = Signal.Secondary, fontSize = 12.sp, lineHeight = 21.sp)
            SettingsRow("APS ${BuildConfig.VERSION_NAME}", "开放源代码 · Apache License 2.0", Glyph.INFO, onAbout)
        }
        Spacer(Modifier.height(12.dp))
    }
}

@Composable
private fun SettingsRow(title: String, subtitle: String, glyph: Glyph, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().heightIn(min = 62.dp).clickable(onClick = onClick),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        SignalIcon(glyph, Modifier.size(21.dp), Signal.Accent)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(5.dp)) {
            Text(title, fontSize = 14.sp)
            Text(subtitle, color = Signal.Secondary, fontSize = 11.sp, lineHeight = 18.sp)
        }
        SignalIcon(Glyph.ARROW, Modifier.size(18.dp), Signal.Secondary)
    }
}

@Composable
internal fun DiagnosticsScreen(runtime: RuntimeSnapshot, host: String?, system: SystemStatus,
    onRefresh: () -> Unit, onBackground: () -> Unit) {
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)) {
        PageHeading("FOLLOW THE CONNECTION", "找到连接的断点。", "先检查手机本地，再验证客户端与目标。")
        SecondaryAction("刷新本机状态", Glyph.ACTIVITY, onRefresh, Modifier.fillMaxWidth())
        DiagnosticStep("01", "局域网地址", if (host == null) "未发现" else "已发现",
            host?.let { "$it\n这是本机地址，不保证客户端可以访问。" } ?: "确认手机已接入可信局域网，避免访客网络或 AP 隔离。",
            if (host == null) Signal.Warning else Signal.Accent)
        DiagnosticStep("02", "本地监听", if (runtime.running) "启动自检通过" else if (runtime.phase == SessionPhase.FAILED) "启动失败" else "尚未监听",
            if (runtime.running) "已启用的监听器完成本地接受连接自检。这不是外网连通性测试。"
            else runtime.lastError ?: "启用至少一种协议，并在概览页启动服务。", if (runtime.running) Signal.Accent else Signal.Warning)
        DiagnosticStep("03", "客户端 → 手机", if (runtime.activeConnections > 0) "有入站连接" else "待验证",
            if (runtime.activeConnections > 0) "当前观察到 ${runtime.activeConnections} 条活动 TCP 连接，不代表 ${runtime.activeConnections} 台设备。"
            else "在另一台设备填写正确的地址与协议端口。检查同一局域网、访客隔离与防火墙。", Signal.Secondary)
        DiagnosticStep("04", "手机 → 目标", "未主动测试",
            "先确认手机本身能访问目标。其他 VPN 的分流策略会影响出站路由。此页面不会向外部测试站点发送请求。", Signal.Secondary)
        DiagnosticStep("05", "锁屏持续运行", if (system.batteryUnrestricted && system.notificationsAllowed) "基础设置已完成" else "建议检查设置",
            "保持前台服务通知，并允许忽略电池优化；部分设备还需要允许后台活动或自启动。实际稳定性需要锁屏测试。",
            if (system.batteryUnrestricted && system.notificationsAllowed) Signal.Accent else Signal.Warning)
        SecondaryAction("检查后台运行设置", Glyph.POWER, onBackground, Modifier.fillMaxWidth())
        Text("HTTP / HTTPS CONNECT 与 SOCKS5 TCP CONNECT 不可混用端口。当前不支持用户名密码、UDP ASSOCIATE 或 BIND。",
            fontSize = 11.sp, lineHeight = 19.sp, color = Signal.Secondary)
        Spacer(Modifier.height(12.dp))
    }
}

@Composable
private fun DiagnosticStep(number: String, title: String, status: String, detail: String,
    color: androidx.compose.ui.graphics.Color) {
    SignalCard {
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(number, fontFamily = Signal.Mono, color = Signal.Accent, fontSize = 15.sp)
            Text(title, Modifier.weight(1f), fontSize = 15.sp)
            Text(status, color = color, fontSize = 10.sp)
        }
        Text(detail, color = Signal.Secondary, fontSize = 12.sp, lineHeight = 21.sp)
    }
}
