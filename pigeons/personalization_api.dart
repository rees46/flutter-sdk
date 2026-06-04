import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartPackageName: 'personalization_flutter_sdk',
    dartOut: 'lib/src/pigeon/personalization_api.g.dart',
    kotlinOut:
        'android/src/main/kotlin/com/rees46/rees46_flutter_sdk/pigeon/PersonalizationApi.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'com.rees46.rees46_flutter_sdk.pigeon',
    ),
    swiftOut: 'ios/Classes/pigeon/PersonalizationApi.g.swift',
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

@HostApi()
abstract class PersonalizationHostApi {
  @async
  void initialize(InitConfig config);

  String getPlatformVersion();

  /// Returns the push token stored by the native SDK (if any).
  String? getStoredPushToken();

  /// [customFieldsJson] is JSON object string or null (maps to native custom fields map).
  @async
  void trackEvent(
    String event,
    int? time,
    String? category,
    String? label,
    int? value,
    String? customFieldsJson,
  );

  @async
  void setProfile(ProfileParamsWire params);

  /// Returns the recommendation block as a JSON string.
  /// [paramsJson] is a JSON object string with optional filter parameters.
  /// Dart layer parses the result into [RecommendationResponse].
  @async
  String getRecommendation(String code, String? paramsJson);

  /// Returns the current session ID from the native SDK.
  String getSid();

  /// Returns the device ID assigned by the native SDK, or null before first sync.
  String? getDid();

  /// Returns a single product's details as a JSON string.
  /// Dart layer parses the result into [Product].
  @async
  String getProductInfo(String itemId);

  /// Returns a paginated product catalog list as a JSON string.
  /// [paramsJson] is a JSON object with optional filter fields.
  /// Dart layer parses the result into [ProductsListResponse].
  @async
  String getProductsList(String? paramsJson);

  /// Returns blank search results (trending/popular) as a JSON string.
  /// No parameters — the native SDK decides what to return based on shop config.
  /// Dart layer parses the result into [SearchBlankResponse].
  @async
  String searchBlank();

  /// Returns instant (typeahead) search results as a JSON string.
  /// [paramsJson] may contain optional "locations" (String) and "excluded_brands" ([String]).
  /// Dart layer parses the result into [SearchInstantResponse].
  @async
  String searchInstant(String query, String? paramsJson);

  /// Returns full search results as a JSON string.
  /// [paramsJson] is a JSON object string with optional search parameters.
  /// Dart layer parses the result into [SearchFullResponse].
  @async
  String searchFull(String query, String? paramsJson);

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
  );
}

@FlutterApi()
abstract class PersonalizationFlutterApi {
  void onPushReceived(Map<String, String?> payload);

  void onPushDelivered(Map<String, String?> payload);

  void onPushClicked(Map<String, String?> payload);
}
