package com.ningso.aps

import android.animation.ValueAnimator
import android.app.Application
import android.content.Intent
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkRequest
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.ningso.aps.model.*
import com.ningso.aps.service.ProxyService
import java.net.Inet4Address
import java.net.NetworkInterface
import java.util.Collections
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.channels.BufferOverflow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

data class SystemStatus(
    val batteryUnrestricted: Boolean = false,
    val notificationsAllowed: Boolean = false,
    val motionDisabled: Boolean = false,
)

class ProxyViewModel(application: Application) : AndroidViewModel(application) {
    private val preferences = ProxyPreferences(application)
    private val mutableSettings = MutableStateFlow(preferences.read())
    val settings = mutableSettings.asStateFlow()
    val runtime = SessionStore.state
    private val mutableAddresses = MutableStateFlow<List<String>>(emptyList())
    val addresses = mutableAddresses.asStateFlow()
    private val mutableSelected = MutableStateFlow<String?>(null)
    val selectedAddress = mutableSelected.asStateFlow()
    private val mutableSystem = MutableStateFlow(SystemStatus())
    val system = mutableSystem.asStateFlow()
    private val mutableMessages = MutableSharedFlow<String>(
        extraBufferCapacity = 4, onBufferOverflow = BufferOverflow.DROP_OLDEST,
    )
    val messages = mutableMessages.asSharedFlow()
    private val connectivity = application.getSystemService(ConnectivityManager::class.java)
    private var addressJob: Job? = null
    private var registered = false
    private var pendingExport: String? = null
    private val callback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) { refreshAddresses() }
        override fun onLost(network: Network) { refreshAddresses() }
        override fun onLinkPropertiesChanged(network: Network, linkProperties: LinkProperties) { refreshAddresses() }
    }

    init {
        // Observe link changes without collecting SSIDs, interface names or device identities.
        registered = runCatching {
            connectivity.registerNetworkCallback(NetworkRequest.Builder().build(), callback)
            true
        }.getOrDefault(false)
        refreshSystem()
    }

    fun note(message: String) { mutableMessages.tryEmit(message) }

    fun refreshSystem() {
        val context = getApplication<Application>()
        mutableSystem.value = SystemStatus(
            context.getSystemService(PowerManager::class.java).isIgnoringBatteryOptimizations(context.packageName),
            NotificationManagerCompat.from(context).areNotificationsEnabled(),
            !ValueAnimator.areAnimatorsEnabled(),
        )
        refreshAddresses()
    }

    fun refreshAddresses() {
        viewModelScope.launch {
            addressJob?.cancel()
            addressJob = viewModelScope.launch {
                val next = withContext(Dispatchers.IO) { localIpv4Addresses() }
                val previous = mutableSelected.value
                mutableAddresses.value = next
                if (previous !in next) mutableSelected.value = next.firstOrNull()
                if (previous != null && previous != mutableSelected.value) {
                    note("局域网地址已改变，请更新客户端配置并重新确认网络可信")
                }
            }
        }
    }

    fun selectAddress(address: String) {
        if (address in mutableAddresses.value) mutableSelected.value = address
    }

    fun start() {
        if (runtime.value.running || runtime.value.busy) return
        if (!settings.value.hasProtocol) { note("请至少启用一种代理协议"); return }
        if (selectedAddress.value == null) { note("请先接入可信局域网"); return }
        runCatching { ProxyService.start(getApplication()) }
            .onFailure {
                SessionStore.launchFailed(it.message ?: "系统未允许启动前台服务")
                note("启动失败，请查看诊断")
            }
    }

    fun stop() {
        if (!runtime.value.running && !runtime.value.busy) return
        runCatching { ProxyService.stop(getApplication()) }
            .onFailure { note("停止请求失败：${it.message ?: "请重试"}") }
    }

    /** The caller's confirmation sheet explains that a live configuration edit rebuilds both listeners. */
    fun saveProtocol(protocol: Protocol, port: Int, enabled: Boolean) {
        if (runtime.value.busy) { note("正在处理服务，请稍后重试"); return }
        val next = settings.value.withProtocol(protocol, port, enabled)
        if (!next.validPorts()) { note("端口无效或与另一协议冲突"); return }
        val previous = settings.value
        preferences.write(next)
        mutableSettings.value = next
        if (runtime.value.running && previous.config() != next.config()) {
            runCatching {
                if (next.hasProtocol) ProxyService.start(getApplication()) else ProxyService.stop(getApplication())
            }.onFailure {
                preferences.write(previous)
                mutableSettings.value = previous
                note("系统未接受重配置请求，已恢复原配置；请停止后重试")
            }
        }
    }

    fun setReducedMotion(enabled: Boolean) {
        val next = settings.value.copy(reducedMotion = enabled)
        preferences.write(next)
        mutableSettings.value = next
    }

    fun backgroundIntent(): Intent = Intent(
        Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
        Uri.parse("package:${getApplication<Application>().packageName}"),
    )
    fun applicationSettingsIntent(): Intent = Intent(
        Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
        Uri.parse("package:${getApplication<Application>().packageName}"),
    )

    fun prepareExport() { pendingExport = exportLogs(runtime.value.log) }
    fun writeExport(uri: Uri?) {
        val content = pendingExport
        pendingExport = null
        if (uri == null) return
        if (content == null) { note("会话已结束，请重新导出"); return }
        viewModelScope.launch {
            val result = withContext(Dispatchers.IO) {
                runCatching {
                    val stream = getApplication<Application>().contentResolver.openOutputStream(uri)
                        ?: error("无法打开所选文件")
                    stream.bufferedWriter(Charsets.UTF_8).use { it.write(content) }
                }
            }
            note(if (result.isSuccess) "会话日志已导出" else "导出失败，请重新选择文件位置")
        }
    }

    override fun onCleared() {
        if (registered) runCatching { connectivity.unregisterNetworkCallback(callback) }
        super.onCleared()
    }
}

private fun localIpv4Addresses(): List<String> = runCatching {
    Collections.list(NetworkInterface.getNetworkInterfaces()).asSequence()
        .filter { network ->
            network.isUp && !network.isLoopback &&
                listOf("tun", "tap", "p2p", "rmnet").none(network.name.lowercase()::contains)
        }
        .flatMap { Collections.list(it.inetAddresses).asSequence() }
        .filterIsInstance<Inet4Address>()
        .filterNot { it.isLoopbackAddress || it.isLinkLocalAddress || it.isAnyLocalAddress }
        .mapNotNull { it.hostAddress }
        .filter(::validClientAddress)
        .distinct().sorted().toList()
}.getOrDefault(emptyList())
