import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/rees46_sdk.dart';
import 'package:rees46_sdk/src/pigeon/personalization_api.g.dart' as pigeon;

import '../support/wire.dart';

const _initChannel =
    'dev.flutter.pigeon.personalization_flutter_sdk.PersonalizationHostApi.initialize';

// `REES46.initialize` hands the shop's handle back at once and the native init goes on. Its
// outcome is the handle's `ready`; a failed init is not left as an unhandled error.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void answerInit(List<Object?> reply) {
    messenger.setMockMessageHandler(
      _initChannel,
      (_) async =>
          pigeon.PersonalizationHostApi.pigeonChannelCodec.encodeMessage(reply),
    );
  }

  tearDown(() {
    messenger.setMockMessageHandler(_initChannel, null);
    REES46.reset();
  });

  test('a failed native init is not left as an unhandled error', () async {
    answerInit(<Object?>['invalidArgument', 'shopId must not be empty', null]);

    REES46.initialize(const REES46Config(shopId: 'refused-shop'));
    await pumpEventQueue();
  });

  test('a failed native init reaches ready as an SdkException', () async {
    answerInit(<Object?>[
      'invalidArgument',
      'shopId must not be empty',
      <String, Object?>{'httpCode': null, 'serverCode': null},
    ]);

    final sdk = REES46.initialize(const REES46Config(shopId: 'bad-shop'));

    await expectLater(
      sdk.ready,
      throwsA(
        isA<SdkException>()
            .having((e) => e.error, 'error', isA<SdkErrorInvalidArgument>())
            // Code that caught the released PlatformException still does.
            .having((e) => e, 'released type', isA<PlatformException>()),
      ),
    );
  });

  test('a native init that is ready completes ready', () async {
    answerInit(<Object?>[snapshotWire('live-shop')]);

    final sdk = REES46.initialize(const REES46Config(shopId: 'live-shop'));

    await expectLater(sdk.ready, completes);
    expect(sdk.state, SdkState.ready);
    expect(sdk.deviceId, 'did-1');
    expect(sdk.sessionId, 'sid-1');
  });

  test('ready waits for the native state to reach ready', () async {
    answerInit(<Object?>[
      snapshotWire('slow-shop', state: 'initializing', deviceId: null),
    ]);

    final sdk = REES46.initialize(const REES46Config(shopId: 'slow-shop'));
    var done = false;
    unawaited(sdk.ready.then((_) => done = true));
    await pumpEventQueue();
    expect(done, isFalse);
    expect(sdk.state, SdkState.initializing);

    final states = <SdkState>[];
    final subscription = sdk.stateChanges.listen(states.add);
    await sendStateEvent('onSnapshot', <Object?>[snapshotWire('slow-shop')]);
    await pumpEventQueue();
    expect(done, isTrue);
    expect(states, [SdkState.initializing, SdkState.ready]);
    expect(sdk.deviceId, 'did-1');
    await subscription.cancel();
  });

  test('retrying with a device id of an earlier launch is ready', () async {
    answerInit(<Object?>[snapshotWire('offline-shop', state: 'retrying')]);

    final sdk = REES46.initialize(const REES46Config(shopId: 'offline-shop'));

    await expectLater(sdk.ready, completes);
  });

  test('a refused shop fails ready with shopBlocked', () async {
    answerInit(<Object?>[
      snapshotWire('blocked-shop', state: 'initializing', deviceId: null),
    ]);

    final sdk = REES46.initialize(const REES46Config(shopId: 'blocked-shop'));
    final outcome = expectLater(
      sdk.ready,
      throwsA(
        isA<SdkException>().having(
          (e) => e.error,
          'error',
          isA<SdkErrorShopBlocked>(),
        ),
      ),
    );
    await pumpEventQueue();
    await sendStateEvent('onSnapshot', <Object?>[
      snapshotWire('blocked-shop', state: 'refused', deviceId: null),
    ]);
    await outcome;
    expect(sdk.state, SdkState.refused);
  });
}
