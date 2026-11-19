package com.rees46.rees46_flutter_sdk.push

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.personalization.Rees46
import com.personalization.core.PushEvent
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * The `deleteIntent` of a notification the plugin drew: dismissed without a tap, it is
 * `Rees46.handlePush(push, CLOSED)` — `track/closed` and the `onClosed` callbacks, for the shop the push names,
 * with the whole push. In a process the dismissal started, the provider registered the stored shops first, so the
 * event goes by the shop's stored device id. The broadcast ends once the shop's queue took the event, or after
 * [WAIT_MS], so such a process is not stopped before.
 */
class Rees46PushDismissReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val push = pushOf(intent) ?: return
        val pending = goAsync()
        Thread {
            val accepted = CountDownLatch(1)
            val sink = Rees46.onPushEvent { event, payload ->
                if (event == PushEvent.CLOSED && payload.code == push["id"]) accepted.countDown()
            }
            try {
                if (Rees46.handlePush(push, PushEvent.CLOSED) != null) accepted.await(WAIT_MS, TimeUnit.MILLISECONDS)
            } catch (t: Throwable) {
                Log.e(Rees46PushNotifier.TAG, "A dismissed notification could not be reported", t)
            } finally {
                sink.cancel()
                pending.finish()
            }
        }.start()
    }

    internal companion object {
        /** How long the broadcast waits for the queue: well inside the system's 10 s. */
        const val WAIT_MS = 5_000L

        /** The push the intent carries, under the keys of a push's data; null without its code or type. */
        fun pushOf(intent: Intent): Map<String, String>? {
            val extras = intent.extras ?: return null
            val push = extras.keySet().mapNotNull { key -> extras.getString(key)?.let { key to it } }.toMap()
            if (push["id"].isNullOrBlank() || push["type"].isNullOrBlank()) return null
            return push
        }

        /** The intent that reports the dismissal of the notification [notificationId] of [push]. */
        fun intent(context: Context, notificationId: Int, push: Map<String, String>): PendingIntent {
            val intent = Intent(context, Rees46PushDismissReceiver::class.java)
            push.forEach { (key, value) -> intent.putExtra(key, value) }
            return PendingIntent.getBroadcast(
                context,
                notificationId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
    }
}
