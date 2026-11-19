/// One product line in a tracking event.
///
/// [quantity] is the domain name for the line quantity; on the wire it is sent as `amount` —
/// the field the REES46 API has always consumed.
class TrackingItem {
  final String id;
  final int quantity;
  final double? price;
  final String? fashionSize;

  const TrackingItem({
    required this.id,
    this.quantity = 1,
    this.price,
    this.fashionSize,
  });
}

/// The tool an event is attributed to (`recommended_by` on the wire).
///
/// [dynamicBlock] carries the wire value `dynamic`, which cannot be an enum member name in Dart.
enum TrackingSourceType {
  dynamicBlock('dynamic'),
  chain('chain'),
  bulk('bulk'),
  transactional('transactional'),
  instantSearch('instant_search'),
  fullSearch('full_search'),
  stories('stories'),
  webPushDigest('web_push_digest');

  const TrackingSourceType(this.wireValue);

  /// The value the API expects for `recommended_by`.
  final String wireValue;
}

/// Where a tracked action came from — a recommender block, a search result, a story.
///
/// Passed per call to attribute a single event, or stored for subsequent events with
/// [TrackingApi.setSource].
class TrackingSource {
  final TrackingSourceType type;
  final String code;

  const TrackingSource({required this.type, required this.code});
}

/// A completed order for [TrackingApi.purchase] (`purchase`).
class PurchaseTrackingRequest {
  const PurchaseTrackingRequest({
    required this.orderId,
    required this.orderPrice,
    required this.items,
    this.deliveryType,
    this.deliveryAddress,
    this.paymentType,
    this.isTaxFree = false,
    this.promocode,
    this.orderCash,
    this.orderBonuses,
    this.orderDelivery,
    this.orderDiscount,
    this.channel,
    this.custom,
    this.isGiftPackage = false,
  });

  final String orderId;
  final double orderPrice;

  /// The order's lines; an empty list is `invalidArgument`.
  final List<PurchaseItem> items;
  final String? deliveryType;
  final String? deliveryAddress;
  final String? paymentType;
  final bool isTaxFree;
  final String? promocode;
  final double? orderCash;
  final double? orderBonuses;
  final double? orderDelivery;
  final double? orderDiscount;
  final String? channel;

  /// Free-form fields of the order; `tax_free` and `gift_package` are reserved.
  final Map<String, Object?>? custom;

  /// Sent only when `true`.
  final bool isGiftPackage;
}

/// One line of a [PurchaseTrackingRequest].
class PurchaseItem {
  const PurchaseItem({
    required this.id,
    required this.amount,
    required this.price,
    this.lineId,
    this.fashionSize,
  });

  final String id;

  /// Units of the product in the order, from 1.
  final int amount;
  final double price;
  final String? lineId;
  final String? fashionSize;
}
