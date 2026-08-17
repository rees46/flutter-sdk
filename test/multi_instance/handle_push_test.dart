import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/src/multi_instance/push_event.dart';
import 'package:rees46_sdk/src/multi_instance/rees46.dart';
import 'package:rees46_sdk/src/multi_instance/rees46_config.dart';
import 'package:rees46_sdk/src/personalization_sdk.dart';
import 'package:rees46_sdk/src/pigeon/personalization_api.g.dart' as pigeon;

/// F4 contract: [Rees46.handlePush] resolves the target shop from the payload's
/// `shop_id` (drop on unknown/ambiguous), tracks natively, and fires that shop's
/// callbacks — mirror of the native `Rees46.handlePush` routing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const handlePushChannel =
      'dev.flutter.pigeon.personalization_flutter_sdk.PersonalizationHostApi.handlePush';

  late List<List<Object?>> nativeCalls;
  late Map<String, PersonalizationSdk> handles;

  Rees46Config cfg(String shopId) => Rees46Config(shopId: shopId);

  Map<String, String> push(String? shopId) => {
    'shop_id': ?shopId,
    'type': 'bulk',
    'id': 'mi-demo',
    'title': 't',
    'body': 'b',
  };

  setUp(() {
    nativeCalls = [];
    handles = {};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(handlePushChannel, (message) async {
          nativeCalls.add(
            pigeon.PersonalizationHostApi.pigeonChannelCodec.decodeMessage(
                  message,
                )
                as List<Object?>,
          );
          return pigeon.PersonalizationHostApi.pigeonChannelCodec.encodeMessage(
            <Object?>[],
          );
        });
    Rees46.debugFactory = (config) {
      final sdk = PersonalizationSdk(shopId: config.shopId);
      handles[config.shopId] = sdk;
      return sdk;
    };
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(handlePushChannel, null);
    Rees46.reset();
  });

  test('routes to the shop named by shop_id and tracks natively', () async {
    Rees46.initialize(cfg('A'));
    Rees46.initialize(cfg('B'));

    final routed = await Rees46.handlePush(push('B'), PushEvent.received);

    expect(routed, 'B');
    expect(nativeCalls, hasLength(1));
    expect(nativeCalls.single[1], PushEvent.received.index); // event index
  });

  test('unknown shop is dropped — no native call', () async {
    Rees46.initialize(cfg('A'));

    final routed = await Rees46.handlePush(push('zzz'), PushEvent.received);

    expect(routed, isNull);
    expect(nativeCalls, isEmpty);
  });

  test('no shop_id with a single live shop falls back to it', () async {
    Rees46.initialize(cfg('A'));

    final routed = await Rees46.handlePush(push(null), PushEvent.received);

    expect(routed, 'A');
    expect(nativeCalls, hasLength(1));
  });

  test('no shop_id with two live shops is ambiguous and dropped', () async {
    Rees46.initialize(cfg('A'));
    Rees46.initialize(cfg('B'));

    final routed = await Rees46.handlePush(push(null), PushEvent.received);

    expect(routed, isNull);
    expect(nativeCalls, isEmpty);
  });

  test('materializes a pending shop and routes to it', () async {
    Rees46.registerShops([cfg('A')]);
    expect(Rees46.liveShopIds, isEmpty);

    final routed = await Rees46.handlePush(push('A'), PushEvent.received);

    expect(routed, 'A');
    expect(Rees46.liveShopIds, ['A']); // materialized on the push
  });

  test('fires only the target shop callbacks', () async {
    Rees46.initialize(cfg('A'));
    Rees46.initialize(cfg('B'));
    Map<String, String?>? gotA;
    Map<String, String?>? gotB;
    handles['A']!.setPushNotificationCallbacks(onReceived: (p) => gotA = p);
    handles['B']!.setPushNotificationCallbacks(onReceived: (p) => gotB = p);

    await Rees46.handlePush(push('B'), PushEvent.received);

    expect(gotB, isNotNull);
    expect(gotB!['shop_id'], 'B');
    expect(gotA, isNull);
  });
}
