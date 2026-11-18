package com.rees46.rees46_flutter_sdk

import com.personalization.sdk.data.models.dto.notification.NotificationData
import com.rees46.rees46_flutter_sdk.push.Rees46PushNotifier
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

/** A push the plugin drew goes to the SDK's routing as its code, type and shop, the way a push's data has them. */
internal class PushNotifierTest {

    private fun data(id: String?, type: String?) =
        NotificationData(id = id, title = "Title", body = "Body", icon = null, type = type, actions = null, actionUrls = null, image = null, event = null)

    @Test
    fun aShownPushIsReportedWithItsCodeTypeAndShop() {
        assertEquals(
            mapOf("id" to "m-1", "type" to "bulk", "shop_id" to "shop-1"),
            Rees46PushNotifier.shownPayload("shop-1", data("m-1", "bulk")),
        )
    }

    @Test
    fun aPushWithoutItsCodeOrTypeIsNotReported() {
        assertNull(Rees46PushNotifier.shownPayload("shop-1", data(null, "bulk")))
        assertNull(Rees46PushNotifier.shownPayload("shop-1", data("m-1", " ")))
    }
}
