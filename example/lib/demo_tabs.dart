import 'package:flutter/material.dart';

/// The demo's sections as bottom tabs, in the order and under the names of the
/// native demos: "API" — the SDK methods, "UI Kit" — the kit's showcase, "Shop" —
/// the demo shop. "API" is open at start.
///
/// The tabs keep their state: a tab is built the first time it is opened and stays
/// mounted after that, only the open one is shown — switching back finds it as it
/// was left. Built on first open rather than all at once, so the shop and the kit
/// do not load before the API tab has initialized the SDK.
///
/// "Shop" has a navigator of its own, like a navigation controller in an iOS tab:
/// its category, product and search screens open inside the tab with the tab bar
/// still in place. System back walks that stack while "Shop" is the open tab; on
/// the shop's home, and on the other tabs, back does what it does anywhere else.
class DemoTabs extends StatefulWidget {
  const DemoTabs({
    super.key,
    required this.api,
    required this.uiKit,
    required this.shop,
  });

  final Widget api;
  final Widget uiKit;

  /// Home of the "Shop" tab, the first screen of its navigator.
  final Widget shop;

  @override
  State<DemoTabs> createState() => _DemoTabsState();
}

class _DemoTabsState extends State<DemoTabs> {
  static const int _shopTab = 2;

  int _tab = 0;

  /// Tabs opened at least once; the others are not built yet.
  final Set<int> _opened = <int>{0};

  final GlobalKey<NavigatorState> _shopNavigator = GlobalKey<NavigatorState>();

  void _open(int tab) => setState(() {
    _tab = tab;
    _opened.add(tab);
  });

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      widget.api,
      widget.uiKit,
      // Enabled only while the tab is open: from a hidden tab back would walk a
      // stack nobody sees.
      NavigatorPopHandler<Object?>(
        enabled: _tab == _shopTab,
        onPopWithResult: (_) => _shopNavigator.currentState?.maybePop(),
        child: Navigator(
          key: _shopNavigator,
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => widget.shop,
          ),
        ),
      ),
    ];
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          for (final (index, tab) in tabs.indexed)
            _opened.contains(index) ? tab : const SizedBox.shrink(),
        ],
      ),
      // The bar keeps clear of the bottom safe area itself.
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _open,
        destinations: const [
          NavigationDestination(
            key: Key('tab-api'),
            icon: Icon(Icons.list),
            label: 'API',
          ),
          NavigationDestination(
            key: Key('tab-ui-kit'),
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
            label: 'UI Kit',
          ),
          NavigationDestination(
            key: Key('tab-shop'),
            icon: Icon(Icons.shopping_bag_outlined),
            selectedIcon: Icon(Icons.shopping_bag),
            label: 'Shop',
          ),
        ],
      ),
    );
  }
}
