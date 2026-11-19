import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/rees46_sdk.dart';
import 'package:rees46_sdk/src/pigeon/personalization_api.g.dart' as pigeon;

import '../support/wire.dart';

// A 1.6.4 app makes its own handle and awaits `initialize` before `runApp`: the future
// completes once the native SDK took the configuration, not once `/init` went through.
// Waiting for the shop, and a refused shop's `shopBlocked`, are `ready`'s.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    unstub('initialize');
    REES46.reset();
  });

  test(
    'initialize completes on a first launch without network; ready waits',
    () async {
      stubValue(
        'initialize',
        snapshotWire('offline-shop', state: 'retrying', deviceId: null),
      );
      final sdk = PersonalizationSdk();

      await expectLater(
        sdk.initialize(const SdkInitConfig(shopId: 'offline-shop')),
        completes,
      );
      var ready = false;
      unawaited(sdk.ready.then((_) => ready = true));
      await pumpEventQueue();
      expect(
        ready,
        isFalse,
        reason: 'no device id yet: the shop does not work',
      );
      expect(sdk.state, SdkState.retrying);

      await sendStateEvent('onSnapshot', <Object?>[
        snapshotWire('offline-shop'),
      ]);
      await pumpEventQueue();
      expect(ready, isTrue);
    },
  );

  test(
    'a refused shop: initialize completes, ready fails with shopBlocked',
    () async {
      stubValue(
        'initialize',
        snapshotWire('blocked-shop', state: 'refused', deviceId: null),
      );
      final sdk = PersonalizationSdk();

      await expectLater(
        sdk.initialize(const SdkInitConfig(shopId: 'blocked-shop')),
        completes,
      );
      await expectLater(
        sdk.ready,
        throwsA(
          isA<SdkException>().having(
            (e) => e.error,
            'error',
            isA<SdkErrorShopBlocked>(),
          ),
        ),
      );
    },
  );

  test(
    'a refused shop whose ready nobody awaits is no unhandled error',
    () async {
      stubValue(
        'initialize',
        snapshotWire('blocked-shop', state: 'refused', deviceId: null),
      );
      await PersonalizationSdk().initialize(
        const SdkInitConfig(shopId: 'blocked-shop'),
      );
      await pumpEventQueue();
    },
  );

  test('a native start that failed fails initialize and ready', () async {
    stubHost(
      'initialize',
      (_) => errorReply('invalidArgument', message: 'shopId must not be empty'),
    );
    final sdk = PersonalizationSdk();
    final invalid = throwsA(
      isA<SdkException>().having(
        (e) => e.error,
        'error',
        isA<SdkErrorInvalidArgument>(),
      ),
    );

    await expectLater(
      sdk.initialize(const SdkInitConfig(shopId: 'bad-shop')),
      invalid,
    );
    await expectLater(sdk.ready, invalid);
  });

  group('push callbacks set before initialize', () {
    pigeon.PushPayloadWire push(String shopId) => pigeon.PushPayloadWire(
      shopId: shopId,
      code: 'm1',
      type: 'bulk',
      actions: const [],
      data: const {'id': 'm1', 'type': 'bulk'},
    );

    test('a handle without a shop id keeps them for its shop', () async {
      stubValue('initialize', snapshotWire('early-shop'));
      final heard = <String>[];
      final sdk = PersonalizationSdk();
      sdk.notifications.setCallbacks(
        PushCallbacks(onClicked: (p) => heard.add('clicked ${p.code}')),
      );

      await sdk.initialize(const SdkInitConfig(shopId: 'early-shop'));
      await sendStateEvent('onPushEvent', <Object?>[
        'early-shop',
        'clicked',
        push('early-shop'),
      ]);

      expect(heard, ['clicked m1']);
    });

    test('callbacks set after initialize replace them', () async {
      stubValue('initialize', snapshotWire('early-shop'));
      final heard = <String>[];
      final sdk = PersonalizationSdk();
      sdk.notifications.setCallbacks(
        PushCallbacks(onClicked: (p) => heard.add('early')),
      );
      await sdk.initialize(const SdkInitConfig(shopId: 'early-shop'));
      sdk.notifications.setCallbacks(
        PushCallbacks(onClicked: (p) => heard.add('late')),
      );

      await sendStateEvent('onPushEvent', <Object?>[
        'early-shop',
        'clicked',
        push('early-shop'),
      ]);

      expect(heard, ['late']);
    });
  });
}
