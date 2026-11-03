import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rees46_sdk/rees46_sdk.dart';

// What the full demo (`main.dart`) and the shop-only one (`main_shop.dart`) share:
// the hardcoded shop and its init, the theme and the demo's stories links.

/// Hardcoded demo shop: both demos initialize it, the UI Kit and the shop reach it
/// by this id.
const String demoShopId = 'c1140c8254976de297c3caf971701a';

const String _demoApiDomain = 'api.rees46.ru';

/// Initializes [demoShopId] through the multi-instance [REES46] facade — the same
/// entry point the iOS/Android demos use — and returns its handle. The flags start
/// as the API tab shows them; it re-initializes with the switched ones.
PersonalizationSdk initializeDemoShop({
  bool enableLogs = false,
  bool autoSendPushToken = true,
  bool sendAdvertisingId = false,
  bool enableAutoPopupPresentation = true,
  bool needReInitialization = false,
}) => REES46.initialize(
  REES46Config(
    shopId: demoShopId,
    apiDomain: _demoApiDomain,
    stream: defaultTargetPlatform == TargetPlatform.android ? 'android' : 'ios',
    enableLogs: enableLogs,
    autoSendPushToken: autoSendPushToken,
    sendAdvertisingId: sendAdvertisingId,
    enableAutoPopupPresentation: enableAutoPopupPresentation,
    needReInitialization: needReInitialization,
  ),
);

/// Asks the host for the Android 13+ notification permission. Called from a
/// post-frame callback rather than MainActivity.onCreate, so it runs after Patrol's
/// app-service handshake and the system dialog never hangs an integration test.
Future<void> requestDemoNotificationPermission() async {
  try {
    await const MethodChannel(
      'rees46_sdk_example/platform',
    ).invokeMethod<void>('requestNotificationPermission');
  } catch (_) {
    // Best-effort: the app still runs without it (pushes just won't be shown
    // until the permission is granted), and non-Android hosts ignore it.
  }
}

/// Seed theme of both demos.
ThemeData demoTheme(Brightness brightness) => ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.blue,
    brightness: brightness,
  ),
);

/// Scheme of the demo's own links. The stories with sharing share
/// `rees46flutter://<site>/?r46_stories=…` instead of `https://`, and the app opens
/// such links (any host and path) from [DemoLinks].
const String demoLinkScheme = 'rees46flutter';

/// Host of the stories API v3 of the demo's stories with sharing and of their links;
/// the global `PersonalizationStories.apiV3Domain` stays unset.
const String demoStoriesApiV3Domain = 'app.rees46.ru';

/// The slide link with the demo scheme instead of `http(s)://`.
String demoShareUrl(String url) => url.replaceFirst(
  RegExp(r'^https?://', caseSensitive: false),
  '$demoLinkScheme://',
);

/// Stories "Share" links in the demo scheme
/// (`rees46flutter://<any host>/?r46_stories=…`). MainActivity / AppDelegate hand them
/// over: the one the app was started with on request (`getInitialLink`), later ones as
/// `onLink`.
abstract final class DemoLinks {
  static const MethodChannel _channel = MethodChannel(
    'rees46_sdk_example/links',
  );

  /// Hands [onLink] the link the app was started with (once, after the first frame)
  /// and every link that comes while it runs.
  static void listen(ValueChanged<String> onLink) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onLink') onLink(call.arguments as String);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final link = await _channel.invokeMethod<String>('getInitialLink');
        if (link != null) onLink(link);
      } catch (_) {
        // No host channel (tests): no links.
      }
    });
  }

  static void cancel() => _channel.setMethodCallHandler(null);
}
