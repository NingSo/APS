package com.hect0x7.proxy.core

import com.hect0x7.proxy.core.internal.StatsTracker
import com.hect0x7.proxy.core.internal.isSelfConnection
import com.hect0x7.proxy.core.internal.http.HttpTargetParser
import io.netty.buffer.Unpooled
import io.netty.handler.codec.http.DefaultHttpRequest
import io.netty.handler.codec.http.HttpHeaderNames
import io.netty.handler.codec.http.HttpMethod
import io.netty.handler.codec.http.HttpVersion
import java.net.InetSocketAddress
import org.junit.Assert.*
import org.junit.Test

class CoreRegressionTest {
    @Test fun invalidPortsAreRejected() {
        assertThrows(IllegalArgumentException::class.java) { ProxyConfig(true, 0, true, 1080) }
        assertThrows(IllegalArgumentException::class.java) { ProxyConfig(true, 8080, true, 8080) }
    }
    @Test fun httpAbsoluteUriBecomesOriginForm() {
        val request = DefaultHttpRequest(HttpVersion.HTTP_1_1, HttpMethod.GET, "http://example.com:8088/a?q=b")
        val parsed = HttpTargetParser.parse(request)
        assertEquals("example.com", parsed.host); assertEquals(8088, parsed.port)
        assertEquals("/a?q=b", parsed.originForm); assertFalse(parsed.connectTunnel)
    }
    @Test fun connectDefaultPortIs443() {
        val request = DefaultHttpRequest(HttpVersion.HTTP_1_1, HttpMethod.CONNECT, "example.com")
        val parsed = HttpTargetParser.parse(request)
        assertEquals(443, parsed.port); assertTrue(parsed.connectTunnel)
    }
    @Test fun relativeRequestRequiresHost() {
        val request = DefaultHttpRequest(HttpVersion.HTTP_1_1, HttpMethod.GET, "/path")
        assertThrows(IllegalArgumentException::class.java) { HttpTargetParser.parse(request) }
        request.headers().set(HttpHeaderNames.HOST, "example.com:8088")
        assertEquals(8088, HttpTargetParser.parse(request).port)
    }
    @Test fun loopbackAndSamePhoneAddressAreRejected() {
        val local = InetSocketAddress("192.0.2.10", 8080)
        assertTrue(isSelfConnection(local, InetSocketAddress("127.0.0.1", 20000)))
        assertTrue(isSelfConnection(local, InetSocketAddress("192.0.2.10", 20000)))
        assertFalse(isSelfConnection(local, InetSocketAddress("192.0.2.11", 20000)))
    }
    @Test fun connectionErrorsDoNotStopTheListenerState() {
        val stats = StatsTracker(); stats.starting(); stats.running()
        stats.recordError(IllegalStateException("one connection failed"))
        assertTrue(stats.stats.value.running)
    }
    @Test fun countersAreCountedAndResetOnNextStart() {
        val stats = StatsTracker(); stats.starting(); stats.running()
        stats.connectionOpened(); stats.connectionOpened(); stats.connectionClosed()
        val bytes = Unpooled.wrappedBuffer(byteArrayOf(1, 2, 3))
        try { stats.sent(bytes); stats.received(bytes) } finally { bytes.release() }
        assertEquals(1, stats.stats.value.activeConnections)
        assertEquals(2L, stats.stats.value.totalConnections)
        assertEquals(3L, stats.stats.value.sentBytes)
        stats.starting()
        assertEquals(0L, stats.stats.value.totalConnections); assertEquals(0L, stats.stats.value.sentBytes)
    }
}
