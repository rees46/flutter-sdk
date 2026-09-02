import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/rees46_sdk.dart';
import 'package:rees46_sdk/src/pigeon/personalization_api.g.dart' as pigeon;

/// Covers the `tracking` namespace: that every method reaches its own Pigeon channel with the
/// arguments the native side expects, and that the models are put on the wire unchanged.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const codec = pigeon.PersonalizationHostApi.pigeonChannelCodec;
  const prefix =
      'dev.flutter.pigeon.personalization_flutter_sdk.PersonalizationHostApi.';
  const flutterApiPrefix =
      'dev.flutter.pigeon.personalization_flutter_sdk.PersonalizationFlutterApi.';

  final mocked = <String>[];

  void mockChannel(String channel, MessageHandler handler) {
    mocked.add(channel);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(channel, handler);
  }

  /// Captures the decoded argument list of the next call on [method].
  List<Object?> Function() capture(String method) {
    List<Object?>? captured;
    mockChannel(prefix + method, (ByteData? msg) async {
      captured = codec.decodeMessage(msg) as List<Object?>;
      return codec.encodeMessage(<Object?>[]);
    });
    return () => captured!;
  }

  setUp(() {
    // The SDK constructor claims the push channels; stub them so they stay quiet.
    for (final event in [
      'onPushReceived',
      'onPushDelivered',
      'onPushClicked',
    ]) {
      mockChannel(
        flutterApiPrefix + event,
        (ByteData? _) async => codec.encodeMessage(<Object?>[]),
      );
    }
  });

  tearDown(() {
    for (final channel in mocked) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(channel, null);
    }
    mocked.clear();
  });

  group('events reach their channel', () {
    test('productView sends the item id and no source by default', () async {
      final args = capture('trackProductView');
      await PersonalizationSdk().tracking.productView('sku-1');

      expect(args()[0], 'sku-1');
      expect(args()[1], isNull);
    });

    test('categoryView sends the category id', () async {
      final args = capture('trackCategoryView');
      await PersonalizationSdk().tracking.categoryView('women-shoes');

      expect(args()[0], 'women-shoes');
    });

    test('search sends the query and the shown results', () async {
      final args = capture('trackSearch');
      await PersonalizationSdk().tracking.search(
        'boots',
        results: ['sku-1', 'sku-2'],
      );

      expect(args()[0], 'boots');
      expect(args()[1], ['sku-1', 'sku-2']);
    });

    test('addToCart carries quantity and price', () async {
      final args = capture('trackAddToCart');
      await PersonalizationSdk().tracking.addToCart(
        const TrackingItem(id: 'sku-1', quantity: 3, price: 49.9),
      );

      final item = args()[0] as pigeon.TrackingItemWire;
      expect(item.id, 'sku-1');
      expect(item.quantity, 3);
      expect(item.price, 49.9);
    });

    test('syncCart sends every line', () async {
      final args = capture('trackSyncCart');
      await PersonalizationSdk().tracking.syncCart(const [
        TrackingItem(id: 'sku-1', quantity: 2, price: 10),
        TrackingItem(id: 'sku-2'),
      ]);

      final items = (args()[0] as List).cast<pigeon.TrackingItemWire>();
      expect(items.length, 2);
      expect(items[1].quantity, 1, reason: 'quantity defaults to one unit');
      expect(items[1].price, isNull);
    });

    test('removeFromCart sends the item id', () async {
      final args = capture('trackRemoveFromCart');
      await PersonalizationSdk().tracking.removeFromCart('sku-1');

      expect(args()[0], 'sku-1');
    });

    test('favorites reach their own channels', () async {
      final added = capture('trackAddToFavorites');
      final removed = capture('trackRemoveFromFavorites');
      final synced = capture('trackSyncFavorites');
      final sdk = PersonalizationSdk();

      await sdk.tracking.addToFavorites('sku-1');
      await sdk.tracking.removeFromFavorites('sku-2');
      await sdk.tracking.syncFavorites(['sku-1', 'sku-3']);

      expect(added()[0], 'sku-1');
      expect(removed()[0], 'sku-2');
      expect(synced()[0], ['sku-1', 'sku-3']);
    });

    test('story events carry ids and an optional block code', () async {
      final viewed = capture('trackStoryView');
      final clicked = capture('trackStoryClick');
      final sdk = PersonalizationSdk();

      await sdk.tracking.storyView(
        storyId: '42',
        slideId: '3',
        code: 'main_stories',
      );
      await sdk.tracking.storyClick(storyId: '42', slideId: '3');

      expect(viewed().sublist(0, 3), ['42', '3', 'main_stories']);
      expect(
        clicked()[2],
        isNull,
        reason: 'native falls back to the loaded block',
      );
    });
  });

  group('attribution', () {
    test('a per-call source is sent as its wire value', () async {
      final args = capture('trackProductView');
      await PersonalizationSdk().tracking.productView(
        'sku-1',
        source: const TrackingSource(
          type: TrackingSourceType.dynamicBlock,
          code: 'popular',
        ),
      );

      final source = args()[1] as pigeon.TrackingSourceWire;
      expect(source.type, 'dynamic');
      expect(source.code, 'popular');
    });

    test('setSource sends the stored source', () async {
      final args = capture('trackSetSource');
      await PersonalizationSdk().tracking.setSource(
        const TrackingSource(
          type: TrackingSourceType.fullSearch,
          code: 'boots',
        ),
      );

      expect((args()[0] as pigeon.TrackingSourceWire).type, 'full_search');
    });

    test('every source type has the wire value the API expects', () {
      expect(TrackingSourceType.values.map((e) => e.wireValue), [
        'dynamic',
        'chain',
        'bulk',
        'transactional',
        'instant_search',
        'full_search',
        'stories',
        'web_push_digest',
      ]);
    });
  });

  group('the shop id is threaded through', () {
    test('a handle bound to a shop sends it as the last argument', () async {
      final args = capture('trackProductView');
      await PersonalizationSdk(shopId: 'shop-a').tracking.productView('sku-1');

      expect(args().last, 'shop-a');
    });

    test('an unbound handle sends null', () async {
      final args = capture('trackProductView');
      await PersonalizationSdk().tracking.productView('sku-1');

      expect(args().last, isNull);
    });
  });

  group('validation happens before the channel call', () {
    final sdk = PersonalizationSdk();

    test('empty ids throw', () {
      expect(() => sdk.tracking.productView(''), throwsArgumentError);
      expect(() => sdk.tracking.categoryView(''), throwsArgumentError);
      expect(() => sdk.tracking.search(''), throwsArgumentError);
      expect(() => sdk.tracking.removeFromCart(''), throwsArgumentError);
      expect(() => sdk.tracking.addToFavorites(''), throwsArgumentError);
      expect(
        () => sdk.tracking.addToCart(const TrackingItem(id: '')),
        throwsArgumentError,
      );
      expect(
        () => sdk.tracking.storyView(storyId: '', slideId: '3'),
        throwsArgumentError,
      );
    });

    test('empty collections throw', () {
      expect(() => sdk.tracking.syncCart(const []), throwsArgumentError);
      expect(() => sdk.tracking.syncFavorites(const []), throwsArgumentError);
    });
  });

  group('purchase and custom events keep working through the namespace', () {
    test('purchase reaches the existing trackPurchase channel', () async {
      final args = capture('trackPurchase');
      await PersonalizationSdk().tracking.purchase(
        orderId: 'order-1',
        orderPrice: 100,
        items: const [PurchaseLineItem(id: 'sku-1', amount: 1, price: 100)],
      );

      expect(args()[0], 'order-1');
      expect(args()[1], 100.0);
    });

    test('custom reaches the existing trackEvent channel', () async {
      final args = capture('trackEvent');
      await PersonalizationSdk().tracking.custom(
        'checkout_step',
        time: 1000,
        category: 'checkout',
      );

      expect(args()[0], 'checkout_step');
      expect(args()[1], 1000);
      expect(args()[2], 'checkout');
    });
  });
}
