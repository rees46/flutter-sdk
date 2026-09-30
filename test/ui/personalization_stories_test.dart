import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/rees46_sdk.dart';
import 'package:rees46_sdk/src/pigeon/personalization_api.g.dart' as pigeon;
import 'package:rees46_sdk/src/ui/personalization_ui.dart';
import 'package:rees46_sdk/src/ui/widgets/stories_support.dart';

/// A 1×1 transparent PNG: slides and covers need an image that loads offline.
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

ImageProvider _offline(String url) => _pixel;

StoryProduct _product({
  String promocode = '',
  int discountPercent = 0,
  double oldPrice = 0,
}) => StoryProduct(
  id: 'p1',
  name: 'Laptop',
  brand: 'Apple',
  price: 1190900,
  priceFormatted: '1 190 900 ₽',
  oldPrice: oldPrice,
  oldPriceFormatted: oldPrice > 0 ? '245 000 ₽' : '',
  discountPercent: discountPercent,
  promocode: promocode,
  priceWithPromocodeFormatted: promocode.isEmpty ? '' : '1 000 000 ₽',
  url: 'https://shop.example/p1',
);

/// A block of two one-slide product stories, one second each.
String _blockJson() => jsonEncode(<String, dynamic>{
  'id': 1,
  'stories': <Map<String, dynamic>>[
    for (final id in <int>[1, 2])
      <String, dynamic>{
        'id': id,
        'name': 'Story $id',
        'avatar': 'https://cdn.example/$id.jpg',
        'slides': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': '${id}_0',
            'duration': 1,
            'type': '',
            'elements': <Map<String, dynamic>>[
              <String, dynamic>{
                'type': 'product',
                'item': <String, dynamic>{
                  'id': 'p$id',
                  'name': 'Product $id',
                  'price': 100,
                  'price_formatted': '100 ₽',
                  'picture': 'https://cdn.example/p$id.jpg',
                  'url': 'https://shop.example/p$id',
                },
              },
            ],
          },
        ],
      },
  ],
});

class _FakeHostApi extends pigeon.PersonalizationHostApi {
  _FakeHostApi(this.answer);

  /// What `getStories` answers; `null` — the call fails.
  final String? answer;
  Completer<void>? hold;
  final List<String> views = <String>[];
  final List<String> clicks = <String>[];

  @override
  Future<String> getStories(String code, String? shopId) async {
    await hold?.future;
    final json = answer;
    if (json == null) throw PlatformException(code: 'get_stories_failed');
    return json;
  }

  @override
  Future<void> trackStoryView(
    String storyId,
    String slideId,
    String? code,
    String? shopId,
  ) async => views.add('$storyId/$slideId/$code');

  @override
  Future<void> trackStoryClick(
    String storyId,
    String slideId,
    String? code,
    String? shopId,
  ) async => clicks.add('$storyId/$slideId/$code');
}

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 400, child: child),
    ),
  ),
);

void main() {
  group('storyPriceOf', () {
    test('promo code wins over discount, discount over plain price', () {
      final promo = storyPriceOf(
        _product(promocode: 'PROMO', discountPercent: 10, oldPrice: 245000),
      );
      expect(promo.type, PersonalizationStoryPriceType.promoCode);
      expect(promo.price, '1 000 000 ₽', reason: 'the price with the code');
      expect(promo.promoCode, 'PROMO');

      final discount = storyPriceOf(_product(discountPercent: 10));
      expect(discount.type, PersonalizationStoryPriceType.discount);
      expect(discount.discount, '10%');
      expect(discount.price, '1 190 900 ₽');

      final plain = storyPriceOf(_product());
      expect(plain.type, PersonalizationStoryPriceType.price);
      expect(plain.discount, isNull);
      expect(plain.promoCode, isNull);
    });

    test('the old price shows only when it is above the price', () {
      expect(storyPriceOf(_product(oldPrice: 245000)).oldPrice, isNull);
      expect(storyPriceOf(_product(oldPrice: 2000000)).oldPrice, '245 000 ₽');
    });
  });

  group('storyTextBlock', () {
    test('a server block maps opacity, alignment and font', () {
      final solid = storyTextBlock(
        const StoryTextBlockElement(
          text: 'Sale',
          fontSize: 24,
          fontType: 'serif',
          textAlign: 'center',
          backgroundColor: '#16AE13',
          backgroundOpacity: 0.4,
        ),
      );
      expect(solid.solid, isTrue);
      expect(solid.background!.a, closeTo(0.4, 0.01));
      expect(solid.textAlign, TextAlign.center);
      expect(solid.fontFamily, 'serif');
      expect(solid.fontSize, 24);

      final clear = storyTextBlock(
        const StoryTextBlockElement(
          text: 'Sale',
          backgroundColor: '#16AE13',
          backgroundOpacity: 0,
        ),
      );
      expect(clear.solid, isFalse);
    });
  });

  group('PersonalizationStoryViewer', () {
    /// One story: two image slides, a text block on the first.
    final story = Story.fromJson(<String, dynamic>{
      'id': 7,
      'name': 'Media',
      'avatar': '',
      'slides': <Map<String, dynamic>>[
        for (final id in <int>[70, 71])
          <String, dynamic>{
            'id': id,
            'duration': 5,
            'type': 'image',
            'background': 'https://cdn.example/$id.jpg',
            'elements': <Map<String, dynamic>>[
              <String, dynamic>{
                'type': 'text_block',
                'text_input': 'Slide $id',
                'y_offset': 30,
              },
            ],
          },
      ],
    });

    Future<List<String>> open(WidgetTester tester) async {
      final api = _FakeHostApi(null);
      await tester.pumpWidget(
        MaterialApp(
          home: PersonalizationStoryViewer(
            stories: <Story>[story],
            code: 'block',
            sdk: PersonalizationSdk(api: api),
            imageProvider: _offline,
            onClose: () {},
          ),
        ),
      );
      await tester.pump();
      // The slide's clock starts once its image is decoded, and decoding needs real
      // async: let it finish, then pump the result in.
      await tester.runAsync(
        () => precacheImage(
          _pixel,
          tester.element(find.byType(PersonalizationStoryViewer)),
        ),
      );
      await tester.pump();
      await tester.pump();
      return api.views;
    }

    testWidgets('media slides take the dark tokens in a light app', (
      tester,
    ) async {
      await open(tester);
      final text = tester.widget<Text>(find.text('Slide 70'));
      expect(text.style!.color, PersonalizationColors.dark.textPrimary);
      final fill = tester
          .widgetList<ColoredBox>(
            find.descendant(
              of: find.byType(PersonalizationStoryProgress),
              matching: find.byType(ColoredBox),
            ),
          )
          .last;
      expect(fill.color, PersonalizationColors.dark.textSecondary);
    });

    testWidgets('taps move between slides, holding pauses', (tester) async {
      final views = await open(tester);
      expect(views, <String>['7/70/block']);

      final size = tester.getSize(find.byType(PersonalizationStoryViewer));
      // Right two thirds: the next slide.
      await tester.tapAt(Offset(size.width * 0.8, size.height / 2));
      await tester.pump();
      await tester.pump();
      expect(find.text('Slide 71'), findsOneWidget);
      expect(views, <String>['7/70/block', '7/71/block']);

      // Left third: back.
      await tester.tapAt(Offset(size.width * 0.1, size.height / 2));
      await tester.pump();
      await tester.pump();
      expect(find.text('Slide 70'), findsOneWidget);

      // Held longer than the slide lasts: still there.
      final hold = await tester.startGesture(
        Offset(size.width / 2, size.height / 2),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 6));
      expect(find.text('Slide 70'), findsOneWidget);
      await hold.up();
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));
      expect(find.text('Slide 71'), findsOneWidget);
    });
  });

  group('PersonalizationStories', () {
    testWidgets('skeletons while loading, hidden when empty', (tester) async {
      final api = _FakeHostApi(jsonEncode(<String, dynamic>{'stories': []}))
        ..hold = Completer<void>();
      await tester.pumpWidget(
        _host(
          PersonalizationStories(
            code: 'block',
            sdk: PersonalizationSdk(api: api),
          ),
        ),
      );
      final skeletons = find.byWidgetPredicate(
        (widget) =>
            widget is PersonalizationStoryPreview &&
            widget.state == PersonalizationStoryCoverState.skeleton,
      );
      expect(skeletons, findsNWidgets(4));

      api.hold!.complete();
      await tester.pump();
      await tester.pump();
      expect(find.byType(PersonalizationStoriesBar), findsNothing);
    });

    testWidgets('an error hides the block and reaches onError', (tester) async {
      final errors = <Object>[];
      await tester.pumpWidget(
        _host(
          PersonalizationStories(
            code: 'block',
            sdk: PersonalizationSdk(api: _FakeHostApi(null)),
            onError: errors.add,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(PersonalizationStoriesBar), findsNothing);
      expect(errors.single, isA<PlatformException>());
    });

    testWidgets('a story played to the end turns viewed in the bar', (
      tester,
    ) async {
      final api = _FakeHostApi(_blockJson());
      await tester.pumpWidget(
        _host(
          PersonalizationStories(
            code: 'block',
            sdk: PersonalizationSdk(api: api),
            imageProvider: _offline,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      PersonalizationStoryPreview preview(String label) =>
          tester.widget<PersonalizationStoryPreview>(
            find.ancestor(
              of: find.text(label),
              matching: find.byType(PersonalizationStoryPreview),
            ),
          );
      expect(preview('Story 2').state, PersonalizationStoryCoverState.unviewed);
      expect(preview('Story 2').segments, 1);

      // Open the last story: its only slide plays, then the viewer closes.
      await tester.tap(find.text('Story 2'));
      await tester.pump(); // route pushed
      await tester.pump(const Duration(milliseconds: 300)); // transition
      expect(find.byType(PersonalizationStoryViewer), findsOneWidget);
      expect(find.text('Product 2'), findsOneWidget);
      expect(find.text('More info'), findsOneWidget);
      // A product slide sits on Background/Card of the app theme.
      expect(
        find.descendant(
          of: find.byType(PersonalizationStoryViewer),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is ColoredBox &&
                widget.color == PersonalizationColors.light.backgroundCard,
          ),
        ),
        findsWidgets,
      );
      expect(api.views, <String>['2/2_0/block']);

      await tester.pump(const Duration(milliseconds: 1100)); // the slide
      await tester.pump(const Duration(milliseconds: 300)); // pop transition
      expect(find.byType(PersonalizationStoryViewer), findsNothing);

      expect(preview('Story 2').state, PersonalizationStoryCoverState.viewed);
      expect(preview('Story 2').seenSegments, 1);
      expect(preview('Story 1').state, PersonalizationStoryCoverState.unviewed);
    });

    testWidgets('the button tracks a click and hands the link to the host', (
      tester,
    ) async {
      final api = _FakeHostApi(_blockJson());
      final links = <String>[];
      await tester.pumpWidget(
        _host(
          PersonalizationStories(
            code: 'block',
            sdk: PersonalizationSdk(api: api),
            imageProvider: _offline,
            moreInfoText: 'Open',
            onLinkClick: links.add,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Story 1'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Open'));
      await tester.pump();
      expect(api.clicks, <String>['1/1_0/block']);
      // No button on the slide: the product's own link.
      expect(links, <String>['https://shop.example/p1']);
      // Close with the cross before the slide runs out.
      await tester.tap(
        find.descendant(
          of: find.byType(PersonalizationStoryNavigation),
          matching: find.byType(GestureDetector),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(PersonalizationStoryViewer), findsNothing);
    });
  });
}
