import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/rees46_sdk.dart';
import 'package:rees46_sdk/src/personalization_sdk.dart'
    show PersonalizationStoriesBridge;
import 'package:rees46_sdk/src/pigeon/personalization_api.g.dart' as pigeon;
import 'package:rees46_sdk/src/stories/stories_response.dart';

/// A trimmed copy of a real `stories/{code}` answer (block 115bd0b6…, demo shop): a
/// dynamic product slide, a video slide, an image slide with a button and products, plus
/// a text block and a header the kit drops.
final Map<String, dynamic> _block = <String, dynamic>{
  'id': 35,
  'settings': <String, dynamic>{'color': '#212529'},
  'stories': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 39,
      'name': 'Test story',
      'avatar': 'https://cdn.example/avatar.jpg',
      'viewed': false,
      'start_position': 0,
      'pinned': false,
      'slides': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': '39_0',
          'duration': 10,
          'background': '',
          'preview': '',
          'type': '',
          'elements': <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'button',
              'title': 'Buy',
              'link': 'https://shop.example/p/1?recommended_by=dynamic',
              'link_ios': 'https://shop.example/p/1',
              'link_android': 'https://shop.example/p/1',
              'background': '#3b82f6',
              'color': '#ffffff',
            },
            <String, dynamic>{
              'type': 'product',
              'title': ' ',
              'item': <String, dynamic>{
                'id': '216908',
                'name': 'Надувной бассейн INTEX',
                'brand': 'INTEX',
                'picture': 'https://pictures.example/180/135478.jpg',
                'image_url': 'https://api.example/216908_1.jpg',
                'price': 19990,
                'price_formatted': '19 990 ₽',
                'oldprice': 27990,
                'oldprice_formatted': '27 990 ₽',
                'discount_percent': 28,
                'currency': '₽',
                'url': 'https://shop.example/p/1?recommended_by=stories',
                'deeplink_android': 'https://shop.example/p/1',
                'deeplink_ios': 'https://shop.example/p/1',
              },
            },
          ],
        },
      ],
    },
    <String, dynamic>{
      'id': 40,
      'name': 'Test story',
      'avatar': 'https://cdn.example/avatar2.jpg',
      'viewed': true,
      'start_position': '1',
      'pinned': true,
      'slides': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 36,
          'duration': 10,
          'background': 'https://cdn.example/clip.mp4',
          'preview': 'https://cdn.example/poster.jpg',
          'type': 'video',
        },
        <String, dynamic>{
          'id': 37,
          'duration': 0,
          'background': 'https://cdn.example/slide.jpg',
          'background_color': '#000000',
          'preview': '',
          'type': 'image',
          'elements': <Map<String, dynamic>>[
            <String, dynamic>{
              'link': 'https://demo.example/',
              'type': 'button',
              'color': '#ffffff',
              'title': 'Go gaming!',
              'link_ios': '',
              'text_bold': false,
              'background': '#3b82f6',
              'link_android': 'https://demo.example/',
            },
            <String, dynamic>{
              'type': 'products',
              'labels': <String, dynamic>{
                'hide_carousel': 'Скрыть товары',
                'show_carousel': 'Товары для геймеров',
              },
              'products': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 1,
                  'name': 'Mouse',
                  'price': '1990.0',
                  'price_formatted': '1 990 ₽',
                  'oldprice': 0,
                },
              ],
            },
            <String, dynamic>{
              'type': 'text_block',
              'text_input': 'Скидки до 10%',
              'font_size': '24',
              'font_type': 'serif',
              'bold': true,
              'italic': false,
              'text_align': 'center',
              'text_color': '#FFFFFF',
              'text_background_color': '#16AE13',
              'text_background_color_opacity': '40%',
              'text_line_spacing': '1.2',
              'y_offset': 12,
              'promocode': 'SALE10',
            },
            <String, dynamic>{'type': 'header', 'title': 'dropped'},
          ],
        },
        <String, dynamic>{
          'id': 38,
          'background': 'https://cdn.example/plain.jpg',
          'type': 'image',
        },
      ],
    },
  ],
};

class _FakeHostApi extends pigeon.PersonalizationHostApi {
  final List<(String, String?)> requests = <(String, String?)>[];
  final Map<String, Map<String, List<String>>> seen =
      <String, Map<String, List<String>>>{};

  @override
  Future<String> getStories(String code, String? shopId) async {
    requests.add((code, shopId));
    return jsonEncode(_block);
  }

  @override
  Future<Map<String, List<Object?>>> getStoriesSeen(String shop) async =>
      seen[shop] ?? <String, List<String>>{};

  @override
  Future<void> setStorySlideSeen(
    String shop,
    String storyId,
    String slideId,
  ) async {
    (seen[shop] ??= <String, List<String>>{})
        .putIfAbsent(storyId, () => <String>[])
        .add(slideId);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StoriesBlock.fromJson', () {
    final block = StoriesBlock.fromJson(_block);

    test('reads the block and its stories, ids as strings', () {
      expect(block.id, '35');
      expect(block.stories.map((story) => story.id), <String>['39', '40']);
      final second = block.stories[1];
      expect(second.viewed, isTrue);
      expect(second.pinned, isTrue);
      expect(second.startPosition, 1, reason: 'a string number is tolerated');
      expect(second.slides.map((slide) => slide.id), <String>[
        '36',
        '37',
        '38',
      ]);
    });

    test('slide types, backgrounds and durations', () {
      final product = block.stories[0].slides[0];
      expect(product.type, StorySlideType.product);
      expect(product.duration, const Duration(seconds: 10));

      final video = block.stories[1].slides[0];
      expect(video.type, StorySlideType.video);
      expect(video.background, 'https://cdn.example/clip.mp4');
      expect(video.preview, 'https://cdn.example/poster.jpg');
      expect(video.elements, isEmpty);

      final image = block.stories[1].slides[1];
      expect(image.type, StorySlideType.image);
      expect(image.backgroundColor, '#000000');
      expect(
        image.duration,
        const Duration(seconds: StorySlide.defaultDurationSeconds),
        reason: 'zero falls back to the default',
      );
      expect(
        block.stories[1].slides[2].duration,
        const Duration(seconds: StorySlide.defaultDurationSeconds),
        reason: 'missing falls back to the default',
      );
    });

    test('the dynamic product slide carries a button and the product', () {
      final slide = block.stories[0].slides[0];
      final button = slide.elements.whereType<StoryButtonElement>().single;
      expect(button.title, 'Buy');
      expect(button.linkAndroid, 'https://shop.example/p/1');
      expect(button.linkIos, 'https://shop.example/p/1');

      final product = slide.product!;
      expect(product.id, '216908');
      expect(product.brand, 'INTEX');
      expect(product.priceFormatted, '19 990 ₽');
      expect(product.oldPrice, 27990);
      expect(product.hasOldPrice, isTrue);
      expect(product.discountPercent, 28);
      expect(product.promocode, isEmpty);
      expect(product.image, 'https://pictures.example/180/135478.jpg');
    });

    test('products, text block; header dropped', () {
      final elements = block.stories[1].slides[1].elements;
      expect(elements, hasLength(3), reason: 'header is not drawn by the kit');

      final products = elements.whereType<StoryProductsElement>().single;
      expect(products.showLabel, 'Товары для геймеров');
      expect(products.hideLabel, 'Скрыть товары');
      expect(products.products.single.id, '1');
      expect(products.products.single.price, 1990);
      expect(products.products.single.hasOldPrice, isFalse);

      final text = elements.whereType<StoryTextBlockElement>().single;
      expect(text.text, 'Скидки до 10%');
      expect(text.fontSize, 24);
      expect(text.fontType, 'serif');
      expect(text.bold, isTrue);
      expect(text.textAlign, 'center');
      expect(text.backgroundOpacity, closeTo(0.4, 1e-9));
      expect(text.lineSpacing, closeTo(1.2, 1e-9));
      expect(text.yOffset, 12);
      expect(text.promocode, 'SALE10');
    });

    test('a text block without fields takes the native defaults', () {
      final text = StoryTextBlockElement.fromJson(const <String, dynamic>{
        'type': 'text_block',
      });
      expect(text.fontSize, StoryTextBlockElement.defaultFontSize);
      expect(text.backgroundOpacity, 0);
      expect(text.promocode, isNull);
    });
  });

  test('parseStoryOpacity reads percents and fractions', () {
    expect(parseStoryOpacity('0%'), 0);
    expect(parseStoryOpacity('100%'), 1);
    expect(parseStoryOpacity('50'), 0.5);
    expect(parseStoryOpacity(' 25% '), 0.25);
    expect(parseStoryOpacity(0.3), closeTo(0.3, 1e-9));
    expect(parseStoryOpacity(80), closeTo(0.8, 1e-9));
    expect(parseStoryOpacity(null), 0);
    expect(parseStoryOpacity('bad'), 0);
  });

  test('getStories goes through the bridge with the handle\'s shop', () async {
    final api = _FakeHostApi();
    final sdk = PersonalizationSdk(api: api, shopId: 'shop-a');

    final block = await sdk.getStories('115bd0b67cf5989a1b60c841790b2af6');

    expect(api.requests, <(String, String?)>[
      ('115bd0b67cf5989a1b60c841790b2af6', 'shop-a'),
    ]);
    expect(block.stories, hasLength(2));
    expect(() => sdk.getStories(''), throwsArgumentError);
  });

  test('seen slides go through the bridge, per shop', () async {
    final api = _FakeHostApi();
    final sdk = PersonalizationSdk(api: api, shopId: 'shop-a');

    await sdk.setStorySlideSeen('shop-a', '40', '36');
    await sdk.setStorySlideSeen('shop-a', '40', '37');

    expect(await sdk.getStoriesSeen('shop-a'), <String, List<String>>{
      '40': <String>['36', '37'],
    });
    expect(await sdk.getStoriesSeen('shop-b'), isEmpty);
  });

  test('seen slides read over the real channel, whose lists arrive untyped', () async {
    // The platform side answers through the standard codec: the inner lists decode
    // as List<Object?>, not List<String>. A lazy cast of them threw on the first read
    // once a slide had been seen ("List<Object?> is not a subtype of List<String>").
    const channel =
        'dev.flutter.pigeon.personalization_flutter_sdk.PersonalizationHostApi.getStoriesSeen';
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMessageHandler(
      channel,
      (_) async => const StandardMessageCodec().encodeMessage(<Object?>[
        <Object?, Object?>{
          '40': <Object?>['36', '37'],
        },
      ]),
    );
    addTearDown(() => messenger.setMockMessageHandler(channel, null));

    final sdk = PersonalizationSdk(
      api: pigeon.PersonalizationHostApi(),
      shopId: 'shop-a',
    );

    final seen = await sdk.getStoriesSeen('shop-a');
    expect(seen.keys, <String>['40']);
    expect(seen['40'], <String>['36', '37']);
  });

  test('numbers are read as decimals; the default duration is 10 s', () {
    final product = StoryProduct.fromJson(const <String, dynamic>{
      'id': 1,
      'price': '99.9',
      'discount_percent': '12.5',
      'price_with_promocode': 89.5,
    });
    expect(product.price, 99.9);
    expect(product.discountPercent, 12.5);
    expect(product.priceWithPromocode, 89.5);
    expect(StorySlide.defaultDurationSeconds, 10);
  });
}
