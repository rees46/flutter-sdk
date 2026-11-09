import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/src/ui/personalization_ui.dart';

Widget _host(Widget child) => MaterialApp(
  home: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: 400, child: child),
  ),
);

const List<PersonalizationProduct> _rated = <PersonalizationProduct>[
  PersonalizationProduct(
    id: '1',
    name: 'Rated',
    price: '1',
    rating: PersonalizationProductRating(value: '4,7', reviews: 12),
  ),
];

void main() {
  testWidgets('no title and no show-all button — no title row', (tester) async {
    for (final title in <String?>[null, '']) {
      await tester.pumpWidget(
        _host(
          PersonalizationProductsBlock(
            layout: PersonalizationProductsLayout.list,
            title: title,
            products: _rated,
          ),
        ),
      );
      expect(find.byType(PersonalizationTitle), findsNothing);
      expect(find.text('Rated'), findsOneWidget);
    }
  });

  testWidgets('the show-all button keeps the title row without a title', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        PersonalizationProductsBlock(showAllText: 'Show all', products: _rated),
      ),
    );
    expect(find.byType(PersonalizationTitle), findsOneWidget);
    expect(find.text('Show all'), findsOneWidget);
  });

  testWidgets('the rating shows only with showRating', (tester) async {
    Widget block({required bool showRating}) => _host(
      PersonalizationProductsBlock(
        title: 'Rated',
        layout: PersonalizationProductsLayout.grid,
        showRating: showRating,
        products: _rated,
      ),
    );

    await tester.pumpWidget(block(showRating: true));
    expect(find.byType(PersonalizationRating), findsOneWidget);

    await tester.pumpWidget(block(showRating: false));
    expect(find.byType(PersonalizationRating), findsNothing);
  });
}
