package com.rees46.rees46_flutter_sdk

import com.personalization.LogLevel
import com.personalization.SdkLogMessage
import kotlin.test.AfterTest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull

/** The native log reaches each engine whose Dart has a handler; the native handler is set only while one has. */
internal class LogForwardingTest {

    private val installBefore = LogForwarding.install
    private val installed = mutableListOf<((SdkLogMessage) -> Unit)?>()

    @BeforeTest
    fun setUp() {
        LogForwarding.reset()
        LogForwarding.install = { installed += it }
    }

    @AfterTest
    fun restore() {
        LogForwarding.install = installBefore
        LogForwarding.reset()
    }

    private fun message(level: LogLevel = LogLevel.WARNING) =
        SdkLogMessage(level, "init_retry", "/init will be retried", "shop-1", mapOf("attempt" to 2, "path" to "init"))

    @Test
    fun theNativeHandlerIsSetWhileAnEngineWantsTheMessages() {
        val app = mutableListOf<String>()
        val background = mutableListOf<String>()
        val appSink: (SdkLogMessage) -> Unit = { app += it.code }
        val backgroundSink: (SdkLogMessage) -> Unit = { background += it.code }

        LogForwarding.add(appSink)
        LogForwarding.add(appSink)
        LogForwarding.add(backgroundSink)
        assertEquals(1, installed.size, "set once, for the first engine")
        assertNotNull(installed.single())

        installed.single()!!(message())
        LogForwarding.remove(backgroundSink)
        installed.single()!!(message())
        LogForwarding.remove(appSink)

        assertEquals(listOf("init_retry", "init_retry"), app)
        assertEquals(listOf("init_retry"), background)
        assertEquals(2, installed.size)
        assertNull(installed.last(), "cleared with the last engine")
    }

    @Test
    fun aMessageGoesToDartWithTheContractsLevelNameAndItsContext() {
        val wire = message(LogLevel.DEBUG).copy(context = mapOf("attempt" to 2, "nested" to mapOf("k" to 1.5f), "other" to StringBuilder("x"))).toWire()

        assertEquals("debug", wire.level)
        assertEquals("init_retry", wire.code)
        assertEquals("shop-1", wire.shopId)
        assertEquals(2L, wire.context["attempt"])
        assertEquals(mapOf("k" to 1.5), wire.context["nested"])
        assertEquals("x", wire.context["other"])
        assertEquals(listOf("debug", "info", "warning", "error", "none"), LogLevel.entries.map { it.wireName() })
    }
}
