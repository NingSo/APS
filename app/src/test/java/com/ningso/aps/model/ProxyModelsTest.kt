package com.ningso.aps.model

import org.junit.Assert.*
import org.junit.Test

class ProxyModelsTest {
    @Test fun defaultProtocolPreferencesDoNotMeanRunning() {
        assertTrue(ProxySettings().hasProtocol)
        assertFalse(RuntimeSnapshot().running)
        assertFalse(RuntimeSnapshot().listening(Protocol.HTTP))
    }
    @Test fun portBoundariesAreAccepted() {
        assertNull(portProblem("1", 1080)); assertNull(portProblem("65535", 1080))
    }
    @Test fun emptyPortIsRejected() { assertNotNull(portProblem("", 1080)) }
    @Test fun zeroAndOverflowAreRejected() {
        listOf("0", "65536", "999999999999").forEach { assertNotNull(portProblem(it, 1080)) }
    }
    @Test fun nonAsciiAndSignedPortsAreRejected() {
        listOf("８０８０", "-1", "+80", "8 080", "80.0").forEach { assertNotNull(portProblem(it, 1080)) }
    }
    @Test fun portsCannotCollideEvenWhenOtherProtocolIsOff() {
        assertNotNull(portProblem("1080", 1080))
        assertFalse(ProxySettings(socksEnabled = false, httpPort = 1080).validPorts())
    }
    @Test fun editingHttpDoesNotChangeSocksOrMotionPreference() {
        val original = ProxySettings(reducedMotion = true)
        val changed = original.withProtocol(Protocol.HTTP, 8081, false)
        assertEquals(1080, changed.socksPort); assertTrue(changed.socksEnabled)
        assertTrue(changed.reducedMotion); assertFalse(changed.httpEnabled)
        assertEquals(8081, changed.httpPort)
    }
    @Test fun binaryUnitsAndRatesAreExplicit() {
        assertEquals(Amount("0", "B"), amount(-1))
        assertEquals(Amount("1023", "B"), amount(1023))
        assertEquals(Amount("1.0", "KiB/s"), amount(1024, true))
        assertEquals(Amount("1.5", "MiB"), amount(1_572_864))
    }
    @Test fun durationIsMonotonicDurationNotWallClock() {
        assertEquals("00:00:00", duration(-1))
        assertEquals("01:01:01", duration(3_661_000))
        assertEquals("25:00:00", duration(90_000_000))
    }
    @Test fun warningsDoNotTurnAListenerIntoAFailure() {
        val runtime = RuntimeSnapshot(phase = SessionPhase.RUNNING, config = ProxySettings().config(),
            lastError = "One destination refused a connection")
        assertTrue(runtime.running); assertTrue(runtime.listening(Protocol.HTTP))
    }
    @Test fun startingIsBusyButNotListening() {
        val runtime = RuntimeSnapshot(phase = SessionPhase.STARTING, config = ProxySettings().config())
        assertTrue(runtime.busy); assertFalse(runtime.listening(Protocol.HTTP))
    }
    @Test fun actualConfigurationDeterminesListening() {
        val runtime = RuntimeSnapshot(phase = SessionPhase.RUNNING,
            config = ProxySettings(httpEnabled = false).config())
        assertFalse(runtime.listening(Protocol.HTTP)); assertTrue(runtime.listening(Protocol.SOCKS5))
    }
    @Test fun aSavedButUnappliedPortMustNotBeLabeledListening() {
        val runtime = RuntimeSnapshot(phase = SessionPhase.RUNNING, config = ProxySettings().config())
        assertTrue(runtime.listening(Protocol.HTTP, ProxySettings()))
        assertFalse(runtime.listening(Protocol.HTTP, ProxySettings(httpPort = 18080)))
    }
    @Test fun ratesUseActualElapsedTime() {
        val sampler = RateSampler(1_000)
        assertEquals(RateSample(3_000, 1024, 512), sampler.sample(3_000, 2048, 1024))
        assertEquals(RateSample(3_500, 2048, 1024), sampler.sample(3_500, 3072, 1536))
    }
    @Test fun resetCountersNeverProduceNegativeRates() {
        val sampler = RateSampler(0, received = 5000, sent = 5000)
        assertEquals(RateSample(1000, 0, 0), sampler.sample(1000, 10, 10))
    }
    @Test fun sameTimestampDoesNotDivideByZero() {
        assertEquals(1000L, RateSampler(1000).sample(1000, 1, 0).received)
    }
    @Test fun chartRetainsAtMostSixtySamples() {
        var samples = emptyList<RateSample>()
        repeat(90) { samples = appendSample(samples, RateSample(it * 1000L, 0, 0)) }
        assertEquals(60, samples.size); assertEquals(30_000L, samples.first().atMillis)
    }
    @Test fun samplesBeforeWindowAreDroppedAfterGap() {
        assertEquals(listOf(RateSample(61_000, 3, 4)),
            appendSample(listOf(RateSample(1000, 1, 2)), RateSample(61_000, 3, 4)))
    }
    @Test fun exportedLogCannotInjectAnotherLine() {
        val result = exportLogs(listOf(LogEntry(1, "12:00:00", LogLevel.WARN, "first\nsecond\rthird")))
        assertEquals("12:00:00  WARN  first second third", result)
    }
}
