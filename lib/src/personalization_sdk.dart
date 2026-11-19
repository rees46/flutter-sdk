import 'dart:async';
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show PlatformException;

import 'pigeon/personalization_api.g.dart' as pigeon;
import 'category/category_response.dart';
import 'collection/collection_response.dart';
import 'core/handle_channel.dart';
import 'core/native_events.dart';
import 'errors/sdk_error.dart';
import 'init/sdk_init_handler.dart';
import 'loyalty/loyalty_response.dart';
import 'models/request_models.dart';
import 'models/values.dart';
import 'multi_instance/push_dispatcher.dart';
import 'multi_instance/push_event.dart';
import 'namespaces/cart_api.dart';
import 'namespaces/collections_api.dart';
import 'namespaces/loyalty_api.dart';
import 'namespaces/notifications_api.dart';
import 'namespaces/predict_api.dart';
import 'namespaces/products_api.dart';
import 'namespaces/profile_api.dart';
import 'namespaces/recommendations_api.dart';
import 'namespaces/reviews_api.dart';
import 'namespaces/search_api.dart';
import 'namespaces/segments_api.dart';
import 'namespaces/sliders_api.dart';
import 'namespaces/stories_api.dart';
import 'namespaces/subscriptions_api.dart';
import 'namespaces/to_wire.dart';
import 'popups/in_app_popup.dart';
import 'popups/popup_dispatcher.dart';
import 'popups/popup_presenter.dart';
import 'popups_v3/popups_v3_hooks.dart';
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
import 'stories/stories_response.dart';
import 'subscriptions/manage_subscription_params.dart';
import 'tracking/purchase_line_item.dart';
import 'tracking/tracking_api.dart';

/// One shop's SDK: get it from [REES46.initialize] or [REES46.getInstance].
///
/// Each domain is a namespace — `sdk.products.getInfo('37')`, `sdk.search.full(…)`,
/// `sdk.tracking.productView('37')` — over the native Android and iOS SDKs, which run
/// the shop: its init, session, event queue, storage and requests. A failed call is
/// an [SdkException] with the native error's type and codes.
///
/// At the root, besides the shop's identity and state: [flush] sends the queue now,
/// [deleteUserCredentials] forgets the customer, [release] stops the instance.
class PersonalizationSdk {
  final pigeon.PersonalizationHostApi _api;
  late final SdkInitHandler _initHandler = SdkInitHandler(api: _api);

  /// The channel of this handle's calls; closed by [release].
  final HandleChannel _channel;

  /// What the handle mirrored of its shop when it was released; null before.
  ShopMirror? _releasedMirror;
  final PushNotificationCallbacks _pushCallbacks = PushNotificationCallbacks();
  late final PopupPresenter _popups = PopupPresenter(
    trackShown: (popupId) => _api.trackPopupShown(popupId, shopId),
    openUrl: _api.openUrl,
    openNotificationSettings: _api.openNotificationSettings,
  );

  /// The shop this handle is bound to, or `null` for the legacy default instance.
  /// Set by [REES46.initialize] / [REES46.getInstance]; every call carries it to the
  /// native instance of that shop.
  final String? shopId;

  /// The shop the native instance reports its state for: [shopId], or the one the
  /// legacy default instance was initialized with.
  String? _stateShopId;

  /// Standard tracking events: `sdk.tracking.productView('sku-1')`,
  /// `sdk.tracking.addToCart(item)`, and the rest.
  late final TrackingApi tracking;

  /// The shop's catalog: a product's card, the listing, the counters, a category.
  late final ProductsApi products = ProductsApi(_api, shopId);

  /// The shop's product collections.
  late final CollectionsApi collections = CollectionsApi(_api, shopId);

  /// The shop's recommendation blocks.
  late final RecommendationsApi recommendations = RecommendationsApi(
    _api,
    shopId,
  );

  /// Search: empty, instant and full, and the search agent.
  late final SearchApi search = SearchApi(_api, shopId, _mirror);

  /// The customer's cart on the server.
  late final CartApi cart = CartApi(_api, shopId);

  /// The customer's profile, last order and orders.
  late final ProfileApi profile = ProfileApi(_api, shopId, tracking);

  /// The customer's subscriptions to channels, price drops and back-in-stock.
  late final SubscriptionsApi subscriptions = SubscriptionsApi(
    _api,
    shopId,
    tracking,
  );

  /// The customer's segments and the device's A/B group.
  late final SegmentsApi segments = SegmentsApi(
    _api,
    shopId,
    _mirror,
    tracking,
  );

  /// The shop's push token, push events and push callbacks.
  late final NotificationsApi notifications = NotificationsApi(
    _api,
    shopId,
    _mirror,
  );

  /// The stories blocks.
  late final StoriesApi stories = StoriesApi(_api, shopId);

  /// The probability that the customer buys.
  late final PredictApi predict = PredictApi(_api, shopId);

  /// The loyalty program on the customer's side.
  late final LoyaltyApi loyalty = LoyaltyApi(_api, shopId);

  /// Banner sliders.
  late final SlidersApi sliders = SlidersApi(_api, shopId);

  /// NPS, CSAT and CES ratings and the reviews of products.
  late final ReviewsApi reviews = ReviewsApi(_api, shopId);

  /// A handle of [shopId]. [api] stands in for the native channel in tests: its
  /// calls are not closed by [release].
  PersonalizationSdk({pigeon.PersonalizationHostApi? api, String? shopId})
    : this._(api, shopId, HandleChannel());

  PersonalizationSdk._(
    pigeon.PersonalizationHostApi? api,
    this.shopId,
    this._channel,
  ) : _api = api ?? pigeon.PersonalizationHostApi(binaryMessenger: _channel),
      _stateShopId = shopId {
    tracking = TrackingApi(
      _api,
      shopId,
      onPopupShown: (popupId) => _popups.markShown(popupId),
    );
    // One process-global dispatcher owns the Pigeon push channel and routes each
    // inbound push (by shopId) to the right handle — register this handle's
    // callbacks with it instead of claiming the channel per instance.
    PushDispatcher.instance.register(shopId, _pushCallbacks);
    // The receiver of the native state, push events and tokens: set up before the
    // native side can send any.
    NativeEvents.instance;
  }

  ShopMirror? _mirror() {
    if (_channel.isClosed) return _releasedMirror;
    final id = _stateShopId;
    return id == null ? null : NativeEvents.instance.shop(id);
  }

  /// Where the shop's native initialization stands; [SdkState.notInitialized]
  /// before [REES46.initialize] and after [release].
  SdkState get state => _mirror()?.state ?? SdkState.notInitialized;

  /// The current [state] at once, then every change of it; it ends with
  /// [SdkState.notInitialized] once the handle is [release]d.
  Stream<SdkState> get stateChanges {
    final mirror = _mirror();
    if (mirror == null) return Stream<SdkState>.value(state);
    return Stream<SdkState>.multi((controller) {
      controller.add(mirror.state);
      final subscription = mirror.states.listen(
        controller.add,
        onDone: controller.close,
      );
      controller.onCancel = subscription.cancel;
    });
  }

  /// The device's id at this shop (`did`), from the copy the bridge keeps; null
  /// until the server hands one out to a new device.
  String? get deviceId => _mirror()?.deviceId;

  /// The id of the current session (`sid`), from the copy the bridge keeps; null
  /// while there is none.
  String? get sessionId => _mirror()?.sessionId;

  /// Registers optional listeners for push lifecycle events emitted by native code.
  ///
  /// [onReceived] hears a push that reached the app, [onDelivered] one whose
  /// notification is on screen, [onClicked] a tap — with the push as the plugin
  /// reads it.
  @Deprecated(
    'Use sdk.notifications.setCallbacks(PushCallbacks(onDelivered: …, '
    'onOpened: …, onClicked: …)).',
  )
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

  /// The push token the native SDK keeps for this shop; null when there is none.
  @Deprecated('Use sdk.notifications.getPushToken().')
  Future<String?> getStoredPushToken() async {
    try {
      return (await notifications.readPushToken())?.token;
    } on PlatformException {
      // As released: an unknown shop, or one not initialized yet, has no token.
      return null;
    }
  }

  /// Routes [payload] to the native `Rees46.handlePush` for [event] (the entry a
  /// host with its own messaging service calls). Prefer [REES46.handlePush],
  /// which resolves the target shop and drops unroutable pushes first.
  Future<void> handlePush(Map<String, String> payload, PushEvent event) {
    return _api.handlePush(payload, event.index);
  }

  /// Fires this handle's registered push callbacks for [event]. Used by
  /// [REES46.handlePush] to deliver an inbound push to the shop it routed to,
  /// independent of the process-global Pigeon push channel.
  void dispatchInboundPush(PushEvent event, Map<String, String?> payload) {
    switch (event) {
      case PushEvent.received:
        _pushCallbacks.onPushReceived(payload);
      case PushEvent.delivered:
        _pushCallbacks.onPushDelivered(payload);
      case PushEvent.clicked:
        _pushCallbacks.onPushClicked(payload);
    }
  }

  Future<void> initialize(SdkInitConfig config) {
    if (_channel.isClosed) {
      return Future<void>.error(SdkException(const SdkErrorNotInitialized()));
    }
    _popups.autoPresentation = config.enableAutoPopupPresentation ?? true;
    // The native side reports popups under the shop id it was initialized with.
    PopupDispatcher.instance.register(config.shopId, _popups);
    PopupsV3Hooks.initialized(tracking, config);
    _stateShopId = config.shopId;
    return _ready = _start(config);
  }

  Future<void> _start(SdkInitConfig config) async {
    final snapshot = await _initHandler.initialize(config);
    // Released while the native side started it: the shop's next instance owns the
    // mirror now.
    if (_channel.isClosed) throw SdkException(const SdkErrorNotInitialized());
    final mirror = NativeEvents.instance.shop(config.shopId)..apply(snapshot);
    await mirror.whenUsable();
  }

  Future<void>? _ready;

  /// The outcome of the native initialization: completes once the shop works —
  /// [SdkState.ready], or [SdkState.retrying] with a device id from an earlier
  /// launch — and fails with an [SdkException] (`shopBlocked`) once the server
  /// refused the shop, or with the error that kept the native SDK from starting it.
  /// [REES46.initialize] hands the handle back at once — await this to learn
  /// whether the shop is up. Before [initialize] is called it completes at once;
  /// released while it waits, it fails with `notInitialized`.
  Future<void> get ready => _ready ?? Future<void>.value();

  /// Sends the shop's queued events now, without waiting for the queue's own
  /// triggers. Completes once each event queued at the call was tried — sent, or
  /// kept for later: no network, a server that asked to wait, an instance not
  /// ready yet — so it promises no delivery. The only error is `notInitialized`,
  /// after [release].
  Future<void> flush() => sdkCall(() async {
    _ensureLive();
    await _api.flush(shopId);
  });

  /// Stops the shop's instance: nothing more is sent, the queued events stay on
  /// the device for the next launch, and the instance leaves the registry —
  /// [REES46.getInstance] no longer finds it. From then on every call of this
  /// handle fails with `notInitialized`, [state] is [SdkState.notInitialized], and
  /// [deviceId] and [sessionId] keep their last values. A new [REES46.initialize]
  /// of the shop makes a fresh instance and a new handle. Releasing twice does
  /// nothing.
  void release() {
    if (_channel.isClosed) return;
    // The native release goes out before the channel closes: a call is handed to
    // the channel as it is made.
    unawaited(
      _api.release(shopId).catchError((Object error) {
        debugPrint('REES46: release of shop $shopId failed: $error');
      }),
    );
    _channel.close();
    PushDispatcher.instance.unregister(shopId, _pushCallbacks);
    final id = _stateShopId;
    if (id != null) {
      PopupDispatcher.instance.unregister(id, _popups);
      _releasedMirror = NativeEvents.instance.release(id);
    }
    HandleReleases.released(this);
  }

  /// Forgets the shop's customer on this device: the device id, the session, the
  /// queued events, the saved `/init` answer and the rest of the customer's data;
  /// the device's push token, A/B group and advertising id stay. The instance
  /// stays and asks `/init` again: [deviceId] is null until the new device id
  /// comes, and requests made meanwhile wait for it. Other shops keep their
  /// customers. `notInitialized` after [release].
  Future<void> deleteUserCredentials() => sdkCall(() async {
    _ensureLive();
    final snapshot = await _api.deleteUserCredentials(shopId);
    if (!_channel.isClosed) NativeEvents.instance.onSnapshot(snapshot);
  });

  /// A released handle takes no call, whichever channel it was given.
  void _ensureLive() {
    if (_channel.isClosed) throw SdkException(const SdkErrorNotInitialized());
  }

  /// Whether the SDK shows popups by itself: the server popups while no [onPopup] is
  /// set, and the other popups the SDK shows by itself (one shown by hand is shown all
  /// the same).
  /// `enableAutoPopupPresentation` of the config sets it on [initialize]; it may be
  /// changed at any time — off, say, while a screen of the app must not be covered.
  bool get enableAutoPopupPresentation => _popups.autoPresentation;

  set enableAutoPopupPresentation(bool value) =>
      _popups.autoPresentation = value;

  /// Takes the server popups (in-app messages) of this shop instead of the SDK showing
  /// them.
  ///
  /// Popups arrive with the responses to init and tracking calls. Without a handler —
  /// this one or the app-wide `REES46.onPopup`, which this one wins over — the SDK
  /// shows each over the app's root navigator, unless `enableAutoPopupPresentation` is
  /// off. With one, the SDK shows nothing: the handler gets every popup once its delay
  /// has passed and decides — draw it (for instance with `PersonalizationInAppPopup`)
  /// and report it with `tracking.popupShown(popup.id)`, let the SDK show it with
  /// [presentPopup], or drop it. A popup shown within the last minute is not handed
  /// over again. Called on the main isolate.
  void Function(InAppPopup popup)? get onPopup => _popups.onPopup;

  set onPopup(void Function(InAppPopup popup)? handler) =>
      _popups.onPopup = handler;

  /// Shows [popup] the way the SDK shows server popups — over the app's root navigator,
  /// after any popup already on screen, from whichever shop — and reports it as shown
  /// for this shop. For a popup taken with [onPopup] and held back. Completes when the popup closes, or at once when it cannot
  /// be shown.
  Future<void> presentPopup(InAppPopup popup) => _popups.present(popup);

  /// Writes the customer's profile: a delegate of [ProfileApi.set]. The fields
  /// [ProfileUpdateRequest] has no place for go as the free-form fields the API
  /// reads, as before.
  @Deprecated('Use sdk.profile.set(ProfileUpdateRequest(…)).')
  Future<void> setProfile(ProfileParams params) =>
      profile.set(profileParamsToRequest(params));

  /// Subscribes or unsubscribes the client per channel and mailing type: a delegate
  /// of [SubscriptionsApi.manage].
  @Deprecated('Use sdk.subscriptions.manage(request).')
  Future<void> manageSubscription(SubscriptionsUpdateRequest params) =>
      subscriptions.manage(params);

  /// The current session id from the native SDK; see [sessionId] for the copy the
  /// bridge keeps.
  Future<String> getSid() {
    return _api.getSid(shopId);
  }

  /// The device id from the native SDK, or null before the first `/init`; see
  /// [deviceId] for the copy the bridge keeps.
  Future<String?> getDid() {
    return _api.getDid(shopId);
  }

  /// A product's card: a delegate of [ProductsApi.getInfo]. A product the catalog
  /// does not have is an empty [Product], as released.
  @Deprecated('Use sdk.products.getInfo(itemId).')
  Future<Product> getProductInfo(String itemId) async {
    if (itemId.isEmpty) {
      throw ArgumentError.value(itemId, 'itemId', 'must be non-empty');
    }
    return await products.getInfo(itemId) ??
        Product.fromJson(const <String, dynamic>{});
  }

  /// The catalog's listing: a delegate of [ProductsApi.getList].
  @Deprecated('Use sdk.products.getList(request: ProductsListRequest(…)).')
  Future<ProductsListResponse> getProductsList({ProductsListParams? params}) =>
      products.getList(request: productsListParamsToRequest(params));

  /// What to show in an empty search field: a delegate of [SearchApi.blank].
  @Deprecated('Use sdk.search.blank().')
  Future<SearchBlankResponse> searchBlank() => search.blank();

  /// Instant search: a delegate of [SearchApi.instant].
  @Deprecated('Use sdk.search.instant(query, …).')
  Future<SearchInstantResponse> searchInstant(
    String query, {
    SearchInstantParams? params,
  }) async {
    if (query.isEmpty) {
      throw ArgumentError.value(query, 'query', 'must be non-empty');
    }
    return search.instant(
      query,
      locations: splitList(params?.locations),
      excludedBrands: (params?.excludedBrands ?? const []).isEmpty
          ? null
          : params!.excludedBrands,
    );
  }

  /// Full search: a delegate of [SearchApi.full].
  @Deprecated('Use sdk.search.full(query, request: SearchFullRequest(…)).')
  Future<SearchFullResponse> searchFull(
    String query, {
    SearchParams? params,
  }) async {
    if (query.isEmpty) {
      throw ArgumentError.value(query, 'query', 'must be non-empty');
    }
    return search.full(query, request: searchParamsToRequest(params));
  }

  /// Joins the loyalty program: a delegate of [LoyaltyApi.join]. The answer's
  /// [LoyaltyJoinResponse.payload] holds the member's `identifier`. [email] is not
  /// sent: the program's join takes none.
  @Deprecated('Use sdk.loyalty.join(phone, …).')
  Future<LoyaltyJoinResponse> joinLoyalty({
    required String phone,
    String? email,
    String? firstName,
    String? lastName,
  }) async {
    if (phone.isEmpty) {
      throw ArgumentError.value(phone, 'phone', 'must be non-empty');
    }
    final member = await loyalty.join(
      phone,
      firstName: firstName,
      lastName: lastName,
    );
    return LoyaltyJoinResponse(
      status: 'success',
      payload: <String, dynamic>{'identifier': member.identifier},
    );
  }

  /// The loyalty membership of [identifier] (a phone): a delegate of
  /// [LoyaltyApi.getStatus].
  @Deprecated('Use sdk.loyalty.getStatus(phone).')
  Future<LoyaltyStatusResponse> getLoyaltyStatus(String identifier) async {
    if (identifier.isEmpty) {
      throw ArgumentError.value(identifier, 'identifier', 'must be non-empty');
    }
    final status = await loyalty.getStatus(identifier);
    return LoyaltyStatusResponse(
      status: 'success',
      member: status.isMember,
      level: status.level,
    );
  }

  /// The customer's profile: a delegate of [ProfileApi.get]. Without the shop's
  /// secret the API sends no email, phone or name, so they stay empty.
  @Deprecated('Use sdk.profile.get().')
  Future<ProfileResponse> getProfile() async {
    final p = await profile.get();
    return ProfileResponse(
      id: p.id,
      hasEmail: p.hasEmail,
      emailRegisteredAt: p.emailRegisteredAt,
      gender: p.gender?.wireValue,
      computedGender: p.computedGender?.wireValue,
      boughtSomething: p.boughtSomething,
      customProperties: Map<String, dynamic>.from(p.customProperties),
    );
  }

  /// A product's counters: a delegate of [ProductsApi.getCounters].
  @Deprecated('Use sdk.products.getCounters(itemId).')
  Future<ProductCountersResponse> getProductCounters(String item) async {
    if (item.isEmpty) {
      throw ArgumentError.value(item, 'item', 'must be non-empty');
    }
    return products.getCounters(item);
  }

  /// A category's listing: a delegate of [ProductsApi.getCategory]. [brands] and
  /// [locations] are comma-separated; [filters] are the shop's facets by name.
  @Deprecated(
    'Use sdk.products.getCategory(categoryId, request: CategoryRequest(…)).',
  )
  Future<CategoryResponse> getCategory(
    String category, {
    int? limit,
    int? page,
    String? brands,
    String? locations,
    Map<String, List<String>>? filters,
    double? priceMin,
    double? priceMax,
    String? sortBy,
    String? sortDir,
  }) async {
    if (category.isEmpty) {
      throw ArgumentError.value(category, 'category', 'must be non-empty');
    }
    final facets = <String, List<String>>{
      for (final entry in (filters ?? const <String, List<String>>{}).entries)
        if (entry.value.isNotEmpty) entry.key: entry.value,
    };
    return products.getCategory(
      category,
      request: CategoryRequest(
        brands: splitList(brands),
        locations: splitList(locations),
        filters: facets.isEmpty ? null : facets,
        priceMin: priceMin,
        priceMax: priceMax,
        sortBy: (sortBy ?? '').isEmpty ? null : SortBy(sortBy!),
        sortDir: sortDirection(sortDir),
        limit: limit,
        page: page,
      ),
    );
  }

  /// A collection's products: a delegate of [CollectionsApi.get].
  @Deprecated('Use sdk.collections.get(collectionId).')
  Future<CollectionResponse> getCollection(String collectionId) async {
    if (collectionId.isEmpty) {
      throw ArgumentError.value(
        collectionId,
        'collectionId',
        'must be non-empty',
      );
    }
    return collections.get(collectionId);
  }

  /// A recommendation block: a delegate of [RecommendationsApi.get].
  /// [RecommendationParams.imageSize] has no counterpart in the native SDKs and is
  /// not sent.
  @Deprecated(
    'Use sdk.recommendations.get(code, request: RecommendationRequest(…)).',
  )
  Future<RecommendationResponse> getRecommendation(
    String code, {
    RecommendationParams? params,
  }) async {
    if (code.isEmpty) {
      throw ArgumentError.value(code, 'code', 'must be non-empty');
    }
    return recommendations.get(
      code,
      request: recommendationParamsToRequest(params),
    );
  }

  /// Custom event tracking: a delegate of [TrackingApi.custom].
  @Deprecated('Use sdk.tracking.custom(event) instead.')
  Future<void> trackEvent(
    String event, {
    int? time,
    String? category,
    String? label,
    int? value,
    Map<String, Object?>? customFields,
  }) => tracking.custom(
    event,
    time: time,
    category: category,
    label: label,
    value: value,
    customFields: customFields,
  );

  /// Purchase tracking: a delegate of [TrackingApi.purchase].
  @Deprecated('Use sdk.tracking.purchase(...) instead.')
  Future<void> trackPurchase({
    required String orderId,
    required double orderPrice,
    required List<PurchaseLineItem> items,
    String? deliveryType,
    String? deliveryAddress,
    String? paymentType,
    bool isTaxFree = false,
    bool isGiftPackage = false,
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
  }) => tracking.purchase(
    orderId: orderId,
    orderPrice: orderPrice,
    items: items,
    deliveryType: deliveryType,
    deliveryAddress: deliveryAddress,
    paymentType: paymentType,
    isTaxFree: isTaxFree,
    isGiftPackage: isGiftPackage,
    promocode: promocode,
    orderCash: orderCash,
    orderBonuses: orderBonuses,
    orderDelivery: orderDelivery,
    orderDiscount: orderDiscount,
    channel: channel,
    custom: custom,
    recommendedSource: recommendedSource,
    stream: stream,
    segment: segment,
  );
}

/// Stories of the UI kit: the block data and the system handler for its links. It lives
/// in this library because it calls the host API the handle owns.
extension PersonalizationStoriesBridge on PersonalizationSdk {
  /// The stories block [code]: a delegate of [StoriesApi.get].
  @Deprecated('Use sdk.stories.get(code).')
  Future<StoriesBlock> getStories(String code) async {
    if (code.isEmpty) {
      throw ArgumentError.value(code, 'code', 'must be non-empty');
    }
    return stories.get(code);
  }

  /// Opens [url] with the system handler; `false` when nothing could open it.
  Future<bool> openUrl(String url) => _api.openUrl(url);
}

/// The plumbing of the kit's story viewer: the share sheet and the slides seen on this
/// device. Hidden from the package barrel (`export ... hide`) — the viewer reaches it
/// through a direct `src` import.
extension PersonalizationStoryViewerBridge on PersonalizationSdk {
  /// Shows the system share sheet with the link [url]; completes when the sheet is gone.
  /// [anchor] is the "Share" button in global logical pixels: the sheet's popover points
  /// at it on iPad.
  Future<void> shareUrl(String url, Rect anchor) =>
      _api.shareUrl(url, anchor.left, anchor.top, anchor.width, anchor.height);

  /// The stories slides seen on this device for [shop] (slide ids by story id), from the
  /// plugin's own persistent store.
  Future<Map<String, List<String>>> getStoriesSeen(String shop) async {
    final stored = await _api.getStoriesSeen(shop);
    return <String, List<String>>{
      for (final entry in stored.entries)
        entry.key: entry.value.whereType<String>().toList(),
    };
  }

  /// Records slide [slideId] of story [storyId] as seen for [shop].
  Future<void> setStorySlideSeen(String shop, String storyId, String slideId) =>
      _api.setStorySlideSeen(shop, storyId, slideId);
}
