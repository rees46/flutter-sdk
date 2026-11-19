package com.rees46.rees46_flutter_sdk

import android.os.Handler
import android.os.Looper
import com.personalization.AmbiguousShopException
import com.personalization.UnknownShopIdException
import com.personalization.core.CompletionListener
import com.personalization.core.SdkError
import com.personalization.core.SdkException
import com.personalization.core.SdkResult
import com.rees46.rees46_flutter_sdk.pigeon.FlutterError

/**
 * How a failure of the native SDK reaches Dart: a Pigeon [FlutterError] whose `code` is the type of the
 * native [SdkError], whose message is the error's own (English, without personal data or the answer's
 * body), and whose `details` carry the HTTP code and the server's code — Dart makes an `SdkException` of
 * it. A shop the bridge does not know is `notInitialized`, as the contract has it.
 */
internal object BridgeFailures {

    const val HTTP_CODE = "httpCode"
    const val SERVER_CODE = "serverCode"

    /** The wire name of the error's type, the same on iOS. */
    fun typeOf(error: SdkError): String = when (error) {
        SdkError.NotInitialized -> "notInitialized"
        SdkError.ShopBlocked -> "shopBlocked"
        is SdkError.InvalidArgument -> "invalidArgument"
        SdkError.Network -> "network"
        SdkError.Timeout -> "timeout"
        is SdkError.Http -> "http"
        SdkError.Decoding -> "decoding"
        SdkError.Cancelled -> "cancelled"
    }

    fun of(error: SdkError): FlutterError {
        val http = error as? SdkError.Http
        return FlutterError(
            typeOf(error),
            error.message,
            mapOf(HTTP_CODE to http?.code?.toLong(), SERVER_CODE to http?.serverCode),
        )
    }

    /**
     * A failure the plugin itself hit: the shop not found (`notInitialized`), a value of Dart's the native
     * side does not take (`invalidArgument`), a native [SdkException] as its error; anything else
     * `decoding`, with its message.
     */
    fun of(failure: Throwable): FlutterError = when (failure) {
        is FlutterError -> failure
        is SdkException -> of(failure.error)
        is UnknownShopIdException, is AmbiguousShopException -> of(SdkError.NotInitialized)
        is IllegalArgumentException -> of(SdkError.InvalidArgument(failure.message ?: "Invalid argument"))
        else -> FlutterError("decoding", failure.message ?: failure.javaClass.simpleName, details())
    }

    fun invalidArgument(message: String): FlutterError = of(SdkError.InvalidArgument(message))

    private fun details(): Map<String, Any?> = mapOf(HTTP_CODE to null, SERVER_CODE to null)
}

/** Where the plugin's replies and events to Dart run: the main thread, which Pigeon's channels take them on. */
internal object MainThread {
    private val handler by lazy { Handler(Looper.getMainLooper()) }

    /** Runs a block on the main thread: at once when already there, else posted. Tests run it in place. */
    @Volatile
    var run: (() -> Unit) -> Unit = { block ->
        if (Looper.myLooper() == Looper.getMainLooper()) block() else handler.post(block)
    }
}

/** Runs [block] on the main thread ([MainThread.run]). */
internal fun onMain(block: () -> Unit) = MainThread.run(block)

/**
 * A native [CompletionListener] that completes the Pigeon [callback] with [map] of the value, or with the
 * native error. A model the bridge cannot convert fails as `decoding`, not as a crash.
 */
internal fun <T, R> completion(callback: (Result<R>) -> Unit, map: (T) -> R): CompletionListener<T> =
    CompletionListener { result ->
        val reply: Result<R> = when (result) {
            is SdkResult.Success -> try {
                Result.success(map(result.value))
            } catch (t: Throwable) {
                Result.failure(BridgeFailures.of(t))
            }
            is SdkResult.Failure -> Result.failure(BridgeFailures.of(result.error))
        }
        onMain { callback(reply) }
    }

/** [completion] for the calls that answer nothing. */
internal fun done(callback: (Result<Unit>) -> Unit): CompletionListener<Unit> = completion(callback) { }
