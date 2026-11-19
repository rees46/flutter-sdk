package com.rees46.rees46_flutter_sdk

import com.personalization.SDK
import com.personalization.api.managers.QueuedTrackingApi
import com.personalization.api.managers.TrackingApi
import com.personalization.api.models.tracking.TrackingSourceType
import com.personalization.core.CompletionListener
import com.personalization.core.SdkError
import com.personalization.core.SdkResult
import com.rees46.rees46_flutter_sdk.pigeon.FlutterError
import com.rees46.rees46_flutter_sdk.pigeon.PurchaseLineItemWire
import com.rees46.rees46_flutter_sdk.pigeon.TrackingItemWire
import com.rees46.rees46_flutter_sdk.pigeon.TrackingSourceWire
import org.mockito.Mockito.mock
import org.mockito.Mockito.mockingDetails
import org.mockito.Mockito.`when`
import org.mockito.invocation.Invocation
import kotlin.test.AfterTest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * The native `tracking` namespace whose `queued` is [queued]; every other member goes to [legacy]. `queued` is
 * hidden from Java, so a mock of the interface cannot answer it.
 */
private class Queued(legacy: TrackingApi, private val queuedApi: QueuedTrackingApi) : TrackingApi by legacy {
    override val queued: QueuedTrackingApi get() = queuedApi
}

/**
 * Every tracking method of the channel goes to the native `tracking.queued`, whose listener hears that the
 * queue accepted the event: the Dart future completes then, and fails only with the error that kept the
 * event out of the queue — as on iOS. The `tracking` methods that wait for the server are not called.
 */
internal class TrackingBridgeTest {

    private var mainBefore: (() -> Unit) -> Unit = MainThread.run
    /** The `tracking` methods that wait for the server: none may be called. */
    private lateinit var tracking: TrackingApi
    private lateinit var queued: QueuedTrackingApi
    private lateinit var plugin: Rees46FlutterSdkPlugin
    private val shops = mutableListOf<String?>()

    @BeforeTest
    fun setUp() {
        mainBefore = MainThread.run
        MainThread.run = { it() }
        queued = mock(QueuedTrackingApi::class.java)
        tracking = mock(TrackingApi::class.java)
        val sdk = mock(SDK::class.java)
        `when`(sdk.tracking).thenReturn(Queued(tracking, queued))
        plugin = Rees46FlutterSdkPlugin()
        plugin.instances = { shopId -> shops += shopId; sdk }
    }

    @AfterTest
    fun restore() {
        MainThread.run = mainBefore
    }

    /** Each channel method, and the native method of `tracking.queued` it must reach. */
    private val calls: List<Pair<String, (callback: (Result<Unit>) -> Unit) -> Unit>> = listOf(
        "custom" to { cb -> plugin.trackEvent("unknown_event", 1L, "c", "l", 2L, mapOf("k" to "v"), "s", cb) },
        "productView" to { cb -> plugin.trackProductView("37", TrackingSourceWire("dynamic", "block"), "s", cb) },
        "categoryView" to { cb -> plugin.trackCategoryView("7", "s", cb) },
        "search" to { cb -> plugin.trackSearch("kettle", listOf("37"), "s", cb) },
        "addToCart" to { cb -> plugin.trackAddToCart(TrackingItemWire("37", 2L), null, "s", cb) },
        "syncCart" to { cb -> plugin.trackSyncCart(listOf(TrackingItemWire("37", 1L)), "s", cb) },
        "removeFromCart" to { cb -> plugin.trackRemoveFromCart("37", "s", cb) },
        "addToFavorites" to { cb -> plugin.trackAddToFavorites("37", null, "s", cb) },
        "syncFavorites" to { cb -> plugin.trackSyncFavorites(listOf("37"), "s", cb) },
        "removeFromFavorites" to { cb -> plugin.trackRemoveFromFavorites("37", "s", cb) },
        "storyView" to { cb -> plugin.trackStoryView("1", "2", "stories", "s", cb) },
        "storyClick" to { cb -> plugin.trackStoryClick("1", "2", "stories", "s", cb) },
        "bannerView" to { cb -> plugin.trackBannerView("b1", "slider", "s", cb) },
        "bannerClick" to { cb -> plugin.trackBannerClick("b1", "slider", "s", cb) },
        "popupShown" to { cb -> plugin.trackPopupShown(9L, "s", cb) },
        "purchase" to { cb ->
            plugin.trackPurchase(
                "order-1", 1990.0, listOf(PurchaseLineItemWire("37", 1L, 1990.0)),
                null, null, null, false, false, null, null, null, null, null, null, null, null, null, null, "s", cb,
            )
        },
    )

    /** The one call `tracking.queued` got. */
    private fun reached(): Invocation = mockingDetails(queued).invocations.single()

    @Suppress("UNCHECKED_CAST")
    private fun Invocation.listener(): CompletionListener<Unit> = arguments.last() as CompletionListener<Unit>

    @Test
    fun everyMethodGoesToTrackingQueuedAndCompletesOnceTheQueueAcceptedTheEvent() {
        for ((native, send) in calls) {
            setUp()
            val results = mutableListOf<Result<Unit>>()

            send { results += it }
            val invocation = reached()

            assertEquals(native, invocation.method.name)
            assertEquals(emptyList(), mockingDetails(tracking).invocations.map { it.method.name }, native)
            assertEquals(emptyList(), results, "$native completes only when the queue answers")
            invocation.listener().onComplete(SdkResult.Success(Unit))
            assertTrue(results.single().isSuccess, native)
            assertEquals(listOf<String?>("s"), shops, native)
            shops.clear()
        }
    }

    @Test
    fun anEventKeptOutOfTheQueueFailsWithItsError() {
        val errors = listOf(
            SdkError.InvalidArgument("itemId must not be empty") to "invalidArgument",
            SdkError.ShopBlocked to "shopBlocked",
            SdkError.NotInitialized to "notInitialized",
        )
        for ((error, type) in errors) {
            setUp()
            val results = mutableListOf<Result<Unit>>()

            plugin.trackProductView("", null, "s", { results += it })
            reached().listener().onComplete(SdkResult.Failure(error))

            assertEquals(type, (results.single().exceptionOrNull() as FlutterError).code)
        }
    }

    @Test
    fun theEventsArgumentsReachTheQueue() {
        plugin.trackEvent("unknown_event", 1L, "c", "l", 2L, mapOf("k" to "v"), "s") { }
        val custom = reached().arguments.toList()

        assertEquals(listOf("unknown_event", 1, "c", "l", 2, mapOf("k" to "v")), custom.dropLast(1))

        setUp()
        plugin.trackProductView("37", TrackingSourceWire("dynamic", "block"), "s") { }
        val (itemId, source) = reached().arguments
        val native = source as com.personalization.api.models.tracking.TrackingSource

        assertEquals("37", itemId)
        assertEquals(TrackingSourceType.DYNAMIC, native.type)
        assertEquals("block", native.code)
    }
}
