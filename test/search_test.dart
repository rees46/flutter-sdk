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
      'name': 'Test Phone',
      'brand': 'Brand X',
      'description': 'A great phone',
      'image_url': 'https://img.test/1.jpg',
      'url': 'https://shop.test/1',
      'price': 199.99,
      'price_full': 249.99,
      'price_formatted': r'$199.99',
      'price_full_formatted': r'$249.99',
      'currency': 'USD',
      'sales_rate': 42,
      'relative_sales_rate': 0.75,
      'image_url_resized': {
        '120': 'https://img.test/120.jpg',
        '520': 'https://img.test/520.jpg',
      },
    },
  ],
  'categories': [
    {
      'id': 'cat-1',
      'name': 'Electronics',
      'url': '/electronics',
      'parent': 'root',
      'count': 150,
    },
  ],
  'products_total': 42,
  'price_range': {'min': 99.0, 'max': 9999.0},
  'locations': [
    {'id': 'loc-1', 'name': 'Moscow', 'type': 'city'},
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ByteData Function(String) codec;
  final messageCodec = pigeon.PersonalizationHostApi.pigeonChannelCodec;

  setUp(() {
    codec = (String json) => messageCodec.encodeMessage([json])!;
  });

  void stubSearchFull(Object? result) {
    const channel =
        'dev.flutter.pigeon.personalization_flutter_sdk.PersonalizationHostApi.searchFull';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
          channel,
          (_) async => codec(jsonEncode(_stubJson)),
        );
    if (result != null) {
      // Override with custom response.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(channel, (_) async => codec(result as String));
    }
  }

  // -------------------------------------------------------------------------
  // Validation
  // -------------------------------------------------------------------------
  group('searchFull — validation', () {
    test('empty query throws ArgumentError', () {
      final sdk = PersonalizationSdk();
      expect(() => sdk.searchFull(''), throwsArgumentError);
    });

    test('non-empty query does not throw synchronously', () {
      final sdk = PersonalizationSdk();
      stubSearchFull(null);
      expect(() => sdk.searchFull('phone'), returnsNormally);
    });
  });

  // -------------------------------------------------------------------------
  // Channel arguments
  // -------------------------------------------------------------------------
  group('searchFull — channel args', () {
    test('query is forwarded as-is', () async {
      List<Object?>? captured;
      const channel =
          'dev.flutter.pigeon.personalization_flutter_sdk.PersonalizationHostApi.searchFull';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(channel, (msg) async {
            captured = messageCodec.decodeMessage(msg) as List<Object?>;
            return codec(jsonEncode(_stubJson));
          });

      final sdk = PersonalizationSdk();
      await sdk.searchFull('laptop');
      expect(captured![0], equals('laptop'));
    });

    test('null paramsJson when no SearchParams supplied', () async {
      List<Object?>? captured;
      const channel =
          'dev.flutter.pigeon.personalization_flutter_sdk.PersonalizationHostApi.searchFull';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(channel, (msg) async {
            captured = messageCodec.decodeMessage(msg) as List<Object?>;
            return codec(jsonEncode(_stubJson));
          });

      final sdk = PersonalizationSdk();
      await sdk.searchFull('laptop');
      expect(captured![1], isNull);
    });

    test('SearchParams serialised into paramsJson', () async {
      List<Object?>? captured;
      const channel =
          'dev.flutter.pigeon.personalization_flutter_sdk.PersonalizationHostApi.searchFull';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(channel, (msg) async {
            captured = messageCodec.decodeMessage(msg) as List<Object?>;
            return codec(jsonEncode(_stubJson));
          });

      final sdk = PersonalizationSdk();
      await sdk.searchFull(
        'phone',
        params: const SearchParams(
          limit: 20,
          page: 2,
          sortBy: 'price',
          sortDir: 'asc',
          priceMin: 100.0,
          priceMax: 5000.0,
          categories: ['1', '2'],
          colors: ['red', 'blue'],
        ),
      );

      final paramsStr = captured![1] as String;
      final params = jsonDecode(paramsStr) as Map<String, dynamic>;
      expect(params['limit'], equals(20));
      expect(params['page'], equals(2));
      expect(params['sort_by'], equals('price'));
      expect(params['sort_dir'], equals('asc'));
      expect(params['price_min'], equals(100.0));
      expect(params['price_max'], equals(5000.0));
      expect(params['categories'], equals(['1', '2']));
      expect(params['colors'], equals(['red', 'blue']));
    });
  });

  // -------------------------------------------------------------------------
  // Response parsing
  // -------------------------------------------------------------------------
  group('searchFull — response parsing', () {
    late PersonalizationSdk sdk;

    setUp(() {
      sdk = PersonalizationSdk();
      stubSearchFull(null);
    });

    test('productsTotal parsed correctly', () async {
      final r = await sdk.searchFull('phone');
      expect(r.productsTotal, equals(42));
    });

    test('products list parsed correctly', () async {
      final r = await sdk.searchFull('phone');
      expect(r.products.length, equals(1));
      final p = r.products.first;
      expect(p.id, equals('prod-1'));
      expect(p.name, equals('Test Phone'));
      expect(p.brand, equals('Brand X'));
      expect(p.price, equals(199.99));
      expect(p.currency, equals('USD'));
      expect(p.salesRate, equals(42));
      expect(p.resizedImages['120'], equals('https://img.test/120.jpg'));
    });

    test('categories list parsed correctly', () async {
      final r = await sdk.searchFull('phone');
      expect(r.categories.length, equals(1));
      final c = r.categories.first;
      expect(c.id, equals('cat-1'));
      expect(c.name, equals('Electronics'));
      expect(c.parentId, equals('root'));
      expect(c.count, equals(150));
    });

    test('priceRange parsed correctly', () async {
      final r = await sdk.searchFull('phone');
      expect(r.priceRange, isNotNull);
      expect(r.priceRange!.min, equals(99.0));
      expect(r.priceRange!.max, equals(9999.0));
    });

    test('locations parsed correctly', () async {
      final r = await sdk.searchFull('phone');
      expect(r.locations, isNotNull);
      expect(r.locations!.length, equals(1));
      final loc = r.locations!.first;
      expect(loc.id, equals('loc-1'));
      expect(loc.name, equals('Moscow'));
      expect(loc.type, equals('city'));
    });
  });

  // -------------------------------------------------------------------------
  // Edge cases
  // -------------------------------------------------------------------------
  group('searchFull — edge cases', () {
    test('missing optional fields default to safe values', () async {
      const channel =
          'dev.flutter.pigeon.personalization_flutter_sdk.PersonalizationHostApi.searchFull';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(
            channel,
            (_) async => codec(
              jsonEncode({
                'products': <dynamic>[],
                'categories': <dynamic>[],
                'products_total': 0,
              }),
            ),
          );

      final sdk = PersonalizationSdk();
      final r = await sdk.searchFull('phone');
      expect(r.products, isEmpty);
      expect(r.categories, isEmpty);
      expect(r.productsTotal, equals(0));
      expect(r.priceRange, isNull);
      expect(r.locations, isNull);
    });

    test('product with null optional fields is parsed without error', () async {
      const channel =
          'dev.flutter.pigeon.personalization_flutter_sdk.PersonalizationHostApi.searchFull';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(
            channel,
            (_) async => codec(
              jsonEncode({
                'products': [
                  {
                    'id': 'x',
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
                'categories': <dynamic>[],
                'products_total': 1,
              }),
            ),
          );

      final sdk = PersonalizationSdk();
      final r = await sdk.searchFull('x');
      expect(r.products.first.priceFormatted, isNull);
      expect(r.products.first.resizedImages, isEmpty);
    });

    test('empty SearchParams sends empty JSON object', () {
      const p = SearchParams();
      final decoded = jsonDecode(p.toJson()) as Map<String, dynamic>;
      expect(decoded, isEmpty);
    });

    test('SearchParams with empty lists omits those keys', () {
      const p = SearchParams(categories: [], colors: []);
      final decoded = jsonDecode(p.toJson()) as Map<String, dynamic>;
      expect(decoded.containsKey('categories'), isFalse);
      expect(decoded.containsKey('colors'), isFalse);
    });
  });
}
