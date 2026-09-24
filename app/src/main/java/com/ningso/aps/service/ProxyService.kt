package com.ningso.aps.service

import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.IBinder
import android.os.PowerManager
import android.os.SystemClock
import androidx.core.content.ContextCompat
import com.hect0x7.proxy.core.ProxyServerController
import com.ningso.aps.MainActivity
import com.ningso.aps.R
import com.ningso.aps.model.*
import java.time.LocalTime
import java.time.format.DateTimeFormatter
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class ProxyService : Service() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val controller = ProxyServerController()
    private val commands = Channel<Command>(Channel.UNLIMITED)
    private var owner = 0L
    private var latestStartId = 0
    private var nextLogId = 0L
    private var sampler: RateSampler? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var observedError: String? = null

    private data class Command(val startId: Int, val settings: ProxySettings?)

    override fun onCreate() {
        super.onCreate()
        owner = SessionStore.attach()
        getSystemService(NotificationManager::class.java).createNotificationChannel(
            NotificationChannel(CHANNEL_ID, getString(R.string.service_channel), NotificationManager.IMPORTANCE_LOW)
                .apply { setShowBadge(false) },
        )
        scope.launch {
            for (command in commands) apply(command)
        }
        scope.launch {
            while (isActive) {
                delay(1_000)
                sampleRuntime()
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        latestStartId = startId
        if (intent?.action == ACTION_STOP) {
            commands.trySend(Command(startId, null))
        } else if (intent?.action == ACTION_APPLY) {
            try {
                startForeground(NOTIFICATION_ID, notification(null))
                commands.trySend(Command(startId, ProxyPreferences(this).read()))
            } catch (error: RuntimeException) {
                fail(error.message ?: "Foreground service could not start")
                stopSelfResult(startId)
            }
        } else {
            stopSelfResult(startId)
        }
        return START_NOT_STICKY
    }

    private suspend fun apply(command: Command) {
        val settings = command.settings
        if (settings == null || !settings.hasProtocol) {
            SessionStore.update(owner) { it.copy(phase = SessionPhase.STOPPING) }
            try {
                withContext(Dispatchers.IO) { controller.stop() }
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (_: Exception) {
                // Explicit stop still releases resources and clears the app's session.
                // onDestroy makes a second best-effort controller cleanup.
            } finally {
                releaseWakeLock()
                sampler = null
                observedError = null
                SessionStore.update(owner) { RuntimeSnapshot() }
                // A queued newer start must not lose its foreground-service notification.
                if (command.startId == latestStartId && stopSelfResult(command.startId)) {
                    stopForeground(STOP_FOREGROUND_REMOVE)
                }
            }
            return
        }
        val config = settings.config()
        if (SessionStore.state.value.running && controller.config.value == config) {
            getSystemService(NotificationManager::class.java).notify(NOTIFICATION_ID, notification(settings))
            return
        }
        SessionStore.update(owner) { RuntimeSnapshot(phase = SessionPhase.STARTING) }
        log(LogLevel.INFO, "正在绑定端口并校验本地监听")
        sampler = null
        observedError = null
        try {
            withContext(Dispatchers.IO) { controller.reconfigure(config) }
            acquireWakeLock()
            val now = SystemClock.elapsedRealtime()
            sampler = RateSampler(now)
            SessionStore.update(owner) {
                it.copy(phase = SessionPhase.RUNNING, config = config, startedAtMillis = now)
            }
            log(LogLevel.INFO, "本地监听自检通过 · ${protocolNames(settings)}")
            getSystemService(NotificationManager::class.java).notify(NOTIFICATION_ID, notification(settings))
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (error: Exception) {
            withContext(NonCancellable + Dispatchers.IO) { runCatching { controller.stop() } }
            releaseWakeLock()
            fail(error.message ?: error.javaClass.simpleName)
            if (command.startId == latestStartId && stopSelfResult(command.startId)) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            }
        }
    }

    private fun sampleRuntime() {
        val current = SessionStore.state.value
        val activeSampler = sampler ?: return
        if (!current.running) return
        val stats = controller.stats.value
        val now = SystemClock.elapsedRealtime()
        val rate = activeSampler.sample(now, stats.receivedBytes, stats.sentBytes)
        SessionStore.update(owner) {
            it.copy(
                elapsedMillis = (now - it.startedAtMillis).coerceAtLeast(0),
                bytesReceived = stats.receivedBytes,
                bytesSent = stats.sentBytes,
                receiveBytesPerSecond = rate.received,
                sendBytesPerSecond = rate.sent,
                activeConnections = stats.activeConnections,
                totalConnections = stats.totalConnections,
                samples = appendSample(it.samples, rate),
            )
        }
        val error = stats.lastError
        if (error != null && error != observedError) {
            // Forwarding failures and blocked self-connections are not listener-start failures.
            log(LogLevel.WARN, error)
        }
        observedError = error
    }

    private fun fail(message: String) {
        SessionStore.update(owner) {
            RuntimeSnapshot(phase = SessionPhase.FAILED, lastError = message, log = it.log)
        }
        log(LogLevel.ERROR, message)
    }

    private fun log(level: LogLevel, message: String) {
        val entry = LogEntry(++nextLogId, LocalTime.now().format(TIME_FORMAT), level, message.take(2_048))
        SessionStore.update(owner) { it.copy(log = (it.log + entry).takeLast(200)) }
    }

    @SuppressLint("WakelockTimeout")
    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        wakeLock = getSystemService(PowerManager::class.java)
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "$packageName:proxy")
            .apply { setReferenceCounted(false); acquire() }
    }

    private fun releaseWakeLock() {
        wakeLock?.takeIf { it.isHeld }?.release()
        wakeLock = null
    }

    private fun notification(settings: ProxySettings?): Notification {
        val open = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val stop = PendingIntent.getService(
            this, 1, Intent(this, ProxyService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val details = if (settings == null) getString(R.string.service_starting)
            else getString(R.string.service_running, protocolNames(settings))
        return Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_signal)
            .setContentTitle(getString(R.string.service_title))
            .setContentText(details)
            .setContentIntent(open)
            .setOnlyAlertOnce(true)
            .setOngoing(true)
            .setCategory(Notification.CATEGORY_SERVICE)
            .addAction(Notification.Action.Builder(null, getString(R.string.service_stop), stop).build())
            .build()
    }

    override fun onDestroy() {
        commands.close()
        scope.cancel()
        releaseWakeLock()
        SessionStore.detach(owner)
        // Never block the main thread while Netty shuts down its event loops.
        CoroutineScope(Dispatchers.IO).launch { runCatching { controller.stop() } }
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        private const val CHANNEL_ID = "aps_proxy"
        private const val NOTIFICATION_ID = 71
        private const val ACTION_APPLY = "com.ningso.aps.APPLY"
        private const val ACTION_STOP = "com.ningso.aps.STOP"
        private val TIME_FORMAT = DateTimeFormatter.ofPattern("HH:mm:ss")

        fun start(context: Context) {
            ContextCompat.startForegroundService(context, Intent(context, ProxyService::class.java).setAction(ACTION_APPLY))
        }
        fun stop(context: Context) {
            context.startService(Intent(context, ProxyService::class.java).setAction(ACTION_STOP))
        }
        private fun protocolNames(settings: ProxySettings): String = buildList {
            if (settings.httpEnabled) add("HTTP :${settings.httpPort}")
            if (settings.socksEnabled) add("SOCKS5 :${settings.socksPort}")
        }.joinToString(" · ")
    }
}
