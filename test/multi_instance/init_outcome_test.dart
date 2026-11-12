import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/rees46_sdk.dart';
import 'package:rees46_sdk/src/pigeon/personalization_api.g.dart' as pigeon;

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
    answerInit(<Object?>['init_failed', 'shop refused', null]);

    REES46.initialize(const REES46Config(shopId: 'refused-shop'));
    await pumpEventQueue();
  });

  test('a failed native init reaches ready', () async {
    answerInit(<Object?>['init_failed', 'shop refused', null]);

    final sdk = REES46.initialize(const REES46Config(shopId: 'refused-shop'));

    await expectLater(
      sdk.ready,
      throwsA(
        isA<PlatformException>().having((e) => e.code, 'code', 'init_failed'),
      ),
    );
  });

  test('a native init that succeeds completes ready', () async {
    answerInit(<Object?>[]);

    final sdk = REES46.initialize(const REES46Config(shopId: 'live-shop'));

    await expectLater(sdk.ready, completes);
  });
}
