package com.ningso.aps.model

import android.content.Context

/** Protocol selection is a preference, never an instruction to auto-start a session. */
class ProxyPreferences(context: Context) {
    private val preferences = context.getSharedPreferences("aps_signal", Context.MODE_PRIVATE)
    fun read(): ProxySettings {
        val result = ProxySettings(
            httpEnabled = preferences.getBoolean("http_enabled", true),
            httpPort = preferences.getInt("http_port", 8080),
            socksEnabled = preferences.getBoolean("socks_enabled", true),
            socksPort = preferences.getInt("socks_port", 1080),
            reducedMotion = preferences.getBoolean("reduced_motion", false),
        )
        return if (result.validPorts()) result else result.copy(httpPort = 8080, socksPort = 1080)
    }
    fun write(settings: ProxySettings) {
        require(settings.validPorts())
        preferences.edit()
            .putBoolean("http_enabled", settings.httpEnabled)
            .putInt("http_port", settings.httpPort)
            .putBoolean("socks_enabled", settings.socksEnabled)
            .putInt("socks_port", settings.socksPort)
            .putBoolean("reduced_motion", settings.reducedMotion)
            .apply()
    }
}
