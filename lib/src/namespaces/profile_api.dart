import '../models/catalog.dart';
import '../errors/sdk_error.dart';
import '../models/profile_models.dart';
import '../pigeon/personalization_api.g.dart' as pigeon;
import '../popups_v3/popups_v3_hooks.dart';
import 'from_wire.dart';
import 'to_wire.dart';

/// The customer's profile — the `profile` namespace: `sdk.profile.get()`. The API
/// finds the customer by the device id; the SDK keeps none of the personal data
/// [set] sends.
class ProfileApi {
  ProfileApi(this._api, this._shopId, this._hookKey);

  final pigeon.PersonalizationHostApi _api;
  final String? _shopId;
  final Object _hookKey;

  /// The customer's profile (`GET /profile`); `http` 404 for a device the server
  /// does not know.
  Future<Profile> get() async =>
      profileFromWire(await sdkCall(() => _api.profileGet(_shopId)));

  /// Writes the properties of [request] to the profile (`POST /profile/set`), not
  /// through the queue: the result is the server's answer. Call it on sign-in, on a
  /// change of city and on every launch. `invalidArgument` for a request without
  /// fields, an empty `email`, `phone` or `loyaltyId`, a `birthday` that is no date
  /// `YYYY-MM-DD`, a negative `age` or a custom property the API does not take.
  Future<void> set(ProfileUpdateRequest request) {
    final wire = profileUpdateRequestToWire(request);
    PopupsV3Hooks.contextChanged(_hookKey, 'profile', 'set', wire.encode());
    return sdkCall(() => _api.profileSet(wire, _shopId));
  }

  /// The products of the customer's last order (`GET /orders/last_for_user`); an
  /// empty list without orders.
  Future<List<Product>> getLastOrder() async => List<Product>.unmodifiable(
    (await sdkCall(
      () => _api.profileGetLastOrder(_shopId),
    )).map(productFromWire),
  );

  /// The customer's orders (`GET /orders/by_user`) since [dateFrom] (`YYYY-MM-DD`;
  /// the server's default is a month ago).
  ///
  /// A server method: it takes the shop's secret key, [shopSecret], which the SDK
  /// neither keeps nor logs. A secret in an app's binary gives whoever unpacks it
  /// the shop's server access. The customer is the one of [did], [email], [phone],
  /// [loyaltyId] or [externalId], whichever are given: the device's own id goes only
  /// when passed. `invalidArgument` for an empty secret, an empty id, no id at all or
  /// a [dateFrom] that is no date; `http` 403 for a wrong secret.
  Future<List<Order>> getOrders(
    String shopSecret, {
    String? did,
    String? email,
    String? phone,
    String? loyaltyId,
    String? externalId,
    String? dateFrom,
  }) async => List<Order>.unmodifiable(
    (await sdkCall(
      () => _api.profileGetOrders(
        shopSecret,
        did,
        email,
        phone,
        loyaltyId,
        externalId,
        dateFrom,
        _shopId,
      ),
    )).map(orderFromWire),
  );
}
