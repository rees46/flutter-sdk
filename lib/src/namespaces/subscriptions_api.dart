import '../errors/sdk_error.dart';
import '../models/subscription_models.dart';
import '../pigeon/personalization_api.g.dart' as pigeon;
import '../popups_v3/popups_v3_hooks.dart';
import '../subscriptions/manage_subscription_params.dart';
import 'from_wire.dart';

/// The customer's subscriptions — the `subscriptions` namespace: to channels and
/// kinds of mailings, and to a product's price drop or its return to stock. The API
/// finds the customer by the device id; a contact (`email`, `phone`) tells which
/// address a subscription is for, and the server applies the call to the
/// contact's owner: pass one only when it is the customer's own.
class SubscriptionsApi {
  SubscriptionsApi(this._api, this._shopId, this._hookKey);

  final pigeon.PersonalizationHostApi _api;
  final String? _shopId;
  final Object _hookKey;

  /// Subscribes the customer to channels and kinds of mailings, or unsubscribes
  /// (`POST /subscriptions/manage`).
  Future<void> manage(SubscriptionsUpdateRequest request) {
    final wire = request.toWire();
    PopupsV3Hooks.contextChanged(
      _hookKey,
      'subscription',
      'manage',
      wire.encode(),
    );
    return sdkCall(() => _api.subscriptionsManage(wire, _shopId));
  }

  /// The customer's subscriptions on every channel (`GET /subscriptions/check`);
  /// `http` 400 for a device the server does not know.
  Future<SubscriptionStatus> check() async => subscriptionStatusFromWire(
    await sdkCall(() => _api.subscriptionsCheck(_shopId)),
  );

  /// Subscribes the customer to a drop of product [itemId]'s price; [currentPrice]
  /// must be above 0.
  Future<void> subscribeForPriceDrop(
    String itemId,
    double currentPrice, {
    String? email,
    String? phone,
  }) => sdkCall(
    () => _api.subscriptionsSubscribeForPriceDrop(
      itemId,
      currentPrice,
      email,
      phone,
      _shopId,
    ),
  );

  /// Unsubscribes the customer from price drops of [itemIds]; an empty list
  /// unsubscribes from every product.
  Future<void> unsubscribeFromPriceDrop(
    List<String> itemIds, {
    String? email,
    String? phone,
  }) => sdkCall(
    () => _api.subscriptionsUnsubscribeFromPriceDrop(
      itemIds,
      email,
      phone,
      _shopId,
    ),
  );

  /// Subscribes the customer to product [itemId]'s return to stock, in the variant
  /// of [properties].
  Future<void> subscribeForBackInStock(
    String itemId, {
    BackInStockProperties? properties,
    String? email,
    String? phone,
  }) => sdkCall(
    () => _api.subscriptionsSubscribeForBackInStock(
      itemId,
      properties == null
          ? null
          : pigeon.BackInStockPropertiesWire(
              fashionSize: properties.fashionSize,
              fashionColor: properties.fashionColor,
              barcode: properties.barcode,
            ),
      email,
      phone,
      _shopId,
    ),
  );

  /// Unsubscribes the customer from [itemIds]' return to stock; an empty list
  /// unsubscribes from every product.
  Future<void> unsubscribeFromBackInStock(
    List<String> itemIds, {
    String? email,
    String? phone,
  }) => sdkCall(
    () => _api.subscriptionsUnsubscribeFromBackInStock(
      itemIds,
      email,
      phone,
      _shopId,
    ),
  );
}
