package com.rees46.rees46_flutter_sdk.push

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.net.Uri
import android.util.Log
import com.personalization.SDK

/**
 * Installs the push display listener at process start — including the cold process FCM spins up
 * just to deliver a push when the app has been swiped away and no Flutter engine is running.
 *
 * A [ContentProvider.onCreate] runs before `Application.onCreate` and before the SDK's
 * messaging services, the same auto-initialization trick `FirebaseInitProvider` uses. We only
 * attach an [com.personalization.OnMessageListener] to the SDK singleton (no full
 * [SDK.initialize] — display needs none): when the message arrives, the SDK routes it to this
 * listener and the heads-up BigPicture is posted. Tracking the "received" event needs an
 * initialized SDK and is skipped in this cold path; the click is still tracked once the user taps
 * and the app starts and initializes.
 *
 * On a normal launch this listener is replaced by the plugin's full listener (which also forwards
 * the push to Dart) when Dart calls `initialize()` on the same singleton.
 */
class Rees46PushInitProvider : ContentProvider() {

    override fun onCreate(): Boolean {
        val context = context?.applicationContext ?: return false
        try {
            Rees46PushNotifier.ensureChannel(context)
            SDK.instance.setOnMessageListener { data ->
                Log.d(Rees46PushNotifier.TAG, "onMessage (provider listener) id=${data.id}")
                // Off the main thread: show() downloads the image synchronously.
                Thread { Rees46PushNotifier.show(context, data) }.start()
            }
            Log.d(Rees46PushNotifier.TAG, "provider installed cold-start push listener")
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
