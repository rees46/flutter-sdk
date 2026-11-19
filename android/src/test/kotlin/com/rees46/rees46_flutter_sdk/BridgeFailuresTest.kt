package com.rees46.rees46_flutter_sdk

import com.personalization.UnknownShopIdException
import com.personalization.core.SdkError
import com.personalization.core.SdkResult
import com.rees46.rees46_flutter_sdk.pigeon.FlutterError
import kotlin.test.AfterTest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals

/** A native failure reaches Dart as its type, message, HTTP code and server code. */
internal class BridgeFailuresTest {

    private var mainBefore: (() -> Unit) -> Unit = MainThread.run

    @BeforeTest
    fun runInPlace() {
        mainBefore = MainThread.run
        MainThread.run = { it() }
    }

    @AfterTest
    fun restore() {
        MainThread.run = mainBefore
    }

    @Test
    fun everyNativeErrorKeepsItsType() {
        val types = listOf(
            SdkError.NotInitialized to "notInitialized",
            SdkError.ShopBlocked to "shopBlocked",
            SdkError.InvalidArgument("itemId must not be empty") to "invalidArgument",
            SdkError.Network to "network",
            SdkError.Timeout to "timeout",
            SdkError.Http(500) to "http",
            SdkError.Decoding to "decoding",
            SdkError.Cancelled to "cancelled",
        )
        types.forEach { (error, type) ->
            val failure = BridgeFailures.of(error)
            assertEquals(type, failure.code)
            assertEquals(error.message, failure.message)
        }
    }

    @Test
    fun anHttpErrorCarriesItsCodes() {
        val failure = BridgeFailures.of(SdkError.Http(404, serverCode = "not_found"))

        assertEquals(mapOf("httpCode" to 404L, "serverCode" to "not_found"), failure.details)
        assertEquals(mapOf("httpCode" to null, "serverCode" to null), BridgeFailures.of(SdkError.Network).details)
    }

    @Test
    fun thePluginsOwnFailuresHaveTheirTypes() {
        assertEquals("notInitialized", BridgeFailures.of(UnknownShopIdException("no shop")).code)
        assertEquals("invalidArgument", BridgeFailures.of(IllegalArgumentException("Unknown gender: x")).code)
        assertEquals("Unknown gender: x", BridgeFailures.of(IllegalArgumentException("Unknown gender: x")).message)
        assertEquals("decoding", BridgeFailures.of(IllegalStateException("broken")).code)
    }

    @Test
    fun aCompletionHandsOverTheValueOrTheError() {
        val results = mutableListOf<Result<String>>()
        val listener = completion<Int, String>({ results += it }) { "n=$it" }

        listener.onComplete(SdkResult.Success(3))
        listener.onComplete(SdkResult.Failure(SdkError.Timeout))

        assertEquals("n=3", results[0].getOrNull())
        assertEquals("timeout", (results[1].exceptionOrNull() as FlutterError).code)
    }

    @Test
    fun aModelTheBridgeCannotConvertFailsAsDecoding() {
        val results = mutableListOf<Result<String>>()

        completion<Int, String>({ results += it }) { error("no") }.onComplete(SdkResult.Success(1))

        assertEquals("decoding", (results.single().exceptionOrNull() as FlutterError).code)
    }
}
