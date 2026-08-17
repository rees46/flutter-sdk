package com.rees46.rees46_flutter_sdk

import com.personalization.SDK
import com.personalization.api.OnApiCallbackListener
import com.personalization.sdk.data.models.params.UserBasicParams
import com.rees46.rees46_flutter_sdk.pigeon.FlutterError
import com.rees46.rees46_flutter_sdk.pigeon.PurchaseLineItemWire
import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject

/**
 * Builds tracking JSON and posts via [SDK.sendAsync] for published `rees46-sdk` artifacts that do not
 * expose `SDK.trackEvent` / `SDK.trackPurchase` (wire format aligned with personalization-sdk
 * `TrackEventManagerImpl` and `PurchaseTrackingJsonBuilder`).
 */
internal object FlutterTrackingBridge {
    private const val CUSTOM_PUSH_PATH = "push/custom"
    private const val PURCHASE_PUSH_PATH = "push"

    private const val TRACK_EVENT_CLIENT_ERROR_CODE = -1
    private const val TRACK_PURCHASE_CLIENT_ERROR_CODE = -2

    private const val KEY_EVENT = "event"
    private const val KEY_TIME = "time"
    private const val KEY_CATEGORY = "category"
    private const val KEY_LABEL = "label"
    private const val KEY_VALUE = "value"
    private const val KEY_SOURCE = "source"
    private const val KEY_PAYLOAD = "payload"
    private const val KEY_FROM = "from"
    private const val KEY_CODE = "code"
    private const val KEY_STREAM = "stream"

    private val RESERVED_CUSTOM_EVENT_KEYS: Set<String> =
        buildSet {
            add(UserBasicParams.SHOP_ID)
            add(UserBasicParams.DID)
            add(UserBasicParams.SEANCE)
            add(UserBasicParams.SID)
            add(UserBasicParams.SEGMENT)
            add(KEY_STREAM)
            add(KEY_EVENT)
            add(KEY_TIME)
            add(KEY_CATEGORY)
            add(KEY_LABEL)
            add(KEY_VALUE)
            add(KEY_SOURCE)
            add(KEY_PAYLOAD)
            add(KEY_FROM)
            add(KEY_CODE)
        }

    private object PurchaseWireKeys {
        const val EVENT = "event"
        const val PURCHASE_EVENT_VALUE = "purchase"
        const val ITEMS = "items"
        const val ID = "id"
        const val AMOUNT = "amount"
        const val PRICE = "price"
        const val LINE_ID = "line_id"
        const val FASHION_SIZE = "fashion_size"
        const val ORDER_ID = "order_id"
        const val ORDER_PRICE = "order_price"
        const val DELIVERY_TYPE = "delivery_type"
        const val DELIVERY_ADDRESS = "delivery_address"
        const val PAYMENT_TYPE = "payment_type"
        const val TAX_FREE = "tax_free"
        const val PROMOCODE = "promocode"
        const val ORDER_CASH = "order_cash"
        const val ORDER_BONUSES = "order_bonuses"
        const val ORDER_DELIVERY = "order_delivery"
        const val ORDER_DISCOUNT = "order_discount"
        const val CHANNEL = "channel"
        const val CUSTOM = "custom"
        const val RECOMMENDED_SOURCE = "recommended_source"
        const val RECOMMENDED_BY = "recommended_by"
        const val RECOMMENDED_CODE = "recommended_code"
    }

    private val RESERVED_PURCHASE_CUSTOM_KEYS: Set<String> =
        RESERVED_CUSTOM_EVENT_KEYS +
            setOf(
                PurchaseWireKeys.EVENT,
                PurchaseWireKeys.ITEMS,
                PurchaseWireKeys.ORDER_ID,
                PurchaseWireKeys.ORDER_PRICE,
                PurchaseWireKeys.DELIVERY_TYPE,
                PurchaseWireKeys.DELIVERY_ADDRESS,
                PurchaseWireKeys.PAYMENT_TYPE,
                PurchaseWireKeys.TAX_FREE,
                PurchaseWireKeys.PROMOCODE,
                PurchaseWireKeys.ORDER_CASH,
                PurchaseWireKeys.ORDER_BONUSES,
                PurchaseWireKeys.ORDER_DELIVERY,
                PurchaseWireKeys.ORDER_DISCOUNT,
                PurchaseWireKeys.CHANNEL,
                PurchaseWireKeys.CUSTOM,
                PurchaseWireKeys.RECOMMENDED_SOURCE,
                PurchaseWireKeys.RECOMMENDED_BY,
                PurchaseWireKeys.RECOMMENDED_CODE,
            )

    fun postTrackEvent(
        sdk: SDK,
        event: String,
        time: Long?,
        category: String?,
        label: String?,
        value: Long?,
        customFields: Map<String, Any?>?,
        callback: (Result<Unit>) -> Unit,
    ) {
        val effectiveCustom = effectiveCustomFields(customFields)
        validateNoReservedKeyCollisions(effectiveCustom, RESERVED_CUSTOM_EVENT_KEYS)?.let { msg ->
            callback(
                Result.failure(
                    FlutterError(
                        "track_event_failed",
                        msg,
                        mapOf("code" to TRACK_EVENT_CLIENT_ERROR_CODE),
                    ),
                ),
            )
            return
        }

        val body = JSONObject()
        try {
            body.put(KEY_EVENT, event)
            time?.let { body.put(KEY_TIME, longToJsonInt(it)) }
            category?.let { body.put(KEY_CATEGORY, it) }
            label?.let { body.put(KEY_LABEL, it) }
            value?.let { body.put(KEY_VALUE, longToJsonInt(it)) }
            if (effectiveCustom.isNotEmpty()) {
                val payload = JSONObject()
                for ((key, fieldValue) in effectiveCustom) {
                    putJsonValue(body, key, fieldValue)
                    putJsonValue(payload, key, fieldValue)
                }
                body.put(KEY_PAYLOAD, payload)
            }
        } catch (e: JSONException) {
            callback(
                Result.failure(
                    FlutterError(
                        "track_event_failed",
                        "trackEvent: failed to build JSON: ${e.message}",
                        null,
                    ),
                ),
            )
            return
        }

        @Suppress("DEPRECATION")
        sdk.sendAsync(
            CUSTOM_PUSH_PATH,
            body,
            object : OnApiCallbackListener() {
                override fun onSuccess(response: JSONObject?) {
                    callback(Result.success(Unit))
                }

                override fun onError(code: Int, msg: String?) {
                    val message = listOfNotNull(code.toString(), msg).joinToString(": ")
                    callback(Result.failure(FlutterError("track_event_failed", message, null)))
                }
            },
        )
    }

    fun postTrackPurchase(
        sdk: SDK,
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
        custom: Map<String, Any?>?,
        recommendedSource: JSONObject?,
        stream: String?,
        segment: String?,
        callback: (Result<Unit>) -> Unit,
    ) {
        val buildResult = buildPurchaseJsonOrError(
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
            custom = custom,
            recommendedSource = recommendedSource,
            stream = stream,
            segment = segment,
        )
        if (buildResult.isFailure) {
            callback(
                Result.failure(
                    FlutterError(
                        "track_purchase_failed",
                        buildResult.exceptionOrNull()?.message ?: "validation failed",
                        mapOf("code" to TRACK_PURCHASE_CLIENT_ERROR_CODE),
                    ),
                ),
            )
            return
        }
        val body = buildResult.getOrNull()!!

        @Suppress("DEPRECATION")
        sdk.sendAsync(
            PURCHASE_PUSH_PATH,
            body,
            object : OnApiCallbackListener() {
                override fun onSuccess(response: JSONObject?) {
                    callback(Result.success(Unit))
                }

                override fun onError(code: Int, msg: String?) {
                    val message = listOfNotNull(code.toString(), msg).joinToString(": ")
                    callback(Result.failure(FlutterError("track_purchase_failed", message, null)))
                }
            },
        )
    }

    private fun buildPurchaseJsonOrError(
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
        custom: Map<String, Any?>?,
        recommendedSource: JSONObject?,
        stream: String?,
        segment: String?,
    ): Result<JSONObject> {
        if (orderId.isBlank()) {
            return Result.failure(IllegalArgumentException("trackPurchase: orderId must be non-empty"))
        }
        if (items.isEmpty()) {
            return Result.failure(IllegalArgumentException("trackPurchase: items must not be empty"))
        }
        for (item in items) {
            if (item.id.isBlank()) {
                return Result.failure(IllegalArgumentException("trackPurchase: each item.id must be non-empty"))
            }
            if (item.amount <= 0) {
                return Result.failure(IllegalArgumentException("trackPurchase: each item.amount must be > 0"))
            }
            if (!item.price.isFinite()) {
                return Result.failure(IllegalArgumentException("trackPurchase: each item.price must be a finite number"))
            }
        }
        if (!orderPrice.isFinite()) {
            return Result.failure(IllegalArgumentException("trackPurchase: orderPrice must be a finite number"))
        }

        val effectiveCustom = effectiveCustomFields(custom)
        if (effectiveCustom.isNotEmpty()) {
            val collisions = effectiveCustom.keys.intersect(RESERVED_PURCHASE_CUSTOM_KEYS)
            if (collisions.isNotEmpty()) {
                return Result.failure(
                    IllegalArgumentException(
                        "trackPurchase: custom contains reserved keys: ${collisions.toSortedSet().joinToString(", ")}",
                    ),
                )
            }
        }

        return try {
            Result.success(
                buildPurchaseJson(
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
                    effectiveCustom = effectiveCustom,
                    recommendedSource = recommendedSource,
                    stream = stream,
                    segment = segment,
                ),
            )
        } catch (e: JSONException) {
            Result.failure(IllegalArgumentException("trackPurchase: failed to build JSON: ${e.message}", e))
        }
    }

    private fun buildPurchaseJson(
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
        effectiveCustom: Map<String, Any>,
        recommendedSource: JSONObject?,
        stream: String?,
        segment: String?,
    ): JSONObject {
        val root = JSONObject()
        root.put(PurchaseWireKeys.EVENT, PurchaseWireKeys.PURCHASE_EVENT_VALUE)
        root.put(PurchaseWireKeys.ORDER_ID, orderId)
        root.put(PurchaseWireKeys.ORDER_PRICE, orderPrice)

        val itemsArray = JSONArray()
        for (item in items) {
            val row = JSONObject()
            row.put(PurchaseWireKeys.ID, item.id)
            row.put(PurchaseWireKeys.AMOUNT, item.amount)
            row.put(PurchaseWireKeys.PRICE, item.price)
            item.lineId?.takeIf { it.isNotBlank() }?.let { row.put(PurchaseWireKeys.LINE_ID, it) }
            item.fashionSize?.takeIf { it.isNotBlank() }?.let {
                row.put(PurchaseWireKeys.FASHION_SIZE, it)
            }
            itemsArray.put(row)
        }
        root.put(PurchaseWireKeys.ITEMS, itemsArray)

        deliveryType?.takeIf { it.isNotBlank() }?.let {
            root.put(PurchaseWireKeys.DELIVERY_TYPE, it)
        }
        deliveryAddress?.takeIf { it.isNotBlank() }?.let {
            root.put(PurchaseWireKeys.DELIVERY_ADDRESS, it)
        }
        paymentType?.takeIf { it.isNotBlank() }?.let {
            root.put(PurchaseWireKeys.PAYMENT_TYPE, it)
        }
        if (isTaxFree) {
            root.put(PurchaseWireKeys.TAX_FREE, true)
        }
        promocode?.takeIf { it.isNotBlank() }?.let {
            root.put(PurchaseWireKeys.PROMOCODE, it)
        }
        orderCash?.let { root.put(PurchaseWireKeys.ORDER_CASH, it) }
        orderBonuses?.let { root.put(PurchaseWireKeys.ORDER_BONUSES, it) }
        orderDelivery?.let { root.put(PurchaseWireKeys.ORDER_DELIVERY, it) }
        orderDiscount?.let { root.put(PurchaseWireKeys.ORDER_DISCOUNT, it) }
        channel?.takeIf { it.isNotBlank() }?.let {
            root.put(PurchaseWireKeys.CHANNEL, it)
        }

        if (effectiveCustom.isNotEmpty()) {
            val customJson = JSONObject()
            for ((key, value) in effectiveCustom) {
                putJsonValue(customJson, key, value)
            }
            root.put(PurchaseWireKeys.CUSTOM, customJson)
        }

        recommendedSource?.let { root.put(PurchaseWireKeys.RECOMMENDED_SOURCE, it) }

        stream?.takeIf { it.isNotBlank() }?.let {
            root.put(UserBasicParams.STREAM, it)
        }
        segment?.takeIf { it.isNotBlank() }?.let {
            root.put(UserBasicParams.SEGMENT, it)
        }

        return root
    }

    private fun effectiveCustomFields(map: Map<String, Any?>?): Map<String, Any> {
        if (map.isNullOrEmpty()) return emptyMap()
        val out = LinkedHashMap<String, Any>()
        for ((key, value) in map) {
            if (key.isBlank() || value == null) continue
            out[key] = value
        }
        return out
    }

    private fun validateNoReservedKeyCollisions(
        customFields: Map<String, Any>,
        reserved: Set<String>,
    ): String? {
        if (customFields.isEmpty()) return null
        val collisions = customFields.keys.intersect(reserved)
        if (collisions.isEmpty()) return null
        val sorted = collisions.toSortedSet().joinToString(", ")
        return "trackEvent: customFields contains reserved keys: $sorted"
    }

    @Throws(JSONException::class)
    private fun putJsonValue(target: JSONObject, key: String, value: Any) {
        when (value) {
            is String -> target.put(key, value)
            is Int -> target.put(key, value)
            is Long -> target.put(key, value)
            is Double -> target.put(key, value)
            is Float -> target.put(key, value.toDouble())
            is Boolean -> target.put(key, value)
            is JSONObject -> target.put(key, value)
            is JSONArray -> target.put(key, value)
            else -> target.put(key, value.toString())
        }
    }

    private fun longToJsonInt(value: Long): Int =
        when {
            value > Int.MAX_VALUE -> Int.MAX_VALUE
            value < Int.MIN_VALUE -> Int.MIN_VALUE
            else -> value.toInt()
        }
}
