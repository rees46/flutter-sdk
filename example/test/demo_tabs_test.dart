import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk_example/demo_tabs.dart';
import 'package:rees46_sdk_example/shop/shop_sort.dart';

/// A tab that shows whether it kept its state: every tap counts.
class _Counter extends StatefulWidget {
  const _Counter(this.name);

  final String name;

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int _taps = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () => setState(() => _taps++),
        child: Text('${widget.name} taps: $_taps'),
      ),
    ),
  );
}

/// Shop home: opens its screens on the navigator it finds, as the shop does, and
/// has a search panel that back closes first, as the shop's search field does.
class _ShopHome extends StatefulWidget {
  const _ShopHome();

  @override
  State<_ShopHome> createState() => _ShopHomeState();
}

class _ShopHomeState extends State<_ShopHome> {
  bool _searching = false;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_searching,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) setState(() => _searching = false);
    },
    child: Scaffold(
      appBar: AppBar(title: const Text('Shop home')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const _ShopCategory()),
              ),
              child: const Text('Open category'),
            ),
            TextButton(
              onPressed: () => setState(() => _searching = true),
              child: Text(_searching ? 'Search panel' : 'Search'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ShopCategory extends StatelessWidget {
  const _ShopCategory();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Category')),
    body: Center(
      child: TextButton(
        onPressed: () => pickShopSort(context, ShopSort.relevance),
        child: const Text('Sort'),
      ),
    ),
  );
}

Widget _app() => const MaterialApp(
  home: DemoTabs(
    api: _Counter('api'),
    uiKit: _Counter('kit'),
    shop: _ShopHome(),
  ),
);

NavigationBar _bar(WidgetTester tester) =>
    tester.widget<NavigationBar>(find.byType(NavigationBar));

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

/// System back, as Android sends it. `false` — nothing in the app took it, so the
/// app would leave.
Future<bool> _systemBack(WidgetTester tester) async {
  final handled = await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
  return handled;
}

/// Hidden tabs stay mounted, so a finder sees them too; only the open one takes taps.
Finder _shown(String text) => find.text(text).hitTestable();

void main() {
  testWidgets('opens on API with API | UI Kit | Shop in the bar', (
    tester,
  ) async {
    await tester.pumpWidget(_app());

    expect(
      _bar(tester).destinations.map(
        (destination) => (destination as NavigationDestination).label,
      ),
      ['API', 'UI Kit', 'Shop'],
    );
    expect(_bar(tester).selectedIndex, 0);
    expect(_shown('api taps: 0'), findsOneWidget);
    // The other tabs are built when first opened.
    expect(find.text('kit taps: 0'), findsNothing);
    expect(find.text('Shop home'), findsNothing);
  });

  testWidgets('a tab keeps its state while another one is open', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.tap(find.text('api taps: 0'));
    await tester.pump();

    await _openTab(tester, 'UI Kit');
    expect(_bar(tester).selectedIndex, 1);
    expect(_shown('api taps: 1'), findsNothing);
    await tester.tap(_shown('kit taps: 0'));
    await tester.pump();

    await _openTab(tester, 'API');
    expect(_shown('api taps: 1'), findsOneWidget);
    await _openTab(tester, 'UI Kit');
    expect(_shown('kit taps: 1'), findsOneWidget);
  });

  testWidgets('shop screens open inside the tab, under the tab bar', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await _openTab(tester, 'Shop');
    expect(_shown('Shop home'), findsOneWidget);
    // The shop's home is the tab's first screen: nothing to go back to.
    expect(find.byType(BackButton), findsNothing);

    await tester.tap(find.text('Open category'));
    await tester.pumpAndSettle();
    expect(_shown('Category'), findsOneWidget);
    expect(find.byType(NavigationBar).hitTestable(), findsOneWidget);

    // The shop's stack waits while another tab is open.
    await _openTab(tester, 'API');
    await _openTab(tester, 'Shop');
    expect(_shown('Category'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(_shown('Shop home'), findsOneWidget);
  });

  testWidgets('system back walks the shop stack only while Shop is open', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await _openTab(tester, 'Shop');
    await tester.tap(find.text('Open category'));
    await tester.pumpAndSettle();

    // On another tab back leaves the app as usual and the shop keeps its screen.
    await _openTab(tester, 'API');
    expect(await _systemBack(tester), isFalse);
    await _openTab(tester, 'Shop');
    expect(_shown('Category'), findsOneWidget);

    // On Shop it steps back through the shop.
    expect(await _systemBack(tester), isTrue);
    expect(_shown('Shop home'), findsOneWidget);
    expect(_bar(tester).selectedIndex, 2);

    // On the shop's home it is back as on any other tab.
    expect(await _systemBack(tester), isFalse);
    expect(_shown('Shop home'), findsOneWidget);
  });

  testWidgets('system back on the shop home closes its search panel first', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await _openTab(tester, 'Shop');
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    expect(_shown('Search panel'), findsOneWidget);

    expect(await _systemBack(tester), isTrue);
    expect(_shown('Search'), findsOneWidget);
    expect(await _systemBack(tester), isFalse);
  });

  testWidgets('the sort picker of a shop screen closes, not the screen', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await _openTab(tester, 'Shop');
    await tester.tap(find.text('Open category'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sort'));
    await tester.pumpAndSettle();
    expect(find.text('Sort by'), findsOneWidget);
    await tester.tap(find.text('Discount'));
    await tester.pumpAndSettle();
    expect(find.text('Sort by'), findsNothing);
    expect(_shown('Category'), findsOneWidget);

    await tester.tap(find.text('Sort'));
    await tester.pumpAndSettle();
    expect(await _systemBack(tester), isTrue);
    expect(find.text('Sort by'), findsNothing);
    expect(_shown('Category'), findsOneWidget);
  });
}
