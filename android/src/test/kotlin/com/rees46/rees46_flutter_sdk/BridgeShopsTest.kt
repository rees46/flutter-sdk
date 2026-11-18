package com.rees46.rees46_flutter_sdk

import com.personalization.LogLevel
import com.personalization.Rees46Config
import com.rees46.rees46_flutter_sdk.push.Rees46ShopStore
import org.json.JSONObject
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertEquals

/** The store of shops the cold-start provider starts, and the popups that wait for Dart. */
internal class BridgeShopsTest {

    @AfterTest
    fun clear() = PopupRelay.reset()

    @Test
    fun aStoredConfigurationComesBackWhole() {
        val config = Rees46Config(
            shopId = "shop-1",
            apiDomain = "api.example.test",
            stream = "flutter",
            autoSendPushToken = false,
            needReInitialization = true,
            enableAutoPopupPresentation = false,
            logLevel = LogLevel.DEBUG,
            sendAdvertisingId = true,
        )

        assertEquals(config, Rees46ShopStore.fromJson(Rees46ShopStore.toJson(config)))
    }

    @Test
    fun aConfigurationOfAnEarlierReleaseTakesTheNewFieldsDefaults() {
        val earlier = JSONObject()
            .put("shopId", "shop-1")
            .put("apiDomain", "api.rees46.ru")
            .put("stream", "android")
            .put("autoSendPushToken", true)
            .put("needReInitialization", false)
            .put("enableAutoPopupPresentation", true)

        val config = Rees46ShopStore.fromJson(earlier)!!

        assertEquals(LogLevel.WARNING, config.logLevel)
        assertEquals(false, config.sendAdvertisingId)
        assertEquals("android", config.stream)
        assertEquals(null, Rees46ShopStore.fromJson(JSONObject().put("shopId", " ")))
    }

    @Test
    fun aPopupBeforeDartConnectedWaitsForIt() {
        val got = mutableListOf<String>()

        PopupRelay.relay("shop-1", "old", now = 0)
        PopupRelay.relay("shop-1", "fresh", now = 50_000)
        PopupRelay.relay("shop-2", "other", now = 50_000)
        PopupRelay.connect("shop-1", { got += it }, now = PopupRelay.HOLD_MS + 10_000)
        PopupRelay.relay("shop-1", "live", now = 70_000)

        assertEquals(listOf("fresh", "live"), got)
    }

    @Test
    fun afterTheEngineWentPopupsWaitAgain() {
        val first = mutableListOf<String>()
        val second = mutableListOf<String>()
        PopupRelay.connect("shop-1", { first += it }, now = 0)
        PopupRelay.disconnectAll()

        PopupRelay.relay("shop-1", "held", now = 1_000)
        PopupRelay.connect("shop-1", { second += it }, now = 2_000)

        assertEquals(emptyList(), first)
        assertEquals(listOf("held"), second)
    }
}
