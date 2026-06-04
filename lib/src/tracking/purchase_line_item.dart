/// One purchased line item (strict mobile contract, aligned with native
/// `PurchaseItemRequest` on Android / iOS).
///
/// [amount] is the number of units of this product in the order — it is the
/// canonical quantity field the REES46 API has always consumed. The native
/// `PurchaseItemRequest` additionally carries an optional `quantity` alias that
/// duplicates [amount]; it is intentionally not surfaced here to keep a single,
/// unambiguous quantity field.
class PurchaseLineItem {
  final String id;

  /// Number of units of this product in the order (the line quantity).
  final int amount;
  final double price;
  final String? lineId;
  final String? fashionSize;

  const PurchaseLineItem({
    required this.id,
    required this.amount,
    required this.price,
    this.lineId,
    this.fashionSize,
  });
}
