import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/rees46_sdk.dart';
import 'package:rees46_sdk/src/pigeon/personalization_api.g.dart' as pigeon;

// Channel names from generated Pigeon code.
const _trackEventChannel =
    'dev.flutter.pigeon.personalization_flutter_sdk.PersonalizationHostApi.trackEvent';
const _trackPurchaseChannel =
    'dev.flutter.pigeon.personalization_flutter_sdk.PersonalizationHostApi.trackPurchase';
// Stub channels registered by PersonalizationFlutterApi.setUp in the SDK ctor.
const _onReceivedChannel =
    'dev.flutter.pigeon.personalization_flutter_sdk.PersonalizationFlutterApi.onPushReceived';
const _onDeliveredChannel =
    'dev.flutter.pigeon.personalization_flutter_sdk.PersonalizationFlutterApi.onPushDelivered';
const _onClickedChannel =
    'dev.flutter.pigeon.personalization_flutter_sdk.PersonalizationFlutterApi.onPushClicked';

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

  setUp(() {
    // Stub FlutterApi push channels so PersonalizationFlutterApi.setUp in
    // the SDK constructor does not print "channel not mocked" warnings.
    mockChannel(_onReceivedChannel, successHandler());
    mockChannel(_onDeliveredChannel, successHandler());
    mockChannel(_onClickedChannel, successHandler());
    mockChannel(_trackEventChannel, successHandler());
    mockChannel(_trackPurchaseChannel, successHandler());
  });

  tearDown(() {
    for (final ch in [
      _onReceivedChannel,
      _onDeliveredChannel,
      _onClickedChannel,
      _trackEventChannel,
      _trackPurchaseChannel,
    ]) {
      unmockChannel(ch);
    }
  });

  // Installs a capturing handler on [channel] and returns a getter for the
  // decoded argument list.
  List<Object?> Function() captureArgs(String channel) {
    List<Object?>? captured;
    mockChannel(channel, (ByteData? msg) async {
      captured = codec.decodeMessage(msg) as List<Object?>;
      return codec.encodeMessage(<Object?>[]);
    });
    return () => captured!;
  }

  // ---------------------------------------------------------------------------
  // trackEvent
  // ---------------------------------------------------------------------------
  group('trackEvent validation', () {
    test(
      'empty event throws ArgumentError synchronously before channel call',
      () {
        final sdk = PersonalizationSdk();
        expect(() => sdk.trackEvent(''), throwsArgumentError);
      },
    );

    test('non-empty event does not throw synchronously', () {
      final sdk = PersonalizationSdk();
      expect(() => sdk.trackEvent('click'), returnsNormally);
    });
  });

  group('trackEvent channel args', () {
    test('customFields null → customFieldsJson (arg[5]) is null', () async {
      final getArgs = captureArgs(_trackEventChannel);
      await PersonalizationSdk().trackEvent('ev');
      expect(getArgs()[5], isNull);
    });

    test('customFields provided → valid JSON at arg[5]', () async {
      final getArgs = captureArgs(_trackEventChannel);
      await PersonalizationSdk().trackEvent(
        'ev',
        customFields: {'source': 'app', 'count': 3},
      );
      final json = jsonDecode(getArgs()[5] as String) as Map<String, dynamic>;
      expect(json['source'], 'app');
      expect(json['count'], 3);
    });

    test('all positional args sent in correct order', () async {
      final getArgs = captureArgs(_trackEventChannel);
      await PersonalizationSdk().trackEvent(
        'my_event',
        time: 1700000000,
        category: 'cat',
        label: 'lbl',
        value: 42,
        customFields: {'k': 'v'},
      );
      final args = getArgs();
      expect(args[0], 'my_event'); // event
      expect(args[1], 1700000000); // time
      expect(args[2], 'cat'); // category
      expect(args[3], 'lbl'); // label
      expect(args[4], 42); // value
      expect(args[5], isNotNull); // customFieldsJson
    });

    test('customFields with null value → key preserved in JSON', () async {
      final getArgs = captureArgs(_trackEventChannel);
      await PersonalizationSdk().trackEvent(
        'ev',
        customFields: {'present': 'yes', 'absent': null},
      );
      final json = jsonDecode(getArgs()[5] as String) as Map<String, dynamic>;
      expect(json.containsKey('absent'), true);
      expect(json['absent'], isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // trackPurchase
  // ---------------------------------------------------------------------------
  group('trackPurchase validation', () {
    test('empty orderId throws ArgumentError synchronously', () {
      final sdk = PersonalizationSdk();
      expect(
        () => sdk.trackPurchase(
          orderId: '',
          orderPrice: 10.0,
          items: [const PurchaseLineItem(id: 'sku', amount: 1, price: 10.0)],
        ),
        throwsArgumentError,
      );
    });

    test('empty items throws ArgumentError synchronously', () {
      final sdk = PersonalizationSdk();
      expect(
        () => sdk.trackPurchase(orderId: 'ord-1', orderPrice: 10.0, items: []),
        throwsArgumentError,
      );
    });
  });

  group('trackPurchase channel args', () {
    test('PurchaseLineItem maps correctly to wire type', () async {
      final getArgs = captureArgs(_trackPurchaseChannel);
      await PersonalizationSdk().trackPurchase(
        orderId: 'ord-1',
        orderPrice: 99.0,
        items: [
          const PurchaseLineItem(
            id: 'sku-1',
            amount: 2,
            price: 49.5,
            lineId: 'line-A',
            fashionSize: 'M',
          ),
        ],
      );
      final wire =
          (getArgs()[2] as List<Object?>)[0] as pigeon.PurchaseLineItemWire;
      expect(wire.id, 'sku-1');
      expect(wire.amount, 2);
      expect(wire.price, 49.5);
      expect(wire.lineId, 'line-A');
      expect(wire.fashionSize, 'M');
    });

    test('optional item fields are null when not set', () async {
      final getArgs = captureArgs(_trackPurchaseChannel);
      await PersonalizationSdk().trackPurchase(
        orderId: 'ord-1',
        orderPrice: 10.0,
        items: [const PurchaseLineItem(id: 'sku', amount: 1, price: 10.0)],
      );
      final wire =
          (getArgs()[2] as List<Object?>)[0] as pigeon.PurchaseLineItemWire;
      expect(wire.lineId, isNull);
      expect(wire.fashionSize, isNull);
    });

    test('custom null → customJson (arg[14]) is null', () async {
      final getArgs = captureArgs(_trackPurchaseChannel);
      await PersonalizationSdk().trackPurchase(
        orderId: 'ord',
        orderPrice: 1.0,
        items: [const PurchaseLineItem(id: 'x', amount: 1, price: 1.0)],
      );
      expect(getArgs()[14], isNull);
    });

    test('custom provided → valid JSON at arg[14]', () async {
      final getArgs = captureArgs(_trackPurchaseChannel);
      await PersonalizationSdk().trackPurchase(
        orderId: 'ord',
        orderPrice: 1.0,
        items: [const PurchaseLineItem(id: 'x', amount: 1, price: 1.0)],
        custom: {'channel': 'app'},
      );
      final json = jsonDecode(getArgs()[14] as String) as Map<String, dynamic>;
      expect(json['channel'], 'app');
    });

    test('recommendedSource provided → valid JSON at arg[15]', () async {
      final getArgs = captureArgs(_trackPurchaseChannel);
      await PersonalizationSdk().trackPurchase(
        orderId: 'ord',
        orderPrice: 1.0,
        items: [const PurchaseLineItem(id: 'x', amount: 1, price: 1.0)],
        recommendedSource: {'type': 'popular', 'code': 'rec-1'},
      );
      final json = jsonDecode(getArgs()[15] as String) as Map<String, dynamic>;
      expect(json['type'], 'popular');
      expect(json['code'], 'rec-1');
    });

    test('all positional args sent in correct order', () async {
      final getArgs = captureArgs(_trackPurchaseChannel);
      await PersonalizationSdk().trackPurchase(
        orderId: 'order-42',
        orderPrice: 150.0,
        items: [const PurchaseLineItem(id: 'sku', amount: 1, price: 150.0)],
        deliveryType: 'courier',
        deliveryAddress: 'Main St',
        paymentType: 'card',
        isTaxFree: true,
        isGiftPackage: true,
        promocode: 'SAVE10',
        orderCash: 0.0,
        orderBonuses: 5.0,
        orderDelivery: 0.0,
        orderDiscount: 10.0,
        channel: 'mobile',
        stream: 'android',
        segment: 'vip',
      );
      final args = getArgs();
      expect(args[0], 'order-42'); // orderId
      expect(args[1], 150.0); // orderPrice
      // args[2] = items (List)
      expect(args[3], 'courier'); // deliveryType
      expect(args[4], 'Main St'); // deliveryAddress
      expect(args[5], 'card'); // paymentType
      expect(args[6], true); // isTaxFree
      expect(args[7], true); // isGiftPackage
      expect(args[8], 'SAVE10'); // promocode
      expect(args[9], 0.0); // orderCash
      expect(args[10], 5.0); // orderBonuses
      expect(args[11], 0.0); // orderDelivery
      expect(args[12], 10.0); // orderDiscount
      expect(args[13], 'mobile'); // channel
      // args[14] = customJson
      // args[15] = recommendedSourceJson
      expect(args[16], 'android'); // stream
      expect(args[17], 'vip'); // segment
    });
  });
}
