package com.ningso.aps.model

import com.hect0x7.proxy.core.ProxyConfig
import java.util.Locale

data class ProxySettings(
    val httpEnabled: Boolean = true,
    val httpPort: Int = 8080,
    val socksEnabled: Boolean = true,
    val socksPort: Int = 1080,
    val reducedMotion: Boolean = false,
) {
    val hasProtocol: Boolean get() = httpEnabled || socksEnabled
    fun config() = ProxyConfig(httpEnabled, httpPort, socksEnabled, socksPort)
    fun validPorts() = httpPort in 1..65535 && socksPort in 1..65535 && httpPort != socksPort
}

enum class Protocol(val title: String) { HTTP("HTTP"), SOCKS5("SOCKS5") }
enum class SessionPhase { STOPPED, STARTING, RUNNING, STOPPING, FAILED }
enum class LogLevel { INFO, WARN, ERROR }

data class LogEntry(val id: Long, val time: String, val level: LogLevel, val message: String)
data class RateSample(val atMillis: Long, val received: Long, val sent: Long)
data class RuntimeSnapshot(
    val phase: SessionPhase = SessionPhase.STOPPED,
    val config: ProxyConfig? = null,
    val startedAtMillis: Long = 0,
    val elapsedMillis: Long = 0,
    val bytesReceived: Long = 0,
    val bytesSent: Long = 0,
    val receiveBytesPerSecond: Long = 0,
    val sendBytesPerSecond: Long = 0,
    val activeConnections: Int = 0,
    val totalConnections: Long = 0,
    val lastError: String? = null,
    val samples: List<RateSample> = emptyList(),
    val log: List<LogEntry> = emptyList(),
) {
    val running: Boolean get() = phase == SessionPhase.RUNNING
    val busy: Boolean get() = phase == SessionPhase.STARTING || phase == SessionPhase.STOPPING
    fun listening(protocol: Protocol): Boolean = running && when (protocol) {
        Protocol.HTTP -> config?.httpEnabled == true
        Protocol.SOCKS5 -> config?.socksEnabled == true
    }
    fun listening(protocol: Protocol, settings: ProxySettings): Boolean =
        listening(protocol) && settings.enabled(protocol) && settings.port(protocol) == when (protocol) {
            Protocol.HTTP -> config?.httpPort
            Protocol.SOCKS5 -> config?.socksPort
        }
}

/** Counter deltas use a monotonic clock. A new listener session starts a new sampler. */
class RateSampler(private var at: Long, private var received: Long = 0, private var sent: Long = 0) {
    fun sample(now: Long, nextReceived: Long, nextSent: Long): RateSample {
        val elapsed = (now - at).coerceAtLeast(1)
        val result = RateSample(
            now,
            ((nextReceived - received).coerceAtLeast(0).toDouble() * 1000 / elapsed).toLong(),
            ((nextSent - sent).coerceAtLeast(0).toDouble() * 1000 / elapsed).toLong(),
        )
        at = now
        received = nextReceived
        sent = nextSent
        return result
    }
}

fun appendSample(samples: List<RateSample>, next: RateSample): List<RateSample> =
    (samples + next).filter { it.atMillis > next.atMillis - 60_000 }.takeLast(60)

fun portProblem(text: String, otherPort: Int): String? {
    if (text.isEmpty()) return "请输入端口"
    if (text.any { it !in '0'..'9' }) return "端口只能包含数字"
    if (text.length > 5) return "端口范围为 1–65535"
    val port = text.toIntOrNull() ?: return "请输入有效端口"
    return when {
        port !in 1..65535 -> "端口范围为 1–65535"
        port == otherPort -> "HTTP 与 SOCKS5 不能使用同一端口"
        else -> null
    }
}

fun ProxySettings.port(protocol: Protocol): Int = when (protocol) {
    Protocol.HTTP -> httpPort
    Protocol.SOCKS5 -> socksPort
}
fun ProxySettings.enabled(protocol: Protocol): Boolean = when (protocol) {
    Protocol.HTTP -> httpEnabled
    Protocol.SOCKS5 -> socksEnabled
}
fun ProxySettings.withProtocol(protocol: Protocol, port: Int, enabled: Boolean): ProxySettings =
    when (protocol) {
        Protocol.HTTP -> copy(httpPort = port, httpEnabled = enabled)
        Protocol.SOCKS5 -> copy(socksPort = port, socksEnabled = enabled)
    }

fun configText(host: String, settings: ProxySettings, protocol: Protocol): String {
    require(validClientAddress(host)) { "No client-reachable IPv4 address" }
    require(settings.validPorts()) { "Invalid proxy ports" }
    return "APS / SIGNAL\nProtocol: ${protocol.title}\nHost: $host\nPort: ${settings.port(protocol)}\nAuthentication: none\nTrusted LAN only. Configure the client manually."
}

fun validClientAddress(host: String): Boolean {
    val parts = host.split('.')
    return parts.size == 4 && parts.all { part ->
        part.isNotEmpty() && part.length <= 3 && part.all { it in '0'..'9' } &&
            part.toIntOrNull()?.let { it in 0..255 } == true
    } && host != "0.0.0.0" && parts.first() != "127"
}

fun curlCommand(host: String, settings: ProxySettings, protocol: Protocol, windows: Boolean = false): String {
    require(validClientAddress(host))
    val scheme = if (protocol == Protocol.HTTP) "http" else "socks5h"
    return "${if (windows) "curl.exe" else "curl"} --proxy $scheme://$host:${settings.port(protocol)} https://example.com"
}

data class Amount(val value: String, val unit: String)
fun amount(bytes: Long, rate: Boolean = false): Amount {
    val units = listOf("B", "KiB", "MiB", "GiB", "TiB")
    var value = bytes.coerceAtLeast(0).toDouble()
    var unit = 0
    while (value >= 1024 && unit < units.lastIndex) { value /= 1024; unit++ }
    val text = if (unit == 0) value.toLong().toString() else String.format(Locale.ROOT, "%.1f", value)
    return Amount(text, units[unit] + if (rate) "/s" else "")
}
fun duration(millis: Long): String {
    val seconds = millis.coerceAtLeast(0) / 1000
    return String.format(Locale.ROOT, "%02d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
}
fun exportLogs(log: List<LogEntry>): String = log.joinToString("\n") {
    "${it.time}  ${it.level.name}  ${it.message.replace('\n', ' ').replace('\r', ' ')}"
}
