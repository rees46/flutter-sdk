import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/rees46_sdk.dart';
import 'package:rees46_sdk/src/pigeon/personalization_api.g.dart' as pigeon;

const _manageSubscriptionChannel =
    'dev.flutter.pigeon.personalization_flutter_sdk.PersonalizationHostApi.manageSubscription';

// Push channels registered by PersonalizationFlutterApi.setUp in the SDK ctor.
const _pushChannels = [
  'dev.flutter.pigeon.personalization_flutter_sdk.PersonalizationFlutterApi.onPushReceived',
  'dev.flutter.pigeon.personalization_flutter_sdk.PersonalizationFlutterApi.onPushDelivered',
  'dev.flutter.pigeon.personalization_flutter_sdk.PersonalizationFlutterApi.onPushClicked',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const codec = pigeon.PersonalizationHostApi.pigeonChannelCodec;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<Object?> sentArgs;

  setUp(() {
    for (final channel in _pushChannels) {
      messenger.setMockMessageHandler(
        channel,
        (_) async => codec.encodeMessage(<Object?>[]),
      );
    }
    messenger.setMockMessageHandler(_manageSubscriptionChannel, (
      ByteData? message,
    ) async {
      sentArgs = codec.decodeMessage(message) as List<Object?>;
      return codec.encodeMessage(<Object?>[]);
    });
  });

  tearDown(() {
    for (final channel in [..._pushChannels, _manageSubscriptionChannel]) {
      messenger.setMockMessageHandler(channel, null);
    }
  });

  pigeon.ManageSubscriptionParamsWire sentWire() =>
      sentArgs[0] as pigeon.ManageSubscriptionParamsWire;

  test(
    'contacts and Telegram, WhatsApp, Max, Wallet flags reach the bridge',
    () async {
      await PersonalizationSdk().manageSubscription(
        const ManageSubscriptionParams(
          phone: '+79990000000',
          externalId: 'ext-1',
          loyaltyId: 'loy-1',
          telegramId: 'tg-1',
          telegramBulk: true,
          telegramChain: false,
          telegramTransactional: true,
          whatsappBulk: false,
          whatsappChain: true,
          whatsappTransactional: false,
          maxBulk: true,
          maxChain: false,
          maxTransactional: true,
          walletBulk: false,
        ),
      );

      final wire = sentWire();
      expect(wire.phone, '+79990000000');
      expect(wire.externalId, 'ext-1');
      expect(wire.loyaltyId, 'loy-1');
      expect(wire.telegramId, 'tg-1');
      expect(
        [wire.telegramBulk, wire.telegramChain, wire.telegramTransactional],
        [true, false, true],
      );
      expect(
        [wire.whatsappBulk, wire.whatsappChain, wire.whatsappTransactional],
        [false, true, false],
      );
      expect(
        [wire.maxBulk, wire.maxChain, wire.maxTransactional],
        [true, false, true],
      );
      expect(wire.walletBulk, false);
    },
  );

  test(
    'email, SMS and push flags reach the bridge, untouched ones stay null',
    () async {
      await PersonalizationSdk().manageSubscription(
        const ManageSubscriptionParams(
          email: 'user@example.com',
          emailBulk: true,
          smsChain: false,
          webPushTransactional: true,
          mobilePushBulk: false,
        ),
      );

      final wire = sentWire();
      expect(wire.email, 'user@example.com');
      expect(wire.emailBulk, true);
      expect(wire.smsChain, false);
      expect(wire.webPushTransactional, true);
      expect(wire.mobilePushBulk, false);
      expect(wire.phone, isNull);
      expect(wire.emailChain, isNull);
      expect(wire.telegramBulk, isNull);
      expect(wire.walletBulk, isNull);
    },
  );

  test('a handle bound to a shop sends its shop id', () async {
    await PersonalizationSdk(
      shopId: 'shop-b',
    ).manageSubscription(const ManageSubscriptionParams(walletBulk: true));

    expect(sentArgs[1], 'shop-b');
    expect(sentWire().walletBulk, true);
  });
}
