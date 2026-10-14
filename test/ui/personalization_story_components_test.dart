import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/src/ui/personalization_ui.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 400, child: child),
    ),
  ),
);

void main() {
  group('StoryPrice', () {
    test('the currency is the trailing non-digit token', () {
      expect(PersonalizationStoryPrice.splitCurrency('1 190 900 ₽'), (
        '1 190 900',
        '₽',
      ));
      expect(PersonalizationStoryPrice.splitCurrency('9 999₽'), ('9 999', '₽'));
      expect(PersonalizationStoryPrice.splitCurrency('1,190.00 USD'), (
        '1,190.00',
        'USD',
      ));
      expect(PersonalizationStoryPrice.splitCurrency('10 000 тг.'), (
        '10 000',
        'тг.',
      ));
      expect(PersonalizationStoryPrice.splitCurrency(r'$140'), (r'$140', ''));
      expect(PersonalizationStoryPrice.splitCurrency(''), ('', ''));
    });

    testWidgets('discount draws the percent on the brand block', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const PersonalizationStoryPrice(
            type: PersonalizationStoryPriceType.discount,
            price: '1 190 900 ₽',
            oldPrice: '245 000 ₽',
            discount: '10%',
          ),
        ),
      );
      expect(find.text('10%'), findsOneWidget);
      expect(find.text('1 190 900'), findsOneWidget);
      expect(find.text('245 000'), findsOneWidget);
      expect(find.text('₽'), findsNWidgets(2));
      final brand = find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color ==
                PersonalizationColors.light.brandPrimary,
      );
      expect(brand, findsOneWidget);
    });

    testWidgets('tapping the promo code copies it, toasts and reports', (
      tester,
    ) async {
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final copied = <String>[];
      await tester.pumpWidget(
        _host(
          PersonalizationStoryPrice(
            type: PersonalizationStoryPriceType.promoCode,
            price: '1 190 900 ₽',
            promoCode: 'YAGODA-MALINA',
            copiedText: 'Code copied',
            onPromoCopied: copied.add,
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('YAGODA-MALINA')),
      );
      await tester.pump(const Duration(milliseconds: 200));
      final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(scale.scale, PersonalizationStoryPrice.pressedScale);
      await gesture.up();
      await tester.pump();

      expect(clipboard, 'YAGODA-MALINA');
      expect(copied, <String>['YAGODA-MALINA']);
      expect(find.text('Code copied'), findsOneWidget);
      expect(
        tester.getCenter(find.text('Code copied')).dy,
        lessThan(
          tester.view.physicalSize.height / tester.view.devicePixelRatio / 2,
        ),
        reason: 'the toast shows at the top by default',
      );
      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
      // The toast leaves by itself.
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Code copied'), findsNothing);
    });

    testWidgets('columns share the width; a long code takes more', (
      tester,
    ) async {
      Future<double> promoWidth(String code) async {
        await tester.pumpWidget(
          _host(
            PersonalizationStoryPrice(
              type: PersonalizationStoryPriceType.promoCode,
              price: '1 190 900 ₽',
              promoCode: code,
            ),
          ),
        );
        return tester.getSize(find.byType(AnimatedScale)).width;
      }

      expect(await promoWidth('PROMO'), 200);
      final long = await promoWidth('A-VERY-LONG-PROMO-CODE-2026');
      expect(long, greaterThan(200));
      expect(long, lessThanOrEqualTo(400 * 0.7));
    });
  });

  test('the timer splits the rest into days and two-digit units', () {
    expect(
      PersonalizationStoryTimer.format(
        const Duration(days: 2, hours: 18, minutes: 33, seconds: 24),
      ),
      ('2', '18', '33', '24'),
    );
    expect(
      PersonalizationStoryTimer.format(
        const Duration(hours: 1, minutes: 2, seconds: 3),
      ),
      ('0', '01', '02', '03'),
    );
    expect(PersonalizationStoryTimer.format(const Duration(seconds: -5)), (
      '0',
      '00',
      '00',
      '00',
    ));
  });

  testWidgets('a finished timer shows zeros and reports once', (tester) async {
    var finished = 0;
    await tester.pumpWidget(
      _host(
        PersonalizationStoryTimer(
          endTime: DateTime.now().subtract(const Duration(seconds: 1)),
          view: PersonalizationStoryTimerView.separate,
          onFinished: () => finished++,
        ),
      ),
    );
    expect(find.text('0'), findsOneWidget);
    expect(find.text('00'), findsNWidgets(3));
    expect(find.text('d'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(finished, 0, reason: 'already over when shown: nothing to count');
  });

  group('StoryTextBlock', () {
    BoxDecoration? frame(WidgetTester tester) {
      final boxes = find.descendant(
        of: find.byType(PersonalizationStoryTextBlock),
        matching: find.byType(DecoratedBox),
      );
      if (boxes.evaluate().isEmpty) return null;
      return tester.widget<DecoratedBox>(boxes.first).decoration
          as BoxDecoration;
    }

    testWidgets('solid: server colour, radius 12, padding by size', (
      tester,
    ) async {
      const green = Color(0x6616AE13);
      await tester.pumpWidget(
        _host(
          const PersonalizationStoryTextBlock(
            text: 'Open eat dear winding belonging.',
            size: PersonalizationStoryTextSize.large,
            background: green,
          ),
        ),
      );
      expect(frame(tester)!.color, green);
      expect(frame(tester)!.borderRadius, BorderRadius.circular(12));
      final padding = tester.widget<Padding>(
        find.descendant(
          of: find.byType(PersonalizationStoryTextBlock),
          matching: find.byType(Padding),
        ),
      );
      expect(
        padding.padding,
        const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      );
      final text = tester.widget<Text>(find.byType(Text));
      expect(text.style!.color, PersonalizationColors.light.textLightPrimary);
      expect(text.style!.fontSize, 48);

      await tester.pumpWidget(
        _host(
          const PersonalizationStoryTextBlock(
            text: 'Small',
            size: PersonalizationStoryTextSize.small,
            background: green,
          ),
        ),
      );
      expect(
        tester
            .widget<Padding>(
              find.descendant(
                of: find.byType(PersonalizationStoryTextBlock),
                matching: find.byType(Padding),
              ),
            )
            .padding,
        const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      );

      // Medium (30) is not above 30: the small padding, as in the design file.
      await tester.pumpWidget(
        _host(
          const PersonalizationStoryTextBlock(
            text: 'Medium',
            background: green,
          ),
        ),
      );
      expect(
        tester
            .widget<Padding>(
              find.descendant(
                of: find.byType(PersonalizationStoryTextBlock),
                matching: find.byType(Padding),
              ),
            )
            .padding,
        const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      );
    });

    testWidgets('transparent: no frame, Text/Primary', (tester) async {
      await tester.pumpWidget(
        _host(
          const PersonalizationStoryTextBlock(
            text: 'Plain',
            background: Color(0x0016AE13),
          ),
        ),
      );
      expect(frame(tester), isNull);
      final text = tester.widget<Text>(find.byType(Text));
      expect(text.style!.color, PersonalizationColors.light.textPrimary);
      expect(text.style!.fontSize, 30);
    });
  });

  test('ring colours: viewed solid, pinned always warning, seen by index', () {
    const c = PersonalizationColors.light;
    List<Color> ring(
      PersonalizationStoryCoverState state, {
      bool pinned = false,
      Set<int> seen = const <int>{},
    }) => PersonalizationStoryCover.ringColors(
      c,
      state: state,
      pinned: pinned,
      segments: 4,
      seen: seen,
    );

    expect(ring(PersonalizationStoryCoverState.viewed), [c.neutralSubtle]);
    expect(
      ring(PersonalizationStoryCoverState.viewed, pinned: true, seen: {0, 1}),
      [c.semanticWarning],
      reason: 'a fully viewed pinned story: a plain warning ring',
    );
    expect(ring(PersonalizationStoryCoverState.unviewed, seen: {1, 3}), [
      c.buttonPrimary,
      c.buttonPrimaryDisabled,
      c.buttonPrimary,
      c.buttonPrimaryDisabled,
    ]);
    expect(
      ring(PersonalizationStoryCoverState.unviewed, pinned: true, seen: {0}),
      [
        c.buttonPrimaryDisabled,
        c.semanticWarning,
        c.semanticWarning,
        c.semanticWarning,
      ],
    );
  });

  testWidgets('a viewed cover rings solid; a partly seen one in arcs', (
    tester,
  ) async {
    const light = PersonalizationColors.light;
    RenderObject ring() => tester.renderObject(
      find
          .descendant(
            of: find.byType(PersonalizationStoryCover),
            matching: find.byType(CustomPaint),
          )
          .first,
    );
    // Paint keeps its colour as floats: compare the packed value.
    PaintPatternPredicate drawn(Symbol call, Color color) =>
        (method, arguments) =>
            method == call &&
            arguments.whereType<Paint>().single.color.toARGB32() ==
                color.toARGB32();

    await tester.pumpWidget(
      _host(
        const Align(
          alignment: Alignment.topLeft,
          child: PersonalizationStoryCover(
            state: PersonalizationStoryCoverState.viewed,
            pinned: true,
            segments: 5,
            seenSegments: {0, 1, 2, 3, 4},
          ),
        ),
      ),
    );
    expect(ring(), paints..something(drawn(#drawOval, light.semanticWarning)));
    expect(ring(), isNot(paints..arc()));

    await tester.pumpWidget(
      _host(
        const Align(
          alignment: Alignment.topLeft,
          child: PersonalizationStoryCover(segments: 3, seenSegments: {2}),
        ),
      ),
    );
    expect(
      ring(),
      paints
        ..something(drawn(#drawArc, light.buttonPrimary))
        ..something(drawn(#drawArc, light.buttonPrimary))
        ..something(drawn(#drawArc, light.buttonPrimaryDisabled)),
    );
  });

  testWidgets('a pinned cover wears the star; a skeleton has none', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const Align(
          alignment: Alignment.topLeft,
          child: PersonalizationStoryPreview(
            label: 'Pinned',
            pinned: true,
            segments: 5,
            seenSegments: {0, 1},
          ),
        ),
      ),
    );
    expect(find.byType(PersonalizationFavoritesBadge), findsOneWidget);
    expect(find.text('Pinned'), findsOneWidget);
    expect(
      tester.getSize(find.byType(PersonalizationStoryPreview)),
      const Size(88, 88 + 8 + 16),
    );

    await tester.pumpWidget(
      _host(
        const Align(
          alignment: Alignment.topLeft,
          child: PersonalizationStoryPreview(
            state: PersonalizationStoryCoverState.skeleton,
          ),
        ),
      ),
    );
    expect(find.byType(PersonalizationFavoritesBadge), findsNothing);
    expect(
      tester.getSize(find.byType(PersonalizationStoryPreview)),
      const Size(88, 88 + 8 + 16),
      reason: 'the skeleton keeps the height of a labelled preview',
    );
  });

  testWidgets('a cover label takes up to two lines, as wide as the cover', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const Align(
          alignment: Alignment.topLeft,
          child: PersonalizationStoryPreview(
            label: 'A label far too long for one line or even two of them',
          ),
        ),
      ),
    );
    final text = tester.widget<Text>(find.byType(Text));
    expect(text.maxLines, 2);
    expect(text.overflow, TextOverflow.ellipsis);
    expect(text.textAlign, TextAlign.center);
    expect(
      tester.getSize(find.byType(PersonalizationStoryPreview)),
      const Size(88, 88 + 8 + 32),
    );
  });

  test('a text block without a line spacing takes the preset for its size', () {
    double line(double size) =>
        PersonalizationStoryTextBlock.presetLineHeight(size) * size;
    expect(line(48), 48);
    expect(line(30), closeTo(36, 1e-9));
    expect(line(20), closeTo(24, 1e-9));
    // The nearest preset; a tie between Large and Medium goes to Large.
    expect(line(39), 39, reason: 'tie: Large');
    expect(line(38), closeTo(46, 1e-9), reason: 'Medium, 45.6 rounded');
    expect(line(40), 40, reason: 'Large');
    expect(line(14), closeTo(17, 1e-9), reason: 'Small, 16.8 rounded');
  });

  testWidgets('the sound button names the current state and toggles', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    for (final muted in <bool>[true, false]) {
      await tester.pumpWidget(
        _host(PersonalizationStorySoundButton(muted: muted, onPressed: () {})),
      );
      expect(
        tester.getSemantics(find.byType(PersonalizationStorySoundButton)),
        matchesSemantics(
          label: muted ? 'Sound off' : 'Sound on',
          isButton: true,
          hasToggledState: true,
          isToggled: !muted,
          hasTapAction: true,
        ),
      );
    }
    handle.dispose();
  });

  testWidgets('progress fills the passed segments and part of the current', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const PersonalizationStoryProgress(count: 4, current: 1, progress: 0.5),
      ),
    );
    final fills = tester
        .widgetList<FractionallySizedBox>(find.byType(FractionallySizedBox))
        .map((box) => box.widthFactor)
        .toList();
    expect(fills, <double>[1, 0.5, 0, 0]);
  });
}
