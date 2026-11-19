package com.rees46.rees46_flutter_sdk

import com.personalization.LogLevel
import com.personalization.Rees46
import com.personalization.SdkLogHandler
import com.personalization.SdkLogMessage
import com.rees46.rees46_flutter_sdk.pigeon.SdkLogMessageWire

/**
 * The native SDK's log messages, for the engines whose Dart set a log handler (`REES46.setLogHandler`). The
 * native handler is process-global: it is set while at least one engine wants the messages, and cleared when
 * the last one stops or goes. Each message goes to every such engine.
 */
internal object LogForwarding {

    private val sinks = mutableListOf<(SdkLogMessage) -> Unit>()

    /** Sets the native handler. Tests record what it is set to. */
    @Volatile
    internal var install: (((SdkLogMessage) -> Unit)?) -> Unit = { forward ->
        Rees46.setLogHandler(forward?.let { send -> SdkLogHandler { send(it) } })
    }

    @Synchronized
    fun add(sink: (SdkLogMessage) -> Unit) {
        if (sinks.any { it === sink }) return
        sinks += sink
        if (sinks.size == 1) install(::forward)
    }

    @Synchronized
    fun remove(sink: (SdkLogMessage) -> Unit) {
        if (!sinks.removeAll { it === sink }) return
        if (sinks.isEmpty()) install(null)
    }

    /** Called by the native SDK on a background thread. */
    internal fun forward(message: SdkLogMessage) {
        val targets = synchronized(this) { sinks.toList() }
        targets.forEach { sink -> runCatching { sink(message) } }
    }

    @Synchronized
    internal fun attached(): Int = sinks.size

    /** Test-only. */
    @Synchronized
    internal fun reset() {
        sinks.clear()
    }
}

/** The message as Dart reads it: the level by its contract name, the context's values as Pigeon carries them. */
internal fun SdkLogMessage.toWire(): SdkLogMessageWire = SdkLogMessageWire(
    level = level.wireName(),
    code = code,
    message = message,
    shopId = shopId,
    context = context.mapValues { (_, value) -> wireValue(value) },
)

internal fun LogLevel.wireName(): String = name.lowercase()

private fun wireValue(value: Any?): Any? = when (value) {
    null, is String, is Boolean, is Long, is Double -> value
    is Int -> value.toLong()
    is Short -> value.toLong()
    is Byte -> value.toLong()
    is Float -> value.toDouble()
    is Number -> value.toDouble()
    is Map<*, *> -> value.entries.associate { (k, v) -> k.toString() to wireValue(v) }
    is Iterable<*> -> value.map(::wireValue)
    else -> value.toString()
}
