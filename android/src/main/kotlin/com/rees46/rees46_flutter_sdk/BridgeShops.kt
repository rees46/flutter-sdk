package com.rees46.rees46_flutter_sdk

import android.content.Context
import android.os.SystemClock
import com.personalization.PopupPresentationListener
import com.personalization.PushProvider
import com.personalization.Rees46
import com.personalization.Rees46Config
import com.personalization.SDK
import com.personalization.core.SdkState
import com.rees46.rees46_flutter_sdk.pigeon.SdkSnapshotWire
import java.util.concurrent.ConcurrentHashMap

/**
 * The shops the plugin runs, on the native SDK's new core. The native registry holds the instances; this
 * keeps only what the plugin started each with, in this process, so that a shop Dart starts again is
 * reused, or started again when Dart's configuration differs.
 *
 * Every shop starts with `Rees46.initializeBridge`. The cold-start provider
 * ([com.rees46.rees46_flutter_sdk.push.Rees46PushInitProvider]) only registers the stored shops with
 * `Rees46.registerBridge`, on the same core and with no `/init`; the start here makes the full instance in
 * place of the registration, or of the instance a push brought up for itself. Never `Rees46.register`:
 * it asks for the legacy core, and the first start of a process decides its core for every shop.
 */
internal object BridgeShops {

    private val started = ConcurrentHashMap<String, Rees46Config>()

    /**
     * How a shop starts: `Rees46.initializeBridge`. No A/B group of the bridge's own: the legacy core kept it
     * in the native storage the new core adopts, with the device id. Tests start a fake instead.
     */
    @Volatile
    internal var starter: (Context, Rees46Config) -> SDK = { context, config ->
        Rees46.initializeBridge(context.applicationContext, config, segment = null)
    }

    /**
     * The live instance of [config]'s shop on the new core. One the plugin started with the same
     * configuration is reused; one started with another is released and started again with [config], its
     * queue resuming from disk.
     */
    @Synchronized
    fun start(context: Context, config: Rees46Config): SDK {
        val shopId = config.shopId
        val running = started[shopId]
        if (running != null && Rees46.isInitialized(shopId)) {
            val live = Rees46.instance(shopId)
            if (running == config) return live
            live.release()
        }
        val sdk = starter(context, config)
        PopupRelay.attach(sdk, shopId)
        started[shopId] = config
        return sdk
    }

    /**
     * Stops [sdk] (Dart's `release`): the plugin forgets its shop — no snapshot goes for it, its popups no
     * longer reach Dart and those held for it go — and the native instance is released, its queue staying
     * on disk. The next [start] of the shop makes a fresh instance. The shop stays in the store the
     * cold-start provider reads: a later process registers it again, and the queue goes on from there.
     */
    @Synchronized
    fun release(sdk: SDK) {
        val shopId = sdk.shopId
        started.remove(shopId)
        PopupRelay.disconnect(shopId)
        sdk.release()
    }

    /** The shops the plugin started in this process. */
    fun shopIds(): Set<String> = started.keys.toSet()

    /** Test-only. */
    internal fun reset() = started.clear()
}

/**
 * The server popups of every shop the plugin started, for Dart, which draws them with the UI kit: each is
 * kept from the native presentation and handed to the shop's sink. A popup that comes while Dart has not
 * connected the shop yet (the provider started it at process start, the engine is still loading) waits up
 * to [HOLD_MS] for it; the native SDK never shows it.
 *
 * Several engines may connect a shop — the app's and a background one (a messaging or work isolate). The
 * one connected last takes its popups; when an engine goes, only its own sinks go, and the shop's popups
 * go back to the engine connected before it, or wait for the next one.
 */
internal object PopupRelay {

    private class Held(val json: String, val at: Long)

    /** Per shop, the sinks of the engines that connected it, the last connected last. */
    private val sinks = HashMap<String, MutableList<(String) -> Unit>>()
    private val held = HashMap<String, MutableList<Held>>()

    const val HOLD_MS = 60_000L

    /** The time popups are held by. Tests set their own. */
    @Volatile
    internal var clock: () -> Long = { SystemClock.elapsedRealtime() }

    /** Keeps every popup of [sdk] from the native presentation and relays it. Runs on the main thread. */
    fun attach(sdk: SDK, shopId: String) {
        sdk.popupPresentationListener = PopupPresentationListener { _, popup ->
            runCatching { relay(shopId, popup.toJson().toString()) }
            null
        }
    }

    fun relay(shopId: String, json: String, now: Long = clock()) {
        val sink = synchronized(this) {
            sinks[shopId]?.lastOrNull() ?: run {
                held.getOrPut(shopId) { mutableListOf() } += Held(json, now)
                null
            }
        }
        sink?.invoke(json)
    }

    /** Dart takes [shopId]'s popups through [sink] from now on, and those held for it that are still fresh. */
    fun connect(shopId: String, sink: (String) -> Unit, now: Long = clock()) {
        val waiting = synchronized(this) {
            val engines = sinks.getOrPut(shopId) { mutableListOf() }
            engines.removeAll { it === sink }
            engines += sink
            held.remove(shopId)
        } ?: return
        waiting.filter { now - it.at <= HOLD_MS }.forEach { sink(it.json) }
    }

    /**
     * The engine that connected [sink] for [shopId] went: that sink only. Popups go to an engine connected
     * before it, else they are held again until Dart connects.
     */
    @Synchronized
    fun disconnect(shopId: String, sink: (String) -> Unit) {
        val engines = sinks[shopId] ?: return
        engines.removeAll { it === sink }
        if (engines.isEmpty()) sinks.remove(shopId)
    }

    /** [shopId] was released: its popups go to Dart no more, and none is held for it. */
    @Synchronized
    fun disconnect(shopId: String) {
        sinks.remove(shopId)
        held.remove(shopId)
    }

    /** Test-only. */
    @Synchronized
    internal fun reset() {
        sinks.clear()
        held.clear()
    }
}

/** The state's wire name, the same on iOS. */
internal fun SdkState.wireName(): String = when (this) {
    SdkState.NOT_INITIALIZED -> "notInitialized"
    SdkState.INITIALIZING -> "initializing"
    SdkState.READY -> "ready"
    SdkState.RETRYING -> "retrying"
    SdkState.REFUSED -> "refused"
}

/**
 * What Dart mirrors of a shop, now: its state ([state] when a listener was handed one), device id,
 * session, A/B group, whether the search agent is on, and the push tokens the SDK keeps for it.
 */
internal fun snapshotOf(sdk: SDK, state: SdkState = sdk.state): SdkSnapshotWire {
    val notifications = runCatching { sdk.notifications }.getOrNull()
    return SdkSnapshotWire(
        shopId = sdk.shopId,
        state = state.wireName(),
        deviceId = sdk.deviceId?.ifEmpty { null },
        sessionId = sdk.sessionId?.ifEmpty { null },
        segment = runCatching { sdk.segments.getAbGroup() }.getOrNull()?.ifEmpty { null },
        agentEnabled = runCatching { sdk.search.agentEnabled }.getOrDefault(false),
        pushToken = notifications?.let { runCatching { it.getPushToken(null) }.getOrNull() }?.toWire(),
        pushTokens = PushProvider.entries.mapNotNull { provider ->
            notifications?.let { runCatching { it.getPushToken(provider) }.getOrNull() }?.toWire()
        },
    )
}

/**
 * Which push tokens Dart's `onToken` hears: a token the SDK got from its provider, as the contract has it — not
 * one the app handed over itself (`notifications.setPushToken`), and not the tokens the SDK already had when the
 * plugin subscribed, which it tells a new subscriber at once. Dart's copy of the shop's tokens follows every one
 * of them all the same, through the shop's snapshot.
 */
internal class TokenReports {
    private val appSet = ConcurrentHashMap.newKeySet<String>()

    @Volatile
    private var replaying = false

    /** Dart handed [token] of [provider] over itself. */
    fun appSet(provider: PushProvider, token: String) {
        appSet += key(provider, token)
    }

    /** The SDK tells the tokens it already had from now until [endReplay]. */
    fun beginReplay() {
        replaying = true
    }

    fun endReplay() {
        replaying = false
    }

    /** Whether the token is one the SDK got from [provider] now, for Dart's `onToken`. */
    fun isNew(provider: PushProvider, token: String): Boolean = !replaying && key(provider, token) !in appSet

    private fun key(provider: PushProvider, token: String) = "${provider.name}:$token"
}
