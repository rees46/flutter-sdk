import 'package:flutter/foundation.dart';

import '../pigeon/personalization_api.g.dart' as pigeon;
import '../push/push_notification_callbacks.dart';

/// Process-global sink for inbound push callbacks from native.
///
/// There is one Pigeon `PersonalizationFlutterApi` channel per plugin, so a
/// single dispatcher owns it (set up once) and routes each callback — which now
/// carries the `shopId` the push resolved to natively — to that shop's
/// registered [PushNotificationCallbacks]. Every [PersonalizationSdk] registers
/// its callbacks here on construction.
///
/// Routing mirrors the push contract: a known `shopId` delivers to that shop; an
/// unknown one drops; a null `shopId` (legacy payload without `shop_id`) falls
/// back to the single registered target, and drops when several are registered.
class PushDispatcher implements pigeon.PersonalizationFlutterApi {
  PushDispatcher._() {
    pigeon.PersonalizationFlutterApi.setUp(this);
  }

  static final PushDispatcher instance = PushDispatcher._();

  final Map<String, PushNotificationCallbacks> _byShop =
      <String, PushNotificationCallbacks>{};

  /// The legacy default handle (`shopId == null`), if any.
  PushNotificationCallbacks? _default;

  /// Registers [callbacks] as the sink for [shopId] (or the default when null).
  void register(String? shopId, PushNotificationCallbacks callbacks) {
    if (shopId != null) {
      _byShop[shopId] = callbacks;
    } else {
      _default = callbacks;
    }
  }

  PushNotificationCallbacks? _resolve(String? shopId) {
    if (shopId != null) {
      return _byShop[shopId]; // unknown shop → drop
    }
    final targets = <PushNotificationCallbacks>[..._byShop.values, ?_default];
    return targets.length == 1
        ? targets.first
        : null; // several → ambiguous drop
  }

  @override
  void onPushReceived(String? shopId, Map<String, String?> payload) {
    _resolve(shopId)?.onPushReceived(payload);
  }

  @override
  void onPushDelivered(String? shopId, Map<String, String?> payload) {
    _resolve(shopId)?.onPushDelivered(payload);
  }

  @override
  void onPushClicked(String? shopId, Map<String, String?> payload) {
    _resolve(shopId)?.onPushClicked(payload);
  }

  /// Test-only: drops all registrations.
  @visibleForTesting
  void reset() {
    _byShop.clear();
    _default = null;
  }
}
