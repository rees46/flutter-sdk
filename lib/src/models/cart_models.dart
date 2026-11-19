// Models of the SDK contract, as the native SDKs hand them over.

/// A product in the customer's cart on the server.
class CartItem {
  const CartItem({required this.id, required this.quantity});

  /// The product's id.
  final String id;

  final int quantity;
}
