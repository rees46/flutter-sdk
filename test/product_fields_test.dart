import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/rees46_sdk.dart';

/// Live API answers (shop c1140c…, api.rees46.ru) as the Android bridge passes them on
/// for the raw-JSON methods.
Map<String, dynamic> _fixture(String name) =>
    jsonDecode(File('test/fixtures/$name.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  group('recommendation (recommends, extended=1)', () {
    final response = RecommendationResponse.fromJson(
      _fixture('recommend_extended'),
    );

    test('a discounted product carries the old price and the discount', () {
      final product = response.products.first;
      expect(product.id, '52173');
      expect(product.oldPrice, 174990);
      expect(product.oldPriceFormatted, '174 990 ₽');
      expect(product.discount, 6);
      expect(product.discountFormatted, '6%');
      expect(product.discountPercent, 5);
      expect(product.isNew, isNull);
    });

    test('a product without a discount has none of the discount fields', () {
      final product = response.products[1];
      expect(product.oldPrice, isNull);
      expect(product.oldPriceFormatted, isNull);
      expect(product.discount, isNull);
      expect(product.discountFormatted, isNull);
      expect(product.discountPercent, isNull);
    });

    test('app links and the resized picture', () {
      final product = response.products[1];
      expect(
        product.deeplinkAndroid,
        'https://www.technodom.kz/p/naushniki-nakladnye-honor-choice-headphones-lite-gray-5504adgf-300252',
      );
      expect(product.deeplinkIos, product.deeplinkAndroid);
      expect(product.resizedImageUrl, contains('/resize-images/180/'));
    });
  });

  group('products list', () {
    final response = ProductsListResponse.fromJson(_fixture('products'));

    test('facets: brands, filters, price range', () {
      expect(response.productsTotal, 10000);
      expect(response.brands, <String>['1STPLAYER', '2E', '70mai']);
      expect(response.filters.keys, hasLength(3));
      expect(response.filters['AC гнезда']!.count, 1);
      expect(response.filters['AC гнезда']!.values, <String, int>{'4': 1});
      expect(response.priceRange!.min, 10);
      expect(response.priceRange!.max, 8000000);
    });

    test('a discounted product and one without a discount', () {
      final plain = response.products[0];
      final discounted = response.products[1];
      expect(plain.oldPrice, isNull);
      expect(plain.discount, isNull);
      expect(plain.discountPercent, isNull);
      expect(discounted.oldPrice, 174990);
      expect(discounted.oldPriceFormatted, '174 990 ₽');
      expect(discounted.discount, 6);
      expect(discounted.discountFormatted, '6%');
      expect(discounted.discountPercent, 5);
      expect(discounted.picture, contains('/resize-images/180/'));
      expect(
        discounted.deeplinkAndroid,
        'https://www.technodom.kz/p/holodilnik-beko-rdsk-mw-52173',
      );
      expect(discounted.deeplinkIos, discounted.deeplinkAndroid);
    });

    test('iOS bridge shape: brands as plain names', () {
      final ios = ProductsListResponse.fromJson(<String, dynamic>{
        'products': <Object>[],
        'products_total': 0,
        'brands': <String>['Apple', ''],
        'filters': <String, Object>{
          'color': <String, Object>{
            'count': 2,
            'values': <String, int>{'red': 2},
          },
        },
      });
      expect(ios.brands, <String>['Apple']);
      expect(ios.filters['color']!.values, <String, int>{'red': 2});
    });

    test('a response without facets keeps them empty', () {
      final bare = ProductsListResponse.fromJson(<String, dynamic>{
        'products': <Object>[],
        'products_total': 0,
      });
      expect(bare.brands, isEmpty);
      expect(bare.filters, isEmpty);
    });
  });

  group('category', () {
    final response = CategoryResponse.fromJson(_fixture('category'));

    test('facets: brands, filters, price range', () {
      expect(response.productsTotal, 2320);
      expect(response.brands, <String>['A-Case', 'ACEFAST', 'AULA']);
      expect(response.filters['NFC']!.count, 6);
      expect(response.filters['NFC']!.values, <String, int>{'Нет': 6});
      expect(response.priceRange!.min, 190);
      expect(response.priceRange!.max, 1863890);
    });

    test('products without a discount, with app links', () {
      for (final product in response.products) {
        expect(product.oldPrice, isNull);
        expect(product.discount, isNull);
        expect(product.deeplinkAndroid, isNotNull);
        expect(product.deeplinkIos, isNotNull);
        expect(product.picture, isNotNull);
      }
    });

    test('a category without facets (an older native) keeps them empty', () {
      final bare = CategoryResponse.fromJson(<String, dynamic>{
        'products_total': 0,
        'products': <Object>[],
      });
      expect(bare.brands, isEmpty);
      expect(bare.filters, isEmpty);
      expect(bare.priceRange, isNull);
    });
  });

  group('product info', () {
    final product = Product.fromJson(_fixture('product_info'));

    test('discount `false` reads as no discount', () {
      expect(product.id, '868');
      expect(product.discount, isNull);
      expect(product.oldPrice, isNull);
      expect(product.oldPriceFormatted, isNull);
    });

    test('app links, picture and the price string', () {
      expect(
        product.deeplinkAndroid,
        'https://www.technodom.kz/p/garnitura-nakladnaa-logitech-h-white-868',
      );
      expect(product.deeplinkIos, product.deeplinkAndroid);
      expect(product.picture, startsWith('https://'));
      expect(product.price, 14990);
    });
  });

  group('search full', () {
    final response = SearchFullResponse.fromJson(_fixture('search_full'));

    test('products carry app links, no discount', () {
      final product = response.products.first;
      expect(
        product.deeplinkAndroid,
        'https://www.technodom.kz/p/stiralnaya-mashina-samsung-ww60ak4s00celt-292523',
      );
      expect(product.deeplinkIos, product.deeplinkAndroid);
      expect(product.discountPercent, isNull);
      expect(product.isNew, isNull);
      expect(product.oldPrice, 0);
    });

    test('facets still parse', () {
      expect(response.brands.first, 'Samsung');
      expect(response.filters['merchant']!.values, <String, int>{
        'Technodom': 833,
      });
    });
  });

  group('bridge tolerance', () {
    Product product(Map<String, Object?> extra) => Product.fromJson(
      <String, dynamic>{'id': '1', 'name': 'Item', ...extra},
    );

    test('is_new as a bool, a number or a string', () {
      expect(product(<String, Object?>{'is_new': true}).isNew, isTrue);
      expect(product(<String, Object?>{'is_new': 0}).isNew, isFalse);
      expect(product(<String, Object?>{'is_new': 'true'}).isNew, isTrue);
      expect(product(<String, Object?>{'is_new': 'x'}).isNew, isNull);
    });

    test('empty strings from the iOS models read as absent', () {
      final p = product(<String, Object?>{
        'deeplink_ios': '',
        'oldprice_formatted': '',
        'picture': '',
      });
      expect(p.deeplinkIos, isNull);
      expect(p.oldPriceFormatted, isNull);
      expect(p.picture, isNull);
    });

    test('numbers as strings', () {
      final p = product(<String, Object?>{
        'oldprice': '199.5',
        'discount': '10',
        'discount_percent': 9,
      });
      expect(p.oldPrice, 199.5);
      expect(p.discount, 10);
      expect(p.discountPercent, 9);
    });

    test('search products read the new fields too', () {
      final p = SearchProduct.fromJson(<String, dynamic>{
        'id': '1',
        'deeplink_ios': 'app://p/1',
        'is_new': true,
        'discount_percent': 12,
      });
      expect(p.deeplinkIos, 'app://p/1');
      expect(p.deeplinkAndroid, isNull);
      expect(p.isNew, isTrue);
      expect(p.discountPercent, 12);
    });
  });
}
