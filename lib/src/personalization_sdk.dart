import 'dart:convert';

import 'pigeon/personalization_api.g.dart' as pigeon;
import 'category/category_response.dart';
import 'collection/collection_response.dart';
import 'init/sdk_init_handler.dart';
import 'loyalty/loyalty_response.dart';
import 'products/product_counters_response.dart';
import 'profile/profile_params.dart';
import 'profile/profile_response.dart';
import 'push/push_notification_callbacks.dart';
import 'recommendation/recommendation_params.dart';
import 'recommendation/recommendation_response.dart';
import 'products/products_list_params.dart';
import 'products/products_list_response.dart';
import 'search/search_params.dart';
import 'search/search_response.dart';
import 'sdk_init_config.dart';
import 'tracking/purchase_line_item.dart';

class PersonalizationSdk {
  final pigeon.PersonalizationHostApi _api;
  final SdkInitHandler _initHandler;
  final PushNotificationCallbacks _pushCallbacks = PushNotificationCallbacks();

  PersonalizationSdk({pigeon.PersonalizationHostApi? api})
    : _api = api ?? pigeon.PersonalizationHostApi(),
      _initHandler = SdkInitHandler(api: api) {
    pigeon.PersonalizationFlutterApi.setUp(_pushCallbacks);
  }

  /// Registers optional listeners for push lifecycle events emitted by native code.
  void setPushNotificationCallbacks({
    void Function(Map<String, String?> payload)? onReceived,
    void Function(Map<String, String?> payload)? onDelivered,
    void Function(Map<String, String?> payload)? onClicked,
  }) {
    _pushCallbacks.setCallbacks(
      onReceived: onReceived,
      onDelivered: onDelivered,
      onClicked: onClicked,
    );
  }

  Future<String?> getPlatformVersion() {
    return _api.getPlatformVersion();
  }

  Future<String?> getStoredPushToken() {
    return _api.getStoredPushToken();
  }

  Future<void> initialize(SdkInitConfig config) {
    return _initHandler.initialize(config);
  }

  Future<void> setProfile(ProfileParams params) {
    return _api.setProfile(params.toWire());
  }

  Future<String> getSid() {
    return _api.getSid();
  }

  Future<String?> getDid() {
    return _api.getDid();
  }

  Future<Product> getProductInfo(String itemId) async {
    if (itemId.isEmpty) {
      throw ArgumentError.value(itemId, 'itemId', 'must be non-empty');
    }
    final json = await _api.getProductInfo(itemId);
    return Product.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  Future<ProductsListResponse> getProductsList({
    ProductsListParams? params,
  }) async {
    final json = await _api.getProductsList(params?.toJson());
    return ProductsListResponse.fromJson(
      jsonDecode(json) as Map<String, dynamic>,
    );
  }

  Future<SearchBlankResponse> searchBlank() async {
    final json = await _api.searchBlank();
    return SearchBlankResponse.fromJson(
      jsonDecode(json) as Map<String, dynamic>,
    );
  }

  Future<SearchInstantResponse> searchInstant(
    String query, {
    SearchInstantParams? params,
  }) async {
    if (query.isEmpty) {
      throw ArgumentError.value(query, 'query', 'must be non-empty');
    }
    final json = await _api.searchInstant(query, params?.toJson());
    return SearchInstantResponse.fromJson(
      jsonDecode(json) as Map<String, dynamic>,
    );
  }

  Future<SearchFullResponse> searchFull(
    String query, {
    SearchParams? params,
  }) async {
    if (query.isEmpty) {
      throw ArgumentError.value(query, 'query', 'must be non-empty');
    }
    final json = await _api.searchFull(query, params?.toJson());
    return SearchFullResponse.fromJson(
      jsonDecode(json) as Map<String, dynamic>,
    );
  }

  /// Joins the loyalty program (native `loyalty/members/join`).
  ///
  /// The shop is identified by the SDK's configured `shop_id`; [phone] is
  /// required, the remaining member fields are optional.
  Future<LoyaltyJoinResponse> joinLoyalty({
    required String phone,
    String? email,
    String? firstName,
    String? lastName,
  }) async {
    if (phone.isEmpty) {
      throw ArgumentError.value(phone, 'phone', 'must be non-empty');
    }
    final json = await _api.joinLoyalty(phone, email, firstName, lastName);
    return LoyaltyJoinResponse.fromJson(
      jsonDecode(json) as Map<String, dynamic>,
    );
  }

  /// Returns the loyalty membership status (native `loyalty/members/status`).
  ///
  /// [identifier] is the member identifier (phone).
  Future<LoyaltyStatusResponse> getLoyaltyStatus(String identifier) async {
    if (identifier.isEmpty) {
      throw ArgumentError.value(identifier, 'identifier', 'must be non-empty');
    }
    final json = await _api.getLoyaltyStatus(identifier);
    return LoyaltyStatusResponse.fromJson(
      jsonDecode(json) as Map<String, dynamic>,
    );
  }

  /// Returns the current user's profile (native `ProfileManager.getProfile`).
  Future<ProfileResponse> getProfile() async {
    final json = await _api.getProfile();
    return ProfileResponse.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  /// Returns view / cart / purchase counters for [item]
  /// (native `ProductsManager.getProductCounters`).
  Future<ProductCountersResponse> getProductCounters(String item) async {
    if (item.isEmpty) {
      throw ArgumentError.value(item, 'item', 'must be non-empty');
    }
    final json = await _api.getProductCounters(item);
    return ProductCountersResponse.fromJson(
      jsonDecode(json) as Map<String, dynamic>,
    );
  }

  /// Returns a category product listing (native `CategoryManager.getCategory`).
  ///
  /// [limit] and [page] paginate the result; both are optional.
  Future<CategoryResponse> getCategory(
    String category, {
    int? limit,
    int? page,
  }) async {
    if (category.isEmpty) {
      throw ArgumentError.value(category, 'category', 'must be non-empty');
    }
    final json = await _api.getCategory(category, limit, page);
    return CategoryResponse.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  /// Returns a merchandised collection's products
  /// (native `CollectionManager.getCollection`).
  Future<CollectionResponse> getCollection(String collectionId) async {
    if (collectionId.isEmpty) {
      throw ArgumentError.value(
        collectionId,
        'collectionId',
        'must be non-empty',
      );
    }
    final json = await _api.getCollection(collectionId);
    return CollectionResponse.fromJson(
      jsonDecode(json) as Map<String, dynamic>,
    );
  }

  Future<RecommendationResponse> getRecommendation(
    String code, {
    RecommendationParams? params,
  }) async {
    if (code.isEmpty) {
      throw ArgumentError.value(code, 'code', 'must be non-empty');
    }
    final json = await _api.getRecommendation(code, params?.toJson());
    return RecommendationResponse.fromJson(
      jsonDecode(json) as Map<String, dynamic>,
    );
  }

  /// Custom event tracking (native `trackEvent` / `TrackEventManager.trackEvent`).
  Future<void> trackEvent(
    String event, {
    int? time,
    String? category,
    String? label,
    int? value,
    Map<String, Object?>? customFields,
  }) {
    if (event.isEmpty) {
      throw ArgumentError.value(event, 'event', 'must be non-empty');
    }
    final customFieldsJson = customFields == null
        ? null
        : jsonEncode(customFields);
    return _api.trackEvent(
      event,
      time,
      category,
      label,
      value,
      customFieldsJson,
    );
  }

  /// Purchase tracking (native `trackPurchase` with typed line items).
  Future<void> trackPurchase({
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
    if (orderId.isEmpty) {
      throw ArgumentError.value(orderId, 'orderId', 'must be non-empty');
    }
    if (items.isEmpty) {
      throw ArgumentError.value(items, 'items', 'must be non-empty');
    }
    final wireItems = items
        .map(
          (e) => pigeon.PurchaseLineItemWire(
            id: e.id,
            amount: e.amount,
            price: e.price,
            lineId: e.lineId,
            fashionSize: e.fashionSize,
          ),
        )
        .toList();
    return _api.trackPurchase(
      orderId,
      orderPrice,
      wireItems,
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
    );
  }
}
