import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/src/ui/components/personalization_wrap_row.dart';
import 'package:rees46_sdk/src/ui/personalization_ui.dart';

const Key _first = ValueKey<String>('first');
const Key _second = ValueKey<String>('second');

/// Two fixed boxes in a row of [width], top-left in a vertical scroll view.
Widget _row({
  required double width,
  bool pinEnd = false,
  bool withSecond = true,
}) => _host(
  width,
  PersonalizationWrapRow(
    horizontalGap: 8,
    verticalGap: 4,
    pinEnd: pinEnd,
    children: <Widget>[
      const SizedBox(key: _first, width: 100, height: 40),
      if (withSecond) const SizedBox(key: _second, width: 80, height: 20),
    ],
  ),
);

Widget _host(double width, Widget child) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: width, child: child),
      ),
    ),
  ),
);

RenderPersonalizationWrapRow _render(WidgetTester tester) =>
    tester.renderObject<RenderPersonalizationWrapRow>(
      find.byType(PersonalizationWrapRow).first,
    );

void main() {
  testWidgets(
    'boxes that fit share the line, the pinned one at the right edge',
    (tester) async {
      await tester.pumpWidget(_row(width: 300, pinEnd: true));

      expect(_render(tester).isWrapped, isFalse);
      expect(tester.getSize(find.byType(PersonalizationWrapRow)).height, 40);
      expect(tester.getTopLeft(find.byKey(_second)), const Offset(220, 10));
    },
  );

  testWidgets(
    'without the pin the second box follows the first after the gap',
    (tester) async {
      await tester.pumpWidget(_row(width: 300));

      expect(tester.getTopLeft(find.byKey(_second)).dx, 108);
    },
  );

  testWidgets('boxes that do not fit wrap, the pinned one to the right', (
    tester,
  ) async {
    await tester.pumpWidget(_row(width: 180, pinEnd: true));

    expect(_render(tester).isWrapped, isTrue);
    expect(tester.getSize(find.byType(PersonalizationWrapRow)).height, 64);
    expect(tester.getTopLeft(find.byKey(_second)), const Offset(100, 44));
  });

  testWidgets('a wrapped box without the pin starts at the left edge', (
    tester,
  ) async {
    await tester.pumpWidget(_row(width: 150));

    expect(tester.getTopLeft(find.byKey(_second)), const Offset(0, 44));
  });

  testWidgets('a single box stays alone on its line', (tester) async {
    await tester.pumpWidget(_row(width: 120, pinEnd: true, withSecond: false));

    expect(_render(tester).isWrapped, isFalse);
    expect(tester.getSize(find.byType(PersonalizationWrapRow)).height, 40);
  });

  testWidgets('intrinsic height follows the wrap', (tester) async {
    await tester.pumpWidget(
      _host(
        180,
        const IntrinsicHeight(
          child: PersonalizationWrapRow(
            horizontalGap: 8,
            verticalGap: 4,
            children: <Widget>[
              SizedBox(width: 100, height: 40),
              SizedBox(width: 80, height: 20),
            ],
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(IntrinsicHeight)).height, 64);
  });

  testWidgets('wrapping above puts the second box over the first', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        150,
        const PersonalizationWrapRow(
          horizontalGap: 8,
          verticalGap: 4,
          wrapAbove: true,
          children: <Widget>[
            SizedBox(key: _first, width: 100, height: 30),
            SizedBox(key: _second, width: 80, height: 20),
          ],
        ),
      ),
    );

    expect(tester.getTopLeft(find.byKey(_second)), const Offset(0, 0));
    expect(tester.getTopLeft(find.byKey(_first)), const Offset(0, 24));
  });

  testWidgets('bottom alignment lines the boxes up by their bottoms', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        300,
        const PersonalizationWrapRow(
          horizontalGap: 8,
          verticalGap: 4,
          alignBottom: true,
          children: <Widget>[
            SizedBox(key: _first, width: 100, height: 30),
            SizedBox(key: _second, width: 80, height: 20),
          ],
        ),
      ),
    );

    expect(
      tester.getBottomLeft(find.byKey(_second)).dy,
      tester.getBottomLeft(find.byKey(_first)).dy,
    );
  });

  group('grid product card', () {
    Widget card(double width) => _host(
      width,
      const PersonalizationProductCard(
        type: PersonalizationProductCardType.grid,
        brand: 'Bang & Olufsen',
        name: 'Телевизор Bang & Olufsen 40" BeoVision Horizon',
        price: '799 990 ₽',
        oldPrice: '1 574 990 ₽',
        discount: '-49%',
        actionText: 'Add to cart',
      ),
    );

    testWidgets('long prices put the old price above the price, unbroken', (
      tester,
    ) async {
      await tester.pumpWidget(card(240));

      expect(tester.takeException(), isNull);
      expect(
        tester.getBottomLeft(find.text('1 574 990 ₽')).dy,
        lessThanOrEqualTo(tester.getTopLeft(find.text('799 990 ₽')).dy),
      );
      expect(tester.widget<Text>(find.text('1 574 990 ₽')).maxLines, 1);
    });

    testWidgets('prices that fit stay on one line', (tester) async {
      await tester.pumpWidget(card(600));

      expect(
        tester.getTopLeft(find.text('1 574 990 ₽')).dy,
        greaterThan(tester.getTopLeft(find.text('799 990 ₽')).dy - 1),
      );
      expect(
        tester.getTopLeft(find.text('1 574 990 ₽')).dx,
        greaterThan(tester.getTopRight(find.text('799 990 ₽')).dx),
      );
    });
  });

  group('list product card', () {
    Widget card(double width) => _host(
      width,
      const PersonalizationProductCard(
        type: PersonalizationProductCardType.list,
        brand: 'HP',
        name: 'Мышка игровая проводная HP OMEN 600',
        price: '7 990 ₽',
        oldPrice: '9 990 ₽',
        discount: '-20%',
        actionText: 'Add to cart',
      ),
    );

    RenderPersonalizationWrapRow bottomRow(WidgetTester tester) =>
        tester.renderObject<RenderPersonalizationWrapRow>(
          find.byType(PersonalizationWrapRow).first,
        );

    testWidgets('a wide card keeps the price and the button on one line', (
      tester,
    ) async {
      await tester.pumpWidget(card(600));

      expect(tester.takeException(), isNull);
      expect(bottomRow(tester).isWrapped, isFalse);
    });

    testWidgets(
      'a narrow card moves the button under the price, nothing overflows',
      (tester) async {
        await tester.pumpWidget(card(330));

        expect(tester.takeException(), isNull);
        expect(bottomRow(tester).isWrapped, isTrue);
        expect(
          tester.getTopLeft(find.text('Add to cart')).dy,
          greaterThan(tester.getBottomLeft(find.text('9 990 ₽')).dy),
        );
        final Text badge = tester.widget<Text>(find.text('-20%'));
        expect(badge.maxLines, 1);
      },
    );
  });
}
