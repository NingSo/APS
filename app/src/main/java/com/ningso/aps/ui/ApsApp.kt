package com.ningso.aps.ui

import android.Manifest
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.Crossfade
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.saveable.rememberSaveableStateHolder
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LifecycleResumeEffect
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.compose.currentStateAsState
import com.ningso.aps.ProxyViewModel
import com.ningso.aps.model.*
import kotlinx.coroutines.flow.collect

private enum class Page { OVERVIEW, CONNECT, ACTIVITY, SETTINGS, DIAGNOSTICS }

@Composable
fun ApsApp(viewModel: ProxyViewModel) {
    val settings by viewModel.settings.collectAsStateWithLifecycle()
    val runtime by viewModel.runtime.collectAsStateWithLifecycle()
    val addresses by viewModel.addresses.collectAsStateWithLifecycle()
    val host by viewModel.selectedAddress.collectAsStateWithLifecycle()
    val system by viewModel.system.collectAsStateWithLifecycle()
    val lifecycle by LocalLifecycleOwner.current.lifecycle.currentStateAsState()
    val context = LocalContext.current
    val haptic = LocalHapticFeedback.current
    val snackbar = remember { SnackbarHostState() }
    val savedPages = rememberSaveableStateHolder()
    var page by rememberSaveable { mutableStateOf(Page.OVERVIEW) }
    var mainPage by rememberSaveable { mutableStateOf(Page.OVERVIEW) }
    var diagnosticParent by rememberSaveable { mutableStateOf(Page.CONNECT) }
    var consent by rememberSaveable { mutableStateOf(false) }
    var consentAddress by rememberSaveable { mutableStateOf<String?>(null) }
    var stopping by rememberSaveable { mutableStateOf(false) }
    var editing by rememberSaveable { mutableStateOf<Protocol?>(null) }
    var sharing by rememberSaveable { mutableStateOf<Protocol?>(null) }
    var information by rememberSaveable { mutableStateOf<InfoKind?>(null) }
    val reduced = settings.reducedMotion || system.motionDisabled

    fun goMain(target: Page) { page = target; mainPage = target }
    fun back() { page = if (page == Page.DIAGNOSTICS) diagnosticParent else mainPage }
    fun diagnostic() { diagnosticParent = page; page = Page.DIAGNOSTICS }
    fun copy(text: String) {
        runCatching { context.getSystemService(ClipboardManager::class.java).setPrimaryClip(ClipData.newPlainText("APS", text)) }
            .onSuccess { viewModel.note("已复制") }
            .onFailure { viewModel.note("复制失败，请手动填写配置") }
    }
    fun background() {
        runCatching { context.startActivity(viewModel.backgroundIntent()) }
            .onFailure {
                runCatching { context.startActivity(viewModel.applicationSettingsIntent()) }
                    .onFailure { viewModel.note("无法打开系统设置，请从系统应用列表进入 APS 设置") }
            }
    }
    val notificationRequest = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { allowed ->
        viewModel.refreshSystem()
        if (!allowed) viewModel.note("通知未允许；后台运行状态可在系统应用设置中检查")
        val confirmed = consentAddress
        consentAddress = null
        if (confirmed != null && confirmed == viewModel.selectedAddress.value) viewModel.start()
        else viewModel.note("地址已改变，请重新确认网络可信后启动")
    }
    val export = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("text/plain"), viewModel::writeExport)
    LaunchedEffect(Unit) { viewModel.messages.collect { snackbar.showSnackbar(it) } }
    // A changing address invalidates an open consent/share sheet rather than retaining a stale QR.
    LaunchedEffect(host) { sharing = null; consent = false }
    LifecycleResumeEffect(Unit) { viewModel.refreshSystem(); onPauseOrDispose { } }
    BackHandler(page == Page.SETTINGS || page == Page.DIAGNOSTICS) { back() }

    Box(Modifier.fillMaxSize().background(Signal.Background).windowInsetsPadding(WindowInsets.safeDrawing),
        contentAlignment = Alignment.TopCenter) {
        Scaffold(Modifier.fillMaxHeight().widthIn(max = 600.dp).fillMaxWidth(),
            containerColor = Signal.Background,
            contentWindowInsets = WindowInsets(0, 0, 0, 0),
            topBar = {
                Row(Modifier.fillMaxWidth().height(70.dp).padding(start = 14.dp, end = 8.dp),
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(9.dp)) {
                    if (page == Page.SETTINGS || page == Page.DIAGNOSTICS) {
                        IconControl(Glyph.BACK, "返回", { back() })
                    } else {
                        Surface(shape = RoundedCornerShape(10.dp), color = Signal.Background,
                            border = androidx.compose.foundation.BorderStroke(1.dp, Signal.Accent.copy(alpha = .35f))) {
                            SignalIcon(Glyph.LOGO, Modifier.padding(7.dp).size(25.dp), Signal.Accent)
                        }
                    }
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text(when (page) { Page.SETTINGS -> "设置"; Page.DIAGNOSTICS -> "连接诊断"; else -> "APS" }, fontSize = 19.sp)
                        Eyebrow("ANDROID PROXY SERVER", color = Signal.Secondary)
                    }
                    if (page != Page.SETTINGS && page != Page.DIAGNOSTICS) IconControl(Glyph.SETTINGS, "设置", { page = Page.SETTINGS })
                }
            },
            bottomBar = {
                Column {
                    HorizontalDivider(color = Signal.Border)
                    Row(Modifier.fillMaxWidth().height(69.dp).padding(horizontal = 24.dp)) {
                        listOf(Triple(Page.OVERVIEW, "概览", Glyph.TUNE), Triple(Page.CONNECT, "连接", Glyph.LINK),
                            Triple(Page.ACTIVITY, "活动", Glyph.ACTIVITY)).forEach { (target, label, glyph) ->
                            val selected = mainPage == target
                            Column(Modifier.weight(1f).fillMaxHeight().testTag("nav-${target.name.lowercase()}")
                                .selectable(selected, role = Role.Tab) { goMain(target) },
                                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
                                Box(Modifier.size(58.dp, 30.dp).background(
                                    if (selected) Signal.Accent.copy(alpha = .08f) else Signal.Background, RoundedCornerShape(50)),
                                    contentAlignment = Alignment.Center) {
                                    SignalIcon(glyph, Modifier.size(22.dp), if (selected) Signal.Accent else Signal.Muted)
                                }
                                Spacer(Modifier.height(4.dp))
                                Text(label, fontSize = 10.sp, color = if (selected) Signal.Accent else Signal.Muted)
                            }
                        }
                    }
                }
            },
            snackbarHost = { SnackbarHost(snackbar) },
        ) { padding ->
            Crossfade(page, Modifier.fillMaxSize().padding(padding), animationSpec = tween(if (reduced) 0 else 220), label = "page") { current ->
                savedPages.SaveableStateProvider(current.name) {
                    when (current) {
                        Page.OVERVIEW -> OverviewScreen(settings, runtime, host,
                            animate = !reduced && lifecycle.isAtLeast(Lifecycle.State.RESUMED),
                            onPower = {
                                haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                                when {
                                    runtime.running -> stopping = true
                                    runtime.busy -> Unit
                                    host == null -> diagnostic()
                                    !settings.hasProtocol -> { page = Page.SETTINGS; viewModel.note("请先选用至少一种协议") }
                                    else -> consent = true
                                }
                            },
                            onCopy = { host?.let(::copy) }, onConnect = { goMain(Page.CONNECT) },
                            onEdit = { editing = it }, onRisk = { information = InfoKind.RISK }, onDiagnostics = { diagnostic() })
                        Page.CONNECT -> ConnectScreen(settings, runtime, host, addresses, viewModel::selectAddress,
                            onCopy = ::copy, onShare = { sharing = it }, onDiagnostics = { diagnostic() }, onEdit = { editing = it })
                        Page.ACTIVITY -> ActivityScreen(runtime) { information = InfoKind.EXPORT }
                        Page.SETTINGS -> SettingsScreen(settings, system,
                            onEdit = { editing = it }, onBackground = ::background,
                            onSystemSettings = { runCatching { context.startActivity(viewModel.applicationSettingsIntent()) }
                                .onFailure { viewModel.note("请从系统应用列表打开 APS 设置") } },
                            onReduceMotion = viewModel::setReducedMotion, onDiagnostics = { diagnostic() },
                            onRoute = { information = InfoKind.ROUTE }, onAbout = { information = InfoKind.ABOUT })
                        Page.DIAGNOSTICS -> DiagnosticsScreen(runtime, host, system,
                            onRefresh = { viewModel.refreshSystem(); viewModel.note("已请求刷新本机状态；客户端和外网仍需另行验证") },
                            onBackground = ::background)
                    }
                }
            }
        }
    }
    if (consent) ConsentSheet(host, { consent = false }) {
        consent = false
        consentAddress = host
        if (Build.VERSION.SDK_INT >= 33 && ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS)
            != PackageManager.PERMISSION_GRANTED) notificationRequest.launch(Manifest.permission.POST_NOTIFICATIONS)
        else { consentAddress = null; viewModel.start() }
    }
    if (stopping) StopSheet(runtime, { stopping = false }) { stopping = false; viewModel.stop() }
    editing?.let { protocol -> PortSheet(protocol, settings, runtime, { editing = null }) { port, enabled ->
        viewModel.saveProtocol(protocol, port, enabled); editing = null
    } }
    sharing?.let { protocol -> host?.let { address ->
        ShareSheet(address, settings, protocol, { sharing = null }, ::copy) { text ->
            runCatching { context.startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"; putExtra(Intent.EXTRA_TEXT, text)
            }, "分享 APS 配置")) }.onFailure { viewModel.note("系统分享不可用，请使用复制配置") }
        }
    } }
    information?.let { kind -> InfoSheet(kind, { information = null }) {
        information = null
        viewModel.prepareExport()
        export.launch("aps-session.txt")
    } }
}
