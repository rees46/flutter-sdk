import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personalization_flutter_sdk/personalization_flutter_sdk.dart';
import 'package:personalization_flutter_sdk/src/pigeon/personalization_api.g.dart'
    as pigeon;

const _setProfileChannel =
    'dev.flutter.pigeon.personalization_flutter_sdk.PersonalizationHostApi.setProfile';
const _getSidChannel =
    'dev.flutter.pigeon.personalization_flutter_sdk.PersonalizationHostApi.getSid';
const _getDidChannel =
    'dev.flutter.pigeon.personalization_flutter_sdk.PersonalizationHostApi.getDid';

// Push channels registered by PersonalizationFlutterApi.setUp in the SDK ctor.
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
    mockChannel(_onReceivedChannel, successHandler());
    mockChannel(_onDeliveredChannel, successHandler());
    mockChannel(_onClickedChannel, successHandler());
    mockChannel(_setProfileChannel, successHandler());
    mockChannel(
      _getSidChannel,
      (_) async => codec.encodeMessage(<Object?>['sid-stub']),
    );
    mockChannel(
      _getDidChannel,
      (_) async => codec.encodeMessage(<Object?>['did-stub']),
    );
  });

  tearDown(() {
    for (final ch in [
      _onReceivedChannel,
      _onDeliveredChannel,
      _onClickedChannel,
      _setProfileChannel,
      _getSidChannel,
      _getDidChannel,
    ]) {
      unmockChannel(ch);
    }
  });

  pigeon.ProfileParamsWire Function() captureWire() {
    pigeon.ProfileParamsWire? captured;
    mockChannel(_setProfileChannel, (ByteData? msg) async {
      final args = codec.decodeMessage(msg) as List<Object?>;
      captured = args[0] as pigeon.ProfileParamsWire;
      return codec.encodeMessage(<Object?>[]);
    });
    return () => captured!;
  }

  // ---------------------------------------------------------------------------
  // toWire: field mapping
  // ---------------------------------------------------------------------------
  group('ProfileParams.toWire field mapping', () {
    test('all string fields map to correct wire fields', () {
      final wire = const ProfileParams(
        email: 'user@example.com',
        phone: '+79001234567',
        loyaltyId: 'loyalty-42',
        firstName: 'Ivan',
        lastName: 'Petrov',
        birthday: '1990-06-15',
        location: 'Moscow',
        advertisingId: 'adv-id-123',
        fbId: 'fb-456',
        vkId: 'vk-789',
        telegramId: 'tg-000',
        loyaltyCardLocation: 'store-1',
        loyaltyStatus: 'gold',
        userId: 'user-99',
      ).toWire();

      expect(wire.email, 'user@example.com');
      expect(wire.phone, '+79001234567');
      expect(wire.loyaltyId, 'loyalty-42');
      expect(wire.firstName, 'Ivan');
      expect(wire.lastName, 'Petrov');
      expect(wire.birthday, '1990-06-15');
      expect(wire.location, 'Moscow');
      expect(wire.advertisingId, 'adv-id-123');
      expect(wire.fbId, 'fb-456');
      expect(wire.vkId, 'vk-789');
      expect(wire.telegramId, 'tg-000');
      expect(wire.loyaltyCardLocation, 'store-1');
      expect(wire.loyaltyStatus, 'gold');
      expect(wire.userId, 'user-99');
    });

    test('int and bool fields map correctly', () {
      final wire = const ProfileParams(
        age: 33,
        loyaltyBonuses: 500,
        loyaltyBonusesToNextLevel: 1000,
        boughtSomething: true,
      ).toWire();

      expect(wire.age, 33);
      expect(wire.loyaltyBonuses, 500);
      expect(wire.loyaltyBonusesToNextLevel, 1000);
      expect(wire.boughtSomething, true);
    });

    test('all fields null when ProfileParams is empty', () {
      final wire = const ProfileParams().toWire();

      expect(wire.email, isNull);
      expect(wire.phone, isNull);
      expect(wire.loyaltyId, isNull);
      expect(wire.firstName, isNull);
      expect(wire.lastName, isNull);
      expect(wire.birthday, isNull);
      expect(wire.age, isNull);
      expect(wire.gender, isNull);
      expect(wire.location, isNull);
      expect(wire.advertisingId, isNull);
      expect(wire.fbId, isNull);
      expect(wire.vkId, isNull);
      expect(wire.telegramId, isNull);
      expect(wire.loyaltyCardLocation, isNull);
      expect(wire.loyaltyStatus, isNull);
      expect(wire.loyaltyBonuses, isNull);
      expect(wire.loyaltyBonusesToNextLevel, isNull);
      expect(wire.boughtSomething, isNull);
      expect(wire.userId, isNull);
      expect(wire.customPropertiesJson, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // toWire: gender enum
  // ---------------------------------------------------------------------------
  group('ProfileParams.toWire gender', () {
    test('male → "m"', () {
      expect(
        const ProfileParams(gender: ProfileGender.male).toWire().gender,
        'm',
      );
    });

    test('female → "f"', () {
      expect(
        const ProfileParams(gender: ProfileGender.female).toWire().gender,
        'f',
      );
    });

    test('null gender → null wire gender', () {
      expect(const ProfileParams().toWire().gender, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // toWire: customProperties JSON
  // ---------------------------------------------------------------------------
  group('ProfileParams.toWire customProperties', () {
    test('null customProperties → null customPropertiesJson', () {
      expect(const ProfileParams().toWire().customPropertiesJson, isNull);
    });

    test('customProperties serialized to valid JSON', () {
      final wire = const ProfileParams(
        customProperties: {'club': 'vip', 'score': 42},
      ).toWire();

      expect(wire.customPropertiesJson, isNotNull);
      final decoded =
          jsonDecode(wire.customPropertiesJson!) as Map<String, dynamic>;
      expect(decoded['club'], 'vip');
      expect(decoded['score'], 42);
    });

    test('customProperties with null value keeps key in JSON', () {
      final wire = const ProfileParams(
        customProperties: {'present': 'yes', 'absent': null},
      ).toWire();

      final decoded =
          jsonDecode(wire.customPropertiesJson!) as Map<String, dynamic>;
      expect(decoded.containsKey('absent'), true);
      expect(decoded['absent'], isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // setProfile channel
  // ---------------------------------------------------------------------------
  group('setProfile channel', () {
    test('sends ProfileParamsWire at args[0]', () async {
      final getWire = captureWire();
      await PersonalizationSdk().setProfile(
        const ProfileParams(email: 'a@b.com', phone: '+7000'),
      );
      expect(getWire().email, 'a@b.com');
      expect(getWire().phone, '+7000');
    });

    test('empty ProfileParams does not throw', () {
      final sdk = PersonalizationSdk();
      expect(() => sdk.setProfile(const ProfileParams()), returnsNormally);
    });

    test('gender is encoded as string in wire sent over channel', () async {
      final getWire = captureWire();
      await PersonalizationSdk().setProfile(
        const ProfileParams(gender: ProfileGender.female),
      );
      expect(getWire().gender, 'f');
    });
  });

  // ---------------------------------------------------------------------------
  // getSid
  // ---------------------------------------------------------------------------
  group('getSid', () {
    test('returns value from channel', () async {
      mockChannel(
        _getSidChannel,
        (_) async => codec.encodeMessage(<Object?>['session-abc-123']),
      );
      final sid = await PersonalizationSdk().getSid();
      expect(sid, 'session-abc-123');
    });

    test('returns different values on subsequent calls', () async {
      var callCount = 0;
      final responses = ['sid-first', 'sid-second'];
      mockChannel(_getSidChannel, (_) async {
        return codec.encodeMessage(<Object?>[responses[callCount++]]);
      });
      final sdk = PersonalizationSdk();
      expect(await sdk.getSid(), 'sid-first');
      expect(await sdk.getSid(), 'sid-second');
    });
  });

  // ---------------------------------------------------------------------------
  // getDid
  // ---------------------------------------------------------------------------
  group('getDid', () {
    test('returns device ID from channel', () async {
      mockChannel(
        _getDidChannel,
        (_) async => codec.encodeMessage(<Object?>['device-xyz-456']),
      );
      final did = await PersonalizationSdk().getDid();
      expect(did, 'device-xyz-456');
    });

    test('returns null when channel returns null', () async {
      mockChannel(
        _getDidChannel,
        (_) async => codec.encodeMessage(<Object?>[null]),
      );
      final did = await PersonalizationSdk().getDid();
      expect(did, isNull);
    });
  });
}
