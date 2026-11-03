import 'package:flutter/material.dart';

import 'demo_app.dart';
import 'shop/shop_home.dart';

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
  @override
  void initState() {
    super.initState();
    // Registers the shop and sends the native init before the shop's first request.
    initializeDemoShop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      requestDemoNotificationPermission();
    });
    // Stories links of the demo scheme, the one of a cold start included.
    DemoLinks.listen(_openLink);
  }

  @override
  void dispose() {
    DemoLinks.cancel();
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
