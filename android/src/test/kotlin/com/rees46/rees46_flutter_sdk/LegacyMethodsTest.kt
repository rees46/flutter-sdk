package com.rees46.rees46_flutter_sdk

import com.personalization.Params
import com.personalization.SDK
import com.personalization.api.OnApiCallbackListener
import com.personalization.api.managers.LoyaltyManager
import com.personalization.api.managers.RecommendationManager
import com.rees46.rees46_flutter_sdk.pigeon.FlutterError
import org.json.JSONObject
import org.mockito.Mockito.mock
import org.mockito.Mockito.mockingDetails
import org.mockito.Mockito.`when`
import kotlin.test.AfterTest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * The handle's deprecated methods go to the native SDK's released methods with what 1.6.4 sent, and fail with
 * 1.6.4's error codes.
 */
internal class LegacyMethodsTest {

    private var mainBefore: (() -> Unit) -> Unit = MainThread.run
    private lateinit var sdk: SDK
    private lateinit var legacy: LegacyMethods

    @BeforeTest
    fun setUp() {
        mainBefore = MainThread.run
        MainThread.run = { it() }
        sdk = mock(SDK::class.java)
        legacy = LegacyMethods { sdk }
    }

    @AfterTest
    fun restore() {
        MainThread.run = mainBefore
    }

    @Test
    fun aRecommendationBlockSendsItsImageSizeAsTheReleasedMethodDid() {
        val built = buildRecommendationParams(
            """{"item_id":"37","category_id":"7","locations":"msk","image_size":180,"with_locations":true}""",
        ).build()

        assertEquals("37", built.getString("item"))
        assertEquals("7", built.getString("category_id"))
        assertEquals("msk", built.getString("locations"))
        assertEquals("180", built.getString("resize_image"))
        assertEquals("true", built.getString("with_locations"))
    }

    @Test
    fun theRecommendationReachesTheReleasedManagerWithItsParameters() {
        val manager = mock(RecommendationManager::class.java)
        `when`(sdk.recommendationManager).thenReturn(manager)

        legacy.getRecommendation("block", """{"image_size":220}""", "s") { }
        val call = mockingDetails(manager).invocations.single()

        assertEquals("getExtendedRecommendation", call.method.name)
        assertEquals("block", call.arguments[0])
        assertEquals("220", (call.arguments[1] as Params).build().getString("resize_image"))
    }

    @Test
    fun joinLoyaltySendsTheEmailAndAnswersTheServersEnvelope() {
        val manager = mock(LoyaltyManager::class.java)
        `when`(sdk.loyaltyManager).thenReturn(manager)
        val results = mutableListOf<Result<String>>()

        legacy.joinLoyalty("+79990000000", "a@b.test", "Anna", null, "s") { results += it }
        val call = mockingDetails(manager).invocations.single()

        assertEquals(listOf<Any?>("+79990000000", "a@b.test", "Anna", null), call.arguments.take(4))
        @Suppress("UNCHECKED_CAST")
        val onError = call.arguments[5] as (Int, String?) -> Unit
        onError(500, "server")
        val error = results.single().exceptionOrNull() as FlutterError
        assertEquals("join_loyalty_failed", error.code)
        assertEquals("server", error.message)
    }

    @Test
    fun anArgumentTheReleasedMethodsRefusedIsBadArgs() {
        val results = mutableListOf<Result<String>>()

        legacy.getProductInfo(" ", "s") { results += it }
        legacy.searchInstant("", null, "s") { results += it }
        legacy.joinLoyalty("", null, null, null, "s") { results += it }
        legacy.getCategory("", null, null, null, "s") { results += it }

        assertEquals(List(4) { "bad_args" }, results.map { (it.exceptionOrNull() as FlutterError).code })
    }

    @Test
    fun aShopThePluginDoesNotFindFailsAsTheMethodsOwnError() {
        val missing = LegacyMethods { throw IllegalStateException("No shop") }
        val results = mutableListOf<Result<String>>()

        missing.getProductInfo("37", "nope") { results += it }
        missing.getProfile("nope") { results += it }

        assertEquals(listOf("product_info_failed", "get_profile_failed"), results.map { (it.exceptionOrNull() as FlutterError).code })
        assertNull(missing.getStoredPushToken("nope"))
    }

    @Test
    fun aCustomEventWithAReservedKeyIsRefusedAsIn164() {
        val results = mutableListOf<Result<Unit>>()

        legacy.trackEvent("e", null, null, null, null, """{"did":"x","ok":1}""", "s") { results += it }

        val error = results.single().exceptionOrNull() as FlutterError
        assertEquals("track_event_failed", error.code)
        assertTrue(error.message!!.contains("did"))
    }

    @Test
    fun aCustomEventGoesToPushCustomWithItsFieldsAtTheTopAndInThePayload() {
        val results = mutableListOf<Result<Unit>>()

        legacy.trackEvent("e", 5L, "c", null, 7L, """{"color":"red","n":2}""", "s") { results += it }
        val call = mockingDetails(sdk).invocations.single { it.method.name == "sendAsync" }

        assertEquals("push/custom", call.arguments[0])
        val body = call.arguments[1] as JSONObject
        assertEquals("e", body.getString("event"))
        assertEquals(5, body.getInt("time"))
        assertEquals(7, body.getInt("value"))
        assertEquals("red", body.getString("color"))
        assertEquals("red", body.getJSONObject("payload").getString("color"))
        (call.arguments[2] as OnApiCallbackListener).onError(400, "unknown event")
        assertEquals("track_event_failed", (results.single().exceptionOrNull() as FlutterError).code)
    }
}
