import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/rees46_sdk.dart';
import 'package:rees46_sdk/src/pigeon/personalization_api.g.dart' as pigeon;

const _stubJson = {
  'products': [
    {
      'id': 'blank-1',
      'name': 'Trending Product',
      'brand': 'Hot Brand',
      'description': 'Popular item',
      'image_url': 'https://img.test/b1.jpg',
      'url': 'https://shop.test/b1',
      'price': 499.0,
      'price_full': 599.0,
      'price_formatted': r'$499',
      'price_full_formatted': r'$599',
      'currency': 'USD',
      'sales_rate': 88,
      'relative_sales_rate': 0.9,
      'image_url_resized': {'120': 'https://img.test/b1-120.jpg'},
    },
  ],
  'suggests': [
    {'name': 'phones', 'url': '/search?q=phones'},
    {'name': 'laptops', 'url': '/search?q=laptops'},
  ],
};

const _channel =
    'dev.flutter.pigeon.personalization_flutter_sdk.PersonalizationHostApi.searchBlank';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messageCodec = pigeon.PersonalizationHostApi.pigeonChannelCodec;

  ByteData reply(String value) => messageCodec.encodeMessage([value])!;

  void stubOk() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
          _channel,
          (_) async => reply(jsonEncode(_stubJson)),
        );
  }

  // -------------------------------------------------------------------------
  // Response parsing
  // -------------------------------------------------------------------------
  group('searchBlank — response parsing', () {
    late PersonalizationSdk sdk;

    setUp(() {
      sdk = PersonalizationSdk();
      stubOk();
    });

    test('products list parsed correctly', () async {
      final r = await sdk.searchBlank();
      expect(r.products.length, equals(1));
      final p = r.products.first;
      expect(p.id, equals('blank-1'));
      expect(p.name, equals('Trending Product'));
      expect(p.price, equals(499.0));
      expect(p.salesRate, equals(88));
      expect(p.resizedImages['120'], equals('https://img.test/b1-120.jpg'));
    });

    test('suggests list parsed correctly', () async {
      final r = await sdk.searchBlank();
      expect(r.suggests.length, equals(2));
      expect(r.suggests.first.name, equals('phones'));
      expect(r.suggests.first.url, equals('/search?q=phones'));
      expect(r.suggests.last.name, equals('laptops'));
    });

    test('returns SearchBlankResponse type', () async {
      final r = await sdk.searchBlank();
      expect(r, isA<SearchBlankResponse>());
    });
  });

  // -------------------------------------------------------------------------
  // Edge cases
  // -------------------------------------------------------------------------
  group('searchBlank — edge cases', () {
    test('empty products and suggests default to empty lists', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(
            _channel,
            (_) async => reply(
              jsonEncode({'products': <dynamic>[], 'suggests': <dynamic>[]}),
            ),
          );

      final r = await PersonalizationSdk().searchBlank();
      expect(r.products, isEmpty);
      expect(r.suggests, isEmpty);
    });

    test('missing keys default to empty lists', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(
            _channel,
            (_) async => reply(jsonEncode(<String, dynamic>{})),
          );

      final r = await PersonalizationSdk().searchBlank();
      expect(r.products, isEmpty);
      expect(r.suggests, isEmpty);
    });

    test('iOS-only fields in JSON are silently ignored', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(
            _channel,
            (_) async => reply(
              jsonEncode({
                'products': <dynamic>[],
                'suggests': [
                  {
                    'name': 'shoes',
                    'url': '/search?q=shoes',
                    'deeplink_ios': 'myapp://search?q=shoes', // iOS-only
                  },
                ],
                'last_queries': <dynamic>[], // iOS-only
                'last_products': true, // iOS-only
              }),
            ),
          );

      final r = await PersonalizationSdk().searchBlank();
      expect(r.suggests.first.name, equals('shoes'));
      expect(r.suggests.first.url, equals('/search?q=shoes'));
      // No crash from extra iOS fields.
    });
  });
}
