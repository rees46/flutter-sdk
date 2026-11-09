import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk_example/shop/shop_sort.dart';

void main() {
  test('each sort is the sort_by / sort_dir pair the API takes', () {
    expect(
      ShopSort.values.map((sort) => (sort.label, sort.sortBy, sort.sortDir)),
      [
        ('Relevance', null, null),
        ('Price: low to high', 'price', 'asc'),
        ('Price: high to low', 'price', 'desc'),
        ('Discount', 'discount', 'desc'),
      ],
    );
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('the sheet hands back the chosen sort on ${platform.name}', (
      tester,
    ) async {
      final picked = <ShopSort?>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  picked.add(await pickShopSort(context, ShopSort.relevance)),
              child: const Text('Sort'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Sort'));
      await tester.pumpAndSettle();
      expect(find.text('Sort by'), findsOneWidget);
      expect(find.text('Relevance'), findsOneWidget);
      // The current sort is checked, the others are not.
      expect(find.byIcon(Icons.check), findsOneWidget);
      await tester.tap(find.text('Discount'));
      await tester.pumpAndSettle();

      expect(picked, [ShopSort.discount]);
    });
  }
}
