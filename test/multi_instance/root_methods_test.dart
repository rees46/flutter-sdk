import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/rees46_sdk.dart';
import 'package:rees46_sdk/src/pigeon/personalization_api.g.dart' as pigeon;
import 'package:rees46_sdk/src/popups/popup_dispatcher.dart';
import 'package:rees46_sdk/src/popups/popup_presenter.dart';

import '../support/wire.dart';

const _methods = [
  'initialize',
  'flush',
  'release',
  'deleteUserCredentials',
  'cartGet',
];

Matcher get _notInitialized => throwsA(
  isA<SdkException>().having(
    (e) => e.error,
    'error',
    isA<SdkErrorNotInitialized>(),
  ),
);

/// A fake channel whose calls are the fake's own: the root methods still refuse
/// a released handle.
class _FakeApi extends pigeon.PersonalizationHostApi {
  int flushes = 0;
  final released = <String?>[];

  @override
  Future<void> flush(String? shopId) async => flushes++;

  @override
  Future<void> release(String? shopId) async => released.add(shopId);
}

// The root of the shop's handle: flush, release and deleteUserCredentials go to
// the native instance by the shop's id; a released handle takes no call and
// leaves the registry, and the shop can be initialized again.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    for (final m in _methods) {
      unstub(m);
    }
    REES46.reset();
    PopupDispatcher.instance.reset();
    PopupPresenter.reset();
  });

  /// A shop initialized through the facade, ready with `did-1`.
  Future<PersonalizationSdk> live(String shopId) async {
    stubValue('initialize', snapshotWire(shopId));
    final sdk = REES46.initialize(REES46Config(shopId: shopId));
    await sdk.ready;
    return sdk;
  }

  group('flush', () {
    test('asks the shop of the handle and completes', () async {
      final calls = stubValue('flush', null);

      await PersonalizationSdk(shopId: 's').flush();

      expect(calls, [
        ['s'],
      ]);
    });

    test('a native notInitialized is an SdkException', () async {
      stubHost('flush', (_) => errorReply('notInitialized'));

      await expectLater(
        PersonalizationSdk(shopId: 's').flush(),
        _notInitialized,
      );
    });
  });

  group('deleteUserCredentials', () {
    test('asks the shop of the handle and mirrors the state after the wipe, '
        'then the new device id', () async {
      final sdk = await live('shop-a');
      expect(sdk.deviceId, 'did-1');
      final calls = stubValue(
        'deleteUserCredentials',
        snapshotWire(
          'shop-a',
          state: 'initializing',
          deviceId: null,
          sessionId: null,
        ),
      );
      final states = <SdkState>[];
      final subscription = sdk.stateChanges.listen(states.add);

      await sdk.deleteUserCredentials();

      expect(calls, [
        ['shop-a'],
      ]);
      expect(sdk.deviceId, isNull);
      expect(sdk.sessionId, isNull);
      expect(sdk.state, SdkState.initializing);

      await sendStateEvent('onSnapshot', <Object?>[
        snapshotWire('shop-a', deviceId: 'did-2', sessionId: 'sid-2'),
      ]);
      await pumpEventQueue();
      expect(sdk.deviceId, 'did-2');
      expect(sdk.sessionId, 'sid-2');
      expect(sdk.state, SdkState.ready);
      expect(states, [SdkState.ready, SdkState.initializing, SdkState.ready]);
      await subscription.cancel();
    });

    test('a native failure is an SdkException and leaves the mirror', () async {
      final sdk = await live('shop-a');
      stubHost('deleteUserCredentials', (_) => errorReply('notInitialized'));

      await expectLater(sdk.deleteUserCredentials(), _notInitialized);
      expect(sdk.deviceId, 'did-1');
    });
  });

  group('release', () {
    test('releases the native instance of the shop once', () async {
      final sdk = await live('shop-a');
      final calls = stubValue('release', null);

      sdk.release();
      sdk.release();
      await pumpEventQueue();

      expect(calls, [
        ['shop-a'],
      ]);
    });

    test('every later call of the handle is notInitialized and reaches no '
        'native code', () async {
      final sdk = await live('shop-a');
      stubValue('release', null);
      final flushes = stubValue('flush', null);
      final deletes = stubValue('deleteUserCredentials', snapshotWire('a'));
      final carts = stubValue('cartGet', <Object?>[]);

      sdk.release();

      await expectLater(sdk.flush(), _notInitialized);
      await expectLater(sdk.deleteUserCredentials(), _notInitialized);
      await expectLater(sdk.cart.get(), _notInitialized);
      await expectLater(
        sdk.initialize(SdkInitConfig(shopId: 'shop-a')),
        _notInitialized,
      );
      expect(flushes, isEmpty);
      expect(deletes, isEmpty);
      expect(carts, isEmpty);
    });

    test('the handle reads notInitialized and keeps the last device id and '
        'session; its stateChanges end', () async {
      final sdk = await live('shop-a');
      stubValue('release', null);
      final states = <SdkState>[];
      final done = Completer<void>();
      sdk.stateChanges.listen(states.add, onDone: done.complete);
      await pumpEventQueue();

      sdk.release();
      await done.future;

      expect(states, [SdkState.ready, SdkState.notInitialized]);
      expect(sdk.state, SdkState.notInitialized);
      expect(sdk.deviceId, 'did-1');
      expect(sdk.sessionId, 'sid-1');
      expect(await sdk.stateChanges.toList(), [SdkState.notInitialized]);
    });

    test('the shop leaves the registry', () async {
      final sdk = await live('shop-a');
      stubValue('release', null);

      sdk.release();

      expect(REES46.isInitialized('shop-a'), isFalse);
      expect(REES46.liveShopIds, isEmpty);
      expect(
        () => REES46.getInstance('shop-a'),
        throwsA(isA<UnknownShopIdException>()),
      );
    });

    test('a new initialize of the shop makes a fresh, ready handle; the '
        'released one stays out of it', () async {
      final old = await live('shop-a');
      stubValue('release', null);
      old.release();

      stubValue(
        'initialize',
        snapshotWire('shop-a', deviceId: 'did-1', sessionId: 'sid-9'),
      );
      final fresh = REES46.initialize(const REES46Config(shopId: 'shop-a'));
      await fresh.ready;
      final carts = stubValue('cartGet', <Object?>[]);

      expect(identical(fresh, old), isFalse);
      expect(fresh.state, SdkState.ready);
      expect(fresh.sessionId, 'sid-9');
      expect(identical(REES46.getInstance('shop-a'), fresh), isTrue);
      expect(old.state, SdkState.notInitialized);
      expect(old.sessionId, 'sid-1');
      await fresh.cart.get();
      await expectLater(old.cart.get(), _notInitialized);
      expect(carts, [
        ['shop-a'],
      ]);
    });

    test('a release during the init fails ready with notInitialized', () async {
      stubValue(
        'initialize',
        snapshotWire('slow', state: 'initializing', deviceId: null),
      );
      stubValue('release', null);
      final sdk = REES46.initialize(const REES46Config(shopId: 'slow'));
      final outcome = expectLater(sdk.ready, _notInitialized);
      await pumpEventQueue();

      sdk.release();

      await outcome;
    });

    test('a release before the native init answered keeps the shop out of '
        'the mirrors', () async {
      final answer = Completer<pigeon.SdkSnapshotWire>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(
            hostChannel('initialize'),
            (_) async => okReply(await answer.future),
          );
      stubValue('release', null);
      final sdk = REES46.initialize(const REES46Config(shopId: 'late'));
      final outcome = expectLater(sdk.ready, _notInitialized);

      sdk.release();
      answer.complete(snapshotWire('late'));
      await outcome;

      expect(sdk.state, SdkState.notInitialized);
      expect(PersonalizationSdk(shopId: 'late').state, SdkState.notInitialized);
    });

    testWidgets('popups of the shop no longer reach the released handle', (
      tester,
    ) async {
      final sdk = await live('shop-a');
      stubValue('release', null);
      final taken = <InAppPopup>[];
      sdk.onPopup = taken.add;

      sdk.release();
      PopupDispatcher.instance.onPopup(
        'shop-a',
        jsonEncode(<String, Object?>{
          'id': 1,
          'position': 'centered',
          'delay': 0,
          'components': <String, Object?>{'header': 'Popup'},
        }),
      );
      await tester.pump(Duration.zero);

      expect(taken, isEmpty);
    });

    test('the push callbacks of the released shop are dropped', () async {
      final sdk = await live('shop-a');
      stubValue('release', null);
      final opened = <PushPayload>[];
      final shared = <PushPayload>[];
      sdk.notifications.setCallbacks(PushCallbacks(onOpened: opened.add));
      REES46.setPushCallbacks(PushCallbacks(onOpened: shared.add));

      sdk.release();
      await sendStateEvent('onPushEvent', <Object?>[
        'shop-a',
        'opened',
        pigeon.PushPayloadWire(
          shopId: 'shop-a',
          code: 'c',
          type: 'bulk',
          actions: const [],
          data: const {},
        ),
      ]);

      expect(opened, isEmpty);
      expect(shared.single.shopId, 'shop-a');
    });

    test('a handle on a channel of its own refuses the root methods after '
        'release', () async {
      final api = _FakeApi();
      final sdk = PersonalizationSdk(api: api, shopId: 's');

      await sdk.flush();
      sdk.release();
      await pumpEventQueue();

      await expectLater(sdk.flush(), _notInitialized);
      await expectLater(sdk.deleteUserCredentials(), _notInitialized);
      expect(api.flushes, 1);
      expect(api.released, ['s']);
    });
  });
}
