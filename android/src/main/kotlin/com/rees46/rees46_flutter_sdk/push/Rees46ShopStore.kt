package com.rees46.rees46_flutter_sdk.push

import android.content.Context
import com.personalization.Rees46Config
import org.json.JSONArray
import org.json.JSONObject

/**
 * Persists the configs of shops initialized from Dart, so the cold-start
 * [Rees46PushInitProvider] can re-register them in a process the Flutter engine never ran in —
 * the cold process FCM spins up just to deliver a push after the app was swiped away.
 *
 * Without this the registry is empty on a cold start, so `Rees46.handlePush` (called by the SDK's
 * `MessagingService`) resolves no shop and drops the push — no notification appears. On Android
 * the app draws the notification itself (REES46 pushes are data messages), so it must have the
 * shop registered. iOS needs none of this: its pushes are system-drawn APNs alert payloads, so a
 * registered token delivers regardless of whether the app runs.
 *
 * Upsert-only by shopId; not cleared (a shop that stops receiving simply stops being pushed to).
 */
internal object Rees46ShopStore {

    private const val PREFS = "rees46_flutter_push_shops"
    private const val KEY_CONFIGS = "configs"

    /** Records [config] (upsert by shopId) so it survives to the next cold process start. */
    fun save(context: Context, config: Rees46Config) {
        val byId = read(context).associateByTo(LinkedHashMap()) { it.shopId }
        byId[config.shopId] = config
        val array = JSONArray()
        for (c in byId.values) {
            array.put(
                JSONObject()
                    .put("shopId", c.shopId)
                    .put("apiDomain", c.apiDomain)
                    .put("stream", c.stream)
                    .put("autoSendPushToken", c.autoSendPushToken)
                    .put("needReInitialization", c.needReInitialization),
            )
        }
        prefs(context).edit().putString(KEY_CONFIGS, array.toString()).apply()
    }

    /** All persisted shop configs, or empty if none / unreadable. */
    fun read(context: Context): List<Rees46Config> {
        val raw = prefs(context).getString(KEY_CONFIGS, null) ?: return emptyList()
        return try {
            val array = JSONArray(raw)
            (0 until array.length()).mapNotNull { i ->
                val obj = array.optJSONObject(i) ?: return@mapNotNull null
                val shopId = obj.optString("shopId").takeIf { it.isNotBlank() }
                    ?: return@mapNotNull null
                Rees46Config(
                    shopId = shopId,
                    apiDomain = obj.optString("apiDomain", "api.rees46.ru"),
                    stream = obj.optString("stream", "android"),
                    autoSendPushToken = obj.optBoolean("autoSendPushToken", true),
                    needReInitialization = obj.optBoolean("needReInitialization", false),
                )
            }
        } catch (t: Throwable) {
            emptyList()
        }
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}
