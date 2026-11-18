import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/rees46_sdk.dart';
import 'package:rees46_sdk/src/pigeon/personalization_api.g.dart' as pigeon;

const _setProfileChannel =
    'dev.flutter.pigeon.personalization_flutter_sdk.PersonalizationHostApi.profileSet';
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

  pigeon.ProfileUpdateRequestWire Function() captureWire() {
    pigeon.ProfileUpdateRequestWire? captured;
    mockChannel(_setProfileChannel, (ByteData? msg) async {
      final args = codec.decodeMessage(msg) as List<Object?>;
      captured = args[0] as pigeon.ProfileUpdateRequestWire;
      return codec.encodeMessage(<Object?>[]);
    });
    return () => captured!;
  }

  // ---------------------------------------------------------------------------
  // toWire: field mapping
  // ---------------------------------------------------------------------------
  group('ProfileParams.toWire field mapping', () {
    test('the fields of ProfileUpdateRequest map one to one', () {
      final wire = const ProfileParams(
        email: 'user@example.com',
        phone: '+79001234567',
        loyaltyId: 'loyalty-42',
        firstName: 'Ivan',
        lastName: 'Petrov',
        birthday: '1990-06-15',
        location: 'Moscow',
        fbId: 'fb-456',
        vkId: 'vk-789',
        telegramId: 'tg-000',
        age: 33,
        userId: 'user-99',
      ).toWire();

      expect(wire.email, 'user@example.com');
      expect(wire.phone, '+79001234567');
      expect(wire.loyaltyId, 'loyalty-42');
      expect(wire.firstName, 'Ivan');
      expect(wire.lastName, 'Petrov');
      expect(wire.birthday, '1990-06-15');
      expect(wire.location, 'Moscow');
      expect(wire.fbId, 'fb-456');
      expect(wire.vkId, 'vk-789');
      expect(wire.telegramId, 'tg-000');
      expect(wire.age, 33);
      // The shop's id of the customer: sent as `id` and `external_id`.
      expect(wire.externalId, 'user-99');
      expect(wire.customProperties, isNull);
    });

    test('the fields the contract left out go as free-form fields', () {
      final wire = const ProfileParams(
        advertisingId: 'adv-id-123',
        loyaltyCardLocation: 'store-1',
        loyaltyStatus: 'gold',
        loyaltyBonuses: 500,
        loyaltyBonusesToNextLevel: 1000,
        boughtSomething: true,
      ).toWire();

      expect(wire.customProperties, {
        'loyalty_card_location': 'store-1',
        'loyalty_status': 'gold',
        'loyalty_bonuses': 500,
        'loyalty_bonuses_to_next_level': 1000,
        'bought_something': '1',
        // The test platform is Android.
        'google_advertising_id': 'adv-id-123',
      });
    });

    test('on iOS the advertising id is apple_advertising_id', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final wire = const ProfileParams(advertisingId: 'idfa').toWire();
      expect(wire.customProperties, {'apple_advertising_id': 'idfa'});
    });

    test('all fields null when ProfileParams is empty', () {
      final wire = const ProfileParams().toWire();

      expect(wire.email, isNull);
      expect(wire.phone, isNull);
      expect(wire.externalId, isNull);
      expect(wire.loyaltyId, isNull);
      expect(wire.telegramId, isNull);
      expect(wire.fbId, isNull);
      expect(wire.vkId, isNull);
      expect(wire.firstName, isNull);
      expect(wire.lastName, isNull);
      expect(wire.gender, isNull);
      expect(wire.birthday, isNull);
      expect(wire.age, isNull);
      expect(wire.location, isNull);
      expect(wire.kids, isNull);
      expect(wire.cars, isNull);
      expect(wire.customProperties, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // toWire: gender enum
  // ---------------------------------------------------------------------------
  group('ProfileParams.toWire gender', () {
    test('male → "m"', () {
      expect(const ProfileParams(gender: Gender.male).toWire().gender, 'm');
    });

    test('female → "f"', () {
      expect(const ProfileParams(gender: Gender.female).toWire().gender, 'f');
    });

    test('null gender → null wire gender', () {
      expect(const ProfileParams().toWire().gender, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // toWire: customProperties
  // ---------------------------------------------------------------------------
  group('ProfileParams.toWire customProperties', () {
    test('null customProperties → null', () {
      expect(const ProfileParams().toWire().customProperties, isNull);
    });

    test('customProperties keep their types', () {
      final wire = const ProfileParams(
        customProperties: {
          'club': 'vip',
          'score': 42,
          'tags': ['a', 'b'],
        },
      ).toWire();

      expect(wire.customProperties!['club'], 'vip');
      expect(wire.customProperties!['score'], 42);
      expect(wire.customProperties!['tags'], ['a', 'b']);
    });

    test('customProperties with null value keeps the key', () {
      final wire = const ProfileParams(
        customProperties: {'present': 'yes', 'absent': null},
      ).toWire();

      expect(wire.customProperties!.containsKey('absent'), true);
      expect(wire.customProperties!['absent'], isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // setProfile channel
  // ---------------------------------------------------------------------------
  group('setProfile channel', () {
    test('sends ProfileUpdateRequestWire at args[0]', () async {
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
        const ProfileParams(gender: Gender.female),
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
