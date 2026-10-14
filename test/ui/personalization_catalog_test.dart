import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/src/ui/personalization_ui.dart';

// The catalogue is one scrolling list: header, cards and footer are its parts. Given a
// bounded height it builds cards for what is on screen only, however many it holds.

Widget _host(Widget child, {double height = 600}) => MaterialApp(
  home: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: 400, height: height, child: child),
  ),
);

List<PersonalizationProduct> _products(int count) => <PersonalizationProduct>[
  for (int i = 0; i < count; i++)
    PersonalizationProduct(id: '$i', name: 'Item $i', price: '$i'),
];

const PersonalizationCatalogCount _count = PersonalizationCatalogCount(
  prefix: 'Showing',
  shown: 4,
  separator: 'of',
  total: 40,
);

/// Every card that exists, on screen or in the cache area around it.
final Finder _cards = find.byType(
  PersonalizationProductCard,
  skipOffstage: false,
);

Rect _card(WidgetTester tester, int index) =>
    tester.getRect(find.byType(PersonalizationProductCard).at(index));

void main() {
  testWidgets('a long catalogue builds cards for the screen, not for every '
      'product', (tester) async {
    await tester.pumpWidget(
      _host(PersonalizationCatalog(products: _products(200))),
    );

    final built = _cards.evaluate().length;
    expect(built, inInclusiveRange(1, 30));
  });

  testWidgets('scrolling to the end keeps a screenful of cards', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _host(
        PersonalizationCatalog(
          products: _products(200),
          controller: controller,
          count: _count,
        ),
      ),
    );

    // The extent of a lazy list is an estimate: jump until it holds at the end.
    for (int i = 0; i < 50; i++) {
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
      if (controller.position.pixels == controller.position.maxScrollExtent) {
        break;
      }
    }

    expect(find.text('Item 199'), findsOneWidget);
    expect(find.byType(PersonalizationCount), findsOneWidget);
    expect(_cards.evaluate().length, inInclusiveRange(1, 30));
  });

  testWidgets('inside another scroll it lays out whole and does not scroll '
      'itself', (tester) async {
    await tester.pumpWidget(
      _host(
        ListView(
          children: <Widget>[
            PersonalizationCatalog(
              products: _products(40),
              count: _count,
              scrollable: false,
            ),
          ],
        ),
      ),
    );

    expect(_cards, findsNWidgets(40));
    expect(
      find.byType(PersonalizationCount, skipOffstage: false),
      findsOneWidget,
    );
    final own = tester.widget<Scrollable>(
      find
          .descendant(
            of: find.byType(PersonalizationCatalog),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(own.physics, isA<NeverScrollableScrollPhysics>());
  });

  testWidgets('an unbounded height lays it out whole without the flag', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        SingleChildScrollView(
          child: PersonalizationCatalog(products: _products(10)),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(_cards, findsNWidgets(10));
  });

  testWidgets('blocks are 12 apart, grid cards 16 on both axes, a row shares '
      'its height', (tester) async {
    tester.view.physicalSize = const Size(400, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const header = SizedBox(key: Key('header'), height: 40);
    await tester.pumpWidget(
      _host(
        const PersonalizationCatalog(
          header: header,
          products: <PersonalizationProduct>[
            PersonalizationProduct(
              id: '0',
              brand: 'Brand',
              name: 'A name long enough to take both lines of the card',
              price: '1',
            ),
            PersonalizationProduct(id: '1', name: 'Short', price: '2'),
            PersonalizationProduct(id: '2', name: 'Third', price: '3'),
          ],
          count: _count,
        ),
        height: 2000,
      ),
    );

    final headerRect = tester.getRect(find.byKey(const Key('header')));
    expect(_card(tester, 0).top - headerRect.bottom, PersonalizationSpacing.lg);
    expect(
      _card(tester, 1).left - _card(tester, 0).right,
      PersonalizationSpacing.xl,
    );
    expect(
      _card(tester, 2).top - _card(tester, 0).bottom,
      PersonalizationSpacing.xl,
    );
    expect(_card(tester, 0).height, _card(tester, 1).height);
    expect(
      tester.getRect(find.byType(PersonalizationCount)).top -
          _card(tester, 2).bottom,
      PersonalizationSpacing.lg,
    );
  });

  testWidgets('the list puts one card per row, 16 apart', (tester) async {
    await tester.pumpWidget(
      _host(
        PersonalizationCatalog(
          layout: PersonalizationProductsLayout.list,
          products: _products(3),
        ),
      ),
    );

    expect(_card(tester, 0).width, 400);
    expect(
      _card(tester, 1).top - _card(tester, 0).bottom,
      PersonalizationSpacing.xl,
    );
  });

  testWidgets('the loader takes the place of the count and load more', (
    tester,
  ) async {
    Widget catalog({required bool loading}) => _host(
      PersonalizationCatalog(
        products: _products(4),
        count: _count,
        loadMoreText: 'Load more',
        onLoadMore: () {},
        loading: loading,
      ),
    );
    final loadMore = find.widgetWithText(PersonalizationButton, 'Load more');

    await tester.pumpWidget(catalog(loading: false));
    expect(find.byType(PersonalizationCount), findsOneWidget);
    expect(loadMore, findsOneWidget);
    expect(find.byType(PersonalizationLoader), findsNothing);

    await tester.pumpWidget(catalog(loading: true));
    expect(find.byType(PersonalizationCount), findsNothing);
    expect(loadMore, findsNothing);
    expect(find.byType(PersonalizationLoader), findsOneWidget);
  });

  testWidgets('no products and an empty text show the empty state under the '
      'header', (tester) async {
    const header = SizedBox(key: Key('header'), height: 40);
    await tester.pumpWidget(
      _host(
        const PersonalizationCatalog(
          header: header,
          products: <PersonalizationProduct>[],
          emptyText: 'Nothing found',
        ),
      ),
    );

    expect(find.byKey(const Key('header')), findsOneWidget);
    expect(find.byType(PersonalizationEmptyState), findsOneWidget);
    expect(
      tester.getRect(find.byType(PersonalizationEmptyState)).top -
          tester.getRect(find.byKey(const Key('header'))).bottom,
      PersonalizationSpacing.lg,
    );
  });
}
