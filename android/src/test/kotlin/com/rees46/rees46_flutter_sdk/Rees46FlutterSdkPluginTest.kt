package com.rees46.rees46_flutter_sdk

import com.rees46.rees46_flutter_sdk.pigeon.FlutterError
import com.rees46.rees46_flutter_sdk.pigeon.SdkSnapshotWire
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/*
 * This demonstrates a simple unit test of the Kotlin portion of this plugin's implementation.
 *
 * Once you have built the plugin's example app, you can run these tests from the command
 * line by running `./gradlew testDebugUnitTest` in the `example/android/` directory, or
 * you can run them directly from IDEs that support JUnit such as Android Studio.
 */

internal class Rees46FlutterSdkPluginTest {
    @Test
    fun getPlatformVersion_containsAndroidWord() {
        val plugin = Rees46FlutterSdkPlugin()
        assertTrue(plugin.getPlatformVersion().startsWith("Android "))
    }

    @Test
    fun theRootOfAShopThePluginDoesNotKnowIsNotInitialized() {
        val plugin = Rees46FlutterSdkPlugin()
        val flushed = mutableListOf<Result<Unit>>()
        val deleted = mutableListOf<Result<SdkSnapshotWire>>()

        plugin.flush("unknown-shop") { flushed += it }
        plugin.deleteUserCredentials("unknown-shop") { deleted += it }
        // Released already: nothing to do, and nothing thrown.
        plugin.release("unknown-shop")

        val failures = listOf(flushed.single(), deleted.single()).map { it.exceptionOrNull() as FlutterError }
        assertEquals(listOf("notInitialized", "notInitialized"), failures.map { it.code })
    }
}
