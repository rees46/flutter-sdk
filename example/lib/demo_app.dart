import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rees46_sdk/rees46_sdk.dart';
// The kit stays out of the package barrel until its release; the example reaches
// it directly, which the analyzer flags as an implementation import on purpose.
// ignore: implementation_imports
import 'package:rees46_sdk/src/ui/personalization_ui.dart';

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

/// Theme of both demos, on the kit's palette of that [brightness]: its brand is the
/// primary colour, its card the surface, its text colours the text; the tab bar is the
/// kit's card with the open tab in the brand colour and the others in the secondary
/// text colour.
ThemeData demoTheme(Brightness brightness) {
  final colors =
      (brightness == Brightness.dark
              ? PersonalizationTheme.dark
              : PersonalizationTheme.light)
          .colors;
  WidgetStateProperty<T> byTab<T>(T open, T other) =>
      WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? open : other,
      );
  return ThemeData(
    // The roles the kit has no colour for come from its brand colour.
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: colors.brandPrimary,
          brightness: brightness,
        ).copyWith(
          primary: colors.brandPrimary,
          onPrimary: colors.textLightPrimary,
          error: colors.semanticDanger,
          surface: colors.backgroundCard,
          onSurface: colors.textPrimary,
          onSurfaceVariant: colors.textSecondary,
          outline: colors.lineGeneric,
          outlineVariant: colors.lineGenericSubtle,
        ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colors.backgroundCard,
      indicatorColor: colors.buttonSecondary,
      iconTheme: byTab(
        IconThemeData(color: colors.brandPrimary),
        IconThemeData(color: colors.textSecondary),
      ),
      labelTextStyle: byTab(
        PersonalizationTypography.xsEmphasized.copyWith(
          color: colors.brandPrimary,
        ),
        PersonalizationTypography.xsDefault.copyWith(
          color: colors.textSecondary,
        ),
      ),
    ),
  );
}

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

/// Screen codes the demos report to popups v3 — what the marketer puts in
/// `target_screens` of a popup in the editor.
abstract final class DemoScreens {
  /// The full demo's tabs.
  static const String api = 'api';
  static const String uiKit = 'ui_kit';

  /// The shop's screens.
  static const String home = 'home';
  static const String category = 'category';
  static const String product = 'product';
  static const String search = 'search';
}

/// Screen code of a shop route: its name, the navigator's first route ('/') being
/// the shop's home.
String? demoScreenName(Route<dynamic> route) =>
    route.settings.name == '/' ? DemoScreens.home : route.settings.name;

/// Popups v3 of the demo shop that the "Show popup" menu of the shop's header shows by
/// hand: id and menu item. A new popup is one more line.
const List<({int id, String label})> demoManualPopups = [
  (id: 181, label: '#181 Banner · top'),
  (id: 182, label: '#182 Modal · center'),
];

/// Turns popups v3 on for [sdk], on the dashboard host of the demo shop
/// ([demoStoriesApiV3Domain]). The `/init` flag does not reach Flutter yet (the
/// plugin is built against the published native SDKs), so the demo forces the
/// engine on; its decisions and the popup events go to the debug log. A product of a
/// recommendations block in a popup goes to [onProductClick], which opens it in the
/// shop and returns true; the screen that sets it takes it off when it goes.
void enableDemoPopupsV3(
  PersonalizationSdk sdk, {
  bool Function(PersonalizationProduct product)? onProductClick,
}) {
  sdk.popups
    ..appHost = demoStoriesApiV3Domain
    ..debug = true
    ..onProductClick = onProductClick
    ..ignoreInitFlag = true
    ..enabled = true;
}
