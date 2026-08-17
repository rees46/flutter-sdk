import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/src/personalization_sdk.dart';
import 'package:rees46_sdk/src/pigeon/personalization_api.g.dart' as pigeon;

/// F2 contract: a [PersonalizationSdk] handle threads its own `shopId` as the
/// trailing argument of every per-instance Pigeon call, so the native bridge can
/// route to that shop. A legacy default handle (`shopId == null`) sends `null` —
/// the single/default-instance fallback.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sidChannel =
      'dev.flutter.pigeon.personalization_flutter_sdk.PersonalizationHostApi.getSid';
  const trackChannel =
      'dev.flutter.pigeon.personalization_flutter_sdk.PersonalizationHostApi.trackEvent';

  late List<Object?> capturedGetSidArgs;
  late List<Object?> capturedTrackArgs;

  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMessageHandler(sidChannel, (message) async {
      capturedGetSidArgs =
          pigeon.PersonalizationHostApi.pigeonChannelCodec.decodeMessage(
                message,
              )
              as List<Object?>;
      return pigeon.PersonalizationHostApi.pigeonChannelCodec.encodeMessage(
        <Object?>['sid-123'],
      );
    });
    messenger.setMockMessageHandler(trackChannel, (message) async {
      capturedTrackArgs =
          pigeon.PersonalizationHostApi.pigeonChannelCodec.decodeMessage(
                message,
              )
              as List<Object?>;
      return pigeon.PersonalizationHostApi.pigeonChannelCodec.encodeMessage(
        <Object?>[],
      );
    });
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMessageHandler(sidChannel, null);
    messenger.setMockMessageHandler(trackChannel, null);
  });

  test('getSid sends the handle shopId as the sole argument', () async {
    await PersonalizationSdk(shopId: 'shop-A').getSid();
    expect(capturedGetSidArgs, ['shop-A']);
  });

  test('default handle (no shopId) sends null', () async {
    await PersonalizationSdk().getSid();
    expect(capturedGetSidArgs, [null]);
  });

  test('trackEvent sends shopId as the trailing argument', () async {
    await PersonalizationSdk(shopId: 'shop-B').trackEvent('view');
    // event, time, category, label, value, customFieldsJson, shopId
    expect(capturedTrackArgs.length, 7);
    expect(capturedTrackArgs.first, 'view');
    expect(capturedTrackArgs.last, 'shop-B');
  });
}
