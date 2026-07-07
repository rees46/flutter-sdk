package com.rees46.rees46_flutter_sdk.push

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.personalization.sdk.data.models.dto.notification.NotificationData
import com.rees46.rees46_flutter_sdk.R
import java.net.URL

/**
 * Posts a heads-up BigPicture notification from REES46 push data — the native equivalent of the
 * REES46 React Native demo's notifee BIGPICTURE notification (and of the android-sdk demo's
 * display).
 *
 * Why not the SDK's built-in [com.personalization.features.notification.presentation.helpers.NotificationHelper]:
 * it posts a collapsed custom-view notification on a LOW-importance channel with no content intent,
 * so there is no heads-up pop-up and tapping does nothing. This presenter posts a standard
 * heads-up BigPicture instead: title/body are visible without expanding, the image is shown as the
 * big picture, and tapping opens the app (carrying the push type/id so the click is tracked).
 *
 * [show] downloads images synchronously, so it must be called off the main thread.
 */
object Rees46PushNotifier {

    /** Logcat tag — unconditional, so push display can be traced without SDK debug mode. */
    const val TAG = "Rees46Push"

    /** Distinct from the SDK's own LOW-importance "notification_channel" so HIGH importance sticks. */
    const val CHANNEL_ID = "rees46_push"
    private const val CHANNEL_NAME = "Push notifications"

    /**
     * Manifest meta-data key a host app can set to point at its own notification icon, e.g.:
     * ```
     * <meta-data
     *     android:name="com.rees46.push.notification_icon"
     *     android:resource="@drawable/ic_stat_notify" />
     * ```
     */
    private const val META_DATA_ICON = "com.rees46.push.notification_icon"

    /**
     * Firebase's own default-notification-icon meta-data. Reused so a host that already configured
     * an FCM icon does not have to duplicate it under [META_DATA_ICON]:
     * ```
     * <meta-data
     *     android:name="com.google.firebase.messaging.default_notification_icon"
     *     android:resource="@drawable/ic_stat_notify" />
     * ```
     */
    private const val FIREBASE_META_DATA_ICON =
        "com.google.firebase.messaging.default_notification_icon"

    /** Idempotent. Creates the HIGH-importance channel so pushes appear as a heads-up pop-up. */
    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH,
            )
            ContextCompat.getSystemService(context, NotificationManager::class.java)
                ?.createNotificationChannel(channel)
        }
    }

    /** Builds and posts the notification. Must run off the main thread (downloads images). */
    fun show(context: Context, data: NotificationData) {
        Log.d(TAG, "show() title=${data.title} body=${data.body} image=${data.image}")
        try {
            ensureChannel(context)

            val bigPicture = data.image?.split(",")?.firstOrNull()?.trim()
                ?.takeIf { it.isNotEmpty() }?.let(::loadBitmap)
            val largeIcon = data.icon?.trim()?.takeIf { it.isNotEmpty() }?.let(::loadBitmap)

            val builder = NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(resolveSmallIcon(context))
                .setContentTitle(data.title)
                .setContentText(data.body)
                .setAutoCancel(true)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setDefaults(NotificationCompat.DEFAULT_ALL)
                .setContentIntent(buildContentIntent(context, data))

            if (largeIcon != null) builder.setLargeIcon(largeIcon)
            if (bigPicture != null) {
                builder.setStyle(
                    NotificationCompat.BigPictureStyle()
                        .bigPicture(bigPicture)
                        .bigLargeIcon(null as Bitmap?),
                )
            }

            val id = (data.title.orEmpty() + data.body.orEmpty()).hashCode()
            val manager = ContextCompat.getSystemService(context, NotificationManager::class.java)
            if (manager == null) {
                Log.e(TAG, "NotificationManager unavailable — cannot post notification")
                return
            }
            manager.notify(id, builder.build())
            Log.d(TAG, "notify() posted id=$id (bigPicture=${bigPicture != null})")
        } catch (t: Throwable) {
            Log.e(TAG, "Failed to post notification", t)
        }
    }

    /**
     * Tapping opens the host launcher activity, carrying the push type/id as extras so the plugin's
     * launch-intent handler reports the click to the SDK (and to Dart via onPushClicked). The keys
     * match the SDK's NotificationConstants (NOTIFICATION_TYPE / NOTIFICATION_ID).
     */
    private fun buildContentIntent(context: Context, data: NotificationData): PendingIntent {
        val intent = context.packageManager
            .getLaunchIntentForPackage(context.packageName)
            ?.apply {
                putExtra("NOTIFICATION_TYPE", data.type)
                putExtra("NOTIFICATION_ID", data.id)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            }
            ?: Intent()
        return PendingIntent.getActivity(
            context,
            (data.id ?: (data.title.orEmpty() + data.body.orEmpty())).hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    /**
     * Resolves the small icon so the notification carries the HOST app's branding, never REES46's.
     *
     * Order mirrors FCM's `default_notification_icon` handling:
     *  1. A host-declared icon via [META_DATA_ICON] manifest meta-data. This is the recommended
     *     path — a small icon must be a white, alpha-only silhouette (Android tints it), which a
     *     full-colour launcher icon is not.
     *  2. The host's existing Firebase [FIREBASE_META_DATA_ICON], so an FCM icon that is already
     *     configured is reused without the host duplicating it under our key.
     *  3. The host app's launcher icon, so the branding is still the client's (not REES46's) even
     *     when no dedicated icon is configured.
     *  4. A neutral, non-branded default ([R.drawable.ic_rees46_push_default], a plain white disc),
     *     only as a last resort if the host has no icon at all. Never REES46 branding.
     */
    private fun resolveSmallIcon(context: Context): Int {
        val appInfo = try {
            context.packageManager.getApplicationInfo(
                context.packageName,
                PackageManager.GET_META_DATA,
            )
        } catch (e: Exception) {
            null
        }
        val metaData = appInfo?.metaData

        val configured = metaData?.getInt(META_DATA_ICON, 0) ?: 0
        if (configured != 0) return configured

        val firebaseIcon = metaData?.getInt(FIREBASE_META_DATA_ICON, 0) ?: 0
        if (firebaseIcon != 0) return firebaseIcon

        val launcherIcon = appInfo?.icon ?: 0
        if (launcherIcon != 0) return launcherIcon

        return R.drawable.ic_rees46_push_default
    }

    private fun loadBitmap(url: String): Bitmap? = try {
        URL(url).openStream().use { BitmapFactory.decodeStream(it) }
    } catch (e: Exception) {
        null
    }
}
