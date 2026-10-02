import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/src/ui/personalization_ui.dart';
import 'package:rees46_sdk/src/ui/widgets/stories_support.dart';

StoryProduct _product({
  String promocode = '',
  double discountPercent = 0,
  double oldPrice = 0,
  String withPromo = '',
  double withPromoNumber = 0,
}) => StoryProduct(
  id: 'p1',
  name: 'Laptop',
  price: 1190900,
  priceFormatted: '1 190 900 ₽',
  oldPrice: oldPrice,
  oldPriceFormatted: oldPrice > 0 ? '${oldPrice.toInt()} ₽' : '',
  discountPercent: discountPercent,
  promocode: promocode,
  priceWithPromocode: withPromoNumber,
  priceWithPromocodeFormatted: withPromo,
  url: 'https://shop.example/p1',
  deeplinkAndroid: 'app://p1',
);

StorySlide _slide({
  StorySlideType type = StorySlideType.image,
  String background = 'https://cdn.example/1.jpg',
  String color = '',
  List<StoryElement> elements = const <StoryElement>[],
}) => StorySlide(
  id: '1',
  type: type,
  background: background,
  backgroundColor: color,
  elements: elements,
);

void main() {
  group('price', () {
    test('promo code: the promo price, the old price crossed out', () {
      final price = storyPriceOf(
        _product(promocode: 'P', oldPrice: 2000000, withPromo: '1 000 000 ₽'),
      );
      expect(price.type, PersonalizationStoryPriceType.promoCode);
      expect(price.price, '1 000 000 ₽');
      expect(price.oldPrice, '2000000 ₽');
      expect(price.promoCode, 'P');
    });

    test('promo code without an old price crosses out the regular one', () {
      final crossed = storyPriceOf(
        _product(promocode: 'P', withPromo: '1 000 000 ₽'),
      );
      expect(crossed.oldPrice, '1 190 900 ₽');
      final same = storyPriceOf(
        _product(promocode: 'P', withPromo: '1 190 900 ₽'),
      );
      expect(same.oldPrice, isNull, reason: 'the same price is not crossed');
      final numeric = storyPriceOf(
        _product(promocode: 'P', withPromo: 'x', withPromoNumber: 1190900),
      );
      expect(numeric.oldPrice, isNull, reason: 'numbers decide when sent');
    });

    test('discount keeps a fractional percent; old price only if greater', () {
      final discount = storyPriceOf(_product(discountPercent: 12.5));
      expect(discount.type, PersonalizationStoryPriceType.discount);
      expect(discount.discount, '12.5%');
      expect(storyPriceOf(_product(discountPercent: 10)).discount, '10%');
      expect(storyPriceOf(_product(oldPrice: 245000)).oldPrice, isNull);
      expect(storyPriceOf(_product(oldPrice: 2000000)).oldPrice, isNotNull);
    });
  });

  group('slide', () {
    test('media is a non-empty background, not the slide type', () {
      expect(storyMediaOf(_slide()), StoryMedia.image);
      expect(storyMediaOf(_slide(background: ' ')), StoryMedia.none);
      expect(
        storyMediaOf(_slide(type: StorySlideType.product)),
        StoryMedia.image,
      );
      expect(
        storyMediaOf(_slide(type: StorySlideType.video)),
        StoryMedia.video,
      );
    });

    test('the letterbox is background_color, else black', () {
      expect(storyLetterbox(_slide(color: '#FF0000')), const Color(0xFFFF0000));
      expect(storyLetterbox(_slide()), const Color(0xFF000000));
    });

    test('scrim: 50% only on bare media, 30% otherwise', () {
      expect(storyScrimOpacity(_slide()), 0.5);
      expect(
        storyScrimOpacity(
          _slide(elements: const [StoryTextBlockElement(text: '  ')]),
        ),
        0.5,
        reason: 'a blank text block does not count',
      );
      expect(
        storyScrimOpacity(
          _slide(elements: const [StoryTextBlockElement(text: 'Sale')]),
        ),
        0.3,
      );
      expect(
        storyScrimOpacity(
          _slide(elements: [StoryProductElement(item: _product())]),
        ),
        0.3,
      );
      expect(storyScrimOpacity(_slide(background: '')), 0.3);
    });

    test('only positive integer ids are tracked', () {
      expect(storyTrackableId('36'), isTrue);
      expect(storyTrackableId('39_0'), isFalse);
      expect(storyTrackableId('0'), isFalse);
      expect(storyTrackableId('-3'), isFalse);
      expect(storyTrackableId(''), isFalse);
    });
  });

  group('links and texts', () {
    test('a product slide button: its own link first, else the product', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final product = _product();
      expect(
        storySlideButtonLink(
          const StoryButtonElement(title: 'Buy', link: 'w', linkAndroid: 'a'),
          product,
        ),
        'a',
      );
      expect(
        storySlideButtonLink(const StoryButtonElement(title: 'Buy'), product),
        'app://p1',
      );
    });

    test('promo caption: the admin title, else the host text', () {
      expect(
        storyPromoCaption(const StoryProductElement(title: 'Code'), 'Promo'),
        'Code',
      );
      expect(
        storyPromoCaption(const StoryProductElement(title: ' '), 'Promo'),
        'Promo',
      );
    });

    test('text blocks: blank ones skipped, alignment and line height', () {
      final slide = _slide(
        elements: const [
          StoryTextBlockElement(text: ''),
          StoryTextBlockElement(text: 'Big', fontSize: 48, textAlign: 'end'),
        ],
      );
      final texts = storyTextBlocks(slide);
      expect(texts, hasLength(1));
      final block = storyTextBlock(texts.single);
      expect(block.textAlign, TextAlign.end);
      expect(block.lineHeight, 1);
      expect(storyTextAlign('left'), TextAlign.start);
      expect(storyTextAlign('right'), TextAlign.end);
      expect(storyTextAlign('center'), TextAlign.center);
    });
  });

  test('repeated story ids and stories without slides are dropped', () {
    Story story(Object id, String name, {bool slides = true}) => Story.fromJson(
      <String, dynamic>{
        'id': id,
        'name': name,
        'slides': slides
            ? <Map<String, dynamic>>[
                <String, dynamic>{'id': 1, 'type': 'image', 'background': 'x'},
              ]
            : <Map<String, dynamic>>[],
      },
    );
    final list = playableStories(<Story>[
      story(7, 'first'),
      story(8, 'empty', slides: false),
      story('7', 'again'),
      story(9, 'other'),
    ]);
    expect(list.map((s) => s.name), <String>['first', 'other']);
  });
}
