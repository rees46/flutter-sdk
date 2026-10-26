import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    // Internal pigeon channel namespace. Kept decoupled from the pub package
    // name on purpose: it is baked into generated channel names and the tests
    // that mock them, so renaming the package must not churn it.
    dartPackageName: 'personalization_flutter_sdk',
    dartOut: 'lib/src/pigeon/personalization_api.g.dart',
    kotlinOut:
        'android/src/main/kotlin/com/rees46/rees46_flutter_sdk/pigeon/PersonalizationApi.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'com.rees46.rees46_flutter_sdk.pigeon',
    ),
    swiftOut:
        'ios/rees46_sdk/Sources/rees46_sdk/pigeon/PersonalizationApi.g.swift',
  ),
)
class InitConfig {
  final String shopId;
  final String apiDomain;
  final String stream;
  final bool enableLogs;
  final bool autoSendPushToken;
  final bool sendAdvertisingId;
  final bool enableAutoPopupPresentation;
  final bool needReInitialization;

  const InitConfig({
    required this.shopId,
    required this.apiDomain,
    required this.stream,
    required this.enableLogs,
    required this.autoSendPushToken,
    required this.sendAdvertisingId,
    required this.enableAutoPopupPresentation,
    required this.needReInitialization,
  });
}

/// Wire format for one purchase line (maps to native `PurchaseItemRequest`).
/// [amount] is the canonical line quantity; native's redundant `quantity` alias
/// is intentionally not exposed.
class PurchaseLineItemWire {
  final String id;

  /// Number of units of this product in the order (the line quantity).
  final int amount;
  final double price;
  final String? lineId;
  final String? fashionSize;

  const PurchaseLineItemWire({
    required this.id,
    required this.amount,
    required this.price,
    this.lineId,
    this.fashionSize,
  });
}

/// Wire format for profile fields sent to native SDK.
/// All fields are optional — only non-null values are forwarded.
/// [birthday] must be a "yyyy-MM-dd" string.
/// [gender] must be "m" or "f".
/// [customPropertiesJson] is a JSON object string or null.
class ProfileParamsWire {
  final String? email;
  final String? phone;
  final String? loyaltyId;
  final String? firstName;
  final String? lastName;
  final String? birthday;
  final int? age;
  final String? gender;
  final String? location;
  final String? advertisingId;
  final String? fbId;
  final String? vkId;
  final String? telegramId;
  final String? loyaltyCardLocation;
  final String? loyaltyStatus;
  final int? loyaltyBonuses;
  final int? loyaltyBonusesToNextLevel;
  final bool? boughtSomething;
  final String? userId;
  final String? customPropertiesJson;

  const ProfileParamsWire({
    this.email,
    this.phone,
    this.loyaltyId,
    this.firstName,
    this.lastName,
    this.birthday,
    this.age,
    this.gender,
    this.location,
    this.advertisingId,
    this.fbId,
    this.vkId,
    this.telegramId,
    this.loyaltyCardLocation,
    this.loyaltyStatus,
    this.loyaltyBonuses,
    this.loyaltyBonusesToNextLevel,
    this.boughtSomething,
    this.userId,
    this.customPropertiesJson,
  });
}

/// Wire format for `subscriptions/manage`: contacts that identify the client and one flag per
/// channel and mailing type. `true` subscribes, `false` unsubscribes, `null` leaves it unchanged.
class ManageSubscriptionParamsWire {
  final String? email;
  final String? phone;
  final String? externalId;
  final String? loyaltyId;
  final String? telegramId;
  final bool? emailBulk;
  final bool? emailChain;
  final bool? emailTransactional;
  final bool? smsBulk;
  final bool? smsChain;
  final bool? smsTransactional;
  final bool? webPushBulk;
  final bool? webPushChain;
  final bool? webPushTransactional;
  final bool? mobilePushBulk;
  final bool? mobilePushChain;
  final bool? mobilePushTransactional;
  final bool? telegramBulk;
  final bool? telegramChain;
  final bool? telegramTransactional;
  final bool? whatsappBulk;
  final bool? whatsappChain;
  final bool? whatsappTransactional;
  final bool? maxBulk;
  final bool? maxChain;
  final bool? maxTransactional;
  final bool? walletBulk;

  const ManageSubscriptionParamsWire({
    this.email,
    this.phone,
    this.externalId,
    this.loyaltyId,
    this.telegramId,
    this.emailBulk,
    this.emailChain,
    this.emailTransactional,
    this.smsBulk,
    this.smsChain,
    this.smsTransactional,
    this.webPushBulk,
    this.webPushChain,
    this.webPushTransactional,
    this.mobilePushBulk,
    this.mobilePushChain,
    this.mobilePushTransactional,
    this.telegramBulk,
    this.telegramChain,
    this.telegramTransactional,
    this.whatsappBulk,
    this.whatsappChain,
    this.whatsappTransactional,
    this.maxBulk,
    this.maxChain,
    this.maxTransactional,
    this.walletBulk,
  });
}

/// Wire format for one product line in a tracking event (maps to native `TrackingItem`).
///
/// [quantity] is the domain name for the line quantity; native sends it as `amount`.
class TrackingItemWire {
  final String id;
  final int quantity;
  final double? price;
  final String? fashionSize;

  const TrackingItemWire({
    required this.id,
    required this.quantity,
    this.price,
    this.fashionSize,
  });
}

/// Wire format for event attribution (maps to native `TrackingSource`).
///
/// [type] is the wire value of the source type — `dynamic`, `chain`, `bulk`,
/// `transactional`, `instant_search`, `full_search`, `stories`. Dart only ever sends what its
/// `TrackingSourceType` enum produces; the bridges reject anything else.
class TrackingSourceWire {
  final String type;
  final String code;

  const TrackingSourceWire({required this.type, required this.code});
}

// Multi-instance: every per-instance method carries a trailing `String? shopId`
// so the native bridge can resolve the target instance via the native `REES46`
// facade. `shopId == null` means the legacy single/default instance (the
// back-compat fallback). `initialize` needs no extra param — its shop id is
// inside [InitConfig]; `getPlatformVersion` touches no instance.
@HostApi()
abstract class PersonalizationHostApi {
  @async
  void initialize(InitConfig config);

  String getPlatformVersion();

  /// Returns the push token stored by the native SDK (if any).
  String? getStoredPushToken(String? shopId);

  /// [customFieldsJson] is JSON object string or null (maps to native custom fields map).
  @async
  void trackEvent(
    String event,
    int? time,
    String? category,
    String? label,
    int? value,
    String? customFieldsJson,
    String? shopId,
  );

  @async
  void setProfile(ProfileParamsWire params, String? shopId);

  @async
  void manageSubscription(ManageSubscriptionParamsWire params, String? shopId);

  /// Returns the recommendation block as a JSON string.
  /// [paramsJson] is a JSON object string with optional filter parameters.
  /// Dart layer parses the result into [RecommendationResponse].
  @async
  String getRecommendation(String code, String? paramsJson, String? shopId);

  /// Returns the current session ID from the native SDK.
  String getSid(String? shopId);

  /// Returns the device ID assigned by the native SDK, or null before first sync.
  String? getDid(String? shopId);

  /// Returns a single product's details as a JSON string.
  /// Dart layer parses the result into [Product].
  @async
  String getProductInfo(String itemId, String? shopId);

  /// Returns a paginated product catalog list as a JSON string.
  /// [paramsJson] is a JSON object with optional filter fields.
  /// Dart layer parses the result into [ProductsListResponse].
  @async
  String getProductsList(String? paramsJson, String? shopId);

  /// Returns blank search results (trending/popular) as a JSON string.
  /// No parameters — the native SDK decides what to return based on shop config.
  /// Dart layer parses the result into [SearchBlankResponse].
  @async
  String searchBlank(String? shopId);

  /// Returns instant (typeahead) search results as a JSON string.
  /// [paramsJson] may contain optional "locations" (String) and "excluded_brands" ([String]).
  /// Dart layer parses the result into [SearchInstantResponse].
  @async
  String searchInstant(String query, String? paramsJson, String? shopId);

  /// Returns full search results as a JSON string.
  /// [paramsJson] is a JSON object string with optional search parameters.
  /// Dart layer parses the result into [SearchFullResponse].
  @async
  String searchFull(String query, String? paramsJson, String? shopId);

  /// Joins the loyalty program (`loyalty/members/join`) and returns the
  /// response envelope as a JSON string `{ "status": ..., "payload": { ... } }`.
  /// The shop is identified by the SDK's configured `shop_id`; [phone] is required.
  /// Dart layer parses the result into [LoyaltyJoinResponse].
  @async
  String joinLoyalty(
    String phone,
    String? email,
    String? firstName,
    String? lastName,
    String? shopId,
  );

  /// Returns the loyalty membership status (`loyalty/members/status`) as a JSON
  /// string `{ "status": ..., "payload": { "member": ..., "level": { ... } } }`.
  /// [identifier] is the member identifier (phone).
  /// Dart layer parses the result into [LoyaltyStatusResponse].
  @async
  String getLoyaltyStatus(String identifier, String? shopId);

  /// Returns the current user's profile as a JSON string.
  /// Dart layer parses the result into [ProfileResponse].
  @async
  String getProfile(String? shopId);

  /// Returns view / cart / purchase counters for [item] as a JSON string.
  /// Dart layer parses the result into [ProductCountersResponse].
  @async
  String getProductCounters(String item, String? shopId);

  /// Returns a category product listing as a JSON string.
  /// [limit] and [page] paginate the result; both are optional.
  /// Dart layer parses the result into [CategoryResponse].
  @async
  String getCategory(String category, int? limit, int? page, String? shopId);

  /// Returns a merchandised collection's products as a JSON string.
  /// Dart layer parses the result into [CollectionResponse].
  @async
  String getCollection(String collectionId, String? shopId);

  /// Returns the stories block [code] (`stories/{code}`) as the server's JSON string,
  /// untouched: `{ "id": ..., "stories": [...], "settings": {...} }`. Both platforms hand
  /// over the same raw payload, so Dart parses one shape.
  /// Dart layer parses the result into [StoriesBlock].
  @async
  String getStories(String code, String? shopId);

  /// Opens [url] with the system handler (browser or the app that claims the link).
  /// Returns false when nothing could open it.
  @async
  bool openUrl(String url);

  /// The slide ids seen per story id for [shop] — the plugin's own store
  /// (SharedPreferences on Android, UserDefaults on iOS), not the native SDK's. It
  /// survives app restarts. The inner lists are untyped on purpose: the channel
  /// hands nested lists over as `List<Object?>`, and a typed `List<String>` here
  /// generates a lazy cast that throws on the first read.
  Map<String, List<Object?>> getStoriesSeen(String shop);

  /// Records [slideId] of story [storyId] as seen for [shop].
  void setStorySlideSeen(String shop, String storyId, String slideId);

  /// The app's cache directory: Android `Context.cacheDir`, iOS `Library/Caches`. The
  /// stories viewer keeps its video cache under it.
  String getCacheDirectory();

  /// Remembers the app's audio session before the stories viewer plays its first video,
  /// so [endStoriesAudio] can put it back. iOS only; a no-op on Android, where a muted
  /// video never takes the audio focus (`mixWithOthers`).
  void beginStoriesAudio();

  /// While the viewer plays video: muted — the `ambient` category, which never
  /// interrupts other apps' audio; unmuted — `playback`. Also starts watching the
  /// hardware volume (see [PersonalizationStoriesFlutterApi.onStoriesVolumeUp]). iOS
  /// only; a no-op on Android.
  void updateStoriesAudio(bool muted);

  /// The viewer closed: restores the session saved by [beginStoriesAudio] and stops
  /// watching the volume. iOS only; a no-op on Android.
  void endStoriesAudio();

  /// Routes a push to the shop it belongs to (payload `shop_id`) and tracks it
  /// via the native `REES46.handlePush`. [event] is the index of the Dart
  /// `PushEvent` enum: 0 = received, 1 = delivered, 2 = clicked. The native side
  /// maps it to its own vocabulary (Android `PushEventType`, iOS `PushEvent`).
  @async
  void handlePush(Map<String, String> payload, int event);

  // Standard tracking events (`tracking` namespace). Each maps onto the native namespace
  // method of the same name; `trackEvent` and `trackPurchase` above are its `custom` and
  // `purchase` members.

  @async
  void trackProductView(
    String itemId,
    TrackingSourceWire? source,
    String? shopId,
  );

  @async
  void trackCategoryView(String categoryId, String? shopId);

  @async
  void trackSearch(String query, List<String>? results, String? shopId);

  @async
  void trackAddToCart(
    TrackingItemWire item,
    TrackingSourceWire? source,
    String? shopId,
  );

  @async
  void trackSyncCart(List<TrackingItemWire> items, String? shopId);

  @async
  void trackRemoveFromCart(String itemId, String? shopId);

  @async
  void trackAddToFavorites(
    String itemId,
    TrackingSourceWire? source,
    String? shopId,
  );

  @async
  void trackSyncFavorites(List<String> itemIds, String? shopId);

  @async
  void trackRemoveFromFavorites(String itemId, String? shopId);

  @async
  void trackStoryView(
    String storyId,
    String slideId,
    String? code,
    String? shopId,
  );

  @async
  void trackStoryClick(
    String storyId,
    String slideId,
    String? code,
    String? shopId,
  );

  /// Stores the attribution source natively for the next event.
  void trackSetSource(TrackingSourceWire source, String? shopId);

  /// [customJson] and [recommendedSourceJson] are JSON object strings or null.
  @async
  void trackPurchase(
    String orderId,
    double orderPrice,
    List<PurchaseLineItemWire> items,
    String? deliveryType,
    String? deliveryAddress,
    String? paymentType,
    bool isTaxFree,
    bool isGiftPackage,
    String? promocode,
    double? orderCash,
    double? orderBonuses,
    double? orderDelivery,
    double? orderDiscount,
    String? channel,
    String? customJson,
    String? recommendedSourceJson,
    String? stream,
    String? segment,
    String? shopId,
  );

  /// Reports popup [popupId] as shown (`popup/showed`) — native `tracking.popupShown`
  /// (Android) / `trackPopupShown` (iOS). The native SDKs never show a popup themselves
  /// under the plugin, so they never report one either: Dart does, once it is on screen.
  @async
  void trackPopupShown(int popupId, String? shopId);

  /// Opens the system settings where the user turns notifications on for the app: the
  /// app's notification settings on Android, the app's page in Settings on iOS. What the
  /// native popups do for their push-subscription button.
  void openNotificationSettings();
}

/// Server popups, handed over instead of being shown natively: the plugin sets the native
/// presentation listener (Android) / delegate (iOS), which keeps every popup back and
/// forwards it here. Separate from [PersonalizationFlutterApi], which the push dispatcher
/// owns.
@FlutterApi()
abstract class PersonalizationPopupFlutterApi {
  /// A popup arrived for [shopId]. [popupJson] is the popup as the server sends it:
  /// `id`, `position`, `delay`, `components` and `popup_actions` (an object).
  void onPopup(String shopId, String popupJson);
}

// Multi-instance: each inbound push callback carries the `shopId` the push
// routed to (resolved natively from the payload's `shop_id`), so the Dart
// dispatcher delivers it to that shop's registered callbacks. `shopId == null`
// means the legacy single/default instance.
@FlutterApi()
abstract class PersonalizationFlutterApi {
  void onPushReceived(String? shopId, Map<String, String?> payload);

  void onPushDelivered(String? shopId, Map<String, String?> payload);

  void onPushClicked(String? shopId, Map<String, String?> payload);
}

/// Native events of the stories viewer. Separate from [PersonalizationFlutterApi]: the
/// push dispatcher owns that channel, the UI kit owns this one.
@FlutterApi()
abstract class PersonalizationStoriesFlutterApi {
  /// The hardware volume went up while the viewer plays video (iOS: the audio session's
  /// `outputVolume` grew). Android delivers the volume key to Flutter itself.
  void onStoriesVolumeUp();
}
