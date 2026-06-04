import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personalization_flutter_sdk/src/init/sdk_init_handler.dart';
import 'package:personalization_flutter_sdk/src/pigeon/personalization_api.g.dart'
    as pigeon;
import 'package:personalization_flutter_sdk/src/sdk_init_config.dart';

const _initChannel =
    'dev.flutter.pigeon.personalization_flutter_sdk.PersonalizationHostApi.initialize';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late pigeon.InitConfig captured;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(_initChannel, (ByteData? message) async {
          final args =
              pigeon.PersonalizationHostApi.pigeonChannelCodec.decodeMessage(
                    message,
                  )
                  as List<Object?>;
          captured = args[0] as pigeon.InitConfig;
          return pigeon.PersonalizationHostApi.pigeonChannelCodec.encodeMessage(
            <Object?>[],
          );
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(_initChannel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  Future<void> init(SdkInitConfig config) =>
      SdkInitHandler().initialize(config);

  group('apiDomain', () {
    test('null → api.rees46.ru', () async {
      await init(const SdkInitConfig(shopId: 's'));
      expect(captured.apiDomain, 'api.rees46.ru');
    });

    test('blank → api.rees46.ru', () async {
      await init(const SdkInitConfig(shopId: 's', apiDomain: '   '));
      expect(captured.apiDomain, 'api.rees46.ru');
    });

    test('provided → trimmed', () async {
      await init(
        const SdkInitConfig(shopId: 's', apiDomain: ' custom.api.com '),
      );
      expect(captured.apiDomain, 'custom.api.com');
    });
  });

  group('stream', () {
    test('null on Android → android', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await init(const SdkInitConfig(shopId: 's'));
      expect(captured.stream, 'android');
    });

    test('null on iOS → ios', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await init(const SdkInitConfig(shopId: 's'));
      expect(captured.stream, 'ios');
    });

    test('blank → platform default', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await init(const SdkInitConfig(shopId: 's', stream: ''));
      expect(captured.stream, 'android');
    });

    test('provided → trimmed', () async {
      await init(const SdkInitConfig(shopId: 's', stream: ' web '));
      expect(captured.stream, 'web');
    });
  });

  group('bool defaults', () {
    test('enableLogs null → false', () async {
      await init(const SdkInitConfig(shopId: 's'));
      expect(captured.enableLogs, false);
    });

    test('enableLogs true → true', () async {
      await init(const SdkInitConfig(shopId: 's', enableLogs: true));
      expect(captured.enableLogs, true);
    });

    test('autoSendPushToken null → true', () async {
      await init(const SdkInitConfig(shopId: 's'));
      expect(captured.autoSendPushToken, true);
    });

    test('autoSendPushToken false → false', () async {
      await init(const SdkInitConfig(shopId: 's', autoSendPushToken: false));
      expect(captured.autoSendPushToken, false);
    });

    test('sendAdvertisingId null → false', () async {
      await init(const SdkInitConfig(shopId: 's'));
      expect(captured.sendAdvertisingId, false);
    });

    test('enableAutoPopupPresentation null → true', () async {
      await init(const SdkInitConfig(shopId: 's'));
      expect(captured.enableAutoPopupPresentation, true);
    });

    test('needReInitialization null → false', () async {
      await init(const SdkInitConfig(shopId: 's'));
      expect(captured.needReInitialization, false);
    });
  });

  test('shopId passed through unchanged', () async {
    await init(const SdkInitConfig(shopId: 'my_shop_123'));
    expect(captured.shopId, 'my_shop_123');
  });
}
