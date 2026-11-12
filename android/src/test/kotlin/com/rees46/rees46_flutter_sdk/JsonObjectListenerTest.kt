package com.rees46.rees46_flutter_sdk

import com.rees46.rees46_flutter_sdk.pigeon.FlutterError
import org.json.JSONArray
import org.mockito.Mockito
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * `getProductInfo` and `getProductsList` answer through [jsonObjectListener]: the Dart `Future`
 * completes on an error and on any answer. A listener with only `onSuccess` left it waiting for good.
 */
internal class JsonObjectListenerTest {

    @Test
    fun anErrorCompletesTheCallWithTheError() {
        val results = mutableListOf<Result<String>>()

        jsonObjectListener("products_list_failed") { results += it }.onError(500, "server error")

        assertEquals(1, results.size, "the call never completed")
        val error = results.single().exceptionOrNull() as FlutterError
        assertEquals("products_list_failed", error.code)
        assertEquals("server error", error.message)
    }

    @Test
    fun anErrorWithAnEmptyBodyNamesItsStatus() {
        val results = mutableListOf<Result<String>>()

        // The SDK hands over the error answer's body, empty for most errors.
        jsonObjectListener("product_info_failed") { results += it }.onError(404, "")

        val error = results.single().exceptionOrNull() as FlutterError
        assertEquals("product_info_failed", error.code)
        assertEquals("error 404", error.message)
    }

    @Test
    fun anArrayAnswerCompletesTheCall() {
        val results = mutableListOf<Result<String>>()
        val array = Mockito.mock(JSONArray::class.java)
        Mockito.`when`(array.toString()).thenReturn("[]")

        jsonObjectListener("products_list_failed") { results += it }.onSuccess(array)

        assertEquals("[]", results.single().getOrNull())
    }

    @Test
    fun anEmptyAnswerCompletesTheCallWithAnError() {
        val results = mutableListOf<Result<String>>()

        jsonObjectListener("product_info_failed") { results += it }.onSuccess(null as org.json.JSONObject?)

        assertTrue(results.single().isFailure)
    }
}
