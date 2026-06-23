import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/rees46_sdk.dart';
import 'package:rees46_sdk/src/pigeon/personalization_api.g.dart' as pigeon;

const _joinChannel =
    'dev.flutter.pigeon.personalization_flutter_sdk.PersonalizationHostApi.joinLoyalty';
const _statusChannel =
    'dev.flutter.pigeon.personalization_flutter_sdk.PersonalizationHostApi.getLoyaltyStatus';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messageCodec = pigeon.PersonalizationHostApi.pigeonChannelCodec;
  ByteData reply(String value) => messageCodec.encodeMessage([value])!;

  void stub(String channel, String json) {
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
    test('parses status and raw payload', () async {
      stub(
        _joinChannel,
        jsonEncode({
          'status': 'success',
          'payload': {'member_id': 42, 'created': true},
        }),
      );

      final r = await PersonalizationSdk().joinLoyalty(phone: '79991234567');
      expect(r, isA<LoyaltyJoinResponse>());
      expect(r.status, equals('success'));
      expect(r.payload['member_id'], equals(42));
      expect(r.payload['created'], isTrue);
    });

    test('missing payload defaults to empty map', () async {
      stub(_joinChannel, jsonEncode({'status': 'success'}));

      final r = await PersonalizationSdk().joinLoyalty(phone: '79991234567');
      expect(r.status, equals('success'));
      expect(r.payload, isEmpty);
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
        jsonEncode({
          'status': 'success',
          'payload': {
            'member': true,
            'level': {
              'name': 'Gold',
              'code': 'gold',
              'expiration_date': '2026-12-31',
            },
          },
        }),
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
      stub(
        _statusChannel,
        jsonEncode({
          'status': 'success',
          'payload': {'member': false},
        }),
      );

      final r = await PersonalizationSdk().getLoyaltyStatus('79991234567');
      expect(r.member, isFalse);
      expect(r.level, isNull);
    });

    test('missing payload parses to nulls', () async {
      stub(_statusChannel, jsonEncode({'status': 'success'}));

      final r = await PersonalizationSdk().getLoyaltyStatus('79991234567');
      expect(r.member, isNull);
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
