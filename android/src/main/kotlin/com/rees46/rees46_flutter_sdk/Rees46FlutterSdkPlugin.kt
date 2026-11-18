package com.rees46.rees46_flutter_sdk

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.provider.Settings
import android.view.View
import android.view.ViewTreeObserver
import com.personalization.Cancellable
import com.personalization.Rees46
import com.personalization.SDK
import com.personalization.api.OnApiCallbackListener
import com.personalization.api.models.purchase.PurchaseTrackingRequest
import com.personalization.core.PushEvent
import com.personalization.sdk.data.models.dto.notification.NotificationData
import com.rees46.rees46_flutter_sdk.pigeon.AgentDialogResponseWire
import com.rees46.rees46_flutter_sdk.pigeon.AgentResponseWire
import com.rees46.rees46_flutter_sdk.pigeon.BackInStockPropertiesWire
import com.rees46.rees46_flutter_sdk.pigeon.CartItemWire
import com.rees46.rees46_flutter_sdk.pigeon.CesCampaignWire
import com.rees46.rees46_flutter_sdk.pigeon.ClientReviewWire
import com.rees46.rees46_flutter_sdk.pigeon.CollectionResponseWire
import com.rees46.rees46_flutter_sdk.pigeon.CsatCampaignWire
import com.rees46.rees46_flutter_sdk.pigeon.FlutterError
import com.rees46.rees46_flutter_sdk.pigeon.InitConfig
import com.rees46.rees46_flutter_sdk.pigeon.LoyaltyMemberWire
import com.rees46.rees46_flutter_sdk.pigeon.LoyaltyPromotionWire
import com.rees46.rees46_flutter_sdk.pigeon.LoyaltyStatusWire
import com.rees46.rees46_flutter_sdk.pigeon.NotificationHistoryWire
import com.rees46.rees46_flutter_sdk.pigeon.NpsCategoryWire
import com.rees46.rees46_flutter_sdk.pigeon.OrderWire
import com.rees46.rees46_flutter_sdk.pigeon.PersonalizationFlutterApi
import com.rees46.rees46_flutter_sdk.pigeon.PersonalizationHostApi
import com.rees46.rees46_flutter_sdk.pigeon.PersonalizationPopupFlutterApi
import com.rees46.rees46_flutter_sdk.pigeon.PersonalizationStateFlutterApi
import com.rees46.rees46_flutter_sdk.pigeon.PollChannelWire
import com.rees46.rees46_flutter_sdk.pigeon.PollReviewWire
import com.rees46.rees46_flutter_sdk.pigeon.ProductCountersResponseWire
import com.rees46.rees46_flutter_sdk.pigeon.ProductReviewsResponseWire
import com.rees46.rees46_flutter_sdk.pigeon.ProductWire
import com.rees46.rees46_flutter_sdk.pigeon.ProductsListRequestWire
import com.rees46.rees46_flutter_sdk.pigeon.ProductsListResponseWire
import com.rees46.rees46_flutter_sdk.pigeon.ProfileUpdateRequestWire
import com.rees46.rees46_flutter_sdk.pigeon.ProfileWire
import com.rees46.rees46_flutter_sdk.pigeon.PurchaseLineItemWire
import com.rees46.rees46_flutter_sdk.pigeon.PurchaseProbabilityWire
import com.rees46.rees46_flutter_sdk.pigeon.PushTokenWire
import com.rees46.rees46_flutter_sdk.pigeon.RecommendationRequestWire
import com.rees46.rees46_flutter_sdk.pigeon.RecommendationResponseWire
import com.rees46.rees46_flutter_sdk.pigeon.SdkSnapshotWire
import com.rees46.rees46_flutter_sdk.pigeon.SearchBlankResponseWire
import com.rees46.rees46_flutter_sdk.pigeon.SearchFullRequestWire
import com.rees46.rees46_flutter_sdk.pigeon.SearchFullResponseWire
import com.rees46.rees46_flutter_sdk.pigeon.SearchInstantResponseWire
import com.rees46.rees46_flutter_sdk.pigeon.SegmentWire
import com.rees46.rees46_flutter_sdk.pigeon.SliderWire
import com.rees46.rees46_flutter_sdk.pigeon.StoriesBlockWire
import com.rees46.rees46_flutter_sdk.pigeon.SubscriptionStatusWire
import com.rees46.rees46_flutter_sdk.pigeon.SubscriptionsUpdateRequestWire
import com.rees46.rees46_flutter_sdk.pigeon.TrackingItemWire
import com.rees46.rees46_flutter_sdk.pigeon.TrackingSourceWire
import com.rees46.rees46_flutter_sdk.push.Rees46PushNotifier
import com.rees46.rees46_flutter_sdk.push.Rees46ShopStore
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.PluginRegistry
import java.util.concurrent.ConcurrentHashMap
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject

/**
 * The Flutter bridge over the native Android SDK. Each shop runs on the native SDK's new core
 * (`Rees46.initializeBridge`); each method of the host API calls the native method of the same meaning on
 * the shop's instance — a namespace method (`sdk.products.getInfo`, …) or the `tracking` namespace — and
 * hands its model to Dart as the Pigeon wire type of the contract. The native registry holds the instances;
 * the plugin keeps no requests, storage or queue of its own, only its subscriptions to the instances' state
 * and session and to the SDK's push events, to tell Dart.
 */
class Rees46FlutterSdkPlugin :
    FlutterPlugin,
    ActivityAware,
    PersonalizationHostApi {
    private lateinit var applicationContext: Context
    private val coroutineScope = CoroutineScope(Dispatchers.Main + Job())
    private var flutterApi: PersonalizationFlutterApi? = null
    private var popupApi: PersonalizationPopupFlutterApi? = null
    private var stateApi: PersonalizationStateFlutterApi? = null
    private var activityBinding: ActivityPluginBinding? = null

    /** Per shop, the subscriptions that tell Dart the instance's state and session. */
    private val subscriptions = ConcurrentHashMap<String, Cancellable>()

    /** The SDK's push events and new tokens of every shop, for Dart. */
    private var pushSinks: List<Cancellable> = emptyList()

    private val onNewIntentListener =
        object : PluginRegistry.NewIntentListener {
            override fun onNewIntent(intent: Intent): Boolean {
                this@Rees46FlutterSdkPlugin.handleNotificationLaunchIntent(intent)
                return false
            }
        }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = flutterPluginBinding.applicationContext
        PersonalizationHostApi.setUp(flutterPluginBinding.binaryMessenger, this)
        flutterApi = PersonalizationFlutterApi(flutterPluginBinding.binaryMessenger)
        popupApi = PersonalizationPopupFlutterApi(flutterPluginBinding.binaryMessenger)
        stateApi = PersonalizationStateFlutterApi(flutterPluginBinding.binaryMessenger)
        pushSinks = listOf(
            Rees46.onPushEvent { event, payload ->
                val wire = runCatching { payload.toWire() }.getOrNull() ?: return@onPushEvent
                runCatching {
                    stateApi?.onPushEvent(payload.shopId.orEmpty(), event.name.lowercase(), wire) { }
                }
            },
            Rees46.onPushToken { token ->
                runCatching { stateApi?.onPushToken(token.toWire()) { } }
                // The shops' snapshots carry the token: they changed.
                BridgeShops.shopIds().forEach { shopId ->
                    runCatching { Rees46.instance(shopId) }.getOrNull()?.let { emit(snapshotOf(it)) }
                }
            },
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        PersonalizationHostApi.setUp(binding.binaryMessenger, null)
        pushSinks.forEach { it.cancel() }
        pushSinks = emptyList()
        subscriptions.values.forEach { it.cancel() }
        subscriptions.clear()
        // Popups wait for the next engine instead of going to a channel nobody listens on.
        PopupRelay.disconnectAll()
        flutterApi = null
        popupApi = null
        stateApi = null
        coroutineScope.cancel()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        bindActivity(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        unbindActivity()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        bindActivity(binding)
    }

    override fun onDetachedFromActivity() {
        unbindActivity()
    }

    private fun bindActivity(binding: ActivityPluginBinding) {
        unbindActivity()
        activityBinding = binding
        binding.addOnNewIntentListener(onNewIntentListener)
        handleNotificationLaunchIntent(binding.activity.intent)
    }

    private fun unbindActivity() {
        activityBinding?.removeOnNewIntentListener(onNewIntentListener)
        activityBinding = null
    }

    override fun getPlatformVersion(): String = "Android ${android.os.Build.VERSION.RELEASE}"

    // region shop

    /**
     * The instance of [shopId], or of the single shop with none. An unknown or (with no id) ambiguous shop
     * throws, and the calling method reports `notInitialized`.
     */
    private fun sdk(shopId: String?): SDK = Rees46.instance(shopId?.trim()?.ifEmpty { null })

    /** Resolves the instance and runs [body]; a failure before the native call reaches [callback]. */
    private inline fun <R> call(shopId: String?, noinline callback: (Result<R>) -> Unit, body: (SDK) -> Unit) {
        try {
            body(sdk(shopId))
        } catch (t: Throwable) {
            callback(Result.failure(BridgeFailures.of(t)))
        }
    }

    override fun initialize(config: InitConfig, callback: (Result<SdkSnapshotWire>) -> Unit) {
        if (config.shopId.isBlank()) {
            callback(Result.failure(BridgeFailures.invalidArgument("shopId must not be empty")))
            return
        }
        try {
            val nativeConfig = config.toNative()
            val shopId = nativeConfig.shopId
            // A Dart restart initializes the shop again: the old subscriptions go first, so a release of an
            // instance started with another configuration tells Dart nothing.
            subscriptions.remove(shopId)?.cancel()
            val sdk = BridgeShops.start(applicationContext, nativeConfig)

            // Dart draws popups with the UI kit: every popup is kept back from the native SDK and handed
            // over, those that came before Dart connected the shop among them. Dart decides whether to show
            // it, and reports it once it is on screen.
            PopupRelay.connect(shopId, sink = { json ->
                onMain { runCatching { popupApi?.onPopup(shopId, json) { } } }
            })

            // Persist so the cold-start push provider (Rees46PushInitProvider) starts this shop on a process
            // FCM spins up before Dart runs — otherwise the registry is empty and the push is dropped.
            Rees46ShopStore.save(applicationContext, nativeConfig)
            Rees46PushNotifier.ensureChannel(applicationContext)
            installMessageListener()

            val state = sdk.onStateChange { emit(snapshotOf(sdk, it)) }
            val session = sdk.onSessionChange { emit(snapshotOf(sdk)) }
            subscriptions.put(shopId, Cancellable { state.cancel(); session.cancel() })?.cancel()
            callback(Result.success(snapshotOf(sdk)))
        } catch (t: Throwable) {
            callback(Result.failure(BridgeFailures.of(t)))
        }
    }

    /** Tells Dart a shop's snapshot, on the main thread. */
    private fun emit(snapshot: SdkSnapshotWire) {
        onMain { runCatching { stateApi?.onSnapshot(snapshot) { } } }
    }

    override fun getSnapshot(shopId: String?): SdkSnapshotWire = try {
        snapshotOf(sdk(shopId))
    } catch (t: Throwable) {
        throw BridgeFailures.of(t)
    }

    override fun getSid(shopId: String?): String = try {
        sdk(shopId).sessionId.orEmpty()
    } catch (t: Throwable) {
        throw BridgeFailures.of(t)
    }

    override fun getDid(shopId: String?): String? = try {
        sdk(shopId).deviceId
    } catch (t: Throwable) {
        throw BridgeFailures.of(t)
    }

    // endregion

    // region tracking
    //
    // Each method hands straight to the native `tracking` namespace of the instance; its listener completes
    // the Dart future with the native answer, or the whole native error.

    override fun trackEvent(
        event: String,
        time: Long?,
        category: String?,
        label: String?,
        value: Long?,
        customFields: Map<String, Any?>?,
        shopId: String?,
        callback: (Result<Unit>) -> Unit,
    ) = call(shopId, callback) {
        it.tracking.custom(
            event = event,
            time = time?.let(::toIntClamped),
            category = category,
            label = label,
            value = value?.let(::toIntClamped),
            customFields = customFields,
            listener = answered(callback),
        )
    }

    override fun trackProductView(
        itemId: String,
        source: TrackingSourceWire?,
        shopId: String?,
        callback: (Result<Unit>) -> Unit,
    ) = call(shopId, callback) { it.tracking.productView(itemId, source?.toNative(), answered(callback)) }

    override fun trackCategoryView(categoryId: String, shopId: String?, callback: (Result<Unit>) -> Unit) =
        call(shopId, callback) { it.tracking.categoryView(categoryId, answered(callback)) }

    override fun trackSearch(
        query: String,
        results: List<String>?,
        shopId: String?,
        callback: (Result<Unit>) -> Unit,
    ) = call(shopId, callback) { it.tracking.search(query, results, answered(callback)) }

    override fun trackAddToCart(
        item: TrackingItemWire,
        source: TrackingSourceWire?,
        shopId: String?,
        callback: (Result<Unit>) -> Unit,
    ) = call(shopId, callback) { it.tracking.addToCart(item.toNative(), source?.toNative(), answered(callback)) }

    override fun trackSyncCart(items: List<TrackingItemWire>, shopId: String?, callback: (Result<Unit>) -> Unit) =
        call(shopId, callback) { it.tracking.syncCart(items.map { item -> item.toNative() }, answered(callback)) }

    override fun trackRemoveFromCart(itemId: String, shopId: String?, callback: (Result<Unit>) -> Unit) =
        call(shopId, callback) { it.tracking.removeFromCart(itemId, answered(callback)) }

    override fun trackAddToFavorites(
        itemId: String,
        source: TrackingSourceWire?,
        shopId: String?,
        callback: (Result<Unit>) -> Unit,
    ) = call(shopId, callback) { it.tracking.addToFavorites(itemId, source?.toNative(), answered(callback)) }

    override fun trackSyncFavorites(itemIds: List<String>, shopId: String?, callback: (Result<Unit>) -> Unit) =
        call(shopId, callback) { it.tracking.syncFavorites(itemIds, answered(callback)) }

    override fun trackRemoveFromFavorites(itemId: String, shopId: String?, callback: (Result<Unit>) -> Unit) =
        call(shopId, callback) { it.tracking.removeFromFavorites(itemId, answered(callback)) }

    override fun trackStoryView(
        storyId: String,
        slideId: String,
        code: String?,
        shopId: String?,
        callback: (Result<Unit>) -> Unit,
    ) = call(shopId, callback) { it.tracking.storyView(storyId, slideId, code, answered(callback)) }

    override fun trackStoryClick(
        storyId: String,
        slideId: String,
        code: String?,
        shopId: String?,
        callback: (Result<Unit>) -> Unit,
    ) = call(shopId, callback) { it.tracking.storyClick(storyId, slideId, code, answered(callback)) }

    override fun trackBannerView(bannerId: String, code: String, shopId: String?, callback: (Result<Unit>) -> Unit) =
        call(shopId, callback) { it.tracking.bannerView(bannerId, code, done(callback)) }

    override fun trackBannerClick(bannerId: String, code: String, shopId: String?, callback: (Result<Unit>) -> Unit) =
        call(shopId, callback) { it.tracking.bannerClick(bannerId, code, done(callback)) }

    override fun trackSetSource(source: TrackingSourceWire, shopId: String?) {
        try {
            sdk(shopId).tracking.setSource(source.toNative())
        } catch (t: Throwable) {
            throw BridgeFailures.of(t)
        }
    }

    override fun trackPurchase(
        orderId: String,
        orderPrice: Double,
        items: List<PurchaseLineItemWire>,
        deliveryType: String?,
        deliveryAddress: String?,
        paymentType: String?,
        isTaxFree: Boolean,
        isGiftPackage: Boolean,
        promocode: String?,
        orderCash: Double?,
        orderBonuses: Double?,
        orderDelivery: Double?,
        orderDiscount: Double?,
        channel: String?,
        custom: Map<String, Any?>?,
        recommendedSource: Map<String, Any?>?,
        stream: String?,
        segment: String?,
        shopId: String?,
        callback: (Result<Unit>) -> Unit,
    ) = call(shopId, callback) {
        val request = PurchaseTrackingRequest(
            orderId = orderId,
            orderPrice = orderPrice,
            items = items.map { item -> item.toNative() },
            deliveryType = deliveryType,
            deliveryAddress = deliveryAddress,
            paymentType = paymentType,
            isTaxFree = isTaxFree,
            promocode = promocode,
            orderCash = orderCash,
            orderBonuses = orderBonuses,
            orderDelivery = orderDelivery,
            orderDiscount = orderDiscount,
            channel = channel,
            custom = custom,
            recommendedSource = recommendedSource?.toJsonObject(),
            stream = stream,
            segment = segment,
            isGiftPackage = isGiftPackage,
        )
        // No per-call source: Dart stores one with `setSource`, and the native namespace attaches it.
        it.tracking.purchase(request, null, answered(callback))
    }

    override fun trackPopupShown(popupId: Long, shopId: String?, callback: (Result<Unit>) -> Unit) =
        call(shopId, callback) { it.tracking.popupShown(popupId.toInt(), answered(callback)) }

    // endregion

    // region products, collections, recommendations

    override fun productsGetInfo(itemId: String, shopId: String?, callback: (Result<ProductWire?>) -> Unit) =
        call(shopId, callback) { it.products.getInfo(itemId, completion(callback) { product -> product?.toWire() }) }

    override fun productsGetList(
        request: ProductsListRequestWire,
        shopId: String?,
        callback: (Result<ProductsListResponseWire>) -> Unit,
    ) = call(shopId, callback) { it.products.getList(request.toNative(), completion(callback) { r -> r.toWire() }) }

    override fun productsGetCounters(
        itemId: String,
        shopId: String?,
        callback: (Result<ProductCountersResponseWire>) -> Unit,
    ) = call(shopId, callback) { it.products.getCounters(itemId, completion(callback) { r -> r.toWire() }) }

    override fun productsGetCategory(
        categoryId: String,
        request: ProductsListRequestWire,
        shopId: String?,
        callback: (Result<ProductsListResponseWire>) -> Unit,
    ) = call(shopId, callback) {
        it.products.getCategory(categoryId, request.toCategoryRequest(), completion(callback) { r -> r.toWire() })
    }

    override fun collectionsGet(
        collectionId: String,
        shopId: String?,
        callback: (Result<CollectionResponseWire>) -> Unit,
    ) = call(shopId, callback) { it.collections.get(collectionId, completion(callback) { r -> r.toWire() }) }

    override fun recommendationsGet(
        code: String,
        request: RecommendationRequestWire,
        shopId: String?,
        callback: (Result<RecommendationResponseWire>) -> Unit,
    ) = call(shopId, callback) {
        it.recommendations.get(code, request.toNative(), completion(callback) { r -> r.toWire() })
    }

    // endregion

    // region search

    override fun searchAgentEnabled(shopId: String?): Boolean = try {
        sdk(shopId).search.agentEnabled
    } catch (t: Throwable) {
        throw BridgeFailures.of(t)
    }

    override fun searchBlank(shopId: String?, callback: (Result<SearchBlankResponseWire>) -> Unit) =
        call(shopId, callback) { it.search.blank(completion(callback) { r -> r.toWire() }) }

    override fun searchInstant(
        query: String,
        locations: List<String>?,
        excludedMerchants: List<String>?,
        excludedBrands: List<String>?,
        shopId: String?,
        callback: (Result<SearchInstantResponseWire>) -> Unit,
    ) = call(shopId, callback) {
        it.search.instant(query, locations, excludedMerchants, excludedBrands, completion(callback) { r -> r.toWire() })
    }

    override fun searchFull(
        query: String,
        request: SearchFullRequestWire,
        shopId: String?,
        callback: (Result<SearchFullResponseWire>) -> Unit,
    ) = call(shopId, callback) { it.search.full(query, request.toNative(), completion(callback) { r -> r.toWire() }) }

    override fun searchAgentDialog(
        sessionId: Long?,
        locations: List<String>?,
        shopId: String?,
        callback: (Result<AgentDialogResponseWire>) -> Unit,
    ) = call(shopId, callback) {
        it.search.agentDialog(sessionId, locations, completion(callback) { r -> r.toWire() })
    }

    override fun searchAgent(
        message: String,
        sessionId: Long?,
        locations: List<String>?,
        shopId: String?,
        callback: (Result<AgentResponseWire>) -> Unit,
    ) = call(shopId, callback) {
        it.search.agent(message, sessionId, locations, completion(callback) { r -> r.toWire() })
    }

    // endregion

    // region cart, profile

    override fun cartGet(shopId: String?, callback: (Result<List<CartItemWire>>) -> Unit) =
        call(shopId, callback) { it.cart.get(completion(callback) { items -> items.map { item -> item.toWire() } }) }

    override fun cartClear(
        shopSecret: String,
        email: String?,
        phone: String?,
        loyaltyId: String?,
        externalId: String?,
        telegramId: String?,
        shopId: String?,
        callback: (Result<Unit>) -> Unit,
    ) = call(shopId, callback) {
        it.cart.clear(shopSecret, email, phone, loyaltyId, externalId, telegramId, done(callback))
    }

    override fun profileGet(shopId: String?, callback: (Result<ProfileWire>) -> Unit) =
        call(shopId, callback) { it.profile.get(completion(callback) { r -> r.toWire() }) }

    override fun profileSet(request: ProfileUpdateRequestWire, shopId: String?, callback: (Result<Unit>) -> Unit) =
        call(shopId, callback) { it.profile.set(request.toNative(), done(callback)) }

    override fun profileGetLastOrder(shopId: String?, callback: (Result<List<ProductWire>>) -> Unit) =
        call(shopId, callback) {
            it.profile.getLastOrder(completion(callback) { products -> products.map { p -> p.toWire() } })
        }

    override fun profileGetOrders(
        shopSecret: String,
        did: String?,
        email: String?,
        phone: String?,
        loyaltyId: String?,
        externalId: String?,
        dateFrom: String?,
        shopId: String?,
        callback: (Result<List<OrderWire>>) -> Unit,
    ) = call(shopId, callback) {
        it.profile.getOrders(
            shopSecret, did, email, phone, loyaltyId, externalId, dateFrom,
            completion(callback) { orders -> orders.map { order -> order.toWire() } },
        )
    }

    // endregion

    // region subscriptions, segments

    override fun subscriptionsManage(
        request: SubscriptionsUpdateRequestWire,
        shopId: String?,
        callback: (Result<Unit>) -> Unit,
    ) = call(shopId, callback) { it.subscriptions.manage(request.toNative(), done(callback)) }

    override fun subscriptionsCheck(shopId: String?, callback: (Result<SubscriptionStatusWire>) -> Unit) =
        call(shopId, callback) { it.subscriptions.check(completion(callback) { r -> r.toWire() }) }

    override fun subscriptionsSubscribeForPriceDrop(
        itemId: String,
        currentPrice: Double,
        email: String?,
        phone: String?,
        shopId: String?,
        callback: (Result<Unit>) -> Unit,
    ) = call(shopId, callback) {
        it.subscriptions.subscribeForPriceDrop(itemId, currentPrice, email, phone, done(callback))
    }

    override fun subscriptionsUnsubscribeFromPriceDrop(
        itemIds: List<String>,
        email: String?,
        phone: String?,
        shopId: String?,
        callback: (Result<Unit>) -> Unit,
    ) = call(shopId, callback) { it.subscriptions.unsubscribeFromPriceDrop(itemIds, email, phone, done(callback)) }

    override fun subscriptionsSubscribeForBackInStock(
        itemId: String,
        properties: BackInStockPropertiesWire?,
        email: String?,
        phone: String?,
        shopId: String?,
        callback: (Result<Unit>) -> Unit,
    ) = call(shopId, callback) {
        it.subscriptions.subscribeForBackInStock(itemId, properties?.toNative(), email, phone, done(callback))
    }

    override fun subscriptionsUnsubscribeFromBackInStock(
        itemIds: List<String>,
        email: String?,
        phone: String?,
        shopId: String?,
        callback: (Result<Unit>) -> Unit,
    ) = call(shopId, callback) { it.subscriptions.unsubscribeFromBackInStock(itemIds, email, phone, done(callback)) }

    override fun segmentsAdd(
        segmentId: Long,
        email: String?,
        phone: String?,
        shopId: String?,
        callback: (Result<Unit>) -> Unit,
    ) = call(shopId, callback) { it.segments.add(toIntExact(segmentId, "segmentId"), email, phone, done(callback)) }

    override fun segmentsRemove(
        segmentId: Long,
        email: String?,
        phone: String?,
        shopId: String?,
        callback: (Result<Unit>) -> Unit,
    ) = call(shopId, callback) { it.segments.remove(toIntExact(segmentId, "segmentId"), email, phone, done(callback)) }

    override fun segmentsGet(shopId: String?, callback: (Result<List<SegmentWire>>) -> Unit) =
        call(shopId, callback) { it.segments.get(completion(callback) { list -> list.map { s -> s.toWire() } }) }

    // endregion

    // region notifications

    override fun notificationsTrackDelivered(code: String, type: String, shopId: String?, callback: (Result<Unit>) -> Unit) =
        call(shopId, callback) { it.notifications.trackDelivered(code, type, done(callback)) }

    override fun notificationsTrackOpened(code: String, type: String, shopId: String?, callback: (Result<Unit>) -> Unit) =
        call(shopId, callback) { it.notifications.trackOpened(code, type, done(callback)) }

    override fun notificationsTrackClicked(code: String, type: String, shopId: String?, callback: (Result<Unit>) -> Unit) =
        call(shopId, callback) { it.notifications.trackClicked(code, type, done(callback)) }

    override fun notificationsTrackClosed(code: String, type: String, shopId: String?, callback: (Result<Unit>) -> Unit) =
        call(shopId, callback) { it.notifications.trackClosed(code, type, done(callback)) }

    override fun notificationsGetPushToken(provider: String?, shopId: String?): PushTokenWire? = try {
        sdk(shopId).notifications.getPushToken(provider?.let(::pushProvider))?.toWire()
    } catch (t: Throwable) {
        throw BridgeFailures.of(t)
    }

    override fun notificationsSetPushToken(
        token: String,
        provider: String,
        shopId: String?,
        callback: (Result<Unit>) -> Unit,
    ) = call(shopId, callback) { it.notifications.setPushToken(token, pushProvider(provider), done(callback)) }

    override fun notificationsGetHistory(
        shopSecret: String,
        type: String,
        phone: String?,
        email: String?,
        externalId: String?,
        loyaltyId: String?,
        channel: String?,
        limit: Long?,
        page: Long?,
        dateFrom: String?,
        did: String?,
        shopId: String?,
        callback: (Result<NotificationHistoryWire>) -> Unit,
    ) = call(shopId, callback) {
        it.notifications.getHistory(
            shopSecret, type, phone, email, externalId, loyaltyId, channel,
            limit?.let { value -> toIntExact(value, "limit") },
            page?.let { value -> toIntExact(value, "page") },
            dateFrom, did,
            completion(callback) { r -> r.toWire() },
        )
    }

    /**
     * Hands a push to the native `Rees46.handlePush`, which finds its shop by `shop_id` and sends the event
     * once per message. [event] is the index of Dart's released `PushEvent`: `received` is the push reaching
     * the app (`delivered`), Dart's `delivered` is the notification on screen (`opened`), `clicked` a tap.
     */
    override fun handlePush(payload: Map<String, String>, event: Long, callback: (Result<Unit>) -> Unit) {
        val nativeEvent = when (event) {
            0L -> PushEvent.DELIVERED
            1L -> PushEvent.OPENED
            2L -> PushEvent.CLICKED
            else -> {
                callback(Result.failure(BridgeFailures.invalidArgument("Unknown push event: $event")))
                return
            }
        }
        // Never throws; a push that is not the SDK's, or of no shop, is dropped natively.
        Rees46.handlePush(payload, nativeEvent)
        callback(Result.success(Unit))
    }

    // endregion

    // region stories, predict, loyalty, sliders

    override fun storiesGet(code: String, shopId: String?, callback: (Result<StoriesBlockWire>) -> Unit) =
        call(shopId, callback) { it.stories.get(code, completion(callback) { r -> r.toWire() }) }

    override fun predictGetProbabilityToPurchase(shopId: String?, callback: (Result<PurchaseProbabilityWire>) -> Unit) =
        call(shopId, callback) { it.predict.getProbabilityToPurchase(completion(callback) { r -> r.toWire() }) }

    override fun loyaltyJoin(
        phone: String,
        firstName: String?,
        lastName: String?,
        gender: String?,
        birthday: String?,
        shopId: String?,
        callback: (Result<LoyaltyMemberWire>) -> Unit,
    ) = call(shopId, callback) {
        it.loyalty.join(phone, firstName, lastName, gender(gender), birthday, completion(callback) { r -> r.toWire() })
    }

    override fun loyaltyGetStatus(phone: String, shopId: String?, callback: (Result<LoyaltyStatusWire>) -> Unit) =
        call(shopId, callback) { it.loyalty.getStatus(phone, completion(callback) { r -> r.toWire() }) }

    override fun loyaltyGetPromotions(
        locationId: String?,
        promoCodes: List<String>?,
        chargeBonuses: Boolean?,
        currentTime: String?,
        shopId: String?,
        callback: (Result<List<LoyaltyPromotionWire>>) -> Unit,
    ) = call(shopId, callback) {
        it.loyalty.getPromotions(
            locationId, promoCodes, chargeBonuses, currentTime,
            completion(callback) { list -> list.map { p -> p.toWire() } },
        )
    }

    override fun slidersGet(
        code: String,
        tags: List<String>?,
        locationId: String?,
        shopId: String?,
        callback: (Result<SliderWire>) -> Unit,
    ) = call(shopId, callback) { it.sliders.get(code, tags, locationId, completion(callback) { r -> r.toWire() }) }

    // endregion

    // region reviews

    override fun reviewsCreateNps(
        rate: Long,
        channel: String,
        category: String,
        orderId: String?,
        comment: String?,
        label: String?,
        shopId: String?,
        callback: (Result<PollReviewWire>) -> Unit,
    ) = call(shopId, callback) {
        it.reviews.createNps(
            toIntExact(rate, "rate"), channel, category, orderId, comment, label,
            completion(callback) { r -> r.toWire() },
        )
    }

    override fun reviewsCreateCsat(
        rate: Long,
        channel: String,
        campaign: String,
        orderId: String?,
        comment: String?,
        label: String?,
        shopId: String?,
        callback: (Result<PollReviewWire>) -> Unit,
    ) = call(shopId, callback) {
        it.reviews.createCsat(
            toIntExact(rate, "rate"), channel, campaign, orderId, comment, label,
            completion(callback) { r -> r.toWire() },
        )
    }

    override fun reviewsCreateCes(
        rate: Long,
        channel: String,
        campaign: String,
        orderId: String?,
        comment: String?,
        label: String?,
        shopId: String?,
        callback: (Result<PollReviewWire>) -> Unit,
    ) = call(shopId, callback) {
        it.reviews.createCes(
            toIntExact(rate, "rate"), channel, campaign, orderId, comment, label,
            completion(callback) { r -> r.toWire() },
        )
    }

    override fun reviewsGetNpsCategories(shopId: String?, callback: (Result<List<NpsCategoryWire>>) -> Unit) =
        call(shopId, callback) { it.reviews.getNpsCategories(completion(callback) { l -> l.map { c -> c.toWire() } }) }

    override fun reviewsGetNpsChannels(shopId: String?, callback: (Result<List<PollChannelWire>>) -> Unit) =
        call(shopId, callback) { it.reviews.getNpsChannels(completion(callback) { l -> l.map { c -> c.toWire() } }) }

    override fun reviewsGetCsatCampaigns(shopId: String?, callback: (Result<List<CsatCampaignWire>>) -> Unit) =
        call(shopId, callback) { it.reviews.getCsatCampaigns(completion(callback) { l -> l.map { c -> c.toWire() } }) }

    override fun reviewsGetCesCampaigns(shopId: String?, callback: (Result<List<CesCampaignWire>>) -> Unit) =
        call(shopId, callback) { it.reviews.getCesCampaigns(completion(callback) { l -> l.map { c -> c.toWire() } }) }

    override fun reviewsGetProductReviews(
        itemId: String,
        limit: Long?,
        offset: Long?,
        shopId: String?,
        callback: (Result<ProductReviewsResponseWire>) -> Unit,
    ) = call(shopId, callback) {
        it.reviews.getProductReviews(
            itemId,
            limit?.let { value -> toIntExact(value, "limit") },
            offset?.let { value -> toIntExact(value, "offset") },
            completion(callback) { r -> r.toWire() },
        )
    }

    override fun reviewsGetClientReviews(
        orderId: String,
        shopId: String?,
        callback: (Result<List<ClientReviewWire>>) -> Unit,
    ) = call(shopId, callback) {
        it.reviews.getClientReviews(orderId, completion(callback) { l -> l.map { r -> r.toWire() } })
    }

    // endregion

    // region UI plumbing

    override fun openUrl(url: String, callback: (Result<Boolean>) -> Unit) {
        val uri = Uri.parse(url)
        if (url.isBlank() || uri.scheme.isNullOrEmpty()) {
            callback(Result.success(false))
            return
        }
        // The activity when there is one: from the application context a new task is required.
        val activity = activityBinding?.activity
        val intent = Intent(Intent.ACTION_VIEW, uri)
        if (activity == null) intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            (activity ?: applicationContext).startActivity(intent)
            callback(Result.success(true))
        } catch (e: ActivityNotFoundException) {
            callback(Result.success(false))
        }
    }

    override fun shareUrl(
        url: String,
        anchorX: Double,
        anchorY: Double,
        anchorWidth: Double,
        anchorHeight: Double,
        callback: (Result<Unit>) -> Unit,
    ) {
        // The anchor is for the iPad popover; the Android chooser has none.
        val send = Intent(Intent.ACTION_SEND)
            .setType("text/plain")
            .putExtra(Intent.EXTRA_TEXT, url)
        val chooser = Intent.createChooser(send, null)
        val activity = activityBinding?.activity
        if (activity == null) chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            (activity ?: applicationContext).startActivity(chooser)
        } catch (e: ActivityNotFoundException) {
            callback(Result.failure(FlutterError("share_failed", e.message, null)))
            return
        }
        if (activity == null) {
            callback(Result.success(Unit))
            return
        }
        ShareSheetWatcher(activity.window.decorView, callback).start()
    }

    override fun openNotificationSettings() {
        val packageName = applicationContext.packageName
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
        } else {
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
        }
        val activity = activityBinding?.activity
        if (activity == null) intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            (activity ?: applicationContext).startActivity(intent)
        } catch (e: ActivityNotFoundException) {
            android.util.Log.w(Rees46PushNotifier.TAG, "No notification settings screen", e)
        }
    }

    // region stories viewer (UI kit)

    override fun getStoriesSeen(shop: String): Map<String, List<String>> =
        StoriesSeenStore.read(applicationContext, shop)

    override fun setStorySlideSeen(shop: String, storyId: String, slideId: String) =
        StoriesSeenStore.add(applicationContext, shop, storyId, slideId)

    override fun getCacheDirectory(): String = applicationContext.cacheDir.absolutePath

    // The audio session calls are iOS-only. On Android video_player plays with
    // `mixWithOthers: true` and so never requests the audio focus: a muted video leaves the
    // user's music alone, and there is no session to restore.
    override fun beginStoriesAudio() = Unit

    override fun updateStoriesAudio(muted: Boolean) = Unit

    override fun endStoriesAudio() = Unit

    // endregion

    // endregion

    // region pushes the plugin draws

    /**
     * One process-global, shop-aware listener (not per instance) so a push for any shop routes here with its
     * shop id: it draws a heads-up BigPicture notification (image, tap opens the app), reports it shown
     * (`opened`: the bridge draws the notification, so the bridge reports it) and forwards the push to Dart
     * (`onPushReceived` / `onPushDelivered`), tagged with its shop.
     */
    private fun installMessageListener() {
        Rees46.setOnMessageListener { messageShopId, data ->
            android.util.Log.d(Rees46PushNotifier.TAG, "onMessage (plugin listener) shop=$messageShopId id=${data.id}")
            val payload = data.toPayload()
            // The listener fires on an FCM background thread, but the Pigeon channels are @UiThread: every
            // call to Dart goes from the main thread, and the notification is drawn off it.
            coroutineScope.launch {
                runCatching { flutterApi?.onPushReceived(messageShopId, payload) { _ -> } }
                val shown = withContext(Dispatchers.IO) {
                    Rees46PushNotifier.show(applicationContext, data, messageShopId)
                }
                if (shown) Rees46PushNotifier.reportShown(messageShopId, data)
                runCatching { flutterApi?.onPushDelivered(messageShopId, payload) { _ -> } }
            }
        }
    }

    /**
     * A tap on a notification the plugin drew opened the app: the native `Rees46.handlePush` tracks the click
     * once per message (the intent's `NOTIFICATION_TYPE` and `NOTIFICATION_ID` are the push's type and id),
     * and Dart hears it, tagged with the shop.
     */
    private fun handleNotificationLaunchIntent(intent: Intent?) {
        val extras = intent?.extras ?: return
        if (!extras.isPersonalizationNotificationClick()) {
            return
        }
        val payload = extras.toStringPayloadMap()
        val type = payload[NotificationClickExtraKeys.NOTIFICATION_TYPE] ?: return
        val id = payload[NotificationClickExtraKeys.NOTIFICATION_ID] ?: return
        val signature = "$type|$id"
        if (!shouldProcessClickSignature(signature)) {
            return
        }
        try {
            val shopId = payload[SHOP_ID_KEY]
            val stringPayload = payload.filterValues { it != null }.mapValues { it.value!! }
            Rees46.handlePush(stringPayload, PushEvent.CLICKED)
            flutterApi?.onPushClicked(shopId, payload) { _ -> }
        } catch (_: Throwable) {
            // The shop may not be up yet; the push is the SDK's to drop.
        }
    }

    // endregion

    companion object {
        private const val NOTIFICATION_CLICK_DEBOUNCE_MS = 800L
        private const val SHOP_ID_KEY = "shop_id"

        private var lastClickSignature: String? = null
        private var lastClickAtElapsedMs: Long = 0L

        private fun shouldProcessClickSignature(signature: String): Boolean {
            val now = SystemClock.elapsedRealtime()
            if (signature == lastClickSignature && now - lastClickAtElapsedMs < NOTIFICATION_CLICK_DEBOUNCE_MS) {
                return false
            }
            lastClickSignature = signature
            lastClickAtElapsedMs = now
            return true
        }
    }
}

/** A whole number from Dart as the native `Int`; one outside it is `invalidArgument`. */
internal fun toIntExact(value: Long, name: String): Int {
    if (value < Int.MIN_VALUE || value > Int.MAX_VALUE) throw IllegalArgumentException("$name is out of range")
    return value.toInt()
}

/** An event's whole number (`time`, `value`) as the native `Int`, held to its range as before. */
internal fun toIntClamped(value: Long): Int = value.coerceIn(Int.MIN_VALUE.toLong(), Int.MAX_VALUE.toLong()).toInt()

/** Matches [com.personalization.features.notification.domain.model.NotificationConstants]. */
private object NotificationClickExtraKeys {
    const val NOTIFICATION_TYPE = "NOTIFICATION_TYPE"
    const val NOTIFICATION_ID = "NOTIFICATION_ID"
}

private fun Bundle.isPersonalizationNotificationClick(): Boolean {
    return !getString(NotificationClickExtraKeys.NOTIFICATION_TYPE).isNullOrBlank() &&
        !getString(NotificationClickExtraKeys.NOTIFICATION_ID).isNullOrBlank()
}

private fun Bundle.toStringPayloadMap(): Map<String, String?> {
    val map = mutableMapOf<String, String?>()
    for (key in keySet()) {
        val value = get(key) ?: continue
        map[key] = value.toString()
    }
    return map
}

private fun NotificationData.toPayload(): Map<String, String?> {
    val map = mutableMapOf<String, String?>()
    map["id"] = id
    map["title"] = title
    map["body"] = body
    map["icon"] = icon
    map["type"] = type
    map["image"] = image
    if (!actions.isNullOrEmpty()) {
        val arr = JSONArray()
        actions!!.forEach { action ->
            arr.put(
                JSONObject().put("action", action.action).put("title", action.title)
            )
        }
        map["actions"] = arr.toString()
    }
    if (!actionUrls.isNullOrEmpty()) {
        map["actionUrls"] = actionUrls!!.joinToString(",")
    }
    event?.let { ev ->
        val json = JSONObject()
        json.put("type", ev.type ?: JSONObject.NULL)
        json.put("uri", ev.uri ?: JSONObject.NULL)
        ev.payload?.let { payload ->
            try {
                json.put("payload", JSONObject(payload))
            } catch (_: Exception) {
                json.put("payload", payload.toString())
            }
        }
        map["event"] = json.toString()
    }
    return map
}

/**
 * Completes [shareUrl][Rees46FlutterSdkPlugin.shareUrl] when the chooser is gone: the window of
 * the activity lost its focus to the chooser and got it back (the user picked a target and came
 * back, or closed the chooser). A chooser that never took the focus does not hold the viewer:
 * the call completes after [NO_SHEET_MS].
 */
private class ShareSheetWatcher(
    private val view: View,
    private val done: (Result<Unit>) -> Unit,
) : ViewTreeObserver.OnWindowFocusChangeListener {
    private var lost = !view.hasWindowFocus()
    private var finished = false

    fun start() {
        view.viewTreeObserver.addOnWindowFocusChangeListener(this)
        view.postDelayed({ if (!lost) finish() }, NO_SHEET_MS)
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        if (!hasFocus) {
            lost = true
        } else if (lost) {
            finish()
        }
    }

    private fun finish() {
        if (finished) return
        finished = true
        view.viewTreeObserver.removeOnWindowFocusChangeListener(this)
        done(Result.success(Unit))
    }

    private companion object {
        const val NO_SHEET_MS = 1500L
    }
}

