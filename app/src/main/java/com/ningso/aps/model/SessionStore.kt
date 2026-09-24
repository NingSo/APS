package com.ningso.aps.model

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/** Process-local only. Generation ownership prevents a destroyed Service from overwriting its successor. */
object SessionStore {
    private var generation = 0L
    private val mutable = MutableStateFlow(RuntimeSnapshot())
    val state: StateFlow<RuntimeSnapshot> = mutable.asStateFlow()

    @Synchronized
    fun attach(): Long {
        generation += 1
        mutable.value = RuntimeSnapshot()
        return generation
    }

    @Synchronized
    fun update(owner: Long, transform: (RuntimeSnapshot) -> RuntimeSnapshot) {
        if (owner == generation) mutable.value = transform(mutable.value)
    }

    @Synchronized
    fun detach(owner: Long) {
        if (owner != generation) return
        if (mutable.value.phase != SessionPhase.FAILED) mutable.value = RuntimeSnapshot()
        generation += 1
    }

    @Synchronized
    fun launchFailed(message: String) {
        if (mutable.value.running || mutable.value.busy) return
        mutable.value = RuntimeSnapshot(phase = SessionPhase.FAILED, lastError = message)
    }
}
