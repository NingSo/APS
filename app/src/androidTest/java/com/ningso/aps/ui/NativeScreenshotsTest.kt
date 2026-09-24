package com.ningso.aps.ui

import android.graphics.Bitmap
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.ningso.aps.SystemStatus
import com.ningso.aps.model.*
import java.io.File
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/** Explicit test fixtures. These values are never shipped in the production app or shared online by it.
 * Captures native screen components, not a claim of approved pixel fidelity or live network traffic.
 */
@RunWith(AndroidJUnit4::class)
class NativeScreenshotsTest {
    @get:Rule val compose = createComposeRule()
    private val settings = ProxySettings(reducedMotion = true)
    private val host = "192.0.2.10"
    private val running = RuntimeSnapshot(
        phase = SessionPhase.RUNNING, config = settings.config(), elapsedMillis = 754000,
        bytesReceived = 147_849_216, bytesSent = 15_099_494,
        receiveBytesPerSecond = 1_280_000, sendBytesPerSecond = 124_000,
        activeConnections = 6, totalConnections = 134,
        samples = List(60) { i -> RateSample(i * 1000L, (i % 13 * 74000 + 200000).toLong(), (i % 7 * 9000 + 14000).toLong()) },
        log = listOf(LogEntry(1, "12:00:00", LogLevel.INFO, "本地监听自检通过 · HTTP / SOCKS5")),
    )
    private fun capture(name: String, content: @Composable () -> Unit) {
        compose.setContent { SignalTheme {
            Column(Modifier.fillMaxSize().background(Signal.Background).padding(vertical = 12.dp)) {
                Text("APS / SIGNAL · NATIVE TEST FIXTURE", Modifier.padding(horizontal = 20.dp, vertical = 12.dp),
                    fontFamily = Signal.Mono, fontSize = 11.sp, color = Signal.Secondary)
                Box(Modifier.weight(1f)) { content() }
            }
        } }
        compose.waitForIdle()
        if (name == "02-connect") compose.waitUntil(10000) {
            compose.onAllNodesWithContentDescription("当前代理配置二维码").fetchSemanticsNodes().isNotEmpty()
        }
        val bitmap = compose.onRoot().captureToImage().asAndroidBitmap()
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val directory = File(context.filesDir, "screenshots").apply { mkdirs() }
        File(directory, "$name.png").outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
    }
    @Test fun overview() = capture("01-overview") {
        OverviewScreen(settings, running, host, false, {}, {}, {}, {}, {}, {})
    }
    @Test fun connect() = capture("02-connect") {
        ConnectScreen(settings, running, host, listOf(host), {}, {}, {}, {}, {})
    }
    @Test fun activity() = capture("03-activity") { ActivityScreen(running, {}) }
    @Test fun settings() = capture("04-settings") {
        SettingsScreen(settings, SystemStatus(true, true, true), {}, {}, {}, {}, {}, {}, {})
    }
    @Test fun diagnostics() = capture("05-diagnostics") {
        DiagnosticsScreen(running, host, SystemStatus(true, true, true), {}, {})
    }
    @Test fun standby() = capture("06-standby") {
        OverviewScreen(settings, RuntimeSnapshot(), host, false, {}, {}, {}, {}, {}, {})
    }
    @Test fun failed() = capture("07-failed") {
        OverviewScreen(settings, RuntimeSnapshot(phase = SessionPhase.FAILED, lastError = "HTTP port 8080 is unavailable or already in use"),
            host, false, {}, {}, {}, {}, {}, {})
    }
}
