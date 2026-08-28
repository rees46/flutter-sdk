import 'dart:convert';

import '../pigeon/personalization_api.g.dart' as pigeon;
import 'purchase_line_item.dart';
import 'tracking_models.dart';

/// Standard tracking events — the `tracking` namespace of the SDK.
///
/// Reached through an SDK handle: `Rees46.getInstance().tracking.productView('sku-1')`.
/// Every method routes to the native namespace of the same name, so an event fired from Dart
/// is the same request the native SDKs send.
class TrackingApi {
  TrackingApi(this._api, this._shopId);

  final pigeon.PersonalizationHostApi _api;

  /// The shop this namespace tracks for; `null` is the legacy default instance.
  final String? _shopId;

  /// Product page opened (`view`).
  Future<void> productView(String itemId, {TrackingSource? source}) {
    _requireNonEmpty(itemId, 'itemId');
    return _api.trackProductView(itemId, source?._wire, _shopId);
  }

  /// Category listing opened (`category`).
  Future<void> categoryView(String categoryId) {
    _requireNonEmpty(categoryId, 'categoryId');
    return _api.trackCategoryView(categoryId, _shopId);
  }

  /// Search query issued by the user (`search`).
  ///
  /// Pass [results] when the host runs its own search and knows the ids it showed.
  Future<void> search(String query, {List<String>? results}) {
    _requireNonEmpty(query, 'query');
    return _api.trackSearch(query, results, _shopId);
  }

  /// One product added to the cart (`cart`).
  Future<void> addToCart(TrackingItem item, {TrackingSource? source}) {
    _requireNonEmpty(item.id, 'item.id');
    return _api.trackAddToCart(item._wire, source?._wire, _shopId);
  }

  /// Full cart contents after a change (`cart` with `full_cart`).
  Future<void> syncCart(List<TrackingItem> items) {
    if (items.isEmpty) {
      throw ArgumentError.value(items, 'items', 'must be non-empty');
    }
    return _api.trackSyncCart(items.map((e) => e._wire).toList(), _shopId);
  }

  /// One product removed from the cart (`remove_from_cart`).
  Future<void> removeFromCart(String itemId) {
    _requireNonEmpty(itemId, 'itemId');
    return _api.trackRemoveFromCart(itemId, _shopId);
  }

  /// One product added to favorites (`wish`).
  Future<void> addToFavorites(String itemId, {TrackingSource? source}) {
    _requireNonEmpty(itemId, 'itemId');
    return _api.trackAddToFavorites(itemId, source?._wire, _shopId);
  }

  /// Full favorites contents after a change (`wish` with `full_wish`).
  Future<void> syncFavorites(List<String> itemIds) {
    if (itemIds.isEmpty) {
      throw ArgumentError.value(itemIds, 'itemIds', 'must be non-empty');
    }
    return _api.trackSyncFavorites(itemIds, _shopId);
  }

  /// One product removed from favorites (`remove_wish`).
  Future<void> removeFromFavorites(String itemId) {
    _requireNonEmpty(itemId, 'itemId');
    return _api.trackRemoveFromFavorites(itemId, _shopId);
  }

  /// A story slide was shown (`track/stories`, `view`).
  ///
  /// [code] is the stories block code; when omitted the native SDK uses the block it last
  /// loaded.
  Future<void> storyView({
    required String storyId,
    required String slideId,
    String? code,
  }) {
    _requireNonEmpty(storyId, 'storyId');
    _requireNonEmpty(slideId, 'slideId');
    return _api.trackStoryView(storyId, slideId, code, _shopId);
  }

  /// A story slide was tapped (`track/stories`, `click`).
  Future<void> storyClick({
    required String storyId,
    required String slideId,
    String? code,
  }) {
    _requireNonEmpty(storyId, 'storyId');
    _requireNonEmpty(slideId, 'slideId');
    return _api.trackStoryClick(storyId, slideId, code, _shopId);
  }

  /// Stores the attribution source for subsequent events.
  ///
  /// Use it when the source outlives a single call — a user entering the catalog from a
  /// recommender block. For a single event prefer the `source` parameter.
  Future<void> setSource(TrackingSource source) {
    return _api.trackSetSource(source._wire, _shopId);
  }

  /// Completed order (`purchase`).
  Future<void> purchase({
    required String orderId,
    required double orderPrice,
    required List<PurchaseLineItem> items,
    String? deliveryType,
    String? deliveryAddress,
    String? paymentType,
    bool isTaxFree = false,
    String? promocode,
    double? orderCash,
    double? orderBonuses,
    double? orderDelivery,
    double? orderDiscount,
    String? channel,
    Map<String, Object?>? custom,
    Map<String, Object?>? recommendedSource,
    String? stream,
    String? segment,
  }) {
    _requireNonEmpty(orderId, 'orderId');
    if (items.isEmpty) {
      throw ArgumentError.value(items, 'items', 'must be non-empty');
    }
    return _api.trackPurchase(
      orderId,
      orderPrice,
      items
          .map(
            (e) => pigeon.PurchaseLineItemWire(
              id: e.id,
              amount: e.amount,
              price: e.price,
              lineId: e.lineId,
              fashionSize: e.fashionSize,
            ),
          )
          .toList(),
      deliveryType,
      deliveryAddress,
      paymentType,
      isTaxFree,
      promocode,
      orderCash,
      orderBonuses,
      orderDelivery,
      orderDiscount,
      channel,
      custom == null ? null : jsonEncode(custom),
      recommendedSource == null ? null : jsonEncode(recommendedSource),
      stream,
      segment,
      _shopId,
    );
  }

  /// Custom event defined by the shop (`push/custom`).
  ///
  /// [customFields] is the one deliberately free-form field: its entries are sent at the top
  /// level and duplicated under `payload`. Reserved keys are rejected natively.
  Future<void> custom(
    String event, {
    int? time,
    String? category,
    String? label,
    int? value,
    Map<String, Object?>? customFields,
  }) {
    _requireNonEmpty(event, 'event');
    return _api.trackEvent(
      event,
      time,
      category,
      label,
      value,
      customFields == null ? null : jsonEncode(customFields),
      _shopId,
    );
  }

  void _requireNonEmpty(String value, String name) {
    if (value.isEmpty) {
      throw ArgumentError.value(value, name, 'must be non-empty');
    }
  }
}

extension on TrackingItem {
  pigeon.TrackingItemWire get _wire => pigeon.TrackingItemWire(
    id: id,
    quantity: quantity,
    price: price,
    fashionSize: fashionSize,
  );
}

extension on TrackingSource {
  pigeon.TrackingSourceWire get _wire =>
      pigeon.TrackingSourceWire(type: type.wireValue, code: code);
}
