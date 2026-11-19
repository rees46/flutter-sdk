package com.rees46.rees46_flutter_sdk.push

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.net.Uri
import android.util.Log
import com.personalization.Rees46
import com.rees46.rees46_flutter_sdk.BridgeShops

/**
 * Bootstraps push handling at process start — including the cold process FCM spins up just to
 * deliver a push when the app has been swiped away and no Flutter engine is running.
 *
 * A [ContentProvider.onCreate] runs before `Application.onCreate` and before the SDK's messaging
 * services, the same auto-initialization trick `FirebaseInitProvider` uses. On a cold start Dart
 * never runs, so nothing has started the shops — and `Rees46.handlePush` (called by the SDK's
 * `MessagingService`) would resolve no shop and drop the push. So here we:
 *   1. register every shop initialized in a previous run (persisted in [Rees46ShopStore]) on the
 *      native SDK's new core with `Rees46.registerBridge` — never `Rees46.register`, which asks for the
 *      legacy core and would decide the whole process's core before Dart runs, leaving every namespace
 *      `notInitialized`. A registration sends nothing: a push for a shop goes with its stored did and no
 *      `/init`, so a process the app was never opened in costs no `/init`. Dart's `initialize()` makes
 *      the full instance, with its `/init`, from Dart's configuration. A process start never resets the
 *      device: `needReInitialization` is off here;
 *   2. attach the shop-aware [com.personalization.OnShopMessageListener] via the facade, so a
 *      routed push posts the heads-up BigPicture and is reported shown.
 *
 * On a normal launch this listener is replaced by the plugin's full listener (which also forwards
 * the push to Dart) when Dart calls `initialize()`.
 */
class Rees46PushInitProvider : ContentProvider() {

    override fun onCreate(): Boolean {
        val context = context?.applicationContext ?: return false
        try {
            Rees46PushNotifier.ensureChannel(context)

            // Register the shops of a previous run so Rees46.handlePush can resolve the push instead
            // of dropping it; no instance is made and nothing goes to the network.
            val shops = Rees46ShopStore.read(context)
            if (shops.isNotEmpty()) {
                runCatching { Rees46.registerBridge(context, shops.map { it.copy(needReInitialization = false) }) }
                    .onFailure { Log.e(Rees46PushNotifier.TAG, "provider could not register the stored shops", it) }
            }

            // Shop-aware display listener via the facade, matching the running-app path: the SDK
            // routes each push to its shop and fires this to post the notification.
            Rees46.setOnMessageListener { shopId, data ->
                Log.d(Rees46PushNotifier.TAG, "onMessage (provider listener) shop=$shopId id=${data.id}")
                // Off the main thread: show() downloads the image synchronously.
                Thread {
                    if (Rees46PushNotifier.show(context, data, shopId)) Rees46PushNotifier.reportShown(shopId, data)
                }.start()
            }
            Log.d(
                Rees46PushNotifier.TAG,
                "provider installed cold-start push listener (${shops.size} shop(s) registered)",
            )
        } catch (t: Throwable) {
            // Never let push bootstrap crash the host process at startup.
            Log.e(Rees46PushNotifier.TAG, "provider failed to install push listener", t)
        }
        return true
    }

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?,
    ): Cursor? = null

    override fun getType(uri: Uri): String? = null

    override fun insert(uri: Uri, values: ContentValues?): Uri? = null

    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int = 0

    override fun update(
        uri: Uri,
        values: ContentValues?,
        selection: String?,
        selectionArgs: Array<out String>?,
    ): Int = 0
}
