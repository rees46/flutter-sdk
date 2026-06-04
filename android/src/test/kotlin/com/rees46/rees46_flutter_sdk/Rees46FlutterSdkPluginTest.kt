package com.rees46.rees46_flutter_sdk

import kotlin.test.Test
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
}
