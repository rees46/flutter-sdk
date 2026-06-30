/// Response from [PersonalizationSdk.getProductCounters].
///
/// Mirrors native `ProductCountersResponse`: per-period view/cart/purchase
/// counters plus trigger flags.
class ProductCountersResponse {
  final ProductCounter? daily;
  final ProductCounter? now;
  final ProductCounterTriggers? triggers;

  const ProductCountersResponse({this.daily, this.now, this.triggers});

  factory ProductCountersResponse.fromJson(Map<String, dynamic> json) {
    ProductCounter? counter(String key) {
      final raw = json[key];
      return raw is Map
          ? ProductCounter.fromJson(raw.cast<String, dynamic>())
          : null;
    }

    final triggers = json['triggers'];
    return ProductCountersResponse(
      daily: counter('daily'),
      now: counter('now'),
      triggers: triggers is Map
          ? ProductCounterTriggers.fromJson(triggers.cast<String, dynamic>())
          : null,
    );
  }
}

/// View / cart / purchase counters for a single period.
class ProductCounter {
  final int view;
  final int cart;
  final int purchase;

  const ProductCounter({
    required this.view,
    required this.cart,
    required this.purchase,
  });

  factory ProductCounter.fromJson(Map<String, dynamic> json) {
    return ProductCounter(
      view: json['view'] as int? ?? 0,
      cart: json['cart'] as int? ?? 0,
      purchase: json['purchase'] as int? ?? 0,
    );
  }
}

/// Trigger counters returned inside `ProductCountersResponse.triggers`.
class ProductCounterTriggers {
  final int backInStock;
  final int priceDrop;

  const ProductCounterTriggers({
    required this.backInStock,
    required this.priceDrop,
  });

  factory ProductCounterTriggers.fromJson(Map<String, dynamic> json) {
    return ProductCounterTriggers(
      backInStock: json['back_in_stock'] as int? ?? 0,
      priceDrop: json['price_drop'] as int? ?? 0,
    );
  }
}
