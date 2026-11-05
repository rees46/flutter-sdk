import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/rees46_sdk.dart';
// ignore: implementation_imports
import 'package:rees46_sdk/src/ui/personalization_ui.dart';
import 'package:rees46_sdk_example/demo_app.dart';
import 'package:rees46_sdk_example/game/game_screen.dart';
import 'package:rees46_sdk_example/main_shop.dart';
import 'package:rees46_sdk_example/shop/shop.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

void main() {
  group('the game link', () {
    test('is host game in the scheme of any demo', () {
      for (final url in [
        'rees46://game',
        'rees46flutter://game',
        'rees46rn://game',
        'REES46FLUTTER://GAME',
        'rees46flutter://game/',
        'rees46flutter://game/play?level=2',
        ' rees46://game ',
      ]) {
        expect(isDemoGameLink(url), isTrue, reason: url);
        expect(readDemoGameLink(url)!.page, isNull, reason: url);
      }
    });

    test(
      'with r46_stories is a stories link, and other links are not the game',
      () {
        for (final url in [
          'rees46flutter://game?r46_stories=c&r46_story=40',
          'rees46flutter://game/?url=https%3A%2F%2Fa.example&r46_stories=c',
          'rees46flutter://demo.rees46.ru/?r46_stories=c&r46_story=40&r46_slide=37',
          'rees46flutter://shop',
          'rees46flutter:game',
          'https://game',
          'https://demo.rees46.ru/game',
          'myapp://game',
          '',
          'not a link',
        ]) {
          expect(isDemoGameLink(url), isFalse, reason: url);
        }
      },
    );

    test('takes an https url as the page of a game of the app', () {
      expect(
        readDemoGameLink(
          'rees46://game?url=https%3A%2F%2Fgames.example.com%2Fttt%3Flevel%3D2',
        )!.page,
        Uri.parse('https://games.example.com/ttt?level=2'),
      );
      expect(
        readDemoGameLink(
          'rees46flutter://game?url=https://games.example.com/ttt',
        )!.page,
        Uri.parse('https://games.example.com/ttt'),
      );
    });

    test(
      'opens the built-in game for a url that is not https or is broken',
      () {
        for (final url in [
          'rees46flutter://game?url=http%3A%2F%2Fgames.example.com',
          'rees46flutter://game?url=javascript%3Aalert(1)',
          'rees46flutter://game?url=file%3A%2F%2F%2Fetc%2Fhosts',
          'rees46flutter://game?url=https%3Agames.example.com',
          'rees46flutter://game?url=%FF',
          'rees46flutter://game?url=',
          'rees46flutter://game?url',
        ]) {
          final link = readDemoGameLink(url);
          expect(link, isNotNull, reason: url);
          expect(link!.page, isNull, reason: url);
        }
      },
    );
  });

  group('the game screen', () {
    late _FakeWebViewPlatform web;

    setUp(() => WebViewPlatform.instance = web = _FakeWebViewPlatform());

    testWidgets('loads the built-in page and gives it the app theme', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      expect(openDemoGameLink('rees46flutter://game'), isTrue);
      await _settle(tester);

      expect(find.text(DemoGameScreen.title), findsOneWidget);
      final page = web.controllers.single;
      expect(page.asset, demoGameAsset);
      expect(page.request, isNull);
      expect(page.javaScriptMode, JavaScriptMode.unrestricted);
      expect(
        page.background,
        PersonalizationTheme.light.colors.backgroundGeneric,
      );
      // Covered until the page has the theme, so it does not flash in the wrong one.
      expect(find.byType(PersonalizationLoader), findsOneWidget);

      page.finish();
      await tester.pump();
      await tester.pump();
      expect(page.scripts, [
        "window.setGameTheme && window.setGameTheme('light')",
      ]);
      expect(find.byType(PersonalizationLoader), findsNothing);
      await _close(tester);
    });

    testWidgets('gives the page the dark theme of the app', (tester) async {
      await tester.pumpWidget(_app(brightness: Brightness.dark));
      openDemoGameLink('rees46://game');
      await _settle(tester);

      final page = web.controllers.single;
      expect(
        page.background,
        PersonalizationTheme.dark.colors.backgroundGeneric,
      );
      page.finish();
      await tester.pump();
      expect(page.scripts, [
        "window.setGameTheme && window.setGameTheme('dark')",
      ]);
      await _close(tester);
    });

    testWidgets('loads the https page of the link instead', (tester) async {
      await tester.pumpWidget(_app());
      openDemoGameLink(
        'rees46rn://game?url=https%3A%2F%2Fgames.example.com%2Fttt',
      );
      await _settle(tester);

      final page = web.controllers.single;
      expect(page.asset, isNull);
      expect(page.request, Uri.parse('https://games.example.com/ttt'));
      // A failed page is not left under the cover.
      page.fail();
      await tester.pump();
      await tester.pump();
      expect(find.byType(PersonalizationLoader), findsNothing);
      await _close(tester);
    });

    testWidgets('is one: a second link while it is open opens nothing', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      expect(openDemoGameLink('rees46flutter://game'), isTrue);
      await _settle(tester);
      expect(openDemoGameLink('rees46://game'), isTrue);
      await _settle(tester);
      expect(find.byType(DemoGameScreen), findsOneWidget);
      expect(openDemoGameLink('https://rees46.com'), isFalse);
      await _close(tester);
    });

    testWidgets('closes with its cross and with back', (tester) async {
      await tester.pumpWidget(_app());
      openDemoGameLink('rees46flutter://game');
      await _settle(tester);
      await _close(tester);
      expect(find.text('home'), findsOneWidget);

      openDemoGameLink('rees46flutter://game');
      await _settle(tester);
      expect(await tester.binding.handlePopRoute(), isTrue);
      await _settle(tester);
      expect(find.byType(DemoGameScreen), findsNothing);
    });

    testWidgets('opens from a stories button link of any demo', (tester) async {
      await tester.pumpWidget(_app());
      // The shop is not up here: other links have nothing to open them, and no error.
      demoStoriesLinkClick('no-such-shop')('https://rees46.com');
      await _settle(tester);
      expect(find.byType(DemoGameScreen), findsNothing);

      demoStoriesLinkClick('no-such-shop')('rees46://game');
      await _settle(tester);
      expect(find.byType(DemoGameScreen), findsOneWidget);
      await _close(tester);
    });

    testWidgets('a link from outside opens it over the shop-only demo', (
      tester,
    ) async {
      await tester.pumpWidget(const ShopApp());
      await _linkFromOutside(tester, 'rees46flutter://game');
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(DemoGameScreen), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('the link the shop-only demo started with opens it', (
      tester,
    ) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _links,
        (call) async =>
            call.method == 'getInitialLink' ? 'rees46flutter://game' : null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          _links,
          null,
        ),
      );
      await tester.pumpWidget(const ShopApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(DemoGameScreen), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('a popup link to it opens it, and the popup goes', (
      tester,
    ) async {
      await tester.pumpWidget(const ShopApp());
      final popups = REES46.getInstance(demoShopId).popups;
      expect(popups.onLink!('https://rees46.com'), isFalse);
      expect(find.byType(DemoGameScreen), findsNothing);

      expect(popups.onLink!('rees46://game'), isTrue);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(DemoGameScreen), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('the popups of triggers keep off it while it is open', (
      tester,
    ) async {
      await tester.pumpWidget(const ShopApp());
      final sdk = REES46.getInstance(demoShopId);
      expect(sdk.enableAutoPopupPresentation, isTrue);
      expect(openDemoGameLink('rees46://game'), isTrue);
      await _settle(tester);
      expect(sdk.enableAutoPopupPresentation, isFalse);
      await _close(tester);
      expect(sdk.enableAutoPopupPresentation, isTrue);
      await _unmount(tester);
    });
  });
}

const MethodChannel _links = MethodChannel('rees46_sdk_example/links');

/// An app on the demos' navigator with a home to come back to.
Widget _app({Brightness brightness = Brightness.light}) => MaterialApp(
  navigatorKey: demoNavigatorKey,
  theme: demoTheme(brightness),
  home: const Scaffold(body: Text('home')),
);

/// Taps the cross of the game's panel.
Future<void> _close(WidgetTester tester) async {
  await tester.tap(
    find.byWidgetPredicate(
      (widget) => widget is ShopRoundButton && widget.label == 'Закрыть',
    ),
  );
  await _settle(tester);
  expect(find.byType(DemoGameScreen), findsNothing);
}

/// Through a route's transition: the cover's loader keeps animating, so pumps of a
/// set length, not until it settles.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// A link as MainActivity / AppDelegate hand it over while the app runs.
Future<void> _linkFromOutside(WidgetTester tester, String url) =>
    tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      _links.name,
      _links.codec.encodeMethodCall(MethodCall('onLink', url)),
      (_) {},
    );

/// Drops the shop and runs out the timeouts of its requests, which have no host here.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(minutes: 1));
}

/// WebViews without a platform: each remembers what it was told to do, and the test
/// finishes its page.
class _FakeWebViewPlatform extends WebViewPlatform {
  final List<_FakeController> controllers = <_FakeController>[];

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    final controller = _FakeController(params);
    controllers.add(controller);
    return controller;
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => _FakeDelegate(params);

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => _FakeWidget(params);
}

class _FakeController extends PlatformWebViewController {
  _FakeController(super.params) : super.implementation();

  String? asset;
  Uri? request;
  JavaScriptMode? javaScriptMode;
  Color? background;
  _FakeDelegate? delegate;
  final List<String> scripts = <String>[];

  void finish() => delegate!.onPageFinished!(asset ?? request.toString());

  void fail() => delegate!.onWebResourceError!(
    const WebResourceError(
      errorCode: -2,
      description: 'no network',
      isForMainFrame: true,
    ),
  );

  @override
  Future<void> loadFlutterAsset(String key) async => asset = key;

  @override
  Future<void> loadRequest(LoadRequestParams params) async =>
      request = params.uri;

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async =>
      this.javaScriptMode = javaScriptMode;

  @override
  Future<void> setBackgroundColor(Color color) async => background = color;

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async => delegate = handler as _FakeDelegate;

  @override
  Future<void> runJavaScript(String javaScript) async =>
      scripts.add(javaScript);
}

class _FakeDelegate extends PlatformNavigationDelegate {
  _FakeDelegate(super.params) : super.implementation();

  PageEventCallback? onPageFinished;
  WebResourceErrorCallback? onWebResourceError;

  @override
  Future<void> setOnPageFinished(PageEventCallback onPageFinished) async =>
      this.onPageFinished = onPageFinished;

  @override
  Future<void> setOnWebResourceError(
    WebResourceErrorCallback onWebResourceError,
  ) async => this.onWebResourceError = onWebResourceError;
}

class _FakeWidget extends PlatformWebViewWidget {
  _FakeWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
