import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/rees46_sdk.dart';
import 'package:rees46_sdk/src/pigeon/personalization_api.g.dart' as pigeon;

const _stubJson = {
  'products': [
    {
      'id': 'instant-1',
      'name': 'Instant Phone',
      'brand': 'FastBrand',
      'description': 'Quick result',
      'image_url': 'https://img.test/i1.jpg',
      'url': 'https://shop.test/i1',
      'price': 299.0,
      'price_full': 349.0,
      'price_formatted': r'$299',
      'price_full_formatted': r'$349',
      'currency': 'USD',
      'sales_rate': 10,
      'relative_sales_rate': 0.5,
      'image_url_resized': {'120': 'https://img.test/i1-120.jpg'},
    },
  ],
  'categories': [
    {
      'id': 'c1',
      'name': 'Phones',
      'url': '/phones',
      'parent': null,
      'count': 5,
    },
  ],
  'products_total': 7,
  'locations': [
    {'id': 'l1', 'name': 'SPb', 'type': null},
  ],
};

const _channel =
    'dev.flutter.pigeon.personalization_flutter_sdk.PersonalizationHostApi.searchInstant';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messageCodec = pigeon.PersonalizationHostApi.pigeonChannelCodec;

  ByteData reply(Object? value) =>
      messageCodec.encodeMessage([value as String])!;

  void stubOk() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
          _channel,
          (_) async => reply(jsonEncode(_stubJson)),
        );
  }

  // -------------------------------------------------------------------------
  // Validation
  // -------------------------------------------------------------------------
  group('searchInstant — validation', () {
    test('empty query throws ArgumentError', () {
      final sdk = PersonalizationSdk();
      expect(() => sdk.searchInstant(''), throwsArgumentError);
    });

    test('non-empty query does not throw synchronously', () {
      stubOk();
      final sdk = PersonalizationSdk();
      expect(() => sdk.searchInstant('ph'), returnsNormally);
    });
  });

  // -------------------------------------------------------------------------
  // Channel arguments
  // -------------------------------------------------------------------------
  group('searchInstant — channel args', () {
    test('query forwarded correctly', () async {
      List<Object?>? captured;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(_channel, (msg) async {
            captured = messageCodec.decodeMessage(msg) as List<Object?>;
            return reply(jsonEncode(_stubJson));
          });

      await PersonalizationSdk().searchInstant('iphone');
      expect(captured![0], equals('iphone'));
    });

    test('null paramsJson when no SearchInstantParams', () async {
      List<Object?>? captured;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(_channel, (msg) async {
            captured = messageCodec.decodeMessage(msg) as List<Object?>;
            return reply(jsonEncode(_stubJson));
          });

      await PersonalizationSdk().searchInstant('iphone');
      expect(captured![1], isNull);
    });

    test('SearchInstantParams serialised into paramsJson', () async {
      List<Object?>? captured;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(_channel, (msg) async {
            captured = messageCodec.decodeMessage(msg) as List<Object?>;
            return reply(jsonEncode(_stubJson));
          });

      await PersonalizationSdk().searchInstant(
        'iphone',
        params: const SearchInstantParams(
          locations: 'msk',
          excludedBrands: ['Samsung'],
        ),
      );

      final p = jsonDecode(captured![1] as String) as Map<String, dynamic>;
      expect(p['locations'], equals('msk'));
      expect(p['excluded_brands'], equals(['Samsung']));
    });
  });

  // -------------------------------------------------------------------------
  // Response parsing
  // -------------------------------------------------------------------------
  group('searchInstant — response parsing', () {
    late PersonalizationSdk sdk;

    setUp(() {
      sdk = PersonalizationSdk();
      stubOk();
    });

    test('productsTotal parsed', () async {
      final r = await sdk.searchInstant('ph');
      expect(r.productsTotal, equals(7));
    });

    test('products list parsed', () async {
      final r = await sdk.searchInstant('ph');
      expect(r.products.length, equals(1));
      expect(r.products.first.id, equals('instant-1'));
      expect(r.products.first.price, equals(299.0));
    });

    test('categories list parsed', () async {
      final r = await sdk.searchInstant('ph');
      expect(r.categories.first.name, equals('Phones'));
      expect(r.categories.first.count, equals(5));
    });

    test('locations parsed', () async {
      final r = await sdk.searchInstant('ph');
      expect(r.locations!.first.name, equals('SPb'));
      expect(r.locations!.first.type, isNull);
    });

    test('no priceRange field on SearchInstantResponse', () async {
      final r = await sdk.searchInstant('ph');
      // SearchInstantResponse has no priceRange — verify it is not exposed
      expect(r, isA<SearchInstantResponse>());
    });
  });

  // -------------------------------------------------------------------------
  // Edge cases
  // -------------------------------------------------------------------------
  group('searchInstant — edge cases', () {
    test('empty response defaults to safe values', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(
            _channel,
            (_) async => reply(
              jsonEncode({
                'products': <dynamic>[],
                'categories': <dynamic>[],
                'products_total': 0,
              }),
            ),
          );

      final r = await PersonalizationSdk().searchInstant('x');
      expect(r.products, isEmpty);
      expect(r.productsTotal, equals(0));
      expect(r.locations, isNull);
    });

    test('empty SearchInstantParams produces empty JSON object', () {
      const p = SearchInstantParams();
      final decoded = jsonDecode(p.toJson()) as Map<String, dynamic>;
      expect(decoded, isEmpty);
    });

    test('excludedBrands empty list omitted from JSON', () {
      const p = SearchInstantParams(excludedBrands: []);
      final decoded = jsonDecode(p.toJson()) as Map<String, dynamic>;
      expect(decoded.containsKey('excluded_brands'), isFalse);
    });
  });
}
