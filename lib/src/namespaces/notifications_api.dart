import '../core/native_events.dart';
import '../errors/sdk_error.dart';
import '../models/push_models.dart';
import '../models/values.dart';
import '../pigeon/personalization_api.g.dart' as pigeon;
import 'from_wire.dart';

/// Mobile pushes of one shop — the `notifications` namespace: the device's push
/// token, the push events an app that draws its notifications itself reports, and
/// the push callbacks. A push the plugin handles itself (its notification on
/// Android, the notification centre on iOS) is reported by the native SDK.
///
/// The push events go through the shop's queue: a call ends once the event is
/// accepted, not once the server has it. One event of one message goes once per
/// process; a repeat sends nothing and ends in success.
class NotificationsApi {
  NotificationsApi(
    this._api,
    this._shopId,
    this._mirror, {
    void Function(PushCallbacks callbacks)? onEarlyCallbacks,
  }) : _onEarlyCallbacks = onEarlyCallbacks;

  final pigeon.PersonalizationHostApi _api;
  final String? _shopId;
  final ShopMirror? Function() _mirror;

  /// Keeps callbacks set before the handle knows its shop (a handle made without
  /// a shop id, before `initialize`): they become the shop's at `initialize`.
  final void Function(PushCallbacks callbacks)? _onEarlyCallbacks;

  /// The push of message [code] (the push's `id`) of mailing [type] (`bulk`,
  /// `chain`, `transactional`, `digest`) reached the app (`track/delivered`).
  Future<void> trackDelivered(String code, String type) =>
      sdkCall(() => _api.notificationsTrackDelivered(code, type, _shopId));

  /// The notification of the push was shown (`track/opened`).
  Future<void> trackOpened(String code, String type) =>
      sdkCall(() => _api.notificationsTrackOpened(code, type, _shopId));

  /// The notification was tapped (`track/clicked`); a [type] of a mailing also sets
  /// the tracking source for 48 hours.
  Future<void> trackClicked(String code, String type) =>
      sdkCall(() => _api.notificationsTrackClicked(code, type, _shopId));

  /// The notification was dismissed without a tap (`track/closed`).
  Future<void> trackClosed(String code, String type) =>
      sdkCall(() => _api.notificationsTrackClosed(code, type, _shopId));

  /// The push token the native SDK knows for this shop, from the copy the bridge
  /// keeps: [provider]'s, or without one the token the shop sent last. Null when
  /// there is none.
  PushToken? getPushToken({PushProvider? provider}) {
    final mirror = _mirror();
    if (mirror == null) return null;
    if (provider == null) return mirror.pushToken;
    for (final token in mirror.pushTokens) {
      if (token.provider == provider) return token;
    }
    return null;
  }

  /// The push token the native SDK keeps now, read on the native side.
  Future<PushToken?> readPushToken({PushProvider? provider}) async {
    final wire = await sdkCall(
      () => _api.notificationsGetPushToken(provider?.wireValue, _shopId),
    );
    return wire == null ? null : pushTokenFromWire(wire);
  }

  /// A [token] the app got itself (its own messaging, or `autoSendPushToken:
  /// false`): kept and sent to this shop (`POST /mobile_push_tokens`). A token sent
  /// this week ends in success without a request. `apns` on Android and `hms` on
  /// iOS are `invalidArgument`.
  Future<void> setPushToken(String token, PushProvider provider) => sdkCall(
    () => _api.notificationsSetPushToken(token, provider.wireValue, _shopId),
  );

  /// This shop's push callbacks; a new call replaces the ones before,
  /// `PushCallbacks()` clears them. They win over `REES46.setPushCallbacks`. Set
  /// on a handle made without a shop id before its `initialize`, they are kept
  /// and become the shop's there.
  void setCallbacks(PushCallbacks callbacks) {
    final mirror = _mirror();
    if (mirror != null) {
      mirror.pushCallbacks = callbacks;
    } else {
      _onEarlyCallbacks?.call(callbacks);
    }
  }

  /// The messages the shop sent the customer (`GET /notifications`): mailings of
  /// [type] (`bulk`, `chain`, `transactional`, several joined with commas) on
  /// [channel] (`email`, `mobile_push`, `web_push`, `sms`…) since [dateFrom]
  /// (`YYYY-MM-DD`, which the server needs).
  ///
  /// A server method: it takes the shop's secret key, [shopSecret], which the SDK
  /// neither keeps nor logs. A secret in an app's binary gives whoever unpacks it
  /// the shop's server access. The customer is the one of [phone], [email],
  /// [externalId], [loyaltyId] or [did]: the device's own id goes only when passed.
  Future<NotificationHistory> getHistory(
    String shopSecret,
    String type, {
    String? phone,
    String? email,
    String? externalId,
    String? loyaltyId,
    String? channel,
    int? limit,
    int? page,
    String? dateFrom,
    String? did,
  }) async => notificationHistoryFromWire(
    await sdkCall(
      () => _api.notificationsGetHistory(
        shopSecret,
        type,
        phone,
        email,
        externalId,
        loyaltyId,
        channel,
        limit,
        page,
        dateFrom,
        did,
        _shopId,
      ),
    ),
  );
}
