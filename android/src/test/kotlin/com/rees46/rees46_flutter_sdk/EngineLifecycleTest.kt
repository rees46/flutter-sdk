package com.rees46.rees46_flutter_sdk

import android.content.Context
import com.personalization.sdk.data.models.dto.notification.NotificationData
import com.rees46.rees46_flutter_sdk.push.Rees46PushMessages
import org.mockito.Mockito.mock
import kotlin.test.AfterTest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * An engine that goes takes only what it connected: another engine keeps the shop's popups, and the plugin's
 * push listener keeps drawing and reporting pushes while the process lives, with or without an engine.
 */
internal class EngineLifecycleTest {

    private var mainBefore: (() -> Unit) -> Unit = MainThread.run
    private val drawBefore = Rees46PushMessages.draw
    private val reportBefore = Rees46PushMessages.reportShown
    private val backgroundBefore = Rees46PushMessages.background
    private val clockBefore = PopupRelay.clock
    private val context = mock(Context::class.java)
    private val events = mutableListOf<String>()

    private fun push(id: String) =
        NotificationData(id = id, title = "Title", body = "Body", icon = null, type = "bulk", actions = null, actionUrls = null, image = null, event = null)

    private fun receiver(name: String) = object : Rees46PushMessages.Receiver {
        override fun received(shopId: String, data: NotificationData) {
            events += "$name received ${data.id}"
        }

        override fun delivered(shopId: String, data: NotificationData) {
            events += "$name delivered ${data.id}"
        }
    }

    @BeforeTest
    fun setUp() {
        MainThread.run = { it() }
        Rees46PushMessages.reset()
        PopupRelay.reset()
        PopupRelay.clock = { 0L }
        Rees46PushMessages.background = { it() }
        Rees46PushMessages.draw = { _, data, shopId -> events += "drawn ${data.id} for $shopId"; true }
        Rees46PushMessages.reportShown = { shopId, data -> events += "shown ${data.id} for $shopId" }
    }

    @AfterTest
    fun restore() {
        MainThread.run = mainBefore
        Rees46PushMessages.draw = drawBefore
        Rees46PushMessages.reportShown = reportBefore
        Rees46PushMessages.background = backgroundBefore
        PopupRelay.clock = clockBefore
        Rees46PushMessages.reset()
        PopupRelay.reset()
    }

    @Test
    fun aBackgroundEngineThatWentLeavesTheAppEnginesPopups() {
        val app = Rees46FlutterSdkPlugin()
        val background = Rees46FlutterSdkPlugin()
        val shown = mutableListOf<String>()
        app.popupSinkOf = { shopId -> { json -> shown += "app $shopId $json" } }
        background.popupSinkOf = { shopId -> { json -> shown += "background $shopId $json" } }

        app.connectEngine("shop-1")
        background.connectEngine("shop-1")
        PopupRelay.relay("shop-1", "a", now = 0)
        background.disconnectEngine()
        PopupRelay.relay("shop-1", "b", now = 0)
        app.disconnectEngine()
        PopupRelay.relay("shop-1", "c", now = 0)
        val next = Rees46FlutterSdkPlugin()
        next.popupSinkOf = { shopId -> { json -> shown += "next $shopId $json" } }
        next.connectEngine("shop-1")

        assertEquals(listOf("background shop-1 a", "app shop-1 b", "next shop-1 c"), shown)
    }

    @Test
    fun anEngineThatWentNoLongerHearsPushesButTheyAreStillDrawnAndReported() {
        val plugin = Rees46FlutterSdkPlugin()
        plugin.popupSinkOf = { { } }
        plugin.connectEngine("shop-1")
        assertTrue(plugin.pushReceiver in Rees46PushMessages.attached())

        plugin.disconnectEngine()
        Rees46PushMessages.onMessage(context, "shop-1", push("m-1"))

        assertEquals(emptyList(), Rees46PushMessages.attached())
        assertEquals(listOf("drawn m-1 for shop-1", "shown m-1 for shop-1"), events)
    }

    @Test
    fun aPushGoesToTheDartOfTheEngineAttachedLast() {
        val app = receiver("app")
        val background = receiver("background")
        Rees46PushMessages.attach(app)
        Rees46PushMessages.attach(background)

        Rees46PushMessages.onMessage(context, "shop-1", push("m-1"))
        Rees46PushMessages.detach(background)
        Rees46PushMessages.onMessage(context, "shop-1", push("m-2"))

        assertEquals(
            listOf(
                "background received m-1", "drawn m-1 for shop-1", "shown m-1 for shop-1", "background delivered m-1",
                "app received m-2", "drawn m-2 for shop-1", "shown m-2 for shop-1", "app delivered m-2",
            ),
            events,
        )
    }

    @Test
    fun aNotificationThatWasNotDrawnIsNotReportedShown() {
        Rees46PushMessages.draw = { _, data, _ -> events += "not drawn ${data.id}"; false }
        Rees46PushMessages.attach(receiver("app"))

        Rees46PushMessages.onMessage(context, "shop-1", push("m-1"))

        assertEquals(listOf("app received m-1", "not drawn m-1", "app delivered m-1"), events)
    }
}
