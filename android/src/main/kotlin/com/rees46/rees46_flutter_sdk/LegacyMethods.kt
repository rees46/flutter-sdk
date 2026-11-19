package com.rees46.rees46_flutter_sdk

import com.google.gson.Gson
import com.personalization.Params
import com.personalization.PushProvider
import com.personalization.SDK
import com.personalization.api.OnApiCallbackListener
import com.personalization.api.models.purchase.PurchaseItemRequest
import com.personalization.api.models.purchase.PurchaseTrackingRequest
import com.personalization.api.params.ProfileParams
import com.personalization.core.CompletionListener
import com.personalization.core.SdkError
import com.personalization.core.SdkResult
import com.personalization.api.params.SearchParams as NativeSearchParams
import com.personalization.SearchParams as LegacySearchParams
import com.personalization.sdk.data.models.params.UserBasicParams
import com.rees46.rees46_flutter_sdk.pigeon.FlutterError
import com.rees46.rees46_flutter_sdk.pigeon.ProfileParamsWire
import com.rees46.rees46_flutter_sdk.pigeon.PurchaseLineItemWire
import com.rees46.rees46_flutter_sdk.pigeon.SubscriptionsUpdateRequestWire
import org.json.JSONArray
import org.json.JSONObject

/**
 * The handle's deprecated methods as the plugin ran them in 1.6.4: each calls the native SDK's released method
 * of the same meaning — they still run on the new core — and answers Dart with the JSON 1.6.4 handed over
 * (the server's answer, or the native model through Gson), or fails with 1.6.4's error code: `bad_args` for an
 * argument it refuses, `<method>_failed` with the native error's message otherwise, an unknown shop too. The
 * namespaces are the typed contract; these stay as they were until they are removed.
 */
internal class LegacyMethods(private val sdk: (String?) -> SDK) {

    private fun fail(code: String, message: String?): Result<Nothing> = Result.failure(FlutterError(code, message, null))

    /** Answers [callback] on the main thread, where the plugin's replies go. */
    private fun <T> reply(callback: (Result<T>) -> Unit, result: Result<T>) = onMain { callback(result) }

    fun getRecommendation(code: String, paramsJson: String?, shopId: String?, callback: (Result<String>) -> Unit) {
        if (code.isBlank()) return reply(callback, fail("bad_args", "code is required"))
        try {
            sdk(shopId).recommendationManager.getExtendedRecommendation(
                recommenderCode = code,
                params = buildRecommendationParams(paramsJson),
                onGetExtendedRecommendation = { response -> reply(callback, Result.success(Gson().toJson(response))) },
                onError = { error, message -> reply(callback, fail("recommendation_failed", message ?: "error $error")) },
            )
        } catch (t: Throwable) {
            reply(callback, fail("recommendation_failed", t.message))
        }
    }

    fun getProductInfo(itemId: String, shopId: String?, callback: (Result<String>) -> Unit) {
        if (itemId.isBlank()) return reply(callback, fail("bad_args", "itemId is required"))
        try {
            sdk(shopId).productsManager.getProductInfo(itemId = itemId, listener = jsonListener("product_info_failed", callback))
        } catch (t: Throwable) {
            reply(callback, fail("product_info_failed", t.message))
        }
    }

    fun getProductsList(paramsJson: String?, shopId: String?, callback: (Result<String>) -> Unit) {
        try {
            val p = if (!paramsJson.isNullOrBlank()) JSONObject(paramsJson) else null
            val filters: Map<String, Any>? = p?.optJSONObject("filters")?.let { obj ->
                obj.keys().asSequence().associateWith { key -> obj.get(key) }
            }
            sdk(shopId).productsManager.getProductsList(
                brands = p?.optString("brands")?.takeIf { it.isNotEmpty() },
                merchants = p?.optString("merchants")?.takeIf { it.isNotEmpty() },
                categories = p?.optString("categories")?.takeIf { it.isNotEmpty() },
                locations = p?.optString("locations")?.takeIf { it.isNotEmpty() },
                limit = if (p?.has("limit") == true) p.optInt("limit") else null,
                page = if (p?.has("page") == true) p.optInt("page") else null,
                filters = filters,
                listener = jsonListener("products_list_failed", callback),
            )
        } catch (t: Throwable) {
            reply(callback, fail("products_list_failed", t.message))
        }
    }

    fun searchBlank(shopId: String?, callback: (Result<String>) -> Unit) {
        try {
            sdk(shopId).searchManager.searchBlank(
                onSearchBlank = { response -> reply(callback, Result.success(Gson().toJson(response))) },
                onError = { error, message -> reply(callback, fail("search_blank_failed", message ?: "error $error")) },
            )
        } catch (t: Throwable) {
            reply(callback, fail("search_blank_failed", t.message))
        }
    }

    fun searchInstant(query: String, paramsJson: String?, shopId: String?, callback: (Result<String>) -> Unit) {
        if (query.isBlank()) return reply(callback, fail("bad_args", "query is required"))
        try {
            val json = if (!paramsJson.isNullOrBlank()) JSONObject(paramsJson) else null
            sdk(shopId).searchManager.searchInstant(
                query = query,
                locations = json?.optString("locations")?.takeIf { it.isNotEmpty() },
                excludedMerchants = null,
                excludedBrands = jsonArrayToStringList(json?.optJSONArray("excluded_brands")),
                onSearchInstant = { response -> reply(callback, Result.success(Gson().toJson(response))) },
                onError = { error, message -> reply(callback, fail("search_instant_failed", message ?: "error $error")) },
            )
        } catch (t: Throwable) {
            reply(callback, fail("search_instant_failed", t.message))
        }
    }

    /** The raw search entry point, as 1.6.4: the server's JSON reaches Dart as it is. */
    fun searchFull(query: String, paramsJson: String?, shopId: String?, callback: (Result<String>) -> Unit) {
        if (query.isBlank()) return reply(callback, fail("bad_args", "query is required"))
        try {
            @Suppress("DEPRECATION")
            sdk(shopId).search(
                query,
                LegacySearchParams.TYPE.FULL,
                buildLegacySearchParams(paramsJson),
                object : OnApiCallbackListener() {
                    override fun onSuccess(response: JSONObject?) {
                        reply(callback, Result.success(response?.toString() ?: "{}"))
                    }

                    override fun onError(code: Int, msg: String?) {
                        reply(callback, fail("search_failed", msg ?: "error $code"))
                    }
                },
            )
        } catch (t: Throwable) {
            reply(callback, fail("search_failed", t.message))
        }
    }

    fun joinLoyalty(
        phone: String,
        email: String?,
        firstName: String?,
        lastName: String?,
        shopId: String?,
        callback: (Result<String>) -> Unit,
    ) {
        if (phone.isBlank()) return reply(callback, fail("bad_args", "phone is required"))
        try {
            sdk(shopId).loyaltyManager.join(
                phone = phone,
                email = email,
                firstName = firstName,
                lastName = lastName,
                onSuccess = { response -> reply(callback, Result.success(Gson().toJson(response))) },
                onError = { error, message -> reply(callback, fail("join_loyalty_failed", message ?: "error $error")) },
            )
        } catch (t: Throwable) {
            reply(callback, fail("join_loyalty_failed", t.message))
        }
    }

    fun getLoyaltyStatus(identifier: String, shopId: String?, callback: (Result<String>) -> Unit) {
        if (identifier.isBlank()) return reply(callback, fail("bad_args", "identifier is required"))
        try {
            sdk(shopId).loyaltyManager.getStatus(
                identifier = identifier,
                onSuccess = { response -> reply(callback, Result.success(Gson().toJson(response))) },
                onError = { error, message -> reply(callback, fail("loyalty_status_failed", message ?: "error $error")) },
            )
        } catch (t: Throwable) {
            reply(callback, fail("loyalty_status_failed", t.message))
        }
    }

    fun getProfile(shopId: String?, callback: (Result<String>) -> Unit) {
        try {
            sdk(shopId).profileManager.getProfile(
                onSuccess = { response -> reply(callback, Result.success(Gson().toJson(response))) },
                onError = { error, message -> reply(callback, fail("get_profile_failed", message ?: "error $error")) },
            )
        } catch (t: Throwable) {
            reply(callback, fail("get_profile_failed", t.message))
        }
    }

    fun getProductCounters(item: String, shopId: String?, callback: (Result<String>) -> Unit) {
        if (item.isBlank()) return reply(callback, fail("bad_args", "item is required"))
        try {
            sdk(shopId).productsManager.getProductCounters(
                item = item,
                onSuccess = { response -> reply(callback, Result.success(Gson().toJson(response))) },
                onError = { error, message -> reply(callback, fail("product_counters_failed", message ?: "error $error")) },
            )
        } catch (t: Throwable) {
            reply(callback, fail("product_counters_failed", t.message))
        }
    }

    fun getCategory(
        category: String,
        limit: Long?,
        page: Long?,
        paramsJson: String?,
        shopId: String?,
        callback: (Result<String>) -> Unit,
    ) {
        if (category.isBlank()) return reply(callback, fail("bad_args", "category is required"))
        try {
            val p = if (!paramsJson.isNullOrBlank()) JSONObject(paramsJson) else null
            val filters: Map<String, Any>? = p?.optJSONObject("filters")?.let { obj ->
                obj.keys().asSequence().associateWith { key -> obj.get(key) }
            }?.takeIf { it.isNotEmpty() }
            fun price(key: String): Double? = p?.takeIf { it.has(key) && !it.isNull(key) }?.getDouble(key)
            sdk(shopId).categoryManager.getCategory(
                category = category,
                limit = limit?.toInt(),
                page = page?.toInt(),
                brands = p?.optString("brands")?.takeIf { it.isNotEmpty() },
                locations = p?.optString("locations")?.takeIf { it.isNotEmpty() },
                filters = filters,
                priceMin = price("price_min"),
                priceMax = price("price_max"),
                sortBy = p?.optString("sort_by")?.takeIf { it.isNotEmpty() },
                sortDir = p?.optString("sort_dir")?.takeIf { it.isNotEmpty() },
                onSuccess = { response -> reply(callback, Result.success(Gson().toJson(response))) },
                onError = { error, message -> reply(callback, fail("get_category_failed", message ?: "error $error")) },
            )
        } catch (t: Throwable) {
            reply(callback, fail("get_category_failed", t.message))
        }
    }

    fun getCollection(collectionId: String, shopId: String?, callback: (Result<String>) -> Unit) {
        if (collectionId.isBlank()) return reply(callback, fail("bad_args", "collectionId is required"))
        try {
            sdk(shopId).collectionManager.getCollection(
                collectionId = collectionId,
                onSuccess = { response -> reply(callback, Result.success(Gson().toJson(response))) },
                onError = { error, message -> reply(callback, fail("get_collection_failed", message ?: "error $error")) },
            )
        } catch (t: Throwable) {
            reply(callback, fail("get_collection_failed", t.message))
        }
    }

    /** The raw stories entry point: the server's JSON as it is, the payload the iOS bridge hands over too. */
    fun getStories(code: String, shopId: String?, callback: (Result<String>) -> Unit) {
        if (code.isBlank()) return reply(callback, fail("bad_args", "code is required"))
        try {
            sdk(shopId).stories(
                code,
                object : OnApiCallbackListener() {
                    override fun onSuccess(response: JSONObject?) {
                        reply(callback, Result.success(response?.toString() ?: "{}"))
                    }

                    override fun onError(code: Int, msg: String?) {
                        reply(callback, fail("get_stories_failed", msg ?: "error $code"))
                    }
                },
            )
        } catch (t: Throwable) {
            reply(callback, fail("get_stories_failed", t.message))
        }
    }

    fun setProfile(params: ProfileParamsWire, shopId: String?, callback: (Result<Unit>) -> Unit) {
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
            // The API has no `advertising_id`: the native SDK sends the Google advertising id as
            // `google_advertising_id`.
            params.advertisingId?.let { builder.put("google_advertising_id", it) }
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
            sdk(shopId).profile(builder.build(), unitListener("set_profile_failed", callback))
        } catch (t: Throwable) {
            reply(callback, fail("set_profile_failed", t.message))
        }
    }

    fun manageSubscription(params: SubscriptionsUpdateRequestWire, shopId: String?, callback: (Result<Unit>) -> Unit) {
        try {
            val subscriptions = HashMap<String, Boolean>()
            fun put(key: String, value: Boolean?) {
                value?.let { subscriptions[key] = it }
            }
            put("email_bulk", params.emailBulk)
            put("email_chain", params.emailChain)
            put("email_transactional", params.emailTransactional)
            put("sms_bulk", params.smsBulk)
            put("sms_chain", params.smsChain)
            put("sms_transactional", params.smsTransactional)
            put("web_push_bulk", params.webPushBulk)
            put("web_push_chain", params.webPushChain)
            put("web_push_transactional", params.webPushTransactional)
            put("mobile_push_bulk", params.mobilePushBulk)
            put("mobile_push_chain", params.mobilePushChain)
            put("mobile_push_transactional", params.mobilePushTransactional)
            put("telegram_bulk", params.telegramBulk)
            put("telegram_chain", params.telegramChain)
            put("telegram_transactional", params.telegramTransactional)
            put("whatsapp_bulk", params.whatsappBulk)
            put("whatsapp_chain", params.whatsappChain)
            put("whatsapp_transactional", params.whatsappTransactional)
            put("max_bulk", params.maxBulk)
            put("max_chain", params.maxChain)
            put("max_transactional", params.maxTransactional)
            put("wallet_bulk", params.walletBulk)
            sdk(shopId).manageSubscription(
                params.email,
                params.phone,
                params.externalId,
                params.loyaltyId,
                params.telegramId,
                subscriptions,
                unitListener("manage_subscription_failed", callback),
            )
        } catch (t: Throwable) {
            reply(callback, fail("manage_subscription_failed", t.message))
        }
    }

    /**
     * `push/custom` as 1.6.4 built it — the event's fields and the custom fields at the top level and in
     * `payload`, the keys the request owns refused — through the native `tracking.queued.custom`, which
     * sends the same body. It completes once the shop's queue accepted the event: on the new core the
     * server's answer can be days away (no network), and an app awaiting it before going on would wait
     * that long. A refusal before the queue is `track_event_failed`.
     */
    fun trackEvent(
        event: String,
        time: Long?,
        category: String?,
        label: String?,
        value: Long?,
        customFieldsJson: String?,
        shopId: String?,
        callback: (Result<Unit>) -> Unit,
    ) {
        if (event.isBlank()) return reply(callback, fail("bad_args", "event is required"))
        try {
            val custom = (jsonObjectStringToMap(customFieldsJson) ?: emptyMap())
                .filter { (key, field) -> key.isNotBlank() && field != null }
                .mapValues { it.value!! }
            val collisions = custom.keys.intersect(RESERVED_CUSTOM_EVENT_KEYS)
            if (collisions.isNotEmpty()) {
                val sorted = collisions.toSortedSet().joinToString(", ")
                return reply(
                    callback,
                    Result.failure(
                        FlutterError(
                            "track_event_failed",
                            "trackEvent: customFields contains reserved keys: $sorted",
                            mapOf("code" to TRACK_EVENT_CLIENT_ERROR_CODE),
                        ),
                    ),
                )
            }
            sdk(shopId).tracking.queued.custom(
                event = event,
                time = time?.let(::toIntClamped),
                category = category,
                label = label,
                value = value?.let(::toIntClamped),
                customFields = custom.ifEmpty { null },
                listener = accepted("track_event_failed", TRACK_EVENT_CLIENT_ERROR_CODE, callback),
            )
        } catch (t: Throwable) {
            reply(callback, fail("track_event_failed", t.message))
        }
    }

    fun trackPurchase(
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
        customJson: String?,
        recommendedSourceJson: String?,
        stream: String?,
        segment: String?,
        shopId: String?,
        callback: (Result<Unit>) -> Unit,
    ) {
        if (orderId.isBlank()) return reply(callback, fail("bad_args", "orderId is required"))
        if (items.isEmpty()) return reply(callback, fail("bad_args", "items must be non-empty"))
        try {
            val request = PurchaseTrackingRequest(
                orderId = orderId,
                orderPrice = orderPrice,
                items = items.map {
                    PurchaseItemRequest(id = it.id, amount = it.amount.toInt(), price = it.price, lineId = it.lineId, fashionSize = it.fashionSize)
                },
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
                recommendedSource = if (recommendedSourceJson.isNullOrBlank()) null else JSONObject(recommendedSourceJson),
                stream = stream,
                segment = segment,
                isGiftPackage = isGiftPackage,
            )
            // The same request as `tracking.purchase`, completed once the shop's queue accepted it: the
            // server's answer can be days away, and the app must not take a late one for a lost purchase.
            sdk(shopId).tracking.queued.purchase(
                request,
                null,
                accepted("track_purchase_failed", PURCHASE_CLIENT_VALIDATION_ERROR_CODE, callback),
            )
        } catch (t: Throwable) {
            reply(callback, fail("track_purchase_failed", t.message))
        }
    }

    /** The shop's FCM token, else its HMS one; null when there is none or the shop is not found. */
    fun getStoredPushToken(shopId: String?): String? = try {
        val instance = sdk(shopId)
        instance.getPushToken(PushProvider.FCM) ?: instance.getPushToken(PushProvider.HMS)
    } catch (t: Throwable) {
        null
    }

    private fun jsonListener(errorCode: String, callback: (Result<String>) -> Unit) =
        object : OnApiCallbackListener() {
            override fun onSuccess(response: JSONObject?) {
                if (response != null) {
                    reply(callback, Result.success(response.toString()))
                } else {
                    reply(callback, fail(errorCode, "Empty response"))
                }
            }

            override fun onSuccess(response: JSONArray) {
                reply(callback, Result.success(response.toString()))
            }

            override fun onError(code: Int, msg: String?) {
                reply(callback, fail(errorCode, msg ?: "error $code"))
            }
        }

    /**
     * Completes [callback] once the queue accepted the event. A refusal fails with 1.6.4's [errorCode]; one
     * of the arguments (`invalidArgument`) carries [validationCode] in `details`, as the native builder's
     * refusal did.
     */
    private fun accepted(errorCode: String, validationCode: Int, callback: (Result<Unit>) -> Unit) =
        CompletionListener<Unit> { result ->
            when (result) {
                is SdkResult.Success -> reply(callback, Result.success(Unit))
                is SdkResult.Failure -> {
                    val error = result.error
                    val details = if (error is SdkError.InvalidArgument) mapOf("code" to validationCode) else null
                    reply(callback, Result.failure(FlutterError(errorCode, error.message, details)))
                }
            }
        }

    private fun unitListener(errorCode: String, callback: (Result<Unit>) -> Unit) =
        object : OnApiCallbackListener() {
            override fun onSuccess(response: JSONObject?) {
                reply(callback, Result.success(Unit))
            }

            override fun onError(code: Int, msg: String?) {
                reply(callback, fail(errorCode, msg ?: "error $code"))
            }
        }

    internal companion object {
        /** The native builder's code for a purchase it refused before sending, kept in `details`. */
        const val PURCHASE_CLIENT_VALIDATION_ERROR_CODE = -2
        private const val TRACK_EVENT_CLIENT_ERROR_CODE = -1

        /** The keys of `push/custom` the request owns: a custom field may not take them. */
        val RESERVED_CUSTOM_EVENT_KEYS: Set<String> = setOf(
            UserBasicParams.SHOP_ID, UserBasicParams.DID, UserBasicParams.SEANCE, UserBasicParams.SID,
            UserBasicParams.SEGMENT, "stream", "event", "time", "category", "label", "value", "source",
            "payload", "from", "code",
        )
    }
}

/**
 * Search parameters from the bridge's JSON, on the legacy params class the raw search entry point takes. Keys
 * come from the current parameter enum — both classes implement the same interface — so the wire names stay.
 */
@Suppress("DEPRECATION")
internal fun buildLegacySearchParams(paramsJson: String?): LegacySearchParams {
    val params = LegacySearchParams()
    if (paramsJson.isNullOrBlank()) return params
    val json = JSONObject(paramsJson)
    json.optInt("limit").takeIf { it > 0 }?.let { params.put(NativeSearchParams.Parameter.LIMIT, it) }
    json.optInt("page").takeIf { it > 0 }?.let { params.put(NativeSearchParams.Parameter.PAGE, it) }
    json.optInt("category_limit").takeIf { it > 0 }?.let { params.put(NativeSearchParams.Parameter.CATEGORY_LIMIT, it) }
    json.optInt("brand_limit").takeIf { it > 0 }?.let { params.put(NativeSearchParams.Parameter.BRAND_LIMIT, it) }
    json.optString("sort_by").takeIf { it.isNotEmpty() }?.let { params.put(NativeSearchParams.Parameter.SORT_BY, it) }
    json.optString("sort_dir").takeIf { it.isNotEmpty() }?.let { params.put(NativeSearchParams.Parameter.SORT_DIR, it) }
    json.optString("locations").takeIf { it.isNotEmpty() }?.let { params.put(NativeSearchParams.Parameter.LOCATIONS, it) }
    json.optString("brands").takeIf { it.isNotEmpty() }?.let { params.put(NativeSearchParams.Parameter.BRANDS, it) }
    if (json.has("price_min")) params.put(NativeSearchParams.Parameter.PRICE_MIN, json.getDouble("price_min").toString())
    if (json.has("price_max")) params.put(NativeSearchParams.Parameter.PRICE_MAX, json.getDouble("price_max").toString())
    jsonArrayToStringArray(json.optJSONArray("categories"))?.let { params.put(NativeSearchParams.Parameter.CATEGORIES, it) }
    jsonArrayToStringArray(json.optJSONArray("excluded_brands"))?.let { params.put(NativeSearchParams.Parameter.EXCLUDED_BRANDS, it) }
    jsonArrayToStringArray(json.optJSONArray("colors"))?.let { params.put(NativeSearchParams.Parameter.COLORS, it) }
    jsonArrayToStringArray(json.optJSONArray("fashion_sizes"))?.let { params.put(NativeSearchParams.Parameter.FASHION_SIZES, it) }
    json.optJSONObject("filters")?.let { facets ->
        val searchFilters = NativeSearchParams.SearchFilters()
        var any = false
        facets.keys().forEach { name ->
            jsonArrayToStringArray(facets.optJSONArray(name))?.let {
                searchFilters.put(name, it)
                any = true
            }
        }
        if (any) params.put(NativeSearchParams.Parameter.FILTERS, searchFilters.toString())
    }
    return params
}

/** A recommendation block's parameters from the bridge's JSON, `image_size` among them, as 1.6.4 sent them. */
internal fun buildRecommendationParams(paramsJson: String?): Params {
    val params = Params()
    if (paramsJson.isNullOrBlank()) return params
    val json = JSONObject(paramsJson)
    json.optString("item_id").takeIf { it.isNotEmpty() }?.let { params.put(Params.Parameter.ITEM, it) }
    json.optString("category_id").takeIf { it.isNotEmpty() }?.let { params.put(Params.Parameter.CATEGORY_ID, it) }
    json.optString("locations").takeIf { it.isNotEmpty() }?.let { params.put(Params.Parameter.LOCATIONS, it) }
    if (json.has("image_size")) params.put(Params.Parameter.IMAGE_SIZE, json.getInt("image_size").toString())
    if (json.has("with_locations")) params.put(Params.Parameter.WITH_LOCATIONS, json.getBoolean("with_locations").toString())
    return params
}

private fun jsonArrayToStringArray(arr: JSONArray?): Array<String>? {
    if (arr == null || arr.length() == 0) return null
    return Array(arr.length()) { i -> arr.getString(i) }
}

private fun jsonArrayToStringList(arr: JSONArray?): List<String>? {
    if (arr == null || arr.length() == 0) return null
    return (0 until arr.length()).map { arr.getString(it) }
}

internal fun jsonObjectStringToMap(json: String?): Map<String, Any?>? {
    if (json.isNullOrBlank()) return null
    return jsonObjectToNestedMap(JSONObject(json))
}

private fun jsonObjectToNestedMap(obj: JSONObject): Map<String, Any?> {
    val out = LinkedHashMap<String, Any?>()
    obj.keys().forEach { key -> out[key] = jsonValueToKotlin(obj.get(key)) }
    return out
}

private fun jsonValueToKotlin(value: Any?): Any? = when (value) {
    null, JSONObject.NULL -> null
    is JSONObject -> jsonObjectToNestedMap(value)
    is JSONArray -> (0 until value.length()).map { jsonValueToKotlin(value.opt(it)) }
    else -> value
}
