import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/rees46_sdk.dart';
import 'package:rees46_sdk/src/ui/components/personalization_product.dart';
import 'package:rees46_sdk/src/ui/widgets/product_mapping.dart';

Map<String, dynamic> _fixture(String name) =>
    jsonDecode(File('test/fixtures/$name.json').readAsStringSync())
        as Map<String, dynamic>;

SearchProduct _search(Map<String, Object?> json) => SearchProduct.fromJson(
  <String, dynamic>{'id': '1', 'name': 'Item', ...json},
);

String? _imageUrl(ImageProvider? image) => (image as NetworkImage?)?.url;

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  group('price', () {
    test('the formatted price, else price and currency', () {
      expect(
        productFromSearch(
          _search(<String, Object?>{'price': 10, 'price_formatted': r'$10'}),
        ).price,
        r'$10',
      );
      expect(
        productFromSearch(
          _search(<String, Object?>{'price': 10, 'currency': 'USD'}),
        ).price,
        '10.0 USD',
      );
    });
  });

  group('old price and discount', () {
    test('an old price above the price, with the formatted discount', () {
      final card = productFromSearch(
        _search(<String, Object?>{
          'price': 90,
          'oldprice': 100,
          'oldprice_formatted': '100 ₽',
          'discount': 10,
          'discount_formatted': '10%',
        }),
      );
      expect(card.oldPrice, '100 ₽');
      expect(card.discount, '-10%');
    });

    test('without a formatted discount the number goes with a percent', () {
      final card = productFromSearch(
        _search(<String, Object?>{
          'price': 90,
          'oldprice': 100,
          'oldprice_formatted': '100 ₽',
          'discount': 10,
        }),
      );
      expect(card.discount, '-10%');
    });

    test('a discount that already has its sign keeps exactly one', () {
      PersonalizationProduct card(String formatted) => productFromSearch(
        _search(<String, Object?>{
          'price': 90,
          'oldprice': 100,
          'oldprice_formatted': '100 ₽',
          'discount': 10,
          'discount_formatted': formatted,
        }),
      );
      expect(card('-10%').discount, '-10%');
      expect(card('--10%').discount, '-10%');
    });

    // Old price shown, the discount itself decides the badge.
    Map<String, Object?> discounted(Map<String, Object?> discount) =>
        <String, Object?>{
          'price': 90,
          'oldprice': 100,
          'oldprice_formatted': '100 ₽',
          ...discount,
        };

    test('a zero discount shows no badge, even formatted', () {
      final card = productFromSearch(
        _search(
          discounted(<String, Object?>{
            'discount': 0,
            'discount_formatted': '0%',
          }),
        ),
      );
      expect(card.oldPrice, '100 ₽');
      expect(card.discount, isNull);
    });

    test('a discount of true or garbage is no discount', () {
      for (final value in <Object>[true, false, 'abc']) {
        final card = productFromSearch(
          _search(discounted(<String, Object?>{'discount': value})),
        );
        expect(card.discount, isNull, reason: '$value');
      }
    });

    test('discount_percent stands in for a missing discount', () {
      final card = productFromSearch(
        _search(discounted(<String, Object?>{'discount_percent': '5'})),
      );
      expect(card.discount, '-5%');
    });

    test('a number in a string counts', () {
      final card = productFromCatalog(
        Product.fromJson(<String, dynamic>{
          'id': '1',
          'name': 'Item',
          ...discounted(<String, Object?>{'discount': '7'}),
        }),
      );
      expect(card.discount, '-7%');
    });

    test('no old price at or below the price, and then no discount', () {
      final card = productFromSearch(
        _search(<String, Object?>{
          'price': 100,
          'oldprice': 100,
          'oldprice_formatted': '100 ₽',
          'discount_formatted': '10%',
        }),
      );
      expect(card.oldPrice, isNull);
      expect(card.discount, isNull);
    });
  });

  group('picture, brand, links', () {
    test('the resized picture, else the original, else none', () {
      expect(
        _imageUrl(
          productFromSearch(
            _search(<String, Object?>{'picture': 'p', 'image_url': 'i'}),
          ).image,
        ),
        'p',
      );
      expect(
        _imageUrl(
          productFromSearch(_search(<String, Object?>{'image_url': 'i'})).image,
        ),
        'i',
      );
      expect(productFromSearch(_search(<String, Object?>{})).image, isNull);
    });

    test('an empty brand and url read as none', () {
      final card = productFromSearch(_search(<String, Object?>{}));
      expect(card.brand, isNull);
      expect(card.url, isNull);
      expect(card.rating, isNull);
    });

    test('the deeplink of the running platform', () {
      final product = _search(<String, Object?>{
        'url': 'https://shop/p/1',
        'deeplink_android': 'android://p/1',
        'deeplink_ios': 'ios://p/1',
      });
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(productFromSearch(product).deeplink, 'android://p/1');
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(productFromSearch(product).deeplink, 'ios://p/1');
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(productFromSearch(product).deeplink, isNull);
      expect(productFromSearch(product).url, 'https://shop/p/1');
    });
  });

  group('every product model maps the same way', () {
    test('a discounted recommendation', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final product = RecommendationResponse.fromJson(
        _fixture('recommend_extended'),
      ).products.first;
      final card = productFromRecommendation(product, actionText: 'Buy');
      expect(card.id, '52173');
      expect(card.brand, 'Beko');
      expect(card.price, '164 990 ₽');
      expect(card.oldPrice, '174 990 ₽');
      expect(card.discount, '-6%');
      expect(_imageUrl(card.image), contains('/resize-images/180/'));
      expect(
        card.deeplink,
        'https://www.technodom.kz/p/holodilnik-beko-rdsk-mw-52173',
      );
      expect(card.url, startsWith('https://www.technodom.kz/p/holodilnik'));
      expect(card.actionText, 'Buy');
    });

    test('catalog products, with and without a discount', () {
      final products = ProductsListResponse.fromJson(
        _fixture('products'),
      ).products;
      final plain = productFromCatalog(products[0]);
      final discounted = productFromCatalog(products[1]);
      expect(plain.price, '15 990 ₽');
      expect(plain.oldPrice, isNull);
      expect(plain.discount, isNull);
      expect(discounted.oldPrice, '174 990 ₽');
      expect(discounted.discount, '-6%');
      expect(_imageUrl(discounted.image), contains('/resize-images/180/'));
    });
  });
}
