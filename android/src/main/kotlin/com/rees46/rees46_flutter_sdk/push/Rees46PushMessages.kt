package com.rees46.rees46_flutter_sdk.push

import android.content.Context
import android.util.Log
import com.personalization.Rees46
import com.personalization.sdk.data.models.dto.notification.NotificationData
import com.rees46.rees46_flutter_sdk.onMain
import java.util.concurrent.Executors

/**
 * The plugin's listener of the SDK's pushes, one per process ([Rees46.setOnMessageListener]): it draws the
 * notification of every push the SDK routes to a shop and reports it shown, whether a Flutter engine runs or
 * not, and hands the push to the Dart of the engine attached last, if one is.
 *
 * The process outlives its engines: Back out of the root activity destroys the engine and keeps the process,
 * and the next push must still be drawn and reported. So the drawing runs on a thread of the process, not of
 * an engine, and only the hand-over to Dart needs an engine.
 */
internal object Rees46PushMessages {

    /** The Dart side of one engine: the push reached the app; then its notification was drawn, or not. */
    interface Receiver {
        fun received(shopId: String, data: NotificationData)

        fun delivered(shopId: String, data: NotificationData)
    }

    /** The engines that want the pushes, the one attached last last. */
    private val receivers = mutableListOf<Receiver>()

    /** Draws a push's notification; whether it is on screen. Tests draw nothing. */
    @Volatile
    internal var draw: (Context, NotificationData, String) -> Boolean = { context, data, shopId ->
        Rees46PushNotifier.show(context, data, shopId)
    }

    /** Reports a drawn notification shown (`track/opened`). */
    @Volatile
    internal var reportShown: (String, NotificationData) -> Unit = { shopId, data ->
        Rees46PushNotifier.reportShown(shopId, data)
    }

    private val drawer by lazy {
        Executors.newSingleThreadExecutor { runnable -> Thread(runnable, "rees46-push").apply { isDaemon = true } }
    }

    /** Where the drawing runs: off the main thread, as it downloads the image. Tests run it in place. */
    @Volatile
    internal var background: (() -> Unit) -> Unit = { block -> drawer.execute(block) }

    /** Takes the SDK's pushes from the listener the cold-start provider set, for the rest of the process. */
    fun install(context: Context) {
        val app = context.applicationContext
        Rees46.setOnMessageListener { shopId, data -> onMessage(app, shopId, data) }
    }

    /** [receiver]'s engine hears the pushes from now on, instead of the engine attached before it. */
    @Synchronized
    fun attach(receiver: Receiver) {
        receivers.remove(receiver)
        receivers += receiver
    }

    /** [receiver]'s engine went: the pushes go to the engine attached before it, or to no Dart. */
    @Synchronized
    fun detach(receiver: Receiver) {
        receivers.remove(receiver)
    }

    @Synchronized
    internal fun attached(): List<Receiver> = receivers.toList()

    /** A push the SDK routed to [shopId]. */
    internal fun onMessage(context: Context, shopId: String, data: NotificationData) {
        runCatching { Log.d(Rees46PushNotifier.TAG, "onMessage (plugin listener) shop=$shopId id=${data.id}") }
        onMain { current()?.received(shopId, data) }
        background {
            val shown = runCatching { draw(context, data, shopId) }.getOrDefault(false)
            if (shown) runCatching { reportShown(shopId, data) }
            onMain { current()?.delivered(shopId, data) }
        }
    }

    @Synchronized
    private fun current(): Receiver? = receivers.lastOrNull()

    /** Test-only. */
    @Synchronized
    internal fun reset() {
        receivers.clear()
    }
}
