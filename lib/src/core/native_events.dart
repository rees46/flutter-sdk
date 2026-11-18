import 'dart:async';

import 'package:flutter/foundation.dart';

import '../errors/sdk_error.dart';
import '../models/push_models.dart';
import '../models/values.dart';
import '../namespaces/from_wire.dart';
import '../pigeon/personalization_api.g.dart' as pigeon;

/// What the bridge keeps of one shop's native instance: the copy of its local
/// values the contract reads at once — state, device id, session, A/B group, push
/// tokens, whether the search agent is on — updated by the native SDK.
class ShopMirror {
  ShopMirror(this.shopId);

  final String shopId;

  SdkState state = SdkState.notInitialized;
  String? deviceId;
  String? sessionId;
  String? segment;
  bool agentEnabled = false;
  PushToken? pushToken;
  List<PushToken> pushTokens = const [];

  /// The shop's own push callbacks (`notifications.setCallbacks`).
  PushCallbacks? pushCallbacks;

  final StreamController<SdkState> _states =
      StreamController<SdkState>.broadcast();

  /// Every change of [state].
  Stream<SdkState> get states => _states.stream;

  /// Applies a snapshot of the native instance.
  void apply(pigeon.SdkSnapshotWire snapshot) {
    final previous = state;
    state = sdkStateFromWire(snapshot.state);
    deviceId = snapshot.deviceId;
    sessionId = snapshot.sessionId;
    segment = snapshot.segment;
    agentEnabled = snapshot.agentEnabled;
    pushToken = snapshot.pushToken == null
        ? null
        : pushTokenFromWire(snapshot.pushToken!);
    pushTokens = List<PushToken>.unmodifiable(
      snapshot.pushTokens.map(pushTokenFromWire),
    );
    if (state != previous) _states.add(state);
  }

  /// Completes once the shop works: [SdkState.ready], or [SdkState.retrying] with a
  /// device id from an earlier launch. Fails with [SdkErrorShopBlocked] once the
  /// shop is refused.
  Future<void> whenUsable() {
    final now = _outcome();
    if (now != null) return now;
    final completer = Completer<void>();
    late final StreamSubscription<SdkState> subscription;
    subscription = states.listen((_) {
      final outcome = _outcome();
      if (outcome == null) return;
      subscription.cancel();
      completer.complete(outcome);
    });
    return completer.future;
  }

  Future<void>? _outcome() => switch (state) {
    SdkState.ready => Future<void>.value(),
    SdkState.retrying when (deviceId ?? '').isNotEmpty => Future<void>.value(),
    SdkState.refused => Future<void>.error(
      SdkException(const SdkErrorShopBlocked()),
    ),
    _ => null,
  };
}

/// The one receiver of what the native instances tell Dart on their own — shop
/// snapshots, push events and push tokens — for the whole process. It routes each
/// to the shop it is of.
class NativeEvents implements pigeon.PersonalizationStateFlutterApi {
  NativeEvents._() {
    pigeon.PersonalizationStateFlutterApi.setUp(this);
  }

  static final NativeEvents instance = NativeEvents._();

  final Map<String, ShopMirror> _shops = <String, ShopMirror>{};

  /// The push callbacks for every shop (`REES46.setPushCallbacks`); a shop's own
  /// win over them, callback by callback.
  PushCallbacks? sharedPushCallbacks;

  /// The mirror of [shopId], made on first use.
  ShopMirror shop(String shopId) =>
      _shops.putIfAbsent(shopId, () => ShopMirror(shopId));

  @override
  void onSnapshot(pigeon.SdkSnapshotWire snapshot) =>
      shop(snapshot.shopId).apply(snapshot);

  @override
  void onPushEvent(
    String shopId,
    String event,
    pigeon.PushPayloadWire payload,
  ) {
    final own = _shops[shopId]?.pushCallbacks;
    final shared = sharedPushCallbacks;
    final parsed = pushPayloadFromWire(payload);
    final callback = switch (event) {
      'delivered' => own?.onDelivered ?? shared?.onDelivered,
      'opened' => own?.onOpened ?? shared?.onOpened,
      'clicked' => own?.onClicked ?? shared?.onClicked,
      'closed' => own?.onClosed ?? shared?.onClosed,
      _ => null,
    };
    _guard(() => callback?.call(parsed));
  }

  @override
  void onPushToken(pigeon.PushTokenWire token) {
    final parsed = pushTokenFromWire(token);
    final owners = _shops.values
        .map((shop) => shop.pushCallbacks?.onToken)
        .whereType<void Function(PushToken)>()
        .toSet();
    final shared = sharedPushCallbacks?.onToken;
    for (final callback in {...owners, ?shared}) {
      _guard(() => callback(parsed));
    }
  }

  /// A callback of the app that throws is reported, and goes no further.
  void _guard(void Function() call) {
    try {
      call();
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'rees46_sdk',
          context: ErrorDescription('in a push callback of the app'),
        ),
      );
    }
  }

  /// Forgets every shop and the shared callbacks (`REES46.reset`, for tests).
  void reset() {
    _shops.clear();
    sharedPushCallbacks = null;
  }
}
