package com.rees46.rees46_flutter_sdk_example

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // The Flutter layer asks for the notification permission from a post-frame
        // callback (see main.dart) instead of from onCreate. Requesting it only after
        // the engine and first frame are up keeps the system dialog from racing
        // Patrol's app-service handshake during integration tests (which would hang the
        // run), while the real app still prompts the user right at startup.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestNotificationPermission" -> {
                        ensureNotificationPermission()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun ensureNotificationPermission() {
        // On Android 13+ POST_NOTIFICATIONS is a runtime permission; without it the OS
        // silently drops every notification. The native REES46 demo requests it the same
        // way, so the Flutter host must too, otherwise pushes never appear.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val granted = checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
                PackageManager.PERMISSION_GRANTED
            if (!granted) {
                requestPermissions(
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    REQUEST_CODE_POST_NOTIFICATIONS,
                )
            }
        }
    }

    private companion object {
        const val CHANNEL = "rees46_sdk_example/platform"
        const val REQUEST_CODE_POST_NOTIFICATIONS = 1001
    }
}
