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

/// The state of one shop's native instance, as the bridge mirrors it: on init and on each change.
class SdkSnapshotWire {
  final String shopId;
  final String state;
  final String? deviceId;
  final String? sessionId;
  final String? segment;
  final bool agentEnabled;
  final PushTokenWire? pushToken;
  final List<PushTokenWire> pushTokens;

  const SdkSnapshotWire({
    required this.shopId,
    required this.state,
    this.deviceId,
    this.sessionId,
    this.segment,
    required this.agentEnabled,
    this.pushToken,
    required this.pushTokens,
  });
}

/// `Product` of the contract (products.md).
class ProductWire {
  final String id;
  final String? groupId;
  final String name;
  final String? brand;
  final String? model;
  final String? description;
  final String? barcode;
  final String url;
  final String? deeplinkAndroid;
  final String? deeplinkIos;
  final String? imageUrl;
  final String? picture;
  final Map<String, String>? resizedImages;
  final double price;
  final String? priceFormatted;
  final double? priceFull;
  final String? priceFullFormatted;
  final double? oldPrice;
  final String? oldPriceFormatted;
  final double? oldPriceFull;
  final String? oldPriceFullFormatted;
  final String currency;
  final int? discountPercent;
  final String? discountFormatted;
  final int? salesRate;
  final double? relativeSalesRate;
  final int? rating;
  final bool isNew;
  final int? stockQuantity;
  final List<String>? categoryIds;
  final List<ProductCategoryWire>? categories;
  final List<ProductParamWire>? params;
  final List<String>? locationIds;

  const ProductWire({
    required this.id,
    this.groupId,
    required this.name,
    this.brand,
    this.model,
    this.description,
    this.barcode,
    required this.url,
    this.deeplinkAndroid,
    this.deeplinkIos,
    this.imageUrl,
    this.picture,
    this.resizedImages,
    required this.price,
    this.priceFormatted,
    this.priceFull,
    this.priceFullFormatted,
    this.oldPrice,
    this.oldPriceFormatted,
    this.oldPriceFull,
    this.oldPriceFullFormatted,
    required this.currency,
    this.discountPercent,
    this.discountFormatted,
    this.salesRate,
    this.relativeSalesRate,
    this.rating,
    required this.isNew,
    this.stockQuantity,
    this.categoryIds,
    this.categories,
    this.params,
    this.locationIds,
  });
}

/// `ProductCategory`.
class ProductCategoryWire {
  final String id;
  final String? name;
  final String? url;
  final String? parentId;
  final int? level;
  final int? count;
  final String? alias;

  const ProductCategoryWire({
    required this.id,
    this.name,
    this.url,
    this.parentId,
    this.level,
    this.count,
    this.alias,
  });
}

/// `ProductParam`.
class ProductParamWire {
  final String key;
  final List<String> values;

  const ProductParamWire({required this.key, required this.values});
}

/// `Location`.
class LocationWire {
  final String id;
  final String name;
  final String? type;

  const LocationWire({required this.id, required this.name, this.type});
}

/// `Brand`.
class BrandWire {
  final String name;
  final int count;

  const BrandWire({required this.name, required this.count});
}

/// `SearchFilter`.
class SearchFilterWire {
  final int? count;
  final int? priority;
  final Map<String, int>? values;
  final double? min;
  final double? max;

  const SearchFilterWire({
    this.count,
    this.priority,
    this.values,
    this.min,
    this.max,
  });
}

/// `ColorFilter`.
class ColorFilterWire {
  final String color;
  final int count;

  const ColorFilterWire({required this.color, required this.count});
}

/// `SizeFilter`.
class SizeFilterWire {
  final String size;
  final int count;

  const SizeFilterWire({required this.size, required this.count});
}

/// `IndustrialFilters`.
class IndustrialFiltersWire {
  final List<ColorFilterWire>? colors;
  final List<SizeFilterWire>? fashionSizes;

  const IndustrialFiltersWire({this.colors, this.fashionSizes});
}

/// `PriceRange`.
class PriceRangeWire {
  final double min;
  final double max;

  const PriceRangeWire({required this.min, required this.max});
}

/// `PriceInterval`.
class PriceIntervalWire {
  final double from;
  final double? to;
  final int? count;

  const PriceIntervalWire({required this.from, this.to, this.count});
}

/// `ProductsListResponse`; `products.getCategory` answers with it too (`CategoryResponse` is its subset).
class ProductsListResponseWire {
  final int? productsTotal;
  final List<ProductWire> products;
  final List<ProductCategoryWire>? categories;
  final List<BrandWire>? brands;
  final List<LocationWire>? locations;
  final Map<String, SearchFilterWire>? filters;
  final IndustrialFiltersWire? industrialFilters;
  final PriceRangeWire? priceRange;
  final List<PriceIntervalWire>? priceRanges;
  final double? priceMedian;

  const ProductsListResponseWire({
    this.productsTotal,
    required this.products,
    this.categories,
    this.brands,
    this.locations,
    this.filters,
    this.industrialFilters,
    this.priceRange,
    this.priceRanges,
    this.priceMedian,
  });
}

/// `ProductsListRequest`; `products.getCategory` takes it as `CategoryRequest` and leaves out `categoryIds` and `merchants`.
class ProductsListRequestWire {
  final List<String>? categoryIds;
  final List<String>? brands;
  final List<String>? merchants;
  final List<String>? locations;
  final double? priceMin;
  final double? priceMax;
  final Map<String, List<String>>? filters;
  final String? sortBy;
  final String? sortDir;
  final int? limit;
  final int? page;

  const ProductsListRequestWire({
    this.categoryIds,
    this.brands,
    this.merchants,
    this.locations,
    this.priceMin,
    this.priceMax,
    this.filters,
    this.sortBy,
    this.sortDir,
    this.limit,
    this.page,
  });
}

/// `ProductCounter`.
class ProductCounterWire {
  final int view;
  final int cart;
  final int purchase;

  const ProductCounterWire({
    required this.view,
    required this.cart,
    required this.purchase,
  });
}

/// `ProductCounterTriggers`.
class ProductCounterTriggersWire {
  final int backInStock;
  final int priceDrop;

  const ProductCounterTriggersWire({
    required this.backInStock,
    required this.priceDrop,
  });
}

/// `ProductCountersResponse`.
class ProductCountersResponseWire {
  final ProductCounterWire? daily;
  final ProductCounterWire? now;
  final ProductCounterTriggersWire? triggers;

  const ProductCountersResponseWire({this.daily, this.now, this.triggers});
}

/// `CollectionResponse`.
class CollectionResponseWire {
  final List<ProductWire> products;

  const CollectionResponseWire({required this.products});
}

/// `RecommendationRequest`.
class RecommendationRequestWire {
  final String? itemId;
  final String? categoryId;
  final String? searchQuery;
  final List<String>? excludedItemIds;
  final List<String>? brands;
  final List<String>? locations;
  final int? limit;
  final bool extended;
  final bool withLocations;

  const RecommendationRequestWire({
    this.itemId,
    this.categoryId,
    this.searchQuery,
    this.excludedItemIds,
    this.brands,
    this.locations,
    this.limit,
    required this.extended,
    required this.withLocations,
  });
}

/// `RecommendationResponse`.
class RecommendationResponseWire {
  final int? id;
  final String? title;
  final String? link;
  final List<ProductWire> products;
  final List<String> itemIds;

  const RecommendationResponseWire({
    this.id,
    this.title,
    this.link,
    required this.products,
    required this.itemIds,
  });
}

/// `SearchFullRequest`.
class SearchFullRequestWire {
  final List<String>? categoryIds;
  final List<String>? brands;
  final List<String>? excludedBrands;
  final List<String>? merchants;
  final List<String>? excludedMerchants;
  final List<String>? locations;
  final double? priceMin;
  final double? priceMax;
  final List<String>? colors;
  final List<String>? fashionSizes;
  final List<String>? excludedItemIds;
  final Map<String, List<String>>? filters;
  final String? sortBy;
  final String? sortDir;
  final bool disableClarification;
  final int? categoryLimit;
  final int? brandLimit;
  final int? limit;
  final int? page;

  const SearchFullRequestWire({
    this.categoryIds,
    this.brands,
    this.excludedBrands,
    this.merchants,
    this.excludedMerchants,
    this.locations,
    this.priceMin,
    this.priceMax,
    this.colors,
    this.fashionSizes,
    this.excludedItemIds,
    this.filters,
    this.sortBy,
    this.sortDir,
    required this.disableClarification,
    this.categoryLimit,
    this.brandLimit,
    this.limit,
    this.page,
  });
}

/// `Query`.
class QueryWire {
  final String name;
  final String? url;
  final double? score;

  const QueryWire({required this.name, this.url, this.score});
}

/// `PopularItem`.
class PopularItemWire {
  final String name;
  final String url;

  const PopularItemWire({required this.name, required this.url});
}

/// `SearchRedirect`.
class SearchRedirectWire {
  final String? query;
  final String? url;
  final String? deeplink;

  const SearchRedirectWire({this.query, this.url, this.deeplink});
}

/// `SearchBlankResponse`.
class SearchBlankResponseWire {
  final List<ProductWire> products;
  final bool lastProducts;
  final List<QueryWire>? lastQueries;
  final List<QueryWire>? suggests;
  final List<PopularItemWire>? popularCategories;
  final List<PopularItemWire>? popularBrands;
  final List<PopularItemWire>? popularLinks;

  const SearchBlankResponseWire({
    required this.products,
    required this.lastProducts,
    this.lastQueries,
    this.suggests,
    this.popularCategories,
    this.popularBrands,
    this.popularLinks,
  });
}

/// `SearchInstantResponse`.
class SearchInstantResponseWire {
  final String? searchQuery;
  final String? searchQueryOriginal;
  final bool? clarification;
  final int? productsTotal;
  final List<ProductWire> products;
  final List<ProductCategoryWire>? categories;
  final List<QueryWire>? queries;
  final List<LocationWire>? locations;
  final SearchRedirectWire? redirect;

  const SearchInstantResponseWire({
    this.searchQuery,
    this.searchQueryOriginal,
    this.clarification,
    this.productsTotal,
    required this.products,
    this.categories,
    this.queries,
    this.locations,
    this.redirect,
  });
}

/// `SearchFullResponse`.
class SearchFullResponseWire {
  final String? searchQuery;
  final String? searchQueryOriginal;
  final bool? clarification;
  final int? productsTotal;
  final List<ProductWire> products;
  final List<ProductCategoryWire>? categories;
  final List<BrandWire>? brands;
  final List<LocationWire>? locations;
  final Map<String, SearchFilterWire>? filters;
  final IndustrialFiltersWire? industrialFilters;
  final PriceRangeWire? priceRange;
  final List<PriceIntervalWire>? priceRanges;
  final double? priceMedian;

  const SearchFullResponseWire({
    this.searchQuery,
    this.searchQueryOriginal,
    this.clarification,
    this.productsTotal,
    required this.products,
    this.categories,
    this.brands,
    this.locations,
    this.filters,
    this.industrialFilters,
    this.priceRange,
    this.priceRanges,
    this.priceMedian,
  });
}

/// `AgentProduct`.
class AgentProductWire {
  final String id;
  final String? name;
  final double? price;
  final double? oldPrice;
  final String? priceFormatted;
  final String? oldPriceFormatted;
  final String? picture;
  final String? url;
  final String? reason;

  const AgentProductWire({
    required this.id,
    this.name,
    this.price,
    this.oldPrice,
    this.priceFormatted,
    this.oldPriceFormatted,
    this.picture,
    this.url,
    this.reason,
  });
}

/// `AgentMessage`; [role] is the wire value (`user`, `assistant`).
class AgentMessageWire {
  final int id;
  final String? role;
  final String? content;
  final String? createdAt;
  final List<AgentProductWire> products;

  const AgentMessageWire({
    required this.id,
    this.role,
    this.content,
    this.createdAt,
    required this.products,
  });
}

/// `AgentSession`.
class AgentSessionWire {
  final int id;
  final String? title;
  final String? updatedAt;
  final List<AgentMessageWire> messages;

  const AgentSessionWire({
    required this.id,
    this.title,
    this.updatedAt,
    required this.messages,
  });
}

/// `AgentDialogResponse`.
class AgentDialogResponseWire {
  final List<AgentSessionWire> sessions;
  final AgentSessionWire? session;

  const AgentDialogResponseWire({required this.sessions, this.session});
}

/// `AgentResponse`.
class AgentResponseWire {
  final AgentSessionWire session;
  final AgentMessageWire message;

  const AgentResponseWire({required this.session, required this.message});
}

/// `CartItem`.
class CartItemWire {
  final String id;
  final int quantity;

  const CartItemWire({required this.id, required this.quantity});
}

/// `Profile`; genders are the wire values `m` / `f`.
class ProfileWire {
  final String? id;
  final bool? hasEmail;
  final String? emailRegisteredAt;
  final String? gender;
  final String? computedGender;
  final bool? boughtSomething;
  final Map<String, Object?>? customProperties;

  const ProfileWire({
    this.id,
    this.hasEmail,
    this.emailRegisteredAt,
    this.gender,
    this.computedGender,
    this.boughtSomething,
    this.customProperties,
  });
}

/// `ProfileKid`.
class ProfileKidWire {
  final String? gender;
  final String? birthday;

  const ProfileKidWire({this.gender, this.birthday});
}

/// `ProfileCar`.
class ProfileCarWire {
  final String? brand;
  final String? model;
  final String? vds;

  const ProfileCarWire({this.brand, this.model, this.vds});
}

/// `ProfileUpdateRequest`; [gender] is `m` or `f`.
class ProfileUpdateRequestWire {
  final String? email;
  final String? phone;
  final String? externalId;
  final String? loyaltyId;
  final String? telegramId;
  final String? fbId;
  final String? vkId;
  final String? firstName;
  final String? lastName;
  final String? gender;
  final String? birthday;
  final int? age;
  final String? location;
  final List<ProfileKidWire>? kids;
  final List<ProfileCarWire>? cars;
  final Map<String, Object?>? customProperties;

  const ProfileUpdateRequestWire({
    this.email,
    this.phone,
    this.externalId,
    this.loyaltyId,
    this.telegramId,
    this.fbId,
    this.vkId,
    this.firstName,
    this.lastName,
    this.gender,
    this.birthday,
    this.age,
    this.location,
    this.kids,
    this.cars,
    this.customProperties,
  });
}

/// An item of `Order`, the native SDKs' released model: sums are strings.
class OrderItemWire {
  final int? amount;
  final String? price;
  final String? status;
  final String? originalPrice;
  final String? barcode;
  final String? lineId;
  final String? cancelReason;
  final ProductWire? item;

  const OrderItemWire({
    this.amount,
    this.price,
    this.status,
    this.originalPrice,
    this.barcode,
    this.lineId,
    this.cancelReason,
    this.item,
  });
}

/// `Order` of `profile.getOrders`, the native SDKs' released model: sums are strings.
class OrderWire {
  final int? internalId;
  final String? id;
  final String? date;
  final String? value;
  final String? cashValue;
  final String? bonusesValue;
  final String? deliveryValue;
  final String? promocode;
  final String? deliveryDate;
  final String? internalStatus;
  final String? stream;
  final String? channel;
  final bool? taxFree;
  final String? deliveryType;
  final String? deliveryAddress;
  final String? orderStatus;
  final String? paymentType;
  final List<OrderItemWire> items;

  const OrderWire({
    this.internalId,
    this.id,
    this.date,
    this.value,
    this.cashValue,
    this.bonusesValue,
    this.deliveryValue,
    this.promocode,
    this.deliveryDate,
    this.internalStatus,
    this.stream,
    this.channel,
    this.taxFree,
    this.deliveryType,
    this.deliveryAddress,
    this.orderStatus,
    this.paymentType,
    required this.items,
  });
}

/// `SubscriptionsUpdateRequest`: `true` subscribes, `false` unsubscribes, `null` leaves it.
class SubscriptionsUpdateRequestWire {
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
  final bool? walletChain;
  final bool? walletTransactional;

  const SubscriptionsUpdateRequestWire({
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
    this.walletChain,
    this.walletTransactional,
  });
}

/// `SubscriptionStatus`.
class SubscriptionStatusWire {
  final bool exists;
  final bool emailBulk;
  final bool emailChain;
  final bool emailTransactional;
  final bool smsBulk;
  final bool smsChain;
  final bool smsTransactional;
  final bool webPushBulk;
  final bool webPushChain;
  final bool webPushTransactional;
  final bool mobilePushBulk;
  final bool mobilePushChain;
  final bool mobilePushTransactional;
  final bool telegramBulk;
  final bool telegramChain;
  final bool telegramTransactional;
  final bool whatsappBulk;
  final bool whatsappChain;
  final bool whatsappTransactional;
  final bool maxBulk;
  final bool maxChain;
  final bool maxTransactional;
  final bool walletBulk;
  final bool walletChain;
  final bool walletTransactional;
  final bool hasWebPush;
  final bool hasMobilePush;
  final bool emailInvalid;
  final bool emailBlacklisted;
  final bool emailBounced;
  final bool emailSuppressed;
  final bool emailConfirmed;

  const SubscriptionStatusWire({
    required this.exists,
    required this.emailBulk,
    required this.emailChain,
    required this.emailTransactional,
    required this.smsBulk,
    required this.smsChain,
    required this.smsTransactional,
    required this.webPushBulk,
    required this.webPushChain,
    required this.webPushTransactional,
    required this.mobilePushBulk,
    required this.mobilePushChain,
    required this.mobilePushTransactional,
    required this.telegramBulk,
    required this.telegramChain,
    required this.telegramTransactional,
    required this.whatsappBulk,
    required this.whatsappChain,
    required this.whatsappTransactional,
    required this.maxBulk,
    required this.maxChain,
    required this.maxTransactional,
    required this.walletBulk,
    required this.walletChain,
    required this.walletTransactional,
    required this.hasWebPush,
    required this.hasMobilePush,
    required this.emailInvalid,
    required this.emailBlacklisted,
    required this.emailBounced,
    required this.emailSuppressed,
    required this.emailConfirmed,
  });
}

/// `BackInStockProperties`.
class BackInStockPropertiesWire {
  final String? fashionSize;
  final String? fashionColor;
  final String? barcode;

  const BackInStockPropertiesWire({
    this.fashionSize,
    this.fashionColor,
    this.barcode,
  });
}

/// `Segment`.
class SegmentWire {
  final int id;
  final String? type;

  const SegmentWire({required this.id, this.type});
}

/// `PushToken`; [provider] is `apns`, `fcm` or `hms`.
class PushTokenWire {
  final String token;
  final String provider;

  const PushTokenWire({required this.token, required this.provider});
}

/// `PushAction`.
class PushActionWire {
  final String id;
  final String title;
  final String? url;

  const PushActionWire({required this.id, required this.title, this.url});
}

/// `PushTarget`; [type] is the wire value of `PushTargetType`.
class PushTargetWire {
  final String type;
  final String uri;
  final Map<String, Object?> payload;

  const PushTargetWire({
    required this.type,
    required this.uri,
    required this.payload,
  });
}

/// `PushPayload`.
class PushPayloadWire {
  final String? shopId;
  final String code;
  final String type;
  final String? title;
  final String? body;
  final String? icon;
  final String? image;
  final List<PushActionWire> actions;
  final PushTargetWire? target;
  final String? source;
  final String? sound;
  final Map<String, Object?> data;

  const PushPayloadWire({
    this.shopId,
    required this.code,
    required this.type,
    this.title,
    this.body,
    this.icon,
    this.image,
    required this.actions,
    this.target,
    this.source,
    this.sound,
    required this.data,
  });
}

/// The statistics of a message in `notifications.getHistory`.
class NotificationStatisticsWire {
  final bool clicked;
  final bool complained;
  final bool hardBounced;
  final bool opened;
  final bool purchased;
  final bool softBounced;
  final bool unsubscribed;

  const NotificationStatisticsWire({
    required this.clicked,
    required this.complained,
    required this.hardBounced,
    required this.opened,
    required this.purchased,
    required this.softBounced,
    required this.unsubscribed,
  });
}

/// A message in `notifications.getHistory`.
class NotificationMessageWire {
  final String? body;
  final int? campaignId;
  final String? channel;
  final String? code;
  final String? date;
  final String? icon;
  final String? picture;
  final String? sentAt;
  final NotificationStatisticsWire? statistics;
  final String? subject;
  final String? type;
  final String? url;

  const NotificationMessageWire({
    this.body,
    this.campaignId,
    this.channel,
    this.code,
    this.date,
    this.icon,
    this.picture,
    this.sentAt,
    this.statistics,
    this.subject,
    this.type,
    this.url,
  });
}

/// The answer of `notifications.getHistory`.
class NotificationHistoryWire {
  final String? status;
  final List<NotificationMessageWire> messages;

  const NotificationHistoryWire({this.status, required this.messages});
}

/// `StoriesBlock`.
class StoriesBlockWire {
  final String id;
  final List<StoryWire> stories;

  const StoriesBlockWire({required this.id, required this.stories});
}

/// `Story`.
class StoryWire {
  final String id;
  final String name;
  final String avatar;
  final bool viewed;
  final bool pinned;
  final int startPosition;
  final List<StorySlideWire> slides;

  const StoryWire({
    required this.id,
    required this.name,
    required this.avatar,
    required this.viewed,
    required this.pinned,
    required this.startPosition,
    required this.slides,
  });
}

/// `StorySlide`; [type] is `image`, `video` or `product`, [duration] whole seconds.
class StorySlideWire {
  final String id;
  final String type;
  final String background;
  final String backgroundColor;
  final String preview;
  final int duration;
  final List<StoryElementWire> elements;

  const StorySlideWire({
    required this.id,
    required this.type,
    required this.background,
    required this.backgroundColor,
    required this.preview,
    required this.duration,
    required this.elements,
  });
}

/// One element of a slide: [type] is `button`, `product`, `products` or `text_block`, and the fields of that kind are set.
class StoryElementWire {
  final String type;
  final String? title;
  final String? link;
  final String? linkAndroid;
  final String? linkIos;
  final String? background;
  final String? color;
  final bool? textBold;
  final StoryProductWire? item;
  final String? showLabel;
  final String? hideLabel;
  final List<StoryProductWire>? products;
  final String? text;
  final double? fontSize;
  final String? fontType;
  final bool? bold;
  final bool? italic;
  final String? textAlign;
  final String? textColor;
  final String? backgroundColor;
  final double? backgroundOpacity;
  final double? lineSpacing;
  final double? yOffset;
  final String? promocode;

  const StoryElementWire({
    required this.type,
    this.title,
    this.link,
    this.linkAndroid,
    this.linkIos,
    this.background,
    this.color,
    this.textBold,
    this.item,
    this.showLabel,
    this.hideLabel,
    this.products,
    this.text,
    this.fontSize,
    this.fontType,
    this.bold,
    this.italic,
    this.textAlign,
    this.textColor,
    this.backgroundColor,
    this.backgroundOpacity,
    this.lineSpacing,
    this.yOffset,
    this.promocode,
  });
}

/// `StoryProduct`.
class StoryProductWire {
  final String id;
  final String name;
  final String brand;
  final String picture;
  final String imageUrl;
  final double price;
  final String priceFormatted;
  final double? oldPrice;
  final String oldPriceFormatted;
  final double discountPercent;
  final String promocode;
  final double priceWithPromocode;
  final String priceWithPromocodeFormatted;
  final String currency;
  final String url;
  final String deeplinkAndroid;
  final String deeplinkIos;

  const StoryProductWire({
    required this.id,
    required this.name,
    required this.brand,
    required this.picture,
    required this.imageUrl,
    required this.price,
    required this.priceFormatted,
    this.oldPrice,
    required this.oldPriceFormatted,
    required this.discountPercent,
    required this.promocode,
    required this.priceWithPromocode,
    required this.priceWithPromocodeFormatted,
    required this.currency,
    required this.url,
    required this.deeplinkAndroid,
    required this.deeplinkIos,
  });
}

/// `PurchaseProbability`.
class PurchaseProbabilityWire {
  final double probability;
  final String? clientId;

  const PurchaseProbabilityWire({required this.probability, this.clientId});
}

/// `LoyaltyMember`.
class LoyaltyMemberWire {
  final String identifier;

  const LoyaltyMemberWire({required this.identifier});
}

/// `LoyaltyLevel`.
class LoyaltyLevelWire {
  final String code;
  final String? name;
  final String? expirationDate;

  const LoyaltyLevelWire({required this.code, this.name, this.expirationDate});
}

/// `LoyaltyStatus`.
class LoyaltyStatusWire {
  final bool isMember;
  final LoyaltyLevelWire? level;

  const LoyaltyStatusWire({required this.isMember, this.level});
}

/// `LoyaltyPromotion`; [rewardType] is the wire value.
class LoyaltyPromotionWire {
  final int id;
  final String name;
  final String? description;
  final String? startDate;
  final String? finishDate;
  final String? stream;
  final String? badgeLabel;
  final String? badgeColor;
  final String? rewardType;

  const LoyaltyPromotionWire({
    required this.id,
    required this.name,
    this.description,
    this.startDate,
    this.finishDate,
    this.stream,
    this.badgeLabel,
    this.badgeColor,
    this.rewardType,
  });
}

/// `Slider` of the contract.
class SliderWire {
  final String code;
  final int width;
  final int height;
  final List<SliderBannerWire> banners;

  const SliderWire({
    required this.code,
    required this.width,
    required this.height,
    required this.banners,
  });
}

/// `SliderBanner`.
class SliderBannerWire {
  final String id;
  final String code;
  final String? imageUrl;
  final String? url;
  final String? deeplinkIos;
  final String? deeplinkAndroid;
  final String? html;

  const SliderBannerWire({
    required this.id,
    required this.code,
    this.imageUrl,
    this.url,
    this.deeplinkIos,
    this.deeplinkAndroid,
    this.html,
  });
}

/// `PollReview`.
class PollReviewWire {
  final int id;

  const PollReviewWire({required this.id});
}

/// `NpsCategory`.
class NpsCategoryWire {
  final String code;
  final String name;
  final String? detractorQuestion;
  final String? passiveQuestion;
  final String? promoterQuestion;
  final String? detractorSuccess;
  final String? passiveSuccess;
  final String? promoterSuccess;
  final String? buttonLabel;

  const NpsCategoryWire({
    required this.code,
    required this.name,
    this.detractorQuestion,
    this.passiveQuestion,
    this.promoterQuestion,
    this.detractorSuccess,
    this.passiveSuccess,
    this.promoterSuccess,
    this.buttonLabel,
  });
}

/// `CsatCampaign`.
class CsatCampaignWire {
  final String code;
  final String name;
  final String? dissatisfiedQuestion;
  final String? neutralQuestion;
  final String? satisfiedQuestion;
  final String? dissatisfiedSuccess;
  final String? neutralSuccess;
  final String? satisfiedSuccess;
  final String? buttonLabel;

  const CsatCampaignWire({
    required this.code,
    required this.name,
    this.dissatisfiedQuestion,
    this.neutralQuestion,
    this.satisfiedQuestion,
    this.dissatisfiedSuccess,
    this.neutralSuccess,
    this.satisfiedSuccess,
    this.buttonLabel,
  });
}

/// `CesCampaign`.
class CesCampaignWire {
  final String code;
  final String name;
  final String? difficultQuestion;
  final String? neutralQuestion;
  final String? easyQuestion;
  final String? difficultSuccess;
  final String? neutralSuccess;
  final String? easySuccess;
  final String? buttonLabel;

  const CesCampaignWire({
    required this.code,
    required this.name,
    this.difficultQuestion,
    this.neutralQuestion,
    this.easyQuestion,
    this.difficultSuccess,
    this.neutralSuccess,
    this.easySuccess,
    this.buttonLabel,
  });
}

/// `PollChannel`.
class PollChannelWire {
  final String code;
  final String name;

  const PollChannelWire({required this.code, required this.name});
}

/// `ProductRatingSummary`; [ratings] is the count per star.
class ProductRatingSummaryWire {
  final int count;
  final double? averageRating;
  final Map<int, int> ratings;

  const ProductRatingSummaryWire({
    required this.count,
    this.averageRating,
    required this.ratings,
  });
}

/// `ProductReview`.
class ProductReviewWire {
  final int id;
  final int rating;
  final String? comment;
  final String? author;
  final String createdAt;

  const ProductReviewWire({
    required this.id,
    required this.rating,
    this.comment,
    this.author,
    required this.createdAt,
  });
}

/// `ProductReviewsResponse`.
class ProductReviewsResponseWire {
  final ProductRatingSummaryWire summary;
  final List<ProductReviewWire> reviews;

  const ProductReviewsResponseWire({
    required this.summary,
    required this.reviews,
  });
}

/// `ClientReview`; [state] is the wire value (`moderation`, `published`, `rejected`).
class ClientReviewWire {
  final int id;
  final String itemId;
  final String orderId;
  final int rating;
  final String? comment;
  final String? state;
  final String createdAt;

  const ClientReviewWire({
    required this.id,
    required this.itemId,
    required this.orderId,
    required this.rating,
    this.comment,
    this.state,
    required this.createdAt,
  });
}

// Multi-instance: every per-instance method carries a trailing `String? shopId`
// so the native bridge can resolve the target instance via the native `Rees46`
// facade. `shopId == null` means the legacy single/default instance (the
// back-compat fallback). `initialize` needs no extra param — its shop id is
// inside [InitConfig]; `getPlatformVersion` touches no instance.
//
// The namespaces (`products…`, `search…` and the rest) call the native namespace
// method of the same name on the native SDK's new core. A failure comes back as a
// `FlutterError` whose `code` is the type of the native `SdkError`
// (`notInitialized`, `shopBlocked`, `invalidArgument`, `network`, `timeout`,
// `http`, `decoding`, `cancelled`), whose `message` is the error's message and
// whose `details` is `{"httpCode": int?, "serverCode": String?}`. Dart turns it
// into an `SdkException`. A shop the bridge does not know is `notInitialized`.
@HostApi()
abstract class PersonalizationHostApi {
  /// Starts the shop on the native SDK's new core (`Rees46.initializeBridge`)
  /// and answers with its state at once; [PersonalizationStateFlutterApi] tells
  /// every change after that.
  @async
  SdkSnapshotWire initialize(InitConfig config);

  String getPlatformVersion();

  /// The shop's state as the native instance has it now.
  SdkSnapshotWire getSnapshot(String? shopId);

  /// Returns the current session ID from the native SDK.
  String getSid(String? shopId);

  /// Returns the device ID assigned by the native SDK, or null before first sync.
  String? getDid(String? shopId);

  // region tracking

  /// `tracking.custom`. [customFields] are the event's free-form fields.
  @async
  void trackEvent(
    String event,
    int? time,
    String? category,
    String? label,
    int? value,
    Map<String, Object?>? customFields,
    String? shopId,
  );

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

  /// `tracking.bannerView`: a banner of a slider was shown.
  @async
  void trackBannerView(String bannerId, String code, String? shopId);

  /// `tracking.bannerClick`: a banner of a slider was tapped.
  @async
  void trackBannerClick(String bannerId, String code, String? shopId);

  /// Stores the attribution source natively for the next event.
  void trackSetSource(TrackingSourceWire source, String? shopId);

  /// `tracking.purchase`. [custom] and [recommendedSource] are free-form.
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
    Map<String, Object?>? custom,
    Map<String, Object?>? recommendedSource,
    String? stream,
    String? segment,
    String? shopId,
  );

  /// Reports popup [popupId] as shown (`popup/showed`) — native `tracking.popupShown`.
  /// The native SDKs never show a popup themselves under the plugin, so they never
  /// report one either: Dart does, once it is on screen.
  @async
  void trackPopupShown(int popupId, String? shopId);

  // endregion

  // region products

  @async
  ProductWire? productsGetInfo(String itemId, String? shopId);

  @async
  ProductsListResponseWire productsGetList(
    ProductsListRequestWire request,
    String? shopId,
  );

  @async
  ProductCountersResponseWire productsGetCounters(
    String itemId,
    String? shopId,
  );

  /// `products.getCategory`: [request] without `categoryIds` and `merchants`.
  @async
  ProductsListResponseWire productsGetCategory(
    String categoryId,
    ProductsListRequestWire request,
    String? shopId,
  );

  // endregion

  @async
  CollectionResponseWire collectionsGet(String collectionId, String? shopId);

  @async
  RecommendationResponseWire recommendationsGet(
    String code,
    RecommendationRequestWire request,
    String? shopId,
  );

  // region search

  /// `search.agentEnabled`, read now from the last `/init` answer.
  bool searchAgentEnabled(String? shopId);

  @async
  SearchBlankResponseWire searchBlank(String? shopId);

  @async
  SearchInstantResponseWire searchInstant(
    String query,
    List<String>? locations,
    List<String>? excludedMerchants,
    List<String>? excludedBrands,
    String? shopId,
  );

  @async
  SearchFullResponseWire searchFull(
    String query,
    SearchFullRequestWire request,
    String? shopId,
  );

  @async
  AgentDialogResponseWire searchAgentDialog(
    int? sessionId,
    List<String>? locations,
    String? shopId,
  );

  @async
  AgentResponseWire searchAgent(
    String message,
    int? sessionId,
    List<String>? locations,
    String? shopId,
  );

  // endregion

  // region cart

  @async
  List<CartItemWire> cartGet(String? shopId);

  /// A server method: [shopSecret] is passed by the caller and never kept.
  @async
  void cartClear(
    String shopSecret,
    String? email,
    String? phone,
    String? loyaltyId,
    String? externalId,
    String? telegramId,
    String? shopId,
  );

  // endregion

  // region profile

  @async
  ProfileWire profileGet(String? shopId);

  @async
  void profileSet(ProfileUpdateRequestWire request, String? shopId);

  @async
  List<ProductWire> profileGetLastOrder(String? shopId);

  /// A server method: [shopSecret] is passed by the caller and never kept.
  @async
  List<OrderWire> profileGetOrders(
    String shopSecret,
    String? did,
    String? email,
    String? phone,
    String? loyaltyId,
    String? externalId,
    String? dateFrom,
    String? shopId,
  );

  // endregion

  // region subscriptions

  @async
  void subscriptionsManage(
    SubscriptionsUpdateRequestWire request,
    String? shopId,
  );

  @async
  SubscriptionStatusWire subscriptionsCheck(String? shopId);

  @async
  void subscriptionsSubscribeForPriceDrop(
    String itemId,
    double currentPrice,
    String? email,
    String? phone,
    String? shopId,
  );

  @async
  void subscriptionsUnsubscribeFromPriceDrop(
    List<String> itemIds,
    String? email,
    String? phone,
    String? shopId,
  );

  @async
  void subscriptionsSubscribeForBackInStock(
    String itemId,
    BackInStockPropertiesWire? properties,
    String? email,
    String? phone,
    String? shopId,
  );

  @async
  void subscriptionsUnsubscribeFromBackInStock(
    List<String> itemIds,
    String? email,
    String? phone,
    String? shopId,
  );

  // endregion

  // region segments

  @async
  void segmentsAdd(int segmentId, String? email, String? phone, String? shopId);

  @async
  void segmentsRemove(
    int segmentId,
    String? email,
    String? phone,
    String? shopId,
  );

  @async
  List<SegmentWire> segmentsGet(String? shopId);

  // endregion

  // region notifications

  @async
  void notificationsTrackDelivered(String code, String type, String? shopId);

  @async
  void notificationsTrackOpened(String code, String type, String? shopId);

  @async
  void notificationsTrackClicked(String code, String type, String? shopId);

  @async
  void notificationsTrackClosed(String code, String type, String? shopId);

  /// The push token the native SDK keeps for the shop, read without the network;
  /// [provider] is `apns`, `fcm` or `hms`.
  PushTokenWire? notificationsGetPushToken(String? provider, String? shopId);

  @async
  void notificationsSetPushToken(String token, String provider, String? shopId);

  /// A server method: [shopSecret] is passed by the caller and never kept.
  @async
  NotificationHistoryWire notificationsGetHistory(
    String shopSecret,
    String type,
    String? phone,
    String? email,
    String? externalId,
    String? loyaltyId,
    String? channel,
    int? limit,
    int? page,
    String? dateFrom,
    String? did,
    String? shopId,
  );

  /// Routes a push to the shop it belongs to (payload `shop_id`) and tracks it
  /// via the native `Rees46.handlePush`. [event] is the index of the Dart
  /// `PushEvent` enum: 0 = received (native `delivered`), 1 = delivered (native
  /// `opened`: the notification is on screen), 2 = clicked.
  @async
  void handlePush(Map<String, String> payload, int event);

  // endregion

  @async
  StoriesBlockWire storiesGet(String code, String? shopId);

  @async
  PurchaseProbabilityWire predictGetProbabilityToPurchase(String? shopId);

  // region loyalty

  /// [gender] is `m` or `f`.
  @async
  LoyaltyMemberWire loyaltyJoin(
    String phone,
    String? firstName,
    String? lastName,
    String? gender,
    String? birthday,
    String? shopId,
  );

  @async
  LoyaltyStatusWire loyaltyGetStatus(String phone, String? shopId);

  @async
  List<LoyaltyPromotionWire> loyaltyGetPromotions(
    String? locationId,
    List<String>? promoCodes,
    bool? chargeBonuses,
    String? currentTime,
    String? shopId,
  );

  // endregion

  @async
  SliderWire slidersGet(
    String code,
    List<String>? tags,
    String? locationId,
    String? shopId,
  );

  // region reviews

  @async
  PollReviewWire reviewsCreateNps(
    int rate,
    String channel,
    String category,
    String? orderId,
    String? comment,
    String? label,
    String? shopId,
  );

  @async
  PollReviewWire reviewsCreateCsat(
    int rate,
    String channel,
    String campaign,
    String? orderId,
    String? comment,
    String? label,
    String? shopId,
  );

  @async
  PollReviewWire reviewsCreateCes(
    int rate,
    String channel,
    String campaign,
    String? orderId,
    String? comment,
    String? label,
    String? shopId,
  );

  @async
  List<NpsCategoryWire> reviewsGetNpsCategories(String? shopId);

  @async
  List<PollChannelWire> reviewsGetNpsChannels(String? shopId);

  @async
  List<CsatCampaignWire> reviewsGetCsatCampaigns(String? shopId);

  @async
  List<CesCampaignWire> reviewsGetCesCampaigns(String? shopId);

  @async
  ProductReviewsResponseWire reviewsGetProductReviews(
    String itemId,
    int? limit,
    int? offset,
    String? shopId,
  );

  @async
  List<ClientReviewWire> reviewsGetClientReviews(
    String orderId,
    String? shopId,
  );

  // endregion

  // region UI plumbing (not the SDK contract: the kit's own needs)

  /// Opens [url] with the system handler (browser or the app that claims the link).
  /// Returns false when nothing could open it.
  @async
  bool openUrl(String url);

  /// Shows the system share sheet with one link [url] — the "Share" button of the stories
  /// viewer. Completes when the sheet is gone: iOS — `completionWithItemsHandler` of
  /// `UIActivityViewController`; Android — the window got its focus back after the
  /// chooser (`Intent.createChooser` of `ACTION_SEND`). The anchor is the button in
  /// logical pixels of the Flutter view: the popover of the sheet points at it on iPad.
  @async
  void shareUrl(
    String url,
    double anchorX,
    double anchorY,
    double anchorWidth,
    double anchorHeight,
  );

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

  /// Opens the system settings where the user turns notifications on for the app: the
  /// app's notification settings on Android, the app's page in Settings on iOS. What the
  /// native popups do for their push-subscription button.
  void openNotificationSettings();

  // endregion
}

/// What the native instances tell Dart on their own: a shop's state, the push
/// events and the push tokens the native SDK sees. Separate from
/// [PersonalizationFlutterApi], which carries the legacy push callbacks.
@FlutterApi()
abstract class PersonalizationStateFlutterApi {
  /// A shop's state, device id, session or A/B group changed.
  void onSnapshot(SdkSnapshotWire snapshot);

  /// A push event the native SDK handled for [shopId]: [event] is `delivered`,
  /// `opened`, `clicked` or `closed`.
  void onPushEvent(String shopId, String event, PushPayloadWire payload);

  /// A new push token the native SDK got from APNs, FCM or HMS.
  void onPushToken(PushTokenWire token);
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
