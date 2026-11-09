import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/rees46_sdk.dart';

// Recommendations and categories reach Dart re-serialized by the bridges, not as the raw
// API answer. These samples rebuild the live answers (test/fixtures) the way each bridge
// does it today:
// - Android: Gson of the native models of android-sdk v2.45.0, the version the plugin
//   pins. Its Product has no deeplink_android, deeplink_ios or discount_percent, so they
//   stay null until a native release with them is pinned.
// - iOS: the dictionaries of Rees46FlutterSdkPlugin.swift over REES46 3.35.0. Recommended
//   has no discount_formatted, discount_percent, deeplink_android or is_new; the category
//   product has no old price, discount, app links or is_new, and the category no filters
//   or price range. They stay null until a native release with them, plus the matching
//   lines in the Swift bridge.

Map<String, dynamic> _fixture(String name) =>
    jsonDecode(File('test/fixtures/$name.json').readAsStringSync())
        as Map<String, dynamic>;

/// Fields of the Android `Product` (v2.45.0) that Gson writes back out.
const Set<String> _androidProductKeys = <String>{
  'brand', 'categories', 'category_ids', 'location_ids', 'currency', //
  'description', '_id', 'id', 'image_url', 'image_url_handle', //
  'image_url_resized', 'name', 'picture', 'price', 'price_formatted', //
  'price_full', 'price_full_formatted', 'relative_sales_rate', 'sales_rate', //
  'url', 'url_handle', 'oldprice', 'oldprice_formatted', 'discount', //
  'discount_formatted', 'is_new',
};

/// [keys] of [raw] as Gson writes them: absent and `null` fields are left out.
Map<String, dynamic> _gson(Map<String, dynamic> raw, Set<String> keys) =>
    <String, dynamic>{
      for (final key in keys)
        if (raw[key] != null) key: raw[key],
    };

Map<String, dynamic> _androidProduct(dynamic raw) =>
    _gson(raw as Map<String, dynamic>, _androidProductKeys);

/// `_productToDict(Recommended)` of the iOS bridge.
Map<String, dynamic> _iosRecommended(dynamic product) {
  final raw = product as Map<String, dynamic>;
  double number(String key) => (raw[key] as num?)?.toDouble() ?? 0;
  final oldPrice = number('oldprice');
  final discount = raw['discount'] is int ? raw['discount'] as int : 0;
  final deeplink = raw['deeplink_ios'] as String? ?? '';
  return <String, dynamic>{
    for (final key in <String>['id', 'name', 'brand', 'description'])
      key: raw[key] ?? '',
    'image_url': raw['image_url'] ?? '',
    'picture': raw['picture'] ?? '',
    'image_url_resized': raw['image_url_resized'] ?? <String, String>{},
    'url': raw['url'] ?? '',
    'price': number('price'),
    'price_full': number('price_full'),
    'currency': raw['currency'] ?? '',
    'sales_rate': raw['sales_rate'] ?? 0,
    'relative_sales_rate': raw['relative_sales_rate'] ?? 0,
    'categories': <Object>[],
    if (raw['price_formatted'] != null)
      'price_formatted': raw['price_formatted'],
    if (raw['price_full_formatted'] != null)
      'price_full_formatted': raw['price_full_formatted'],
    if (oldPrice > 0) 'oldprice': oldPrice,
    if ((raw['oldprice_formatted'] as String? ?? '').isNotEmpty)
      'oldprice_formatted': raw['oldprice_formatted'],
    if (discount > 0) 'discount': discount,
    if (deeplink.isNotEmpty) 'deeplink_ios': deeplink,
  };
}

/// `_categoryProductToDict(CategoryProduct)` of the iOS bridge.
Map<String, dynamic> _iosCategoryProduct(dynamic product) {
  final raw = product as Map<String, dynamic>;
  return <String, dynamic>{
    for (final key in <String>[
      'id', 'name', 'brand', 'price', 'price_formatted', 'price_full', //
      'price_full_formatted', 'currency', 'image_url', 'url', 'picture',
    ])
      if (raw[key] != null) key: raw[key],
  };
}

void main() {
  final recommend = _fixture('recommend_extended');
  final category = _fixture('category');

  group('recommendation, Android bridge (Gson, v2.45.0)', () {
    final response = RecommendationResponse.fromJson(<String, dynamic>{
      'html': '',
      'id': recommend['id'],
      'title': recommend['title'],
      'recommends': (recommend['recommends'] as List)
          .map(_androidProduct)
          .toList(),
    });

    test('old price and discount, with the display form', () {
      final product = response.products.first;
      expect(product.oldPrice, 174990);
      expect(product.oldPriceFormatted, '174 990 ₽');
      expect(product.discount, 6);
      expect(product.discountFormatted, '6%');
      expect(product.resizedImageUrl, contains('/resize-images/180/'));
    });

    test('app links and discount_percent wait for a native release', () {
      for (final product in response.products) {
        expect(product.deeplinkAndroid, isNull);
        expect(product.deeplinkIos, isNull);
        expect(product.discountPercent, isNull);
      }
    });
  });

  group('recommendation, iOS bridge (REES46 3.35.0)', () {
    final response = RecommendationResponse.fromJson(<String, dynamic>{
      'title': recommend['title'],
      'recommends': (recommend['recommends'] as List)
          .map(_iosRecommended)
          .toList(),
    });

    test('old price, discount and the iOS app link', () {
      final product = response.products.first;
      expect(product.oldPrice, 174990);
      expect(product.oldPriceFormatted, '174 990 ₽');
      expect(product.discount, 6);
      expect(
        product.deeplinkIos,
        'https://www.technodom.kz/p/holodilnik-beko-rdsk-mw-52173',
      );
    });

    test('a product without a discount sends none of it', () {
      final product = response.products[1];
      expect(product.oldPrice, isNull);
      expect(product.oldPriceFormatted, isNull);
      expect(product.discount, isNull);
    });

    test('the display form, discount_percent, deeplink_android and is_new wait '
        'for a native release', () {
      final product = response.products.first;
      expect(product.discountFormatted, isNull);
      expect(product.discountPercent, isNull);
      expect(product.deeplinkAndroid, isNull);
      expect(product.isNew, isNull);
    });
  });

  group('category, Android bridge (Gson, v2.45.0)', () {
    final response = CategoryResponse.fromJson(<String, dynamic>{
      ..._gson(category, <String>{
        'products_total', 'brands', 'categories', 'price_range', //
        'price_ranges', 'price_median', 'filters',
      }),
      'products': (category['products'] as List).map(_androidProduct).toList(),
    });

    test('facets come through', () {
      expect(response.productsTotal, 2320);
      expect(response.brands, <String>['A-Case', 'ACEFAST', 'AULA']);
      expect(response.filters['NFC']!.values, <String, int>{'Нет': 6});
      expect(response.priceRange!.max, 1863890);
    });

    test('products keep the picture; app links wait for a native release', () {
      for (final product in response.products) {
        expect(product.picture, isNotNull);
        expect(product.deeplinkAndroid, isNull);
        expect(product.deeplinkIos, isNull);
        expect(product.discountPercent, isNull);
      }
    });
  });

  group('category, iOS bridge (REES46 3.35.0)', () {
    final response = CategoryResponse.fromJson(<String, dynamic>{
      'products_total': category['products_total'],
      'products': (category['products'] as List)
          .map(_iosCategoryProduct)
          .toList(),
      'brands': category['brands'],
    });

    test('brands come through; filters and price range wait', () {
      expect(response.brands, <String>['A-Case', 'ACEFAST', 'AULA']);
      expect(response.filters, isEmpty);
      expect(response.priceRange, isNull);
    });

    test('products carry price and picture; the rest waits', () {
      final product = response.products.first;
      expect(product.price, 15990);
      expect(product.priceFormatted, '15 990 ₽');
      expect(product.picture, isNotNull);
      expect(product.oldPrice, isNull);
      expect(product.discount, isNull);
      expect(product.deeplinkIos, isNull);
      expect(product.isNew, isNull);
    });
  });
}
