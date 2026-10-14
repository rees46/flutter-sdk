import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/src/ui/personalization_ui.dart';

/// A 1×1 transparent PNG: the tests only need an [ImageProvider] to exist.
final ImageProvider _pixel = MemoryImage(
  Uint8List.fromList(const <int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, //
    0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, //
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82, //
  ]),
);

const List<PersonalizationLoyaltyCardField> _fields = [
  PersonalizationLoyaltyCardField(label: 'Владелец', value: 'Олег'),
  PersonalizationLoyaltyCardField(label: 'Уровень', value: 'Базовый'),
];

/// The card in a vertical scroll view, as a host screen would place it: the
/// height is unbounded, the width is [width].
Widget _host(Widget card, {double width = 370, ThemeData? theme}) =>
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: SingleChildScrollView(
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: width, child: card),
          ),
        ),
      ),
    );

PersonalizationLoyaltyCard _full({
  int stamps = 0,
  int stampsTotal = 5,
  Widget Function(BuildContext, String, double, Color)? iconBuilder,
}) => PersonalizationLoyaltyCard(
  logo: const SizedBox(width: 108),
  balanceLabel: 'Бонусы',
  balanceValue: '50 550',
  stripe: _pixel,
  emblem: _pixel,
  stamps: stamps,
  stampsTotal: stampsTotal,
  fields: _fields,
  code: '2000012345678',
  iconBuilder: iconBuilder,
);

Rect _card(WidgetTester tester) =>
    tester.getRect(find.byType(PersonalizationLoyaltyCard));

final Finder _stripe = find.byWidgetPredicate(
  (widget) => widget is ColoredBox && widget.color == const Color(0xFF000000),
);

void main() {
  testWidgets('the minimum height keeps the 370×560 pass proportion', (
    tester,
  ) async {
    for (final width in <double>[370, 300, 343]) {
      await tester.pumpWidget(
        _host(const PersonalizationLoyaltyCard(), width: width),
      );

      expect(
        _card(tester).height,
        closeTo(width * 560 / 370, 1e-9),
        reason: '$width',
      );
    }
  });

  testWidgets('the full card fits the proportion and pins the code low', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_full()));

    final card = _card(tester);
    expect(card.height, closeTo(560, 1e-9));
    // Code section: 24 below the white box, 20 inside it.
    final barcode = tester.getRect(find.byType(PersonalizationBarcode));
    expect(barcode.bottom, closeTo(card.bottom - 24 - 20, 1e-9));
    expect(barcode.center.dx, closeTo(card.center.dx, 1));
  });

  testWidgets('a card narrower than its content grows past the proportion', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_full(), width: 200));

    // Header 16 + 38 + 16, stripe 200 / 2.6, info 16 + 46 + 16,
    // code 24 + 20 + 42 + 20 + 24.
    expect(_card(tester).height, closeTo(70 + 200 / 2.6 + 78 + 130, 1e-6));
    expect(tester.takeException(), isNull);
  });

  testWidgets('sections without content are left out', (tester) async {
    await tester.pumpWidget(_host(const PersonalizationLoyaltyCard()));
    expect(find.byType(Text), findsNothing);
    expect(_stripe, findsNothing);
    expect(find.byType(PersonalizationBarcode), findsNothing);

    // Only the info fields: no header and no stripe above them.
    await tester.pumpWidget(
      _host(const PersonalizationLoyaltyCard(fields: _fields)),
    );
    expect(
      tester.getTopLeft(find.text('ВЛАДЕЛЕЦ')).dy,
      _card(tester).top + PersonalizationSpacing.xl,
    );

    // A code the barcode cannot carry drops the section.
    for (final code in <String>['', 'é']) {
      await tester.pumpWidget(_host(PersonalizationLoyaltyCard(code: code)));
      expect(find.byType(PersonalizationBarcode), findsNothing, reason: code);
    }

    // The balance shows only the lines it has.
    await tester.pumpWidget(
      _host(const PersonalizationLoyaltyCard(balanceValue: '50 550')),
    );
    expect(find.byType(Text), findsOneWidget);
    expect(find.text('50 550'), findsOneWidget);
  });

  testWidgets('the stripe shows for a picture, an emblem or stamps', (
    tester,
  ) async {
    final cards = <PersonalizationLoyaltyCard>[
      PersonalizationLoyaltyCard(stripe: _pixel),
      PersonalizationLoyaltyCard(emblem: _pixel),
      const PersonalizationLoyaltyCard(stampsTotal: 3),
    ];
    for (final card in cards) {
      await tester.pumpWidget(_host(card));

      expect(_stripe, findsOneWidget);
      final stripe = tester.getRect(
        find.ancestor(of: _stripe, matching: find.byType(SizedBox)).first,
      );
      expect(stripe.width, 370);
      expect(stripe.height, closeTo(370 / 2.6, 1e-9));
    }
  });

  testWidgets('stamps are clamped to the total, filled ones first', (
    tester,
  ) async {
    const light = PersonalizationColors.light;
    const cases = <(int, int, int)>[
      // stamps, total, filled
      (0, 5, 0),
      (4, 5, 4),
      (7, 5, 5),
      (-2, 3, 0),
      (2, -1, 0),
    ];
    for (final (stamps, total, filled) in cases) {
      final drawn = <(String, Color)>[];
      await tester.pumpWidget(
        _host(
          _full(
            stamps: stamps,
            stampsTotal: total,
            iconBuilder: (context, asset, size, color) {
              drawn.add((asset, color));
              return SizedBox.square(dimension: size);
            },
          ),
        ),
      );

      final reason = '$stamps of $total';
      final expected = total < 0 ? 0 : total;
      expect(drawn, hasLength(expected), reason: reason);
      for (final (index, (asset, color)) in drawn.indexed) {
        final isFilled = index < filled;
        expect(
          asset,
          isFilled
              ? PersonalizationIcons.checkRosetteFill
              : PersonalizationIcons.rosette,
          reason: reason,
        );
        // Constant light tokens: the stripe is dark in either theme.
        expect(
          color,
          isFilled ? light.textLightSecondary : light.textLightHint,
          reason: reason,
        );
      }
    }
  });

  testWidgets('without an iconBuilder the kit draws the stamps itself', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const PersonalizationLoyaltyCard(stamps: 2, stampsTotal: 5)),
    );

    final stamps = find.descendant(
      of: find.byType(PersonalizationLoyaltyCard),
      matching: find.byType(CustomPaint),
    );
    expect(stamps, findsNWidgets(5));
    expect(tester.getSize(stamps.first), const Size(32, 32));
  });

  testWidgets('info fields share the width equally', (tester) async {
    await tester.pumpWidget(
      _host(const PersonalizationLoyaltyCard(fields: _fields)),
    );

    const pad = PersonalizationSpacing.xl;
    const gap = PersonalizationSpacing.gapModal;
    const column = (370 - 2 * pad - gap) / 2;
    expect(tester.getTopLeft(find.text('ВЛАДЕЛЕЦ')).dx, pad);
    expect(tester.getTopLeft(find.text('УРОВЕНЬ')).dx, pad + column + gap);
  });

  testWidgets('the palette follows the theme and yields to overrides', (
    tester,
  ) async {
    final schemes = <(ThemeData, PersonalizationColors)>[
      (ThemeData(), PersonalizationColors.light),
      (ThemeData(brightness: Brightness.dark), PersonalizationColors.dark),
    ];
    for (final (theme, colors) in schemes) {
      await tester.pumpWidget(_host(_full(), theme: theme));
      // MaterialApp animates a theme change.
      await tester.pumpAndSettle();

      final reason = '${theme.brightness}';
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is ColoredBox && widget.color == colors.backgroundCard,
        ),
        findsOneWidget,
        reason: reason,
      );
      for (final text in <String>['БОНУСЫ', '50 550', 'ВЛАДЕЛЕЦ', 'Олег']) {
        expect(
          tester.widget<Text>(find.text(text)).style!.color,
          colors.textPrimary,
          reason: '$reason, $text',
        );
      }
      // The barcode keeps its white box in either theme.
      final box = tester.widget<DecoratedBox>(
        find
            .ancestor(
              of: find.byType(PersonalizationBarcode),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(
        (box.decoration as BoxDecoration).color,
        const Color(0xFFFFFFFF),
        reason: reason,
      );
      // Elevation 3 in the scheme's shadow colour.
      final shadow = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(PersonalizationLoyaltyCard),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final shadows = (shadow.decoration as BoxDecoration).boxShadow!;
      expect(shadows, hasLength(PersonalizationElevation.e3.length));
      for (final (index, cast) in shadows.indexed) {
        expect(cast.offset, PersonalizationElevation.e3[index].offset);
        expect(cast.color, colors.shadowHeavy, reason: reason);
      }
    }

    const brand = Color(0xFF0087E8);
    const white = Color(0xFFFFFFFF);
    await tester.pumpWidget(
      _host(
        const PersonalizationLoyaltyCard(
          balanceLabel: 'Бонусы',
          balanceValue: '50 550',
          fields: _fields,
          cardColor: brand,
          contentColor: white,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) => widget is ColoredBox && widget.color == brand,
      ),
      findsOneWidget,
    );
    expect(tester.widget<Text>(find.text('БОНУСЫ')).style!.color, white);
    expect(tester.widget<Text>(find.text('Базовый')).style!.color, white);
  });
}
