package com.rees46.rees46_flutter_sdk

import com.personalization.SDK
import com.personalization.api.OnApiCallbackListener
import com.personalization.sdk.data.models.params.UserBasicParams
import com.rees46.rees46_flutter_sdk.pigeon.FlutterError
import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject

/**
 * Builds custom-event JSON and posts via [SDK.sendAsync] for published `rees46-sdk` artifacts that do
 * not expose `SDK.trackEvent` (wire format aligned with personalization-sdk `TrackEventManagerImpl`).
 *
 * Purchases do not go through here: the plugin hands them to `sdk.tracking.purchase`, so the wire
 * format, the validation and the reserved-key rules live in the native SDK alone.
 */
internal object FlutterTrackingBridge {
    private const val CUSTOM_PUSH_PATH = "push/custom"

    private const val TRACK_EVENT_CLIENT_ERROR_CODE = -1

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
