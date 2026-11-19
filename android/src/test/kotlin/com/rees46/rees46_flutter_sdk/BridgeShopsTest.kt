package com.rees46.rees46_flutter_sdk

import android.content.Context
import com.personalization.LogLevel
import com.personalization.Rees46Config
import com.personalization.SDK
import com.rees46.rees46_flutter_sdk.push.Rees46ShopStore
import org.json.JSONObject
import org.mockito.Mockito.mock
import org.mockito.Mockito.never
import org.mockito.Mockito.verify
import org.mockito.Mockito.`when`
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotSame

/** The store of shops the cold-start provider starts, the shops the plugin runs, and the popups that wait for Dart. */
internal class BridgeShopsTest {

    private val starterBefore = BridgeShops.starter

    @AfterTest
    fun clear() {
        PopupRelay.reset()
        BridgeShops.reset()
        BridgeShops.starter = starterBefore
    }

    /** Starts a fake instance for each shop, recording them. */
    private fun fakeStarts(): MutableList<SDK> {
        val made = mutableListOf<SDK>()
        BridgeShops.starter = { _, config ->
            mock(SDK::class.java).also {
                `when`(it.shopId).thenReturn(config.shopId)
                made += it
            }
        }
        return made
    }

    @Test
    fun aReleasedShopIsForgottenAndItsNextStartMakesAFreshInstance() {
        val made = fakeStarts()
        val context = mock(Context::class.java)
        val first = BridgeShops.start(context, Rees46Config(shopId = "shop-1"))
        val other = BridgeShops.start(context, Rees46Config(shopId = "shop-2"))

        BridgeShops.release(first)

        verify(first).release()
        verify(other, never()).release()
        assertEquals(setOf("shop-2"), BridgeShops.shopIds())

        val again = BridgeShops.start(context, Rees46Config(shopId = "shop-1"))

        assertNotSame(first, again)
        assertEquals(3, made.size)
        assertEquals(setOf("shop-1", "shop-2"), BridgeShops.shopIds())
    }

    @Test
    fun aReleasedShopsPopupsNoLongerReachDartAndNoneWaitsForItsNextInstance() {
        val first = mutableListOf<String>()
        val other = mutableListOf<String>()
        val next = mutableListOf<String>()
        PopupRelay.connect("shop-1", { first += it }, now = 0)
        PopupRelay.connect("shop-2", { other += it }, now = 0)

        PopupRelay.disconnect("shop-1")
        PopupRelay.relay("shop-1", "late", now = 1_000)
        PopupRelay.relay("shop-2", "live", now = 1_000)

        assertEquals(emptyList(), first)
        assertEquals(listOf("live"), other)

        PopupRelay.disconnect("shop-1")
        PopupRelay.connect("shop-1", { next += it }, now = 2_000)

        assertEquals(emptyList(), next)
    }

    @Test
    fun releasingAShopStopsThePopupsHeldForIt() {
        val made = fakeStarts()
        val sdk = BridgeShops.start(mock(Context::class.java), Rees46Config(shopId = "shop-1"))
        val got = mutableListOf<String>()
        PopupRelay.relay("shop-1", "held", now = 0)

        BridgeShops.release(sdk)
        PopupRelay.connect("shop-1", { got += it }, now = 1_000)

        assertEquals(1, made.size)
        assertEquals(emptyList(), got)
    }

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

/** Dart's onToken hears a token the SDK got from its provider, as the contract has it, and no other. */
internal class TokenReportsTest {

    @Test
    fun aTokenTheAppHandedOverOrTheSdkAlreadyHadIsNotNew() {
        val reports = TokenReports()

        reports.beginReplay()
        assertEquals(false, reports.isNew(com.personalization.PushProvider.FCM, "stored"))
        reports.endReplay()

        reports.appSet(com.personalization.PushProvider.FCM, "app-token")
        assertEquals(false, reports.isNew(com.personalization.PushProvider.FCM, "app-token"))
        assertEquals(true, reports.isNew(com.personalization.PushProvider.HMS, "app-token"))
        assertEquals(true, reports.isNew(com.personalization.PushProvider.FCM, "from-fcm"))
    }
}
