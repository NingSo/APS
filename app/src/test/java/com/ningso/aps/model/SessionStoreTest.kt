package com.ningso.aps.model

import org.junit.Assert.*
import org.junit.Before
import org.junit.Test

class SessionStoreTest {
    private var owner = 0L
    @Before fun reset() { owner = SessionStore.attach() }
    @Test fun staleServiceCannotOverwriteSuccessor() {
        val newOwner = SessionStore.attach()
        SessionStore.update(newOwner) { it.copy(phase = SessionPhase.RUNNING) }
        SessionStore.update(owner) { it.copy(phase = SessionPhase.FAILED) }
        SessionStore.detach(owner)
        assertEquals(SessionPhase.RUNNING, SessionStore.state.value.phase)
    }
    @Test fun stoppedServiceClearsMemoryOnlySessionData() {
        SessionStore.update(owner) { it.copy(phase = SessionPhase.RUNNING, bytesReceived = 100,
            log = listOf(LogEntry(1, "12:00:00", LogLevel.INFO, "listener"))) }
        SessionStore.detach(owner)
        assertEquals(RuntimeSnapshot(), SessionStore.state.value)
    }
    @Test fun failureSurvivesServiceDestructionForDiagnosis() {
        SessionStore.update(owner) { it.copy(phase = SessionPhase.FAILED, lastError = "port in use") }
        SessionStore.detach(owner)
        assertEquals("port in use", SessionStore.state.value.lastError)
        assertEquals(SessionPhase.FAILED, SessionStore.state.value.phase)
    }
    @Test fun nextSessionDoesNotReuseLastFailure() {
        SessionStore.update(owner) { it.copy(phase = SessionPhase.FAILED, lastError = "port in use") }
        SessionStore.attach()
        assertEquals(RuntimeSnapshot(), SessionStore.state.value)
    }
    @Test fun failedStartRequestDoesNotEraseAnActiveService() {
        SessionStore.update(owner) { it.copy(phase = SessionPhase.RUNNING) }
        SessionStore.launchFailed("request denied")
        assertTrue(SessionStore.state.value.running)
    }
    @Test fun platformRejectionIsReportedBeforeServiceCreation() {
        SessionStore.launchFailed("request denied")
        assertEquals(SessionPhase.FAILED, SessionStore.state.value.phase)
        assertEquals("request denied", SessionStore.state.value.lastError)
    }
}
