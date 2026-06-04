import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personalization_flutter_sdk/personalization_flutter_sdk.dart';
import 'package:personalization_flutter_sdk/src/pigeon/personalization_api.g.dart'
    as pigeon;

const _stubJson = {
  'products': [
    {
      'id': 'prod-1',
      'name': 'Test Product',
      'brand': 'Test Brand',
      'description': 'A test product',
      'image_url': 'https://img.test/1.jpg',
      'image_url_resized': {'120': 'https://img.test/120.jpg'},
      'url': 'https://shop.test/1',
      'price': 299.0,
      'price_full': 399.0,
      'price_formatted': r'$299',
      'price_full_formatted': r'$399',
      'currency': 'USD',
      'sales_rate': 55,
      'relative_sales_rate': 0.6,
      'categories': [
        {
          'id': 'c1',
          'name': 'Electronics',
          'parent_id': null,
          'url': '/electronics',
        },
      ],
    },
  ],
  'products_total': 42,
  'price_range': {'min': 100.0, 'max': 9999.0},
};

const _channel =
    'dev.flutter.pigeon.personalization_flutter_sdk.PersonalizationHostApi.getProductsList';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messageCodec = pigeon.PersonalizationHostApi.pigeonChannelCodec;

  ByteData reply(String value) => messageCodec.encodeMessage([value])!;

  void stubOk([Map<String, dynamic>? json]) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
          _channel,
          (_) async => reply(jsonEncode(json ?? _stubJson)),
        );
  }

  // -------------------------------------------------------------------------
  // Channel arguments
  // -------------------------------------------------------------------------
  group('getProductsList — channel args', () {
    test('null paramsJson when no ProductsListParams', () async {
      List<Object?>? captured;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(_channel, (msg) async {
            captured = messageCodec.decodeMessage(msg) as List<Object?>;
            return reply(jsonEncode(_stubJson));
          });

      await PersonalizationSdk().getProductsList();
      expect(captured![0], isNull);
    });

    test('params serialised into paramsJson', () async {
      List<Object?>? captured;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(_channel, (msg) async {
            captured = messageCodec.decodeMessage(msg) as List<Object?>;
            return reply(jsonEncode(_stubJson));
          });

      await PersonalizationSdk().getProductsList(
        params: const ProductsListParams(
          brands: 'Apple,Samsung',
          limit: 20,
          page: 2,
          categories: '1,2,3',
        ),
      );

      final p = jsonDecode(captured![0] as String) as Map<String, dynamic>;
      expect(p['brands'], equals('Apple,Samsung'));
      expect(p['limit'], equals(20));
      expect(p['page'], equals(2));
      expect(p['categories'], equals('1,2,3'));
    });

    test('filters serialised correctly', () async {
      List<Object?>? captured;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(_channel, (msg) async {
            captured = messageCodec.decodeMessage(msg) as List<Object?>;
            return reply(jsonEncode(_stubJson));
          });

      await PersonalizationSdk().getProductsList(
        params: const ProductsListParams(
          filters: {
            'color': ['red', 'blue'],
            'size': ['M', 'L'],
          },
        ),
      );

      final p = jsonDecode(captured![0] as String) as Map<String, dynamic>;
      final filters = p['filters'] as Map<String, dynamic>;
      expect(filters['color'], equals(['red', 'blue']));
      expect(filters['size'], equals(['M', 'L']));
    });
  });

  // -------------------------------------------------------------------------
  // Response parsing
  // -------------------------------------------------------------------------
  group('getProductsList — response parsing', () {
    late PersonalizationSdk sdk;

    setUp(() {
      sdk = PersonalizationSdk();
      stubOk();
    });

    test('productsTotal parsed', () async {
      final r = await sdk.getProductsList();
      expect(r.productsTotal, equals(42));
    });

    test('product fields parsed correctly', () async {
      final r = await sdk.getProductsList();
      expect(r.products.length, equals(1));
      final p = r.products.first;
      expect(p.id, equals('prod-1'));
      expect(p.name, equals('Test Product'));
      expect(p.brand, equals('Test Brand'));
      expect(p.price, equals(299.0));
      expect(p.priceFull, equals(399.0));
      expect(p.currency, equals('USD'));
      expect(p.salesRate, equals(55));
      expect(p.resizedImages['120'], equals('https://img.test/120.jpg'));
    });

    test('product categories parsed', () async {
      final r = await sdk.getProductsList();
      final cats = r.products.first.categories;
      expect(cats.length, equals(1));
      expect(cats.first.id, equals('c1'));
      expect(cats.first.name, equals('Electronics'));
    });

    test('priceRange parsed', () async {
      final r = await sdk.getProductsList();
      expect(r.priceRange, isNotNull);
      expect(r.priceRange!.min, equals(100.0));
      expect(r.priceRange!.max, equals(9999.0));
    });
  });

  // -------------------------------------------------------------------------
  // Edge cases
  // -------------------------------------------------------------------------
  group('getProductsList — edge cases', () {
    test('empty response defaults to safe values', () async {
      stubOk({'products': <dynamic>[], 'products_total': 0});
      final r = await PersonalizationSdk().getProductsList();
      expect(r.products, isEmpty);
      expect(r.productsTotal, equals(0));
      expect(r.priceRange, isNull);
    });

    test('missing keys default to empty list and zero', () async {
      stubOk(<String, dynamic>{});
      final r = await PersonalizationSdk().getProductsList();
      expect(r.products, isEmpty);
      expect(r.productsTotal, equals(0));
    });

    test('empty ProductsListParams serialises to empty JSON', () {
      const p = ProductsListParams();
      final decoded = jsonDecode(p.toJson()) as Map<String, dynamic>;
      expect(decoded, isEmpty);
    });

    test('empty filters map omitted from JSON', () {
      const p = ProductsListParams(filters: {});
      final decoded = jsonDecode(p.toJson()) as Map<String, dynamic>;
      expect(decoded.containsKey('filters'), isFalse);
    });

    test('iOS-style uniqid field NOT used — id expected', () async {
      stubOk({
        'products': [
          {
            'id': 'correct-id',
            'uniqid': 'wrong-id',
            'name': 'X',
            'brand': '',
            'description': '',
            'image_url': '',
            'url': '',
            'price': 0,
            'price_full': 0,
            'currency': '',
            'sales_rate': 0,
            'relative_sales_rate': 0,
          },
        ],
        'products_total': 1,
      });
      final r = await PersonalizationSdk().getProductsList();
      expect(r.products.first.id, equals('correct-id'));
    });
  });
}
