package com.ningso.aps.model

import com.google.zxing.BinaryBitmap
import com.google.zxing.RGBLuminanceSource
import com.google.zxing.common.HybridBinarizer
import com.google.zxing.qrcode.QRCodeReader
import org.junit.Assert.*
import org.junit.Test

class ShareQrTest {
    private val host = "192.0.2.10" // RFC 5737 documentation address, never a production default.
    private fun decode(payload: String): String {
        val matrix = qrMatrix(payload)
        val pixels = IntArray(matrix.width * matrix.height) { i ->
            if (matrix[i % matrix.width, i / matrix.width]) 0xFF000000.toInt() else 0xFFFFFFFF.toInt()
        }
        return QRCodeReader().decode(BinaryBitmap(HybridBinarizer(
            RGBLuminanceSource(matrix.width, matrix.height, pixels)))).text
    }
    @Test fun httpQrDecodesToExactCurrentConfiguration() {
        val payload = configText(host, ProxySettings(), Protocol.HTTP)
        assertEquals(payload, decode(payload)); assertTrue(payload.contains("Port: 8080"))
        assertTrue(payload.contains("Authentication: none"))
    }
    @Test fun socksQrDecodesToExactCurrentConfiguration() {
        val payload = configText(host, ProxySettings(), Protocol.SOCKS5)
        assertEquals(payload, decode(payload)); assertTrue(payload.contains("Protocol: SOCKS5"))
        assertTrue(payload.contains("Port: 1080"))
    }
    @Test fun changedPortProducesNewDecodablePayload() {
        val old = configText(host, ProxySettings(), Protocol.HTTP)
        val next = configText(host, ProxySettings(httpPort = 18080), Protocol.HTTP)
        assertNotEquals(old, next); assertEquals(next, decode(next))
    }
    @Test fun changedAddressProducesNewDecodablePayload() {
        val payload = configText("192.0.2.11", ProxySettings(), Protocol.HTTP)
        assertEquals(payload, decode(payload)); assertFalse(payload.contains(host))
    }
    @Test fun configurationNeverUsesUnspecifiedOrLoopbackAddress() {
        listOf("", "0.0.0.0", "127.0.0.1", "999.2.3.4", "example.com", "192.0.2.1;ls").forEach {
            assertFalse(validClientAddress(it))
            assertThrows(IllegalArgumentException::class.java) { configText(it, ProxySettings(), Protocol.HTTP) }
        }
    }
    @Test fun duplicatePortsCannotBeShared() {
        assertThrows(IllegalArgumentException::class.java) {
            configText(host, ProxySettings(httpPort = 1080), Protocol.HTTP)
        }
    }
    @Test fun socksCommandUsesRemoteDnsAndWindowsExecutable() {
        assertEquals("curl.exe --proxy socks5h://192.0.2.10:1080 https://example.com",
            curlCommand(host, ProxySettings(), Protocol.SOCKS5, windows = true))
    }
    @Test fun httpCommandUsesTheCurrentPort() {
        assertEquals("curl --proxy http://192.0.2.10:18080 https://example.com",
            curlCommand(host, ProxySettings(httpPort = 18080), Protocol.HTTP))
    }
}
