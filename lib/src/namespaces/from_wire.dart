// The models of the native channel turned into the public Dart models: the
// contract's models, and the released ones with the contract's fields added. Not
// exported.

import '../category/category_response.dart';
import '../collection/collection_response.dart';
import '../loyalty/loyalty_response.dart' show LoyaltyLevel;
import '../models/agent_models.dart';
import '../models/cart_models.dart';
import '../models/catalog_models.dart';
import '../models/loyalty_models.dart';
import '../models/predict_models.dart';
import '../models/profile_models.dart';
import '../models/push_models.dart';
import '../models/review_models.dart';
import '../models/segment_models.dart';
import '../models/slider_models.dart';
import '../models/subscription_models.dart';
import '../models/values.dart';
import '../pigeon/personalization_api.g.dart' as pigeon;
import '../products/product_counters_response.dart';
import '../products/products_list_response.dart';
import '../recommendation/recommendation_response.dart';
import '../search/search_response.dart';
import '../stories/stories_response.dart';

// region generated from the contract's models

ProductParam productParamFromWire(pigeon.ProductParamWire w) =>
    ProductParam(key: w.key, values: w.values);

PriceInterval priceIntervalFromWire(pigeon.PriceIntervalWire w) =>
    PriceInterval(from: w.from, to: w.to, count: w.count);

SearchRedirect searchRedirectFromWire(pigeon.SearchRedirectWire w) =>
    SearchRedirect(query: w.query, url: w.url, deeplink: w.deeplink);

AgentProduct agentProductFromWire(pigeon.AgentProductWire w) => AgentProduct(
  id: w.id,
  name: w.name,
  price: w.price,
  oldPrice: w.oldPrice,
  priceFormatted: w.priceFormatted,
  oldPriceFormatted: w.oldPriceFormatted,
  picture: w.picture,
  url: w.url,
  reason: w.reason,
);

AgentMessage agentMessageFromWire(pigeon.AgentMessageWire w) => AgentMessage(
  id: w.id,
  role: w.role == null ? null : AgentMessageRole(w.role!),
  content: w.content,
  createdAt: w.createdAt,
  products: w.products.map(agentProductFromWire).toList(),
);

AgentSession agentSessionFromWire(pigeon.AgentSessionWire w) => AgentSession(
  id: w.id,
  title: w.title,
  updatedAt: w.updatedAt,
  messages: w.messages.map(agentMessageFromWire).toList(),
);

AgentDialogResponse agentDialogResponseFromWire(
  pigeon.AgentDialogResponseWire w,
) => AgentDialogResponse(
  sessions: w.sessions.map(agentSessionFromWire).toList(),
  session: w.session == null ? null : agentSessionFromWire(w.session!),
);

AgentResponse agentResponseFromWire(pigeon.AgentResponseWire w) =>
    AgentResponse(
      session: agentSessionFromWire(w.session),
      message: agentMessageFromWire(w.message),
    );

CartItem cartItemFromWire(pigeon.CartItemWire w) =>
    CartItem(id: w.id, quantity: w.quantity);

Profile profileFromWire(pigeon.ProfileWire w) => Profile(
  id: w.id,
  hasEmail: w.hasEmail,
  emailRegisteredAt: w.emailRegisteredAt,
  gender: genderFromWire(w.gender),
  computedGender: genderFromWire(w.computedGender),
  boughtSomething: w.boughtSomething,
  customProperties: Map<String, Object?>.unmodifiable(
    w.customProperties ?? const <String, Object?>{},
  ),
);

OrderItem orderItemFromWire(pigeon.OrderItemWire w) => OrderItem(
  amount: w.amount,
  price: w.price,
  status: w.status,
  originalPrice: w.originalPrice,
  barcode: w.barcode,
  lineId: w.lineId,
  cancelReason: w.cancelReason,
  item: w.item == null ? null : productFromWire(w.item!),
);

Order orderFromWire(pigeon.OrderWire w) => Order(
  internalId: w.internalId,
  id: w.id,
  date: w.date,
  value: w.value,
  cashValue: w.cashValue,
  bonusesValue: w.bonusesValue,
  deliveryValue: w.deliveryValue,
  promocode: w.promocode,
  deliveryDate: w.deliveryDate,
  internalStatus: w.internalStatus,
  stream: w.stream,
  channel: w.channel,
  taxFree: w.taxFree,
  deliveryType: w.deliveryType,
  deliveryAddress: w.deliveryAddress,
  orderStatus: w.orderStatus,
  paymentType: w.paymentType,
  items: w.items.map(orderItemFromWire).toList(),
);

SubscriptionStatus subscriptionStatusFromWire(
  pigeon.SubscriptionStatusWire w,
) => SubscriptionStatus(
  exists: w.exists,
  emailBulk: w.emailBulk,
  emailChain: w.emailChain,
  emailTransactional: w.emailTransactional,
  smsBulk: w.smsBulk,
  smsChain: w.smsChain,
  smsTransactional: w.smsTransactional,
  webPushBulk: w.webPushBulk,
  webPushChain: w.webPushChain,
  webPushTransactional: w.webPushTransactional,
  mobilePushBulk: w.mobilePushBulk,
  mobilePushChain: w.mobilePushChain,
  mobilePushTransactional: w.mobilePushTransactional,
  telegramBulk: w.telegramBulk,
  telegramChain: w.telegramChain,
  telegramTransactional: w.telegramTransactional,
  whatsappBulk: w.whatsappBulk,
  whatsappChain: w.whatsappChain,
  whatsappTransactional: w.whatsappTransactional,
  maxBulk: w.maxBulk,
  maxChain: w.maxChain,
  maxTransactional: w.maxTransactional,
  walletBulk: w.walletBulk,
  walletChain: w.walletChain,
  walletTransactional: w.walletTransactional,
  hasWebPush: w.hasWebPush,
  hasMobilePush: w.hasMobilePush,
  emailInvalid: w.emailInvalid,
  emailBlacklisted: w.emailBlacklisted,
  emailBounced: w.emailBounced,
  emailSuppressed: w.emailSuppressed,
  emailConfirmed: w.emailConfirmed,
);

Segment segmentFromWire(pigeon.SegmentWire w) =>
    Segment(id: w.id, type: w.type);

PushToken pushTokenFromWire(pigeon.PushTokenWire w) =>
    PushToken(token: w.token, provider: pushProviderFromWire(w.provider));

PushAction pushActionFromWire(pigeon.PushActionWire w) =>
    PushAction(id: w.id, title: w.title, url: w.url);

PushTarget pushTargetFromWire(pigeon.PushTargetWire w) => PushTarget(
  type: PushTargetType(w.type),
  uri: w.uri,
  payload: Map<String, Object?>.unmodifiable(w.payload),
);

PushPayload pushPayloadFromWire(pigeon.PushPayloadWire w) => PushPayload(
  shopId: w.shopId,
  code: w.code,
  type: w.type,
  title: w.title,
  body: w.body,
  icon: w.icon,
  image: w.image,
  actions: w.actions.map(pushActionFromWire).toList(),
  target: w.target == null ? null : pushTargetFromWire(w.target!),
  source: w.source,
  sound: w.sound,
  data: Map<String, Object?>.unmodifiable(w.data),
);

NotificationStatistics notificationStatisticsFromWire(
  pigeon.NotificationStatisticsWire w,
) => NotificationStatistics(
  clicked: w.clicked,
  complained: w.complained,
  hardBounced: w.hardBounced,
  opened: w.opened,
  purchased: w.purchased,
  softBounced: w.softBounced,
  unsubscribed: w.unsubscribed,
);

NotificationMessage notificationMessageFromWire(
  pigeon.NotificationMessageWire w,
) => NotificationMessage(
  body: w.body,
  campaignId: w.campaignId,
  channel: w.channel,
  code: w.code,
  date: w.date,
  icon: w.icon,
  picture: w.picture,
  sentAt: w.sentAt,
  statistics: w.statistics == null
      ? null
      : notificationStatisticsFromWire(w.statistics!),
  subject: w.subject,
  type: w.type,
  url: w.url,
);

NotificationHistory notificationHistoryFromWire(
  pigeon.NotificationHistoryWire w,
) => NotificationHistory(
  status: w.status,
  messages: w.messages.map(notificationMessageFromWire).toList(),
);

PurchaseProbability purchaseProbabilityFromWire(
  pigeon.PurchaseProbabilityWire w,
) => PurchaseProbability(probability: w.probability, clientId: w.clientId);

LoyaltyMember loyaltyMemberFromWire(pigeon.LoyaltyMemberWire w) =>
    LoyaltyMember(identifier: w.identifier);

LoyaltyStatus loyaltyStatusFromWire(pigeon.LoyaltyStatusWire w) =>
    LoyaltyStatus(
      isMember: w.isMember,
      level: w.level == null
          ? null
          : LoyaltyLevel(
              code: w.level!.code,
              name: w.level!.name,
              expirationDate: w.level!.expirationDate,
            ),
    );

LoyaltyPromotion loyaltyPromotionFromWire(pigeon.LoyaltyPromotionWire w) =>
    LoyaltyPromotion(
      id: w.id,
      name: w.name,
      description: w.description,
      startDate: w.startDate,
      finishDate: w.finishDate,
      stream: w.stream,
      badgeLabel: w.badgeLabel,
      badgeColor: w.badgeColor,
      rewardType: loyaltyRewardTypeFromWire(w.rewardType),
    );

SliderBanner sliderBannerFromWire(pigeon.SliderBannerWire w) => SliderBanner(
  id: w.id,
  code: w.code,
  imageUrl: w.imageUrl,
  url: w.url,
  deeplinkIos: w.deeplinkIos,
  deeplinkAndroid: w.deeplinkAndroid,
  html: w.html,
);

BannerSlider bannerSliderFromWire(pigeon.SliderWire w) => BannerSlider(
  code: w.code,
  width: w.width,
  height: w.height,
  banners: w.banners.map(sliderBannerFromWire).toList(),
);

PollReview pollReviewFromWire(pigeon.PollReviewWire w) => PollReview(id: w.id);

NpsCategory npsCategoryFromWire(pigeon.NpsCategoryWire w) => NpsCategory(
  code: w.code,
  name: w.name,
  detractorQuestion: w.detractorQuestion,
  passiveQuestion: w.passiveQuestion,
  promoterQuestion: w.promoterQuestion,
  detractorSuccess: w.detractorSuccess,
  passiveSuccess: w.passiveSuccess,
  promoterSuccess: w.promoterSuccess,
  buttonLabel: w.buttonLabel,
);

CsatCampaign csatCampaignFromWire(pigeon.CsatCampaignWire w) => CsatCampaign(
  code: w.code,
  name: w.name,
  dissatisfiedQuestion: w.dissatisfiedQuestion,
  neutralQuestion: w.neutralQuestion,
  satisfiedQuestion: w.satisfiedQuestion,
  dissatisfiedSuccess: w.dissatisfiedSuccess,
  neutralSuccess: w.neutralSuccess,
  satisfiedSuccess: w.satisfiedSuccess,
  buttonLabel: w.buttonLabel,
);

CesCampaign cesCampaignFromWire(pigeon.CesCampaignWire w) => CesCampaign(
  code: w.code,
  name: w.name,
  difficultQuestion: w.difficultQuestion,
  neutralQuestion: w.neutralQuestion,
  easyQuestion: w.easyQuestion,
  difficultSuccess: w.difficultSuccess,
  neutralSuccess: w.neutralSuccess,
  easySuccess: w.easySuccess,
  buttonLabel: w.buttonLabel,
);

PollChannel pollChannelFromWire(pigeon.PollChannelWire w) =>
    PollChannel(code: w.code, name: w.name);

ProductRatingSummary productRatingSummaryFromWire(
  pigeon.ProductRatingSummaryWire w,
) => ProductRatingSummary(
  count: w.count,
  averageRating: w.averageRating,
  ratings: Map<int, int>.unmodifiable(w.ratings),
);

ProductReview productReviewFromWire(pigeon.ProductReviewWire w) =>
    ProductReview(
      id: w.id,
      rating: w.rating,
      comment: w.comment,
      author: w.author,
      createdAt: w.createdAt,
    );

ProductReviewsResponse productReviewsResponseFromWire(
  pigeon.ProductReviewsResponseWire w,
) => ProductReviewsResponse(
  summary: productRatingSummaryFromWire(w.summary),
  reviews: w.reviews.map(productReviewFromWire).toList(),
);

ClientReview clientReviewFromWire(pigeon.ClientReviewWire w) => ClientReview(
  id: w.id,
  itemId: w.itemId,
  orderId: w.orderId,
  rating: w.rating,
  comment: w.comment,
  state: reviewStateFromWire(w.state),
  createdAt: w.createdAt,
);

// endregion

// region the released models, with the contract's fields

Map<String, String> _images(Map<String, String>? images) =>
    Map<String, String>.unmodifiable(images ?? const <String, String>{});

/// A [Product] of the contract's `Product`. The released fields the contract makes
/// optional keep their released defaults: `""` and `0`.
Product productFromWire(pigeon.ProductWire w) => Product(
  id: w.id,
  name: w.name,
  brand: w.brand ?? '',
  description: w.description ?? '',
  imageUrl: w.imageUrl ?? '',
  url: w.url,
  price: w.price,
  priceFull: w.priceFull ?? 0,
  priceFormatted: w.priceFormatted,
  priceFullFormatted: w.priceFullFormatted,
  currency: w.currency,
  salesRate: w.salesRate ?? 0,
  relativeSalesRate: w.relativeSalesRate ?? 0,
  resizedImages: _images(w.resizedImages),
  categories: (w.categories ?? const []).map(productCategoryFromWire).toList(),
  picture: w.picture,
  oldPrice: w.oldPrice,
  oldPriceFormatted: w.oldPriceFormatted,
  discount: w.discountPercent,
  discountFormatted: w.discountFormatted,
  discountPercent: w.discountPercent,
  deeplinkAndroid: w.deeplinkAndroid,
  deeplinkIos: w.deeplinkIos,
  isNew: w.isNew,
  groupId: w.groupId,
  model: w.model,
  barcode: w.barcode,
  oldPriceFull: w.oldPriceFull,
  oldPriceFullFormatted: w.oldPriceFullFormatted,
  rating: w.rating,
  stockQuantity: w.stockQuantity,
  categoryIds: w.categoryIds,
  params: (w.params ?? const []).map(productParamFromWire).toList(),
  locationIds: w.locationIds,
);

/// A product of a recommendation block, the released [RecommendedProduct].
RecommendedProduct recommendedProductFromWire(pigeon.ProductWire w) =>
    RecommendedProduct(
      id: w.id,
      name: w.name,
      brand: w.brand ?? '',
      description: w.description ?? '',
      imageUrl: w.imageUrl ?? '',
      resizedImageUrl: w.picture ?? '',
      resizedImages: _images(w.resizedImages),
      url: w.url,
      categories: (w.categories ?? const [])
          .map(productCategoryFromWire)
          .toList(),
      price: w.price,
      priceFull: w.priceFull ?? 0,
      priceFormatted: w.priceFormatted,
      priceFullFormatted: w.priceFullFormatted,
      currency: w.currency,
      salesRate: w.salesRate ?? 0,
      relativeSalesRate: w.relativeSalesRate ?? 0,
      oldPrice: w.oldPrice,
      oldPriceFormatted: w.oldPriceFormatted,
      discount: w.discountPercent,
      discountFormatted: w.discountFormatted,
      discountPercent: w.discountPercent,
      deeplinkAndroid: w.deeplinkAndroid,
      deeplinkIos: w.deeplinkIos,
      isNew: w.isNew,
      groupId: w.groupId,
      model: w.model,
      barcode: w.barcode,
      oldPriceFull: w.oldPriceFull,
      oldPriceFullFormatted: w.oldPriceFullFormatted,
      rating: w.rating,
      stockQuantity: w.stockQuantity,
      categoryIds: w.categoryIds,
      params: (w.params ?? const []).map(productParamFromWire).toList(),
      locationIds: w.locationIds,
    );

/// A product of a search, the released [SearchProduct]: no old price or discount is
/// `0`, as released.
SearchProduct searchProductFromWire(pigeon.ProductWire w) => SearchProduct(
  id: w.id,
  name: w.name,
  brand: w.brand ?? '',
  description: w.description ?? '',
  imageUrl: w.imageUrl ?? '',
  url: w.url,
  price: w.price,
  priceFull: w.priceFull ?? 0,
  priceFormatted: w.priceFormatted,
  priceFullFormatted: w.priceFullFormatted,
  currency: w.currency,
  salesRate: w.salesRate ?? 0,
  relativeSalesRate: w.relativeSalesRate ?? 0,
  resizedImages: _images(w.resizedImages),
  picture: w.picture,
  oldPrice: w.oldPrice ?? 0,
  oldPriceFormatted: w.oldPriceFormatted,
  discount: w.discountPercent ?? 0,
  discountFormatted: w.discountFormatted,
  discountPercent: w.discountPercent,
  deeplinkAndroid: w.deeplinkAndroid,
  deeplinkIos: w.deeplinkIos,
  isNew: w.isNew,
  categories: (w.categories ?? const []).map(productCategoryFromWire).toList(),
  groupId: w.groupId,
  model: w.model,
  barcode: w.barcode,
  oldPriceFull: w.oldPriceFull,
  oldPriceFullFormatted: w.oldPriceFullFormatted,
  rating: w.rating,
  stockQuantity: w.stockQuantity,
  categoryIds: w.categoryIds,
  params: (w.params ?? const []).map(productParamFromWire).toList(),
  locationIds: w.locationIds,
);

ProductCategory productCategoryFromWire(pigeon.ProductCategoryWire w) =>
    ProductCategory(
      id: w.id,
      name: w.name ?? '',
      parentId: w.parentId,
      url: w.url,
      level: w.level,
      count: w.count,
      alias: w.alias,
    );

SearchCategory searchCategoryFromWire(pigeon.ProductCategoryWire w) =>
    SearchCategory(
      id: w.id,
      name: w.name ?? '',
      url: w.url,
      parentId: w.parentId,
      count: w.count,
      alias: w.alias,
      level: w.level,
    );

SearchLocation searchLocationFromWire(pigeon.LocationWire w) =>
    SearchLocation(id: w.id, name: w.name, type: w.type);

SearchFilter searchFilterFromWire(pigeon.SearchFilterWire w) => SearchFilter(
  count: w.count ?? 0,
  values: Map<String, int>.unmodifiable(w.values ?? const <String, int>{}),
  priority: w.priority,
  min: w.min,
  max: w.max,
);

Map<String, SearchFilter> _filters(Map<String, pigeon.SearchFilterWire>? w) =>
    Map<String, SearchFilter>.unmodifiable(
      (w ?? const <String, pigeon.SearchFilterWire>{}).map(
        (name, filter) => MapEntry(name, searchFilterFromWire(filter)),
      ),
    );

SearchIndustrialFilters searchIndustrialFiltersFromWire(
  pigeon.IndustrialFiltersWire w,
) {
  final colors = w.colors ?? const <pigeon.ColorFilterWire>[];
  final sizes = w.fashionSizes ?? const <pigeon.SizeFilterWire>[];
  return SearchIndustrialFilters(
    colors: colors.map((c) => c.color).toList(),
    fashionSizes: sizes.map((s) => s.size).toList(),
    colorCounts: {for (final c in colors) c.color: c.count},
    fashionSizeCounts: {for (final s in sizes) s.size: s.count},
  );
}

List<String> _brandNames(List<pigeon.BrandWire>? brands) => (brands ?? const [])
    .map((b) => b.name)
    .where((name) => name.isNotEmpty)
    .toList();

Map<String, int> _brandCounts(List<pigeon.BrandWire>? brands) => {
  for (final b in brands ?? const <pigeon.BrandWire>[])
    if (b.name.isNotEmpty) b.name: b.count,
};

ProductsListResponse productsListResponseFromWire(
  pigeon.ProductsListResponseWire w,
) => ProductsListResponse(
  products: w.products.map(productFromWire).toList(),
  productsTotal: w.productsTotal ?? 0,
  priceRange: w.priceRange == null
      ? null
      : PriceRange(min: w.priceRange!.min, max: w.priceRange!.max),
  brands: _brandNames(w.brands),
  filters: _filters(w.filters),
  categories: (w.categories ?? const []).map(productCategoryFromWire).toList(),
  brandCounts: _brandCounts(w.brands),
  locations: w.locations?.map(searchLocationFromWire).toList(),
  industrialFilters: w.industrialFilters == null
      ? null
      : searchIndustrialFiltersFromWire(w.industrialFilters!),
  priceRanges: (w.priceRanges ?? const []).map(priceIntervalFromWire).toList(),
  priceMedian: w.priceMedian,
);

CategoryResponse categoryResponseFromWire(
  pigeon.ProductsListResponseWire w,
) => CategoryResponse(
  productsTotal: w.productsTotal ?? 0,
  products: w.products.map(productFromWire).toList(),
  brands: _brandNames(w.brands),
  brandCounts: _brandCounts(w.brands),
  filters: _filters(w.filters),
  priceRange: w.priceRange == null
      ? null
      : PriceRange(min: w.priceRange!.min, max: w.priceRange!.max),
  categories: (w.categories ?? const []).map(productCategoryFromWire).toList(),
  priceRanges: (w.priceRanges ?? const []).map(priceIntervalFromWire).toList(),
  priceMedian: w.priceMedian,
);

CollectionResponse collectionResponseFromWire(
  pigeon.CollectionResponseWire w,
) => CollectionResponse(products: w.products.map(productFromWire).toList());

ProductCountersResponse productCountersResponseFromWire(
  pigeon.ProductCountersResponseWire w,
) {
  ProductCounter? counter(pigeon.ProductCounterWire? c) => c == null
      ? null
      : ProductCounter(view: c.view, cart: c.cart, purchase: c.purchase);
  final triggers = w.triggers;
  return ProductCountersResponse(
    daily: counter(w.daily),
    now: counter(w.now),
    triggers: triggers == null
        ? null
        : ProductCounterTriggers(
            backInStock: triggers.backInStock,
            priceDrop: triggers.priceDrop,
          ),
  );
}

RecommendationResponse recommendationResponseFromWire(
  pigeon.RecommendationResponseWire w,
) => RecommendationResponse(
  title: w.title ?? '',
  products: w.products.map(recommendedProductFromWire).toList(),
  id: w.id,
  link: w.link,
  itemIds: List<String>.unmodifiable(w.itemIds),
);

SearchSuggest _query(pigeon.QueryWire w) =>
    SearchSuggest(name: w.name, url: w.url ?? '', score: w.score);

SearchSuggest _popular(pigeon.PopularItemWire w) =>
    SearchSuggest(name: w.name, url: w.url);

SearchBlankResponse searchBlankResponseFromWire(
  pigeon.SearchBlankResponseWire w,
) => SearchBlankResponse(
  products: w.products.map(searchProductFromWire).toList(),
  suggests: (w.suggests ?? const []).map(_query).toList(),
  lastQueries: (w.lastQueries ?? const []).map(_query).toList(),
  popularCategories: (w.popularCategories ?? const []).map(_popular).toList(),
  lastProducts: w.lastProducts,
  popularBrands: (w.popularBrands ?? const []).map(_popular).toList(),
  popularLinks: (w.popularLinks ?? const []).map(_popular).toList(),
);

SearchInstantResponse searchInstantResponseFromWire(
  pigeon.SearchInstantResponseWire w,
) => SearchInstantResponse(
  products: w.products.map(searchProductFromWire).toList(),
  categories: (w.categories ?? const []).map(searchCategoryFromWire).toList(),
  productsTotal: w.productsTotal ?? 0,
  locations: w.locations?.map(searchLocationFromWire).toList(),
  queries: (w.queries ?? const []).map(_query).toList(),
  searchQuery: w.searchQuery,
  searchQueryOriginal: w.searchQueryOriginal,
  clarification: w.clarification,
  redirect: w.redirect == null ? null : searchRedirectFromWire(w.redirect!),
);

SearchFullResponse searchFullResponseFromWire(
  pigeon.SearchFullResponseWire w,
) => SearchFullResponse(
  products: w.products.map(searchProductFromWire).toList(),
  categories: (w.categories ?? const []).map(searchCategoryFromWire).toList(),
  productsTotal: w.productsTotal ?? 0,
  priceRange: w.priceRange == null
      ? null
      : SearchPriceRange(min: w.priceRange!.min, max: w.priceRange!.max),
  locations: w.locations?.map(searchLocationFromWire).toList(),
  brands: _brandNames(w.brands),
  brandCounts: _brandCounts(w.brands),
  filters: _filters(w.filters),
  industrialFilters: w.industrialFilters == null
      ? null
      : searchIndustrialFiltersFromWire(w.industrialFilters!),
  searchQuery: w.searchQuery,
  searchQueryOriginal: w.searchQueryOriginal,
  clarification: w.clarification,
  priceRanges: (w.priceRanges ?? const []).map(priceIntervalFromWire).toList(),
  priceMedian: w.priceMedian,
);

StoriesBlock storiesBlockFromWire(pigeon.StoriesBlockWire w) =>
    StoriesBlock(id: w.id, stories: w.stories.map(_story).toList());

Story _story(pigeon.StoryWire w) => Story(
  id: w.id,
  name: w.name,
  avatar: w.avatar,
  viewed: w.viewed,
  pinned: w.pinned,
  startPosition: w.startPosition,
  slides: w.slides.map(_slide).toList(),
);

StorySlide _slide(pigeon.StorySlideWire w) => StorySlide(
  id: w.id,
  type: switch (w.type) {
    'image' => StorySlideType.image,
    'video' => StorySlideType.video,
    _ => StorySlideType.product,
  },
  background: w.background,
  backgroundColor: w.backgroundColor,
  preview: w.preview,
  duration: Duration(
    seconds: w.duration <= 0 ? StorySlide.defaultDurationSeconds : w.duration,
  ),
  elements: w.elements.map(_element).whereType<StoryElement>().toList(),
);

StoryElement? _element(pigeon.StoryElementWire w) => switch (w.type) {
  'button' => StoryButtonElement(
    title: w.title ?? '',
    link: w.link ?? '',
    linkAndroid: w.linkAndroid ?? '',
    linkIos: w.linkIos ?? '',
    background: w.background ?? '',
    color: w.color ?? '',
    textBold: w.textBold ?? false,
  ),
  'product' => StoryProductElement(
    title: w.title ?? '',
    item: w.item == null ? null : _storyProduct(w.item!),
  ),
  'products' => StoryProductsElement(
    showLabel: w.showLabel ?? '',
    hideLabel: w.hideLabel ?? '',
    products: (w.products ?? const []).map(_storyProduct).toList(),
  ),
  'text_block' => StoryTextBlockElement(
    text: w.text ?? '',
    fontSize: w.fontSize ?? StoryTextBlockElement.defaultFontSize,
    fontType: w.fontType ?? '',
    bold: w.bold ?? false,
    italic: w.italic ?? false,
    textAlign: w.textAlign ?? '',
    textColor: w.textColor ?? '',
    backgroundColor: w.backgroundColor ?? '',
    backgroundOpacity: w.backgroundOpacity ?? 0,
    lineSpacing: w.lineSpacing ?? 0,
    yOffset: w.yOffset ?? 0,
    promocode: (w.promocode ?? '').isEmpty ? null : w.promocode,
  ),
  _ => null,
};

StoryProduct _storyProduct(pigeon.StoryProductWire w) => StoryProduct(
  id: w.id,
  name: w.name,
  brand: w.brand,
  picture: w.picture,
  imageUrl: w.imageUrl,
  price: w.price,
  priceFormatted: w.priceFormatted,
  oldPrice: w.oldPrice ?? 0,
  oldPriceFormatted: w.oldPriceFormatted,
  discountPercent: w.discountPercent,
  promocode: w.promocode,
  priceWithPromocode: w.priceWithPromocode,
  priceWithPromocodeFormatted: w.priceWithPromocodeFormatted,
  currency: w.currency,
  url: w.url,
  deeplinkAndroid: w.deeplinkAndroid,
  deeplinkIos: w.deeplinkIos,
);

// endregion
