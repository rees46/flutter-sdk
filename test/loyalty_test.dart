import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/rees46_sdk.dart';
import 'package:rees46_sdk/src/pigeon/personalization_api.g.dart' as pigeon;

const _joinChannel =
    'dev.flutter.pigeon.personalization_flutter_sdk.PersonalizationHostApi.loyaltyJoin';
const _statusChannel =
    'dev.flutter.pigeon.personalization_flutter_sdk.PersonalizationHostApi.loyaltyGetStatus';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messageCodec = pigeon.PersonalizationHostApi.pigeonChannelCodec;
  ByteData reply(Object value) => messageCodec.encodeMessage([value])!;

  void stub(String channel, Object json) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(channel, (_) async => reply(json));
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(_joinChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(_statusChannel, null);
  });

  // -------------------------------------------------------------------------
  // joinLoyalty
  // -------------------------------------------------------------------------
  group('joinLoyalty', () {
    test('answers with the member the native join made', () async {
      stub(_joinChannel, pigeon.LoyaltyMemberWire(identifier: '79991234567'));

      final r = await PersonalizationSdk().joinLoyalty(phone: '79991234567');
      expect(r, isA<LoyaltyJoinResponse>());
      expect(r.status, equals('success'));
      expect(r.payload['identifier'], equals('79991234567'));
    });

    test('a failure of the native join is an SdkException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(
            _joinChannel,
            (_) async => messageCodec.encodeMessage([
              'decoding',
              'The answer could not be read',
              <String, Object?>{'httpCode': null, 'serverCode': null},
            ]),
          );

      await expectLater(
        PersonalizationSdk().joinLoyalty(phone: '79991234567'),
        throwsA(
          isA<SdkException>()
              .having((e) => e.error, 'error', isA<SdkErrorDecoding>())
              .having((e) => e, 'released type', isA<PlatformException>()),
        ),
      );
    });

    test('empty phone throws ArgumentError (no native call)', () async {
      expect(
        () => PersonalizationSdk().joinLoyalty(phone: ''),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  // -------------------------------------------------------------------------
  // getLoyaltyStatus
  // -------------------------------------------------------------------------
  group('getLoyaltyStatus', () {
    test('parses member and level', () async {
      stub(
        _statusChannel,
        pigeon.LoyaltyStatusWire(
          isMember: true,
          level: pigeon.LoyaltyLevelWire(
            code: 'gold',
            name: 'Gold',
            expirationDate: '2026-12-31',
          ),
        ),
      );

      final r = await PersonalizationSdk().getLoyaltyStatus('79991234567');
      expect(r, isA<LoyaltyStatusResponse>());
      expect(r.status, equals('success'));
      expect(r.member, isTrue);
      expect(r.level?.name, equals('Gold'));
      expect(r.level?.code, equals('gold'));
      expect(r.level?.expirationDate, equals('2026-12-31'));
    });

    test('absent level parses to null, non-member', () async {
      stub(_statusChannel, pigeon.LoyaltyStatusWire(isMember: false));

      final r = await PersonalizationSdk().getLoyaltyStatus('79991234567');
      expect(r.member, isFalse);
      expect(r.level, isNull);
    });

    test('empty identifier throws ArgumentError (no native call)', () async {
      expect(
        () => PersonalizationSdk().getLoyaltyStatus(''),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
