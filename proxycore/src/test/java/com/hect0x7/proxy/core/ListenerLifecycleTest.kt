package com.hect0x7.proxy.core

import java.net.ServerSocket
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Test

/** Local listener lifecycle only; no external request and no bypass of the self-connection guard. */
class ListenerLifecycleTest {
    @Test(timeout = 30000) fun realListenersSelfTestAndReleaseTheirPorts() = runBlocking {
        val httpPort = ServerSocket(0).use { it.localPort }
        var socksPort = ServerSocket(0).use { it.localPort }
        while (socksPort == httpPort) socksPort = ServerSocket(0).use { it.localPort }
        val controller = ProxyServerController()
        try {
            controller.start(ProxyConfig(true, httpPort, true, socksPort))
            assertTrue(controller.stats.value.running)
            assertEquals(httpPort, controller.config.value?.httpPort)
            controller.reconfigure(ProxyConfig(true, httpPort, false, socksPort))
            assertTrue(controller.stats.value.running)
            assertEquals(false, controller.config.value?.socksEnabled)
        } finally { controller.stop() }
        assertFalse(controller.stats.value.running)
        assertNull(controller.config.value)
        ServerSocket(httpPort).use { assertTrue(it.isBound) }
        ServerSocket(socksPort).use { assertTrue(it.isBound) }
    }
    @Test(timeout = 30000) fun occupiedPortIsNotReportedAsRunning() = runBlocking {
        ServerSocket(0).use { occupied ->
            val controller = ProxyServerController()
            try {
                var failed = false
                try { controller.start(ProxyConfig(true, occupied.localPort, false)) }
                catch (_: IllegalStateException) { failed = true }
                assertTrue(failed)
                assertFalse(controller.stats.value.running)
                assertNotNull(controller.stats.value.lastError)
            } finally { controller.stop() }
        }
    }
}
