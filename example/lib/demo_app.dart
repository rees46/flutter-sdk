import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rees46_sdk/rees46_sdk.dart';
// v3 (popups of the new builder, stories over API v3) is not public API; its gate is
// lifted when v3 goes public. The example reaches it directly, which the analyzer
// flags as an implementation import on purpose.
// ignore: implementation_imports
import 'package:rees46_sdk/src/v3/personalization_v3.dart';

import 'game/game_screen.dart';

// What the full demo (`main.dart`) and the shop-only one (`main_shop.dart`) share:
// the hardcoded shop and its init, the theme, the demo's stories links and the game's.

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
/// the global `PersonalizationStoriesV3.apiV3Domain` stays unset.
const String demoStoriesApiV3Domain = 'app.rees46.ru';

/// The slide link with the demo scheme instead of `http(s)://`.
String demoShareUrl(String url) => url.replaceFirst(
  RegExp(r'^https?://', caseSensitive: false),
  '$demoLinkScheme://',
);

/// Links of the demo scheme, any host and path: stories "Share" links
/// (`rees46flutter://<any host>/?r46_stories=…`) and the game's
/// (`rees46flutter://game`). MainActivity / AppDelegate hand them over: the one the app
/// was started with on request (`getInitialLink`), later ones as `onLink`.
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

/// Navigator of both demos' apps: the game opens on it, over whatever is open — the
/// tabs and the shop's own navigator included.
final GlobalKey<NavigatorState> demoNavigatorKey = GlobalKey<NavigatorState>();

/// Schemes of the demos' own links: the Android and iOS demos', this one's
/// ([demoLinkScheme]) and the React Native one's.
const Set<String> _demoSchemes = <String>{'rees46', demoLinkScheme, 'rees46rn'};

/// The mini-game's link [url] read; `null` — not its link.
///
/// The game's link is host `game` in the scheme of any demo — so one link of a story
/// or a popup in the dashboard opens the game in each of them — without
/// `r46_stories`, which makes it a stories link; the path does not matter. Its `url`
/// parameter, an `https` address, is a game of the app's own from its server
/// ([page]); anything else there, or nothing, is the built-in game.
({Uri? page})? readDemoGameLink(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || !_demoSchemes.contains(uri.scheme) || uri.host != 'game') {
    return null;
  }
  // Pair by pair: broken %-encoding of one value spoils only that value.
  final params = <String, String?>{};
  for (final pair in uri.query.split('&')) {
    if (pair.isEmpty) continue;
    final eq = pair.indexOf('=');
    final key = _decoded(eq < 0 ? pair : pair.substring(0, eq));
    if (key == null) continue;
    params.putIfAbsent(
      key,
      () => eq < 0 ? '' : _decoded(pair.substring(eq + 1)),
    );
  }
  if (params.containsKey('r46_stories')) return null;
  final page = Uri.tryParse(params['url'] ?? '');
  final own = page != null && page.scheme == 'https' && page.host.isNotEmpty;
  return (page: own ? page : null);
}

String? _decoded(String component) {
  try {
    return Uri.decodeQueryComponent(component);
  } on FormatException {
    return null;
  }
}

/// Whether [url] is the mini-game's link ([readDemoGameLink]).
bool isDemoGameLink(String url) => readDemoGameLink(url) != null;

/// The open game; another link to it while it is open opens nothing new.
Route<void>? _openGame;

/// Opens the game over the open screen if [url] is its link ([readDemoGameLink]).
/// `false` — not the game's link, or the app has no navigator yet.
///
/// While the game is open the popups of triggers do not show: the SDK puts a popup
/// over the app's pages, the game's too — an app that the game's link starts would
/// get its `app_start` popups right over the game.
bool openDemoGameLink(String url) {
  final link = readDemoGameLink(url);
  if (link == null) return false;
  final navigator = demoNavigatorKey.currentState;
  if (navigator == null) return false;
  if (_openGame?.isActive ?? false) return true;
  final game = _openGame = MaterialPageRoute<void>(
    settings: const RouteSettings(name: DemoScreens.game),
    fullscreenDialog: true,
    builder: (_) => DemoGameScreen(url: link.page),
  );
  final sdk = REES46.isInitialized(demoShopId)
      ? REES46.getInstance(demoShopId)
      : null;
  final popups = sdk?.enableAutoPopupPresentation;
  sdk?.enableAutoPopupPresentation = false;
  navigator.push(game).whenComplete(() {
    if (popups != null) sdk!.enableAutoPopupPresentation = popups;
  });
  return true;
}

/// Link of a slide's button in the demo's stories of [shopId] (the viewer has closed
/// by then): the game's opens the game here; the rest go to the system, as they would
/// without the handler.
ValueChanged<String> demoStoriesLinkClick(String shopId) => (url) {
  if (openDemoGameLink(url) || !REES46.isInitialized(shopId)) return;
  REES46.getInstance(shopId).openUrl(url).catchError((Object error) {
    debugPrint('Demo: cannot open $url — $error');
    return false;
  });
};

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

  /// The mini-game, over any screen.
  static const String game = 'game';
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
  (id: 185, label: '#185 Fullscreen'),
];

/// Turns popups v3 on for [sdk], on the dashboard host of the demo shop
/// ([demoStoriesApiV3Domain]). The `/init` flag does not reach Flutter yet (the
/// plugin is built against the published native SDKs), so the demo forces the
/// engine on; its decisions and the popup events go to the debug log. A product of a
/// recommendations block in a popup goes to [onProductClick], which opens it in the
/// shop and returns true; the screen that sets it takes it off when it goes. The game's
/// link opens the game here, and the popup goes; the other links go to the system.
void enableDemoPopupsV3(
  PersonalizationSdk sdk, {
  bool Function(PersonalizationProduct product)? onProductClick,
}) {
  sdk.popups
    ..appHost = demoStoriesApiV3Domain
    ..debug = true
    ..onProductClick = onProductClick
    // The game's link opened here: the popup goes, without `close`.
    ..onLink = openDemoGameLink
    ..ignoreInitFlag = true
    ..enabled = true;
}
