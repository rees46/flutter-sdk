import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/rees46_sdk.dart';
import 'package:rees46_sdk/src/pigeon/personalization_api.g.dart' as pigeon;

const _profileChannel =
    'dev.flutter.pigeon.personalization_flutter_sdk.PersonalizationHostApi.getProfile';
const _countersChannel =
    'dev.flutter.pigeon.personalization_flutter_sdk.PersonalizationHostApi.getProductCounters';
const _categoryChannel =
    'dev.flutter.pigeon.personalization_flutter_sdk.PersonalizationHostApi.getCategory';
const _collectionChannel =
    'dev.flutter.pigeon.personalization_flutter_sdk.PersonalizationHostApi.getCollection';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messageCodec = pigeon.PersonalizationHostApi.pigeonChannelCodec;
  ByteData reply(String value) => messageCodec.encodeMessage([value])!;

  void stub(String channel, String json) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(channel, (_) async => reply(json));
  }

  tearDown(() {
    for (final c in [
      _profileChannel,
      _countersChannel,
      _categoryChannel,
      _collectionChannel,
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(c, null);
    }
  });

  // -------------------------------------------------------------------------
  // getProfile
  // -------------------------------------------------------------------------
  group('getProfile', () {
    test('parses scalar fields and custom properties', () async {
      stub(
        _profileChannel,
        jsonEncode({
          'id': 'u1',
          'email': 'a@b.c',
          'has_email': true,
          'gender': 'm',
          'bought_something': false,
          'custom_properties': {'tier': 'gold'},
        }),
      );

      final r = await PersonalizationSdk().getProfile();
      expect(r, isA<ProfileResponse>());
      expect(r.id, equals('u1'));
      expect(r.email, equals('a@b.c'));
      expect(r.hasEmail, isTrue);
      expect(r.gender, equals('m'));
      expect(r.boughtSomething, isFalse);
      expect(r.customProperties['tier'], equals('gold'));
    });

    test('missing fields parse to nulls / empty map', () async {
      stub(_profileChannel, jsonEncode({'id': 'u1'}));

      final r = await PersonalizationSdk().getProfile();
      expect(r.id, equals('u1'));
      expect(r.email, isNull);
      expect(r.hasEmail, isNull);
      expect(r.customProperties, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // getProductCounters
  // -------------------------------------------------------------------------
  group('getProductCounters', () {
    test('parses periods and triggers', () async {
      stub(
        _countersChannel,
        jsonEncode({
          'now': {'view': 3, 'cart': 1, 'purchase': 0},
          'daily': {'view': 10, 'cart': 4, 'purchase': 2},
          'triggers': {'back_in_stock': 1, 'price_drop': 5},
        }),
      );

      final r = await PersonalizationSdk().getProductCounters('item1');
      expect(r, isA<ProductCountersResponse>());
      expect(r.now?.view, equals(3));
      expect(r.daily?.purchase, equals(2));
      expect(r.triggers?.priceDrop, equals(5));
      expect(r.triggers?.backInStock, equals(1));
    });

    test('absent sections parse to null', () async {
      stub(_countersChannel, jsonEncode({'now': {'view': 1, 'cart': 0, 'purchase': 0}}));

      final r = await PersonalizationSdk().getProductCounters('item1');
      expect(r.now?.view, equals(1));
      expect(r.daily, isNull);
      expect(r.triggers, isNull);
    });

    test('empty item throws ArgumentError (no native call)', () async {
      expect(
        () => PersonalizationSdk().getProductCounters(''),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  // -------------------------------------------------------------------------
  // getCategory
  // -------------------------------------------------------------------------
  group('getCategory', () {
    test('parses total and products', () async {
      stub(
        _categoryChannel,
        jsonEncode({
          'products_total': 2,
          'products': [
            {'id': 'p1', 'name': 'One', 'price': 9.9, 'currency': 'USD'},
            {'id': 'p2', 'name': 'Two', 'price': 19.9, 'currency': 'USD'},
          ],
        }),
      );

      final r = await PersonalizationSdk().getCategory('shoes', limit: 5);
      expect(r, isA<CategoryResponse>());
      expect(r.productsTotal, equals(2));
      expect(r.products, hasLength(2));
      expect(r.products.first.id, equals('p1'));
      expect(r.products.first.price, equals(9.9));
    });

    test('empty products defaults to empty list', () async {
      stub(_categoryChannel, jsonEncode({'products_total': 0}));

      final r = await PersonalizationSdk().getCategory('shoes');
      expect(r.productsTotal, equals(0));
      expect(r.products, isEmpty);
    });

    test('empty category throws ArgumentError (no native call)', () async {
      expect(
        () => PersonalizationSdk().getCategory(''),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  // -------------------------------------------------------------------------
  // getCollection
  // -------------------------------------------------------------------------
  group('getCollection', () {
    test('parses products', () async {
      stub(
        _collectionChannel,
        jsonEncode({
          'products': [
            {'id': 'p1', 'name': 'One', 'price': 5.0, 'currency': 'EUR'},
          ],
        }),
      );

      final r = await PersonalizationSdk().getCollection('1');
      expect(r, isA<CollectionResponse>());
      expect(r.products, hasLength(1));
      expect(r.products.first.id, equals('p1'));
    });

    test('empty collectionId throws ArgumentError (no native call)', () async {
      expect(
        () => PersonalizationSdk().getCollection(''),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
