import 'package:flutter/material.dart';
import 'package:rees46_sdk/rees46_sdk.dart';
// The kit stays out of the package barrel until its release; the example reaches
// it directly, which the analyzer flags as an implementation import on purpose.
// ignore: implementation_imports
import 'package:rees46_sdk/src/ui/personalization_ui.dart';

import 'demo_app.dart';
import 'shop/shop_home.dart';
import 'shop/shop_product.dart';

/// The demo shop alone: home → category → product, search and stories, without the
/// API and UI Kit tabs and their developer tools. Same app, same SDK init and the
/// same stories links as the full demo (`main.dart`):
/// `flutter run -t lib/main_shop.dart`.
void main() => runApp(const ShopApp());

class ShopApp extends StatelessWidget {
  const ShopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'REES46 Shop',
      theme: demoTheme(Brightness.light),
      darkTheme: demoTheme(Brightness.dark),
      // The shop's screens for popups v3; the home reports itself once the SDK is up.
      navigatorObservers: <NavigatorObserver>[
        PersonalizationScreenObserver(
          shopId: demoShopId,
          screenName: demoScreenName,
        ),
      ],
      home: const _ShopHome(),
    );
  }
}

/// Initializes the demo shop, then is its home; a stories link opens the campaign
/// over the shop.
class _ShopHome extends StatefulWidget {
  const _ShopHome();

  @override
  State<_ShopHome> createState() => _ShopHomeState();
}

class _ShopHomeState extends State<_ShopHome> {
  late final PersonalizationSdk _sdk;

  @override
  void initState() {
    super.initState();
    // Registers the shop and sends the native init before the shop's first request.
    final sdk = _sdk = initializeDemoShop();
    enableDemoPopupsV3(
      sdk,
      // A product of a popup opens in the shop, and the popup goes.
      onProductClick: (product) {
        if (!mounted) return false;
        ShopProductScreen.open(context, demoShopId, product.id);
        return true;
      },
    );
    sdk.popups.screenOpened(DemoScreens.home);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      requestDemoNotificationPermission();
    });
    // Stories links of the demo scheme, the one of a cold start included.
    DemoLinks.listen(_openLink);
  }

  @override
  void dispose() {
    DemoLinks.cancel();
    // The handler holds this screen; a new one sets its own.
    _sdk.popups.onProductClick = null;
    super.dispose();
  }

  void _openLink(String url) {
    if (!mounted) return;
    if (!openShopStoriesLink(context, url, demoShopId)) {
      debugPrint('Demo: not a stories link — $url');
    }
  }

  @override
  Widget build(BuildContext context) => const ShopPane(shopId: demoShopId);
}
