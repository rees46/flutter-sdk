import '../errors/sdk_error.dart';
import '../models/cart_models.dart';
import '../pigeon/personalization_api.g.dart' as pigeon;
import 'from_wire.dart';

/// The customer's cart on the server — the `cart` namespace: `sdk.cart.get()`.
/// The server builds it from the cart events of `sdk.tracking` (`addToCart`,
/// `syncCart`, `removeFromCart`) and finds it by the device id.
class CartApi {
  CartApi(this._api, this._shopId);

  final pigeon.PersonalizationHostApi _api;
  final String? _shopId;

  /// The cart's items; an empty cart is an empty list. `http` 404 for a device the
  /// server does not know.
  Future<List<CartItem>> get() async => List<CartItem>.unmodifiable(
    (await sdkCall(() => _api.cartGet(_shopId))).map(cartItemFromWire),
  );

  /// Empties the cart of the customer of [email], [phone], [loyaltyId],
  /// [externalId] or [telegramId], whichever are given; the server finds the
  /// customer by them alone, never by the device.
  ///
  /// A server method: it takes the shop's secret key, [shopSecret], which the SDK
  /// neither keeps nor logs. A secret in an app's binary gives whoever unpacks it
  /// the shop's server access. `invalidArgument` for an empty secret, an empty id or
  /// no id at all; `http` 403 for a wrong secret, 400 for a customer the server does
  /// not find.
  Future<void> clear(
    String shopSecret, {
    String? email,
    String? phone,
    String? loyaltyId,
    String? externalId,
    String? telegramId,
  }) => sdkCall(
    () => _api.cartClear(
      shopSecret,
      email,
      phone,
      loyaltyId,
      externalId,
      telegramId,
      _shopId,
    ),
  );
}
