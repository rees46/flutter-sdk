import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personalization_flutter_sdk/personalization_flutter_sdk.dart';
import 'package:personalization_flutter_sdk/src/pigeon/personalization_api.g.dart'
    as pigeon;

const _getRecommendationChannel =
    'dev.flutter.pigeon.personalization_flutter_sdk.PersonalizationHostApi.getRecommendation';
const _onReceivedChannel =
    'dev.flutter.pigeon.personalization_flutter_sdk.PersonalizationFlutterApi.onPushReceived';
const _onDeliveredChannel =
    'dev.flutter.pigeon.personalization_flutter_sdk.PersonalizationFlutterApi.onPushDelivered';
const _onClickedChannel =
    'dev.flutter.pigeon.personalization_flutter_sdk.PersonalizationFlutterApi.onPushClicked';

const _stubJson = '''
{
  "title": "You may like",
  "recommends": [
    {
      "id": "prod-1",
      "name": "Widget Pro",
      "brand": "Acme",
      "description": "A great widget",
      "image_url": "https://img/1.jpg",
      "picture": "https://img/1-sm.jpg",
      "image_url_resized": {"120": "https://img/1-120.jpg", "310": "https://img/1-310.jpg"},
      "url": "https://shop/prod-1",
      "price": 99.99,
      "price_full": 120.0,
      "price_formatted": "99.99 RUB",
      "price_full_formatted": "120.00 RUB",
      "currency": "RUB",
      "sales_rate": 42,
      "relative_sales_rate": 0.75,
      "categories": [
        {"id": "cat-1", "name": "Gadgets", "parent_id": "cat-0", "url": "/gadgets"}
      ]
    }
  ]
}
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const codec = pigeon.PersonalizationHostApi.pigeonChannelCodec;

  void mockChannel(String channel, MessageHandler handler) =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(channel, handler);

  void unmockChannel(String channel) => TestDefaultBinaryMessengerBinding
      .instance
      .defaultBinaryMessenger
      .setMockMessageHandler(channel, null);

  MessageHandler successHandler() =>
      (ByteData? _) async => codec.encodeMessage(<Object?>[]);

  MessageHandler jsonHandler(String json) =>
      (ByteData? _) async => codec.encodeMessage(<Object?>[json]);

  setUp(() {
    mockChannel(_onReceivedChannel, successHandler());
    mockChannel(_onDeliveredChannel, successHandler());
    mockChannel(_onClickedChannel, successHandler());
    mockChannel(_getRecommendationChannel, jsonHandler(_stubJson));
  });

  tearDown(() {
    for (final ch in [
      _onReceivedChannel,
      _onDeliveredChannel,
      _onClickedChannel,
      _getRecommendationChannel,
    ]) {
      unmockChannel(ch);
    }
  });

  ({List<Object?> args, String result}) Function() captureCall() {
    List<Object?>? capturedArgs;
    String? capturedResult;
    mockChannel(_getRecommendationChannel, (ByteData? msg) async {
      capturedArgs = codec.decodeMessage(msg) as List<Object?>;
      capturedResult = _stubJson;
      return codec.encodeMessage(<Object?>[_stubJson]);
    });
    return () => (args: capturedArgs!, result: capturedResult!);
  }

  // ---------------------------------------------------------------------------
  // validation
  // ---------------------------------------------------------------------------
  group('getRecommendation validation', () {
    test('empty code throws ArgumentError synchronously', () {
      expect(
        () => PersonalizationSdk().getRecommendation(''),
        throwsArgumentError,
      );
    });

    test('non-empty code does not throw synchronously', () {
      expect(
        () => PersonalizationSdk().getRecommendation('block-1'),
        returnsNormally,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // channel args
  // ---------------------------------------------------------------------------
  group('getRecommendation channel args', () {
    test('sends code at args[0]', () async {
      final capture = captureCall();
      await PersonalizationSdk().getRecommendation('block-42');
      expect(capture().args[0], 'block-42');
    });

    test('null paramsJson at args[1] when no params passed', () async {
      final capture = captureCall();
      await PersonalizationSdk().getRecommendation('block-1');
      expect(capture().args[1], isNull);
    });

    test('paramsJson is valid JSON when params passed', () async {
      final capture = captureCall();
      await PersonalizationSdk().getRecommendation(
        'block-1',
        params: const RecommendationParams(
          itemId: 'item-99',
          categoryId: 'cat-5',
          locations: 'loc1,loc2',
          imageSize: 310,
          withLocations: true,
        ),
      );
      final json =
          jsonDecode(capture().args[1] as String) as Map<String, dynamic>;
      expect(json['item_id'], 'item-99');
      expect(json['category_id'], 'cat-5');
      expect(json['locations'], 'loc1,loc2');
      expect(json['image_size'], 310);
      expect(json['with_locations'], true);
    });
  });

  // ---------------------------------------------------------------------------
  // response parsing
  // ---------------------------------------------------------------------------
  group('RecommendationResponse.fromJson', () {
    late RecommendationResponse response;

    setUp(() async {
      response = await PersonalizationSdk().getRecommendation('block-1');
    });

    test('title parsed correctly', () {
      expect(response.title, 'You may like');
    });

    test('products list has correct length', () {
      expect(response.products, hasLength(1));
    });

    test('product fields parsed correctly', () {
      final p = response.products.first;
      expect(p.id, 'prod-1');
      expect(p.name, 'Widget Pro');
      expect(p.brand, 'Acme');
      expect(p.description, 'A great widget');
      expect(p.imageUrl, 'https://img/1.jpg');
      expect(p.resizedImageUrl, 'https://img/1-sm.jpg');
      expect(p.url, 'https://shop/prod-1');
      expect(p.price, 99.99);
      expect(p.priceFull, 120.0);
      expect(p.priceFormatted, '99.99 RUB');
      expect(p.priceFullFormatted, '120.00 RUB');
      expect(p.currency, 'RUB');
      expect(p.salesRate, 42);
      expect(p.relativeSalesRate, 0.75);
    });

    test('resizedImages parsed as map', () {
      final images = response.products.first.resizedImages;
      expect(images['120'], 'https://img/1-120.jpg');
      expect(images['310'], 'https://img/1-310.jpg');
    });

    test('categories parsed correctly', () {
      final cat = response.products.first.categories.first;
      expect(cat.id, 'cat-1');
      expect(cat.name, 'Gadgets');
      expect(cat.parentId, 'cat-0');
      expect(cat.url, '/gadgets');
    });
  });

  // ---------------------------------------------------------------------------
  // edge cases
  // ---------------------------------------------------------------------------
  group('RecommendationResponse.fromJson edge cases', () {
    RecommendationResponse parseJson(String json) =>
        RecommendationResponse.fromJson(
          jsonDecode(json) as Map<String, dynamic>,
        );

    test('missing title defaults to empty string', () {
      final r = parseJson('{"recommends": []}');
      expect(r.title, '');
    });

    test('missing recommends defaults to empty list', () {
      final r = parseJson('{"title": "x"}');
      expect(r.products, isEmpty);
    });

    test('optional price fields null when absent', () {
      final r = parseJson(
        '{"recommends": [{"id":"1","name":"","brand":"",'
        '"description":"","image_url":"","picture":"",'
        '"url":"","price":0,"price_full":0,"currency":"",'
        '"sales_rate":0,"relative_sales_rate":0,"categories":[]}]}',
      );
      expect(r.products.first.priceFormatted, isNull);
      expect(r.products.first.priceFullFormatted, isNull);
    });

    test('category optional fields null when absent', () {
      final r = parseJson(
        '{"recommends": [{"id":"1","name":"","brand":"","description":"",'
        '"image_url":"","picture":"","url":"","price":0,"price_full":0,'
        '"currency":"","sales_rate":0,"relative_sales_rate":0,'
        '"categories": [{"id": "c1", "name": "Books"}]}]}',
      );
      final cat = r.products.first.categories.first;
      expect(cat.parentId, isNull);
      expect(cat.url, isNull);
    });
  });
}
