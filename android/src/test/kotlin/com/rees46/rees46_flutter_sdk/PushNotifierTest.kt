package com.rees46.rees46_flutter_sdk

import com.personalization.features.notification.actions.model.NotificationAction
import com.personalization.features.notification.event.model.NotificationEvent
import com.personalization.sdk.data.models.dto.notification.NotificationData
import com.rees46.rees46_flutter_sdk.push.Rees46PushNotifier
import org.json.JSONArray
import org.json.JSONObject
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

/** A push the plugin drew goes to the SDK's routing whole — code, type, shop, texts, buttons, target — the way a push's data has them. */
internal class PushNotifierTest {

    private fun data(id: String?, type: String?) =
        NotificationData(id = id, title = "Title", body = "Body", icon = null, type = type, actions = null, actionUrls = null, image = null, event = null)

    @Test
    fun aShownPushIsReportedWithItsCodeTypeAndShop() {
        assertEquals(
            mapOf("id" to "m-1", "type" to "bulk", "shop_id" to "shop-1", "title" to "Title", "body" to "Body"),
            Rees46PushNotifier.shownPayload("shop-1", data("m-1", "bulk")),
        )
    }

    @Test
    fun theWholePushGoesWithItsButtonsAndTargetAsJson() {
        val push = NotificationData(
            id = "m-2", title = "Sale", body = "Up to 50%", icon = "https://img.test/i.png", type = "chain",
            actions = listOf(NotificationAction(action = "open", title = "Open")),
            actionUrls = listOf("https://shop.test/a"),
            image = "https://img.test/p.png",
            event = NotificationEvent(type = "web", uri = "https://shop.test/p", payload = mapOf("k" to "v")),
        )

        val data = Rees46PushNotifier.pushData("shop-1", push)!!

        assertEquals("m-2", data["id"])
        assertEquals("chain", data["type"])
        assertEquals("shop-1", data["shop_id"])
        assertEquals("https://img.test/p.png", data["image"])
        assertEquals("https://img.test/i.png", data["icon"])
        assertEquals("open", JSONArray(data["actions"]).getJSONObject(0).getString("action"))
        assertEquals("Open", JSONArray(data["actions"]).getJSONObject(0).getString("title"))
        assertEquals("https://shop.test/a", JSONArray(data["action_urls"]).getString(0))
        val event = JSONObject(data["event"]!!)
        assertEquals("web", event.getString("type"))
        assertEquals("https://shop.test/p", event.getString("uri"))
        assertEquals("v", event.getJSONObject("payload").getString("k"))
    }

    @Test
    fun aPushWithoutItsCodeOrTypeIsNotReported() {
        assertNull(Rees46PushNotifier.shownPayload("shop-1", data(null, "bulk")))
        assertNull(Rees46PushNotifier.shownPayload("shop-1", data("m-1", " ")))
    }
}
