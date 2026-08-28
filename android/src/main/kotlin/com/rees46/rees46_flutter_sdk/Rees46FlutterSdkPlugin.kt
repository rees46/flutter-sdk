package com.rees46.rees46_flutter_sdk

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.SystemClock
import com.rees46.rees46_flutter_sdk.pigeon.FlutterError
import com.rees46.rees46_flutter_sdk.pigeon.InitConfig
import com.rees46.rees46_flutter_sdk.pigeon.PersonalizationFlutterApi
import com.rees46.rees46_flutter_sdk.pigeon.PersonalizationHostApi
import com.rees46.rees46_flutter_sdk.pigeon.ProfileParamsWire
import com.rees46.rees46_flutter_sdk.pigeon.PurchaseLineItemWire
import com.rees46.rees46_flutter_sdk.pigeon.TrackingItemWire
import com.rees46.rees46_flutter_sdk.pigeon.TrackingSourceWire
import com.google.gson.Gson
import com.personalization.Params
import com.personalization.PushEventType
import com.personalization.PushProvider
import com.personalization.Rees46
import com.personalization.Rees46Config
import com.personalization.SDK
import com.personalization.api.OnApiCallbackListener
import com.personalization.api.managers.TrackingApi
import com.personalization.api.models.tracking.TrackingItem
import com.personalization.api.models.tracking.TrackingSource
import com.personalization.api.models.tracking.TrackingSourceType
import com.personalization.api.params.ProfileParams
import com.personalization.api.params.SearchParams as NativeSearchParams
import com.personalization.sdk.data.models.dto.notification.NotificationData
import com.rees46.rees46_flutter_sdk.push.Rees46PushNotifier
import com.rees46.rees46_flutter_sdk.push.Rees46ShopStore
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.PluginRegistry
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject

/** Rees46FlutterSdkPlugin */
class Rees46FlutterSdkPlugin :
    FlutterPlugin,
    ActivityAware,
    PersonalizationHostApi {
    private lateinit var applicationContext: Context
    private val coroutineScope = CoroutineScope(Dispatchers.Main + Job())
    private var flutterApi: PersonalizationFlutterApi? = null
    private var activityBinding: ActivityPluginBinding? = null

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
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        PersonalizationHostApi.setUp(binding.binaryMessenger, null)
        flutterApi = null
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

    /**
     * Resolves the SDK instance a call targets via the multi-instance [Rees46]
     * facade. A null [shopId] resolves the single default instance; an unknown or
     * (with no id) ambiguous shop throws [com.personalization.UnknownShopIdException]
     * / [com.personalization.AmbiguousShopException], which the calling method turns
     * into a Flutter error. This is the F3 wiring; requires the native `Rees46`
     * facade (local `android-sdk` via `includeBuild`, or a version that ships it).
     */
    private fun sdk(shopId: String?): SDK = Rees46.getInstance(shopId)

    override fun getStoredPushToken(shopId: String?): String? =
        try {
            // Read the token from the resolved instance's own storage via the SDK's
            // public getter — NOT the legacy `DEFAULT_STORAGE_KEY` prefs. Multi-instance
            // partitions storage per shop_id (`personalization_sdk_<shopId>`), so the
            // legacy shared file is empty on a fresh install and the token would never
            // be found there.
            val sdk = sdk(shopId)
            sdk.getPushToken(PushProvider.FCM) ?: sdk.getPushToken(PushProvider.HMS)
        } catch (t: Throwable) {
            // Unknown/ambiguous shop, or the instance is not initialized yet.
            null
        }

    override fun initialize(config: InitConfig, callback: (Result<Unit>) -> Unit) {
        val shopId = config.shopId
        if (shopId.isBlank()) {
            callback(Result.failure(FlutterError("bad_args", "shopId is required", null)))
            return
        }
        try {
            val shopConfig = Rees46Config(
                shopId = shopId,
                apiDomain = config.apiDomain,
                stream = config.stream,
                autoSendPushToken = config.autoSendPushToken,
                needReInitialization = config.needReInitialization,
            )
            // F3: initialize (and register) the instance through the multi-instance
            // `Rees46` facade so it is reachable by shopId via Rees46.getInstance.
            Rees46.initialize(context = applicationContext, config = shopConfig)

            // Persist so the cold-start push provider (Rees46PushInitProvider) can re-register this
            // shop on a process FCM spins up before Dart runs — otherwise the registry is empty and
            // Rees46.handlePush drops the push (killed-app "push never arrives" on Android).
            Rees46ShopStore.save(applicationContext, shopConfig)

            Rees46PushNotifier.ensureChannel(applicationContext)

            // FL-5: one process-global, shop-aware listener (not per-instance) so a push for any
            // shop routes here with its shopId. Shows a heads-up BigPicture notification (pop-up,
            // image, tap opens the app) and forwards to Dart (onPushReceived / onPushDelivered)
            // tagged with the shop it routed to, so the Dart dispatcher delivers it to that shop.
            Rees46.setOnMessageListener { messageShopId, data ->
                android.util.Log.d(
                    Rees46PushNotifier.TAG,
                    "onMessage (plugin listener) shop=$messageShopId id=${data.id}",
                )
                val payload = data.toPayload()
                // The listener fires on an FCM background thread, but flutterApi is a Pigeon
                // channel whose methods are @UiThread — calling them off the main thread throws
                // and would abort before the notification is posted. Hop to Main (coroutineScope
                // is Dispatchers.Main) for every flutterApi call, download+post the notification
                // off the main thread, and never let a flutterApi failure block the display.
                coroutineScope.launch {
                    runCatching { flutterApi?.onPushReceived(messageShopId, payload) { _ -> } }
                    withContext(Dispatchers.IO) {
                        Rees46PushNotifier.show(applicationContext, data)
                    }
                    runCatching { flutterApi?.onPushDelivered(messageShopId, payload) { _ -> } }
                }
            }

            callback(Result.success(Unit))
        } catch (t: Throwable) {
            callback(Result.failure(FlutterError("init_failed", t.message, null)))
        }
    }

    override fun getRecommendation(
        code: String,
        paramsJson: String?,
        shopId: String?,
        callback: (Result<String>) -> Unit,
    ) {
        if (code.isBlank()) {
            callback(Result.failure(FlutterError("bad_args", "code is required", null)))
            return
        }
        try {
            val params = buildRecommendationParams(paramsJson)
            sdk(shopId).recommendationManager.getExtendedRecommendation(
                recommenderCode = code,
                params = params,
                onGetExtendedRecommendation = { response ->
                    callback(Result.success(Gson().toJson(response)))
                },
                onError = { code, message ->
                    callback(Result.failure(FlutterError("recommendation_failed", message ?: "error $code", null)))
                },
            )
        } catch (t: Throwable) {
            callback(Result.failure(FlutterError("recommendation_failed", t.message, null)))
        }
    }

    override fun getProductInfo(itemId: String, shopId: String?, callback: (Result<String>) -> Unit) {
        if (itemId.isBlank()) {
            callback(Result.failure(FlutterError("bad_args", "itemId is required", null)))
            return
        }
        try {
            sdk(shopId).productsManager.getProductInfo(
                itemId = itemId,
                listener = object : OnApiCallbackListener() {
                    override fun onSuccess(response: org.json.JSONObject?) {
                        if (response != null) {
                            callback(Result.success(response.toString()))
                        } else {
                            callback(Result.failure(FlutterError("product_info_failed", "Empty response", null)))
                        }
                    }
                }
            )
        } catch (t: Throwable) {
            callback(Result.failure(FlutterError("product_info_failed", t.message, null)))
        }
    }

    override fun getProductsList(paramsJson: String?, shopId: String?, callback: (Result<String>) -> Unit) {
        try {
            val p = if (!paramsJson.isNullOrBlank()) JSONObject(paramsJson) else null
            val brands = p?.optString("brands")?.takeIf { it.isNotEmpty() }
            val merchants = p?.optString("merchants")?.takeIf { it.isNotEmpty() }
            val categories = p?.optString("categories")?.takeIf { it.isNotEmpty() }
            val locations = p?.optString("locations")?.takeIf { it.isNotEmpty() }
            val limit = if (p?.has("limit") == true) p.optInt("limit") else null
            val page = if (p?.has("page") == true) p.optInt("page") else null
            val filters: Map<String, Any>? = p?.optJSONObject("filters")?.let { obj ->
                obj.keys().asSequence().associateWith { key -> obj.get(key) }
            }
            sdk(shopId).productsManager.getProductsList(
                brands = brands,
                merchants = merchants,
                categories = categories,
                locations = locations,
                limit = limit,
                page = page,
                filters = filters,
                listener = object : OnApiCallbackListener() {
                    override fun onSuccess(response: org.json.JSONObject?) {
                        if (response != null) {
                            callback(Result.success(response.toString()))
                        } else {
                            callback(Result.failure(FlutterError("products_list_failed", "Empty response", null)))
                        }
                    }
                }
            )
        } catch (t: Throwable) {
            callback(Result.failure(FlutterError("products_list_failed", t.message, null)))
        }
    }

    override fun searchBlank(shopId: String?, callback: (Result<String>) -> Unit) {
        try {
            sdk(shopId).searchManager.searchBlank(
                onSearchBlank = { response ->
                    callback(Result.success(Gson().toJson(response)))
                },
                onError = { code, message ->
                    callback(Result.failure(FlutterError("search_blank_failed", message ?: "error $code", null)))
                },
            )
        } catch (t: Throwable) {
            callback(Result.failure(FlutterError("search_blank_failed", t.message, null)))
        }
    }

    override fun searchInstant(
        query: String,
        paramsJson: String?,
        shopId: String?,
        callback: (Result<String>) -> Unit,
    ) {
        if (query.isBlank()) {
            callback(Result.failure(FlutterError("bad_args", "query is required", null)))
            return
        }
        try {
            val json = if (!paramsJson.isNullOrBlank()) JSONObject(paramsJson) else null
            val locations = json?.optString("locations")?.takeIf { it.isNotEmpty() }
            val excludedBrands = jsonArrayToStringList(json?.optJSONArray("excluded_brands"))
            sdk(shopId).searchManager.searchInstant(
                query = query,
                locations = locations,
                excludedMerchants = null,
                excludedBrands = excludedBrands,
                onSearchInstant = { response ->
                    callback(Result.success(Gson().toJson(response)))
                },
                onError = { code, message ->
                    callback(Result.failure(FlutterError("search_instant_failed", message ?: "error $code", null)))
                },
            )
        } catch (t: Throwable) {
            callback(Result.failure(FlutterError("search_instant_failed", t.message, null)))
        }
    }

    override fun searchFull(
        query: String,
        paramsJson: String?,
        shopId: String?,
        callback: (Result<String>) -> Unit,
    ) {
        if (query.isBlank()) {
            callback(Result.failure(FlutterError("bad_args", "query is required", null)))
            return
        }
        try {
            val params = buildSearchParams(paramsJson)
            sdk(shopId).searchManager.searchFull(
                query = query,
                searchParams = params,
                onSearchFull = { response ->
                    callback(Result.success(Gson().toJson(response)))
                },
                onError = { code, message ->
                    callback(Result.failure(FlutterError("search_failed", message ?: "error $code", null)))
                },
            )
        } catch (t: Throwable) {
            callback(Result.failure(FlutterError("search_failed", t.message, null)))
        }
    }

    override fun joinLoyalty(
        phone: String,
        email: String?,
        firstName: String?,
        lastName: String?,
        shopId: String?,
        callback: (Result<String>) -> Unit,
    ) {
        if (phone.isBlank()) {
            callback(Result.failure(FlutterError("bad_args", "phone is required", null)))
            return
        }
        try {
            sdk(shopId).loyaltyManager.join(
                phone = phone,
                email = email,
                firstName = firstName,
                lastName = lastName,
                onSuccess = { response ->
                    callback(Result.success(Gson().toJson(response)))
                },
                onError = { code, message ->
                    callback(Result.failure(FlutterError("join_loyalty_failed", message ?: "error $code", null)))
                },
            )
        } catch (t: Throwable) {
            callback(Result.failure(FlutterError("join_loyalty_failed", t.message, null)))
        }
    }

    override fun getLoyaltyStatus(identifier: String, shopId: String?, callback: (Result<String>) -> Unit) {
        if (identifier.isBlank()) {
            callback(Result.failure(FlutterError("bad_args", "identifier is required", null)))
            return
        }
        try {
            sdk(shopId).loyaltyManager.getStatus(
                identifier = identifier,
                onSuccess = { response ->
                    callback(Result.success(Gson().toJson(response)))
                },
                onError = { code, message ->
                    callback(Result.failure(FlutterError("loyalty_status_failed", message ?: "error $code", null)))
                },
            )
        } catch (t: Throwable) {
            callback(Result.failure(FlutterError("loyalty_status_failed", t.message, null)))
        }
    }

    override fun getProfile(shopId: String?, callback: (Result<String>) -> Unit) {
        try {
            sdk(shopId).profileManager.getProfile(
                onSuccess = { response ->
                    callback(Result.success(Gson().toJson(response)))
                },
                onError = { code, message ->
                    callback(Result.failure(FlutterError("get_profile_failed", message ?: "error $code", null)))
                },
            )
        } catch (t: Throwable) {
            callback(Result.failure(FlutterError("get_profile_failed", t.message, null)))
        }
    }

    override fun getProductCounters(item: String, shopId: String?, callback: (Result<String>) -> Unit) {
        if (item.isBlank()) {
            callback(Result.failure(FlutterError("bad_args", "item is required", null)))
            return
        }
        try {
            sdk(shopId).productsManager.getProductCounters(
                item = item,
                onSuccess = { response ->
                    callback(Result.success(Gson().toJson(response)))
                },
                onError = { code, message ->
                    callback(Result.failure(FlutterError("product_counters_failed", message ?: "error $code", null)))
                },
            )
        } catch (t: Throwable) {
            callback(Result.failure(FlutterError("product_counters_failed", t.message, null)))
        }
    }

    override fun getCategory(
        category: String,
        limit: Long?,
        page: Long?,
        shopId: String?,
        callback: (Result<String>) -> Unit,
    ) {
        if (category.isBlank()) {
            callback(Result.failure(FlutterError("bad_args", "category is required", null)))
            return
        }
        try {
            sdk(shopId).categoryManager.getCategory(
                category = category,
                limit = limit?.toInt(),
                page = page?.toInt(),
                onSuccess = { response ->
                    callback(Result.success(Gson().toJson(response)))
                },
                onError = { code, message ->
                    callback(Result.failure(FlutterError("get_category_failed", message ?: "error $code", null)))
                },
            )
        } catch (t: Throwable) {
            callback(Result.failure(FlutterError("get_category_failed", t.message, null)))
        }
    }

    override fun getCollection(collectionId: String, shopId: String?, callback: (Result<String>) -> Unit) {
        if (collectionId.isBlank()) {
            callback(Result.failure(FlutterError("bad_args", "collectionId is required", null)))
            return
        }
        try {
            sdk(shopId).collectionManager.getCollection(
                collectionId = collectionId,
                onSuccess = { response ->
                    callback(Result.success(Gson().toJson(response)))
                },
                onError = { code, message ->
                    callback(Result.failure(FlutterError("get_collection_failed", message ?: "error $code", null)))
                },
            )
        } catch (t: Throwable) {
            callback(Result.failure(FlutterError("get_collection_failed", t.message, null)))
        }
    }

    override fun getSid(shopId: String?): String = sdk(shopId).getSid()

    override fun getDid(shopId: String?): String? = sdk(shopId).getDid()

    override fun setProfile(params: ProfileParamsWire, shopId: String?, callback: (Result<Unit>) -> Unit) {
        try {
            val builder = ProfileParams.Builder()
            params.email?.let { builder.put("email", it) }
            params.phone?.let { builder.put("phone", it) }
            params.loyaltyId?.let { builder.put("loyalty_id", it) }
            params.firstName?.let { builder.put("first_name", it) }
            params.lastName?.let { builder.put("last_name", it) }
            params.birthday?.let { builder.put("birthday", it) }
            params.age?.let { builder.put("age", it.toInt()) }
            params.gender?.let { builder.put("gender", it) }
            params.location?.let { builder.put("location", it) }
            params.advertisingId?.let { builder.put("advertising_id", it) }
            params.fbId?.let { builder.put("fb_id", it) }
            params.vkId?.let { builder.put("vk_id", it) }
            params.telegramId?.let { builder.put("telegram_id", it) }
            params.loyaltyCardLocation?.let { builder.put("loyalty_card_location", it) }
            params.loyaltyStatus?.let { builder.put("loyalty_status", it) }
            params.loyaltyBonuses?.let { builder.put("loyalty_bonuses", it.toInt()) }
            params.loyaltyBonusesToNextLevel?.let { builder.put("loyalty_bonuses_to_next_level", it.toInt()) }
            params.boughtSomething?.let { builder.put("bought_something", if (it) "1" else "0") }
            params.userId?.let { builder.put("id", it) }
            params.customPropertiesJson?.let { json ->
                val obj = JSONObject(json)
                obj.keys().forEach { key -> builder.put(key, obj.getString(key)) }
            }
            sdk(shopId).profile(builder.build(), object : OnApiCallbackListener() {
                override fun onSuccess(response: JSONObject?) {
                    callback(Result.success(Unit))
                }
                override fun onError(code: Int, msg: String?) {
                    callback(Result.failure(FlutterError("set_profile_failed", msg ?: "error $code", null)))
                }
            })
        } catch (t: Throwable) {
            callback(Result.failure(FlutterError("set_profile_failed", t.message, null)))
        }
    }

    // region tracking namespace
    //
    // Each method hands straight to the native `tracking` namespace of the resolved instance;
    // the wire models are translated one to one.

    override fun trackProductView(
        itemId: String,
        source: TrackingSourceWire?,
        shopId: String?,
        callback: (Result<Unit>) -> Unit,
    ) = trackingCall(callback, shopId) {
        it.productView(itemId, source.toNative(), trackingListener(callback))
    }

    override fun trackCategoryView(
        categoryId: String,
        shopId: String?,
        callback: (Result<Unit>) -> Unit,
    ) = trackingCall(callback, shopId) { it.categoryView(categoryId, trackingListener(callback)) }

    override fun trackSearch(
        query: String,
        results: List<String>?,
        shopId: String?,
        callback: (Result<Unit>) -> Unit,
    ) = trackingCall(callback, shopId) { it.search(query, results, trackingListener(callback)) }

    override fun trackAddToCart(
        item: TrackingItemWire,
        source: TrackingSourceWire?,
        shopId: String?,
        callback: (Result<Unit>) -> Unit,
    ) = trackingCall(callback, shopId) {
        it.addToCart(item.toNative(), source.toNative(), trackingListener(callback))
    }

    override fun trackSyncCart(
        items: List<TrackingItemWire>,
        shopId: String?,
        callback: (Result<Unit>) -> Unit,
    ) = trackingCall(callback, shopId) {
        it.syncCart(items.map { item -> item.toNative() }, trackingListener(callback))
    }

    override fun trackRemoveFromCart(
        itemId: String,
        shopId: String?,
        callback: (Result<Unit>) -> Unit,
    ) = trackingCall(callback, shopId) { it.removeFromCart(itemId, trackingListener(callback)) }

    override fun trackAddToFavorites(
        itemId: String,
        source: TrackingSourceWire?,
        shopId: String?,
        callback: (Result<Unit>) -> Unit,
    ) = trackingCall(callback, shopId) {
        it.addToFavorites(itemId, source.toNative(), trackingListener(callback))
    }

    override fun trackSyncFavorites(
        itemIds: List<String>,
        shopId: String?,
        callback: (Result<Unit>) -> Unit,
    ) = trackingCall(callback, shopId) { it.syncFavorites(itemIds, trackingListener(callback)) }

    override fun trackRemoveFromFavorites(
        itemId: String,
        shopId: String?,
        callback: (Result<Unit>) -> Unit,
    ) = trackingCall(callback, shopId) {
        it.removeFromFavorites(itemId, trackingListener(callback))
    }

    override fun trackStoryView(
        storyId: String,
        slideId: String,
        code: String?,
        shopId: String?,
        callback: (Result<Unit>) -> Unit,
    ) = trackingCall(callback, shopId) {
        it.storyView(storyId, slideId, code, trackingListener(callback))
    }

    override fun trackStoryClick(
        storyId: String,
        slideId: String,
        code: String?,
        shopId: String?,
        callback: (Result<Unit>) -> Unit,
    ) = trackingCall(callback, shopId) {
        it.storyClick(storyId, slideId, code, trackingListener(callback))
    }

    override fun trackSetSource(source: TrackingSourceWire, shopId: String?) {
        val native = source.toNative()
            ?: throw FlutterError("bad_args", "unknown source type: ${source.type}", null)
        sdk(shopId).tracking.setSource(native)
    }

    /** Resolves the instance, reports a resolution failure through [callback], then tracks. */
    private fun trackingCall(
        callback: (Result<Unit>) -> Unit,
        shopId: String?,
        body: (TrackingApi) -> Unit,
    ) {
        try {
            body(sdk(shopId).tracking)
        } catch (t: Throwable) {
            callback(Result.failure(FlutterError("track_failed", t.message, null)))
        }
    }

    private fun trackingListener(callback: (Result<Unit>) -> Unit) =
        object : OnApiCallbackListener() {
            override fun onSuccess(response: JSONObject?) {
                callback(Result.success(Unit))
            }

            override fun onError(code: Int, msg: String?) {
                val message = listOfNotNull(code.toString(), msg).joinToString(": ")
                callback(Result.failure(FlutterError("track_failed", message, null)))
            }
        }

    private fun TrackingItemWire.toNative(): TrackingItem = TrackingItem(
        id = id,
        quantity = quantity.toInt(),
        price = price,
        fashionSize = fashionSize,
    )

    /** An unknown source type is dropped rather than guessed — Dart only sends known values. */
    private fun TrackingSourceWire?.toNative(): TrackingSource? {
        val wire = this ?: return null
        val type = TrackingSourceType.entries.firstOrNull { it.value == wire.type } ?: return null
        return TrackingSource(type = type, code = wire.code)
    }

    // endregion

    override fun trackEvent(
        event: String,
        time: Long?,
        category: String?,
        label: String?,
        value: Long?,
        customFieldsJson: String?,
        shopId: String?,
        callback: (Result<Unit>) -> Unit,
    ) {
        if (event.isBlank()) {
            callback(Result.failure(FlutterError("bad_args", "event is required", null)))
            return
        }
        try {
            val customFields = jsonObjectStringToMap(customFieldsJson)
            FlutterTrackingBridge.postTrackEvent(
                sdk = sdk(shopId),
                event = event,
                time = time,
                category = category,
                label = label,
                value = value,
                customFields = customFields,
                callback = callback,
            )
        } catch (t: Throwable) {
            callback(Result.failure(FlutterError("track_event_failed", t.message, null)))
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
        promocode: String?,
        orderCash: Double?,
        orderBonuses: Double?,
        orderDelivery: Double?,
        orderDiscount: Double?,
        channel: String?,
        customJson: String?,
        recommendedSourceJson: String?,
        stream: String?,
        segment: String?,
        shopId: String?,
        callback: (Result<Unit>) -> Unit,
    ) {
        if (orderId.isBlank()) {
            callback(Result.failure(FlutterError("bad_args", "orderId is required", null)))
            return
        }
        if (items.isEmpty()) {
            callback(Result.failure(FlutterError("bad_args", "items must be non-empty", null)))
            return
        }
        try {
            val recommendedSource =
                if (recommendedSourceJson.isNullOrBlank()) {
                    null
                } else {
                    JSONObject(recommendedSourceJson)
                }
            FlutterTrackingBridge.postTrackPurchase(
                sdk = sdk(shopId),
                orderId = orderId,
                orderPrice = orderPrice,
                items = items,
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
                custom = jsonObjectStringToMap(customJson),
                recommendedSource = recommendedSource,
                stream = stream,
                segment = segment,
                callback = callback,
            )
        } catch (t: Throwable) {
            callback(Result.failure(FlutterError("track_purchase_failed", t.message, null)))
        }
    }

    override fun handlePush(
        payload: Map<String, String>,
        event: Long,
        callback: (Result<Unit>) -> Unit,
    ) {
        try {
            // Flutter PushEvent index: 0=received, 1=delivered, 2=clicked. Android's
            // PushEventType has no `delivered`, so received & delivered both track received.
            val type = if (event.toInt() == 2) PushEventType.CLICKED else PushEventType.RECEIVED
            Rees46.handlePush(payload, type)
            callback(Result.success(Unit))
        } catch (t: Throwable) {
            callback(Result.failure(FlutterError("handle_push_failed", t.message, null)))
        }
    }

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
            // FL-5: route the click through the multi-instance facade — it resolves the shop from
            // the payload's shop_id and tracks the click on that instance. Forward to Dart tagged
            // with the shop so the dispatcher delivers the click to it.
            val shopId = payload[SHOP_ID_KEY]
            val stringPayload = payload.filterValues { it != null }.mapValues { it.value!! }
            Rees46.handlePush(stringPayload, PushEventType.CLICKED)
            flutterApi?.onPushClicked(shopId, payload) { _ -> }
        } catch (_: Throwable) {
            // SDK may not be initialized yet; ignore.
        }
    }

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

private fun buildSearchParams(paramsJson: String?): NativeSearchParams {
    val params = NativeSearchParams()
    if (paramsJson.isNullOrBlank()) return params
    val json = JSONObject(paramsJson)
    json.optInt("limit").takeIf { it > 0 }
        ?.let { params.put(NativeSearchParams.Parameter.LIMIT, it) }
    json.optInt("page").takeIf { it > 0 }
        ?.let { params.put(NativeSearchParams.Parameter.PAGE, it) }
    json.optInt("category_limit").takeIf { it > 0 }
        ?.let { params.put(NativeSearchParams.Parameter.CATEGORY_LIMIT, it) }
    json.optInt("brand_limit").takeIf { it > 0 }
        ?.let { params.put(NativeSearchParams.Parameter.BRAND_LIMIT, it) }
    json.optString("sort_by").takeIf { it.isNotEmpty() }
        ?.let { params.put(NativeSearchParams.Parameter.SORT_BY, it) }
    json.optString("sort_dir").takeIf { it.isNotEmpty() }
        ?.let { params.put(NativeSearchParams.Parameter.SORT_DIR, it) }
    json.optString("locations").takeIf { it.isNotEmpty() }
        ?.let { params.put(NativeSearchParams.Parameter.LOCATIONS, it) }
    json.optString("brands").takeIf { it.isNotEmpty() }
        ?.let { params.put(NativeSearchParams.Parameter.BRANDS, it) }
    if (json.has("price_min"))
        params.put(NativeSearchParams.Parameter.PRICE_MIN, json.getDouble("price_min").toString())
    if (json.has("price_max"))
        params.put(NativeSearchParams.Parameter.PRICE_MAX, json.getDouble("price_max").toString())
    jsonArrayToStringArray(json.optJSONArray("categories"))
        ?.let { params.put(NativeSearchParams.Parameter.CATEGORIES, it) }
    jsonArrayToStringArray(json.optJSONArray("excluded_brands"))
        ?.let { params.put(NativeSearchParams.Parameter.EXCLUDED_BRANDS, it) }
    jsonArrayToStringArray(json.optJSONArray("colors"))
        ?.let { params.put(NativeSearchParams.Parameter.COLORS, it) }
    jsonArrayToStringArray(json.optJSONArray("fashion_sizes"))
        ?.let { params.put(NativeSearchParams.Parameter.FASHION_SIZES, it) }
    return params
}

private fun jsonArrayToStringArray(arr: org.json.JSONArray?): Array<String>? {
    if (arr == null || arr.length() == 0) return null
    return Array(arr.length()) { i -> arr.getString(i) }
}

private fun jsonArrayToStringList(arr: org.json.JSONArray?): List<String>? {
    if (arr == null || arr.length() == 0) return null
    return (0 until arr.length()).map { arr.getString(it) }
}

private fun buildRecommendationParams(paramsJson: String?): Params {
    val params = Params()
    if (paramsJson.isNullOrBlank()) return params
    val json = JSONObject(paramsJson)
    json.optString("item_id").takeIf { it.isNotEmpty() }
        ?.let { params.put(Params.Parameter.ITEM, it) }
    json.optString("category_id").takeIf { it.isNotEmpty() }
        ?.let { params.put(Params.Parameter.CATEGORY_ID, it) }
    json.optString("locations").takeIf { it.isNotEmpty() }
        ?.let { params.put(Params.Parameter.LOCATIONS, it) }
    if (json.has("image_size"))
        params.put(Params.Parameter.IMAGE_SIZE, json.getInt("image_size").toString())
    if (json.has("with_locations"))
        params.put(Params.Parameter.WITH_LOCATIONS, json.getBoolean("with_locations").toString())
    return params
}

private fun jsonObjectStringToMap(json: String?): Map<String, Any?>? {
    if (json.isNullOrBlank()) return null
    val root = JSONObject(json)
    return jsonObjectToNestedMap(root)
}

private fun jsonObjectToNestedMap(obj: JSONObject): Map<String, Any?> {
    val out = LinkedHashMap<String, Any?>()
    val keys = obj.keys()
    while (keys.hasNext()) {
        val key = keys.next()
        val raw = obj.get(key)
        out[key] = jsonValueToKotlin(raw)
    }
    return out
}

private fun jsonValueToKotlin(value: Any?): Any? {
    return when (value) {
        null, JSONObject.NULL -> null
        is JSONObject -> jsonObjectToNestedMap(value)
        is JSONArray -> jsonArrayToList(value)
        else -> value
    }
}

private fun jsonArrayToList(arr: JSONArray): List<Any?> {
    val list = ArrayList<Any?>(arr.length())
    for (i in 0 until arr.length()) {
        list.add(jsonValueToKotlin(arr.opt(i)))
    }
    return list
}

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
