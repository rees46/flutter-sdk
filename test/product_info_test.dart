import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/rees46_sdk.dart';
import 'package:rees46_sdk/src/pigeon/personalization_api.g.dart' as pigeon;

const _stubJson = {
  'id': 'item-42',
  'name': 'Pro Widget',
  'brand': 'Widgetco',
  'description': 'The best widget',
  'image_url': 'https://img.test/42.jpg',
  'image_url_resized': {
    '120': 'https://img.test/42-120.jpg',
    '520': 'https://img.test/42-520.jpg',
  },
  'url': 'https://shop.test/42',
  'price': 149.99,
  'price_full': 199.99,
  'price_formatted': r'$149.99',
  'price_full_formatted': r'$199.99',
  'currency': 'USD',
  'sales_rate': 73,
  'relative_sales_rate': 0.8,
  'categories': [
    {'id': 'c1', 'name': 'Widgets', 'parent_id': null, 'url': '/widgets'},
  ],
};

const _channel =
    'dev.flutter.pigeon.personalization_flutter_sdk.PersonalizationHostApi.getProductInfo';

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
  // Validation
  // -------------------------------------------------------------------------
  group('getProductInfo — validation', () {
    test('empty itemId throws ArgumentError', () {
      final sdk = PersonalizationSdk();
      expect(() => sdk.getProductInfo(''), throwsArgumentError);
    });

    test('non-empty itemId does not throw synchronously', () {
      stubOk();
      expect(
        () => PersonalizationSdk().getProductInfo('item-1'),
        returnsNormally,
      );
    });
  });

  // -------------------------------------------------------------------------
  // Channel arguments
  // -------------------------------------------------------------------------
  group('getProductInfo — channel args', () {
    test('itemId forwarded correctly', () async {
      List<Object?>? captured;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(_channel, (msg) async {
            captured = messageCodec.decodeMessage(msg) as List<Object?>;
            return reply(jsonEncode(_stubJson));
          });

      await PersonalizationSdk().getProductInfo('item-99');
      expect(captured![0], equals('item-99'));
    });
  });

  // -------------------------------------------------------------------------
  // Response parsing
  // -------------------------------------------------------------------------
  group('getProductInfo — response parsing', () {
    late PersonalizationSdk sdk;

    setUp(() {
      sdk = PersonalizationSdk();
      stubOk();
    });

    test('returns Product type', () async {
      final p = await sdk.getProductInfo('item-42');
      expect(p, isA<Product>());
    });

    test('all fields parsed correctly', () async {
      final p = await sdk.getProductInfo('item-42');
      expect(p.id, equals('item-42'));
      expect(p.name, equals('Pro Widget'));
      expect(p.brand, equals('Widgetco'));
      expect(p.description, equals('The best widget'));
      expect(p.imageUrl, equals('https://img.test/42.jpg'));
      expect(p.url, equals('https://shop.test/42'));
      expect(p.price, equals(149.99));
      expect(p.priceFull, equals(199.99));
      expect(p.priceFormatted, equals(r'$149.99'));
      expect(p.currency, equals('USD'));
      expect(p.salesRate, equals(73));
      expect(p.relativeSalesRate, equals(0.8));
    });

    test('resizedImages parsed', () async {
      final p = await sdk.getProductInfo('item-42');
      expect(p.resizedImages['120'], equals('https://img.test/42-120.jpg'));
      expect(p.resizedImages['520'], equals('https://img.test/42-520.jpg'));
    });

    test('categories parsed', () async {
      final p = await sdk.getProductInfo('item-42');
      expect(p.categories.length, equals(1));
      expect(p.categories.first.id, equals('c1'));
      expect(p.categories.first.name, equals('Widgets'));
    });
  });

  // -------------------------------------------------------------------------
  // Edge cases
  // -------------------------------------------------------------------------
  group('getProductInfo — edge cases', () {
    test('minimal JSON with only required fields does not throw', () async {
      stubOk({
        'id': 'x',
        'name': '',
        'brand': '',
        'description': '',
        'image_url': '',
        'url': '',
        'price': 0,
        'price_full': 0,
        'currency': '',
        'sales_rate': 0,
        'relative_sales_rate': 0,
      });
      final p = await PersonalizationSdk().getProductInfo('x');
      expect(p.id, equals('x'));
      expect(p.priceFormatted, isNull);
      expect(p.resizedImages, isEmpty);
      expect(p.categories, isEmpty);
    });

    test(
      'iOS-style uniqid in JSON is ignored — id key takes precedence',
      () async {
        stubOk({
          'id': 'normalized-id',
          'uniqid': 'raw-ios-id',
          'name': '',
          'brand': '',
          'description': '',
          'image_url': '',
          'url': '',
          'price': 0,
          'price_full': 0,
          'currency': '',
          'sales_rate': 0,
          'relative_sales_rate': 0,
        });
        final p = await PersonalizationSdk().getProductInfo('normalized-id');
        expect(p.id, equals('normalized-id'));
      },
    );
  });
}
