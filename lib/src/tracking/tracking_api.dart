import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;

import '../errors/sdk_error.dart';
import '../pigeon/personalization_api.g.dart' as pigeon;
import '../popups_v3/popups_v3_hooks.dart';
import 'tracking_models.dart';

/// Standard tracking events — the `tracking` namespace of the SDK.
///
/// Reached through an SDK handle: `REES46.getInstance().tracking.productView('sku-1')`.
/// An event fired from Dart is the same request the native SDKs send: each method goes to the
/// method of the same name in the native `tracking` namespace, in the form that completes as the
/// contract does — `tracking.queued` on Android, `tracking.async` on iOS. Its future completes once
/// the shop's queue accepted the event; the server's later answer is not the call's. It fails with an
/// [SdkException] only when the event does not get into the queue: `invalidArgument`, `shopBlocked`,
/// `notInitialized`. A shop's events reach its queue in the order they were made.
class TrackingApi {
  TrackingApi(
    this._api,
    this._shopId, {
    void Function(int popupId)? onPopupShown,
  }) : _onPopupShown = onPopupShown;

  final pigeon.PersonalizationHostApi _api;

  /// The shop this namespace tracks for; `null` is the legacy default instance.
  final String? _shopId;

  /// Tells the popup presenter a popup the host drew is on screen.
  final void Function(int popupId)? _onPopupShown;

  /// Product page opened (`view`).
  Future<void> productView(String itemId, {TrackingSource? source}) => _send({
    'itemId': itemId,
  }, () => _api.trackProductView(itemId, source?._wire, _shopId));

  /// Category listing opened (`category`).
  Future<void> categoryView(String categoryId) => _send({
    'categoryId': categoryId,
  }, () => _api.trackCategoryView(categoryId, _shopId));

  /// Search query issued by the user (`search`).
  ///
  /// Pass [results] when the host runs its own search and knows the ids it showed.
  Future<void> search(String query, {List<String>? results}) =>
      _send({'query': query}, () => _api.trackSearch(query, results, _shopId));

  /// One product added to the cart (`cart`).
  Future<void> addToCart(TrackingItem item, {TrackingSource? source}) => _send({
    'item.id': item.id,
  }, () => _api.trackAddToCart(item._wire, source?._wire, _shopId));

  /// Full cart contents after a change (`cart` with `full_cart`).
  ///
  /// An empty list is the way to report an emptied cart: the native SDKs always
  /// send the list, so `items` goes on the wire as `[]`.
  Future<void> syncCart(List<TrackingItem> items) {
    return sdkCall(
      () => _api.trackSyncCart(items.map((e) => e._wire).toList(), _shopId),
    );
  }

  /// One product removed from the cart (`remove_from_cart`).
  Future<void> removeFromCart(String itemId) => _send({
    'itemId': itemId,
  }, () => _api.trackRemoveFromCart(itemId, _shopId));

  /// One product added to favorites (`wish`).
  Future<void> addToFavorites(String itemId, {TrackingSource? source}) => _send(
    {'itemId': itemId},
    () => _api.trackAddToFavorites(itemId, source?._wire, _shopId),
  );

  /// Full favorites contents after a change (`wish` with `full_wish`).
  ///
  /// An empty list reports emptied favorites, the same way [syncCart] does.
  Future<void> syncFavorites(List<String> itemIds) {
    return sdkCall(() => _api.trackSyncFavorites(itemIds, _shopId));
  }

  /// One product removed from favorites (`remove_wish`).
  Future<void> removeFromFavorites(String itemId) => _send({
    'itemId': itemId,
  }, () => _api.trackRemoveFromFavorites(itemId, _shopId));

  /// Slide [slideId] of story [storyId] was shown (`track/stories`, `view`).
  ///
  /// [code] is the stories block code; when omitted the native SDK uses the block it last
  /// loaded.
  Future<void> storyView(String storyId, String slideId, {String? code}) =>
      sdkCall(() => _api.trackStoryView(storyId, slideId, code, _shopId));

  /// Slide [slideId] of story [storyId] was tapped (`track/stories`, `click`).
  Future<void> storyClick(String storyId, String slideId, {String? code}) =>
      sdkCall(() => _api.trackStoryClick(storyId, slideId, code, _shopId));

  /// A banner of a slider was shown (`track/slider`, `view`): once, when it first
  /// became visible in this showing of the slider. [bannerId] and [code] are the
  /// banner's `id` and `code` from `sdk.sliders.get`. Fails with [SdkException]
  /// (`invalidArgument`) for a [bannerId] that is not a positive whole number or an
  /// empty [code].
  Future<void> bannerView(String bannerId, String code) =>
      sdkCall(() => _api.trackBannerView(bannerId, code, _shopId));

  /// A banner of a slider was tapped (`track/slider`, `click`); otherwise as
  /// [bannerView].
  Future<void> bannerClick(String bannerId, String code) =>
      sdkCall(() => _api.trackBannerClick(bannerId, code, _shopId));

  /// A server popup the app drew itself is on screen (`popup/showed`).
  ///
  /// Only for popups taken with `onPopup` and drawn by the app: the ones the SDK shows
  /// are reported by the SDK. A reported popup is not handed over again for a minute,
  /// even when the server sends it again.
  Future<void> popupShown(int popupId) {
    _onPopupShown?.call(popupId);
    return sdkCall(() => _api.trackPopupShown(popupId, _shopId));
  }

  /// Stores the attribution source for 48 hours: it goes as `source` with the shop's
  /// `/push` events until it ends or is replaced.
  ///
  /// Use it when the source outlives a single call — a user entering the catalog from a
  /// recommender block. For a single event prefer the `source` parameter.
  void setSource(TrackingSource source) {
    unawaited(
      _api.trackSetSource(source._wire, _shopId).catchError((Object error) {
        debugPrint('REES46: tracking.setSource failed: $error');
      }),
    );
  }

  /// A completed order (`purchase`): [request] with its lines, and the order's own
  /// [source] (`recommended_by`). An empty `orderId` or no lines is
  /// `invalidArgument`.
  Future<void> purchase(
    PurchaseTrackingRequest request, {
    TrackingSource? source,
  }) {
    if (request.items.isEmpty) {
      return Future<void>.error(
        SdkException(const SdkErrorInvalidArgument('items must not be empty')),
      );
    }
    return _send({'orderId': request.orderId}, () {
      PopupsV3Hooks.purchase(this);
      return _api.trackPurchase(
        pigeon.PurchaseTrackingRequestWire(
          orderId: request.orderId,
          orderPrice: request.orderPrice,
          items: [
            for (final item in request.items)
              pigeon.PurchaseLineItemWire(
                id: item.id,
                amount: item.amount,
                price: item.price,
                lineId: item.lineId,
                fashionSize: item.fashionSize,
              ),
          ],
          deliveryType: request.deliveryType,
          deliveryAddress: request.deliveryAddress,
          paymentType: request.paymentType,
          isTaxFree: request.isTaxFree,
          promocode: request.promocode,
          orderCash: request.orderCash,
          orderBonuses: request.orderBonuses,
          orderDelivery: request.orderDelivery,
          orderDiscount: request.orderDiscount,
          channel: request.channel,
          custom: request.custom,
          isGiftPackage: request.isGiftPackage,
        ),
        source?._wire,
        _shopId,
      );
    });
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
    PopupsV3Hooks.trackEvent(this, event);
    return _send(
      {'event': event},
      () => _api.trackEvent(
        event,
        time,
        category,
        label,
        value,
        customFields,
        _shopId,
      ),
    );
  }

  /// [call] once each of [required] is non-empty; an empty one fails the call with
  /// `invalidArgument`, as the native SDKs do, and nothing is sent.
  Future<void> _send(
    Map<String, String> required,
    Future<void> Function() call,
  ) {
    for (final MapEntry(:key, :value) in required.entries) {
      if (value.isEmpty) {
        return Future<void>.error(
          SdkException(SdkErrorInvalidArgument('$key must not be empty')),
        );
      }
    }
    return sdkCall(call);
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
