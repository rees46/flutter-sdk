package com.rees46.rees46_flutter_sdk

import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Bundle
import android.os.SystemClock
import com.rees46.rees46_flutter_sdk.pigeon.FlutterError
import com.rees46.rees46_flutter_sdk.pigeon.InitConfig
import com.rees46.rees46_flutter_sdk.pigeon.PersonalizationFlutterApi
import com.rees46.rees46_flutter_sdk.pigeon.PersonalizationHostApi
import com.rees46.rees46_flutter_sdk.pigeon.ProfileParamsWire
import com.rees46.rees46_flutter_sdk.pigeon.PurchaseLineItemWire
import com.google.gson.Gson
import com.personalization.Params
import com.personalization.SDK
import com.personalization.api.OnApiCallbackListener
import com.personalization.api.params.ProfileParams
import com.personalization.api.params.SearchParams as NativeSearchParams
import com.personalization.features.notification.presentation.helpers.NotificationImageHelper
import com.personalization.sdk.data.models.dto.notification.NotificationData
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

    override fun getStoredPushToken(): String? {
        val prefs: SharedPreferences =
            applicationContext.getSharedPreferences(DEFAULT_STORAGE_KEY, Context.MODE_PRIVATE)
        return prefs.getString(TOKEN_KEY, null)
            ?.takeIf { it.isNotBlank() }
    }

    override fun initialize(config: InitConfig, callback: (Result<Unit>) -> Unit) {
        val shopId = config.shopId
        if (shopId.isBlank()) {
            callback(Result.failure(FlutterError("bad_args", "shopId is required", null)))
            return
        }
        try {
            val sdk = SDK.instance
            sdk.initialize(
                context = applicationContext,
                shopId = shopId,
                apiDomain = config.apiDomain,
                stream = config.stream,
                autoSendPushToken = config.autoSendPushToken,
                needReInitialization = config.needReInitialization,
            )

            // Mirror REES46 entrypoint behaviour: show notifications on message.
            sdk.setOnMessageListener { data ->
                val payload = data.toPayload()
                flutterApi?.onPushReceived(payload) { _ -> }
                coroutineScope.launch {
                    val (images, hasError) = withContext(Dispatchers.IO) {
                        NotificationImageHelper.loadBitmaps(urls = data.image)
                    }
                    sdk.notificationHelper.createNotification(
                        context = applicationContext,
                        data = NotificationData(
                            id = data.id,
                            title = data.title,
                            body = data.body,
                            icon = data.icon,
                            type = data.type,
                            actions = data.actions,
                            actionUrls = data.actionUrls,
                            image = data.image,
                            event = data.event,
                        ),
                        images = images,
                        hasError = hasError,
                    )
                    flutterApi?.onPushDelivered(payload) { _ -> }
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
        callback: (Result<String>) -> Unit,
    ) {
        if (code.isBlank()) {
            callback(Result.failure(FlutterError("bad_args", "code is required", null)))
            return
        }
        try {
            val params = buildRecommendationParams(paramsJson)
            SDK.instance.recommendationManager.getExtendedRecommendation(
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

    override fun getProductInfo(itemId: String, callback: (Result<String>) -> Unit) {
        if (itemId.isBlank()) {
            callback(Result.failure(FlutterError("bad_args", "itemId is required", null)))
            return
        }
        try {
            SDK.instance.productsManager.getProductInfo(
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

    override fun getProductsList(paramsJson: String?, callback: (Result<String>) -> Unit) {
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
            SDK.instance.productsManager.getProductsList(
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

    override fun searchBlank(callback: (Result<String>) -> Unit) {
        try {
            SDK.instance.searchManager.searchBlank(
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
            SDK.instance.searchManager.searchInstant(
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
        callback: (Result<String>) -> Unit,
    ) {
        if (query.isBlank()) {
            callback(Result.failure(FlutterError("bad_args", "query is required", null)))
            return
        }
        try {
            val params = buildSearchParams(paramsJson)
            SDK.instance.searchManager.searchFull(
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

    override fun getSid(): String = SDK.instance.getSid()

    override fun getDid(): String? = SDK.instance.getDid()

    override fun setProfile(params: ProfileParamsWire, callback: (Result<Unit>) -> Unit) {
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
            SDK.instance.profile(builder.build(), object : OnApiCallbackListener() {
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

    override fun trackEvent(
        event: String,
        time: Long?,
        category: String?,
        label: String?,
        value: Long?,
        customFieldsJson: String?,
        callback: (Result<Unit>) -> Unit,
    ) {
        if (event.isBlank()) {
            callback(Result.failure(FlutterError("bad_args", "event is required", null)))
            return
        }
        try {
            val customFields = jsonObjectStringToMap(customFieldsJson)
            FlutterTrackingBridge.postTrackEvent(
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
            SDK.instance.notificationClicked(extras)
            flutterApi?.onPushClicked(payload) { _ -> }
        } catch (_: Throwable) {
            // SDK may not be initialized yet; ignore.
        }
    }

    companion object {
        private const val NOTIFICATION_CLICK_DEBOUNCE_MS = 800L
        private const val DEFAULT_STORAGE_KEY = "DEFAULT_STORAGE_KEY"
        private const val TOKEN_KEY = "token"

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
