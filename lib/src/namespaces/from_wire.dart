// The models of the native channel turned into the public Dart models of the
// contract. Not exported.

import '../loyalty/loyalty_response.dart' show LoyaltyLevel;
import '../models/agent_models.dart';
import '../models/cart_models.dart';
import '../models/catalog.dart';
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

// region the catalog

Product productFromWire(pigeon.ProductWire w) => Product(
  id: w.id,
  groupId: w.groupId,
  name: w.name,
  brand: w.brand,
  model: w.model,
  description: w.description,
  barcode: w.barcode,
  url: w.url,
  deeplinkAndroid: w.deeplinkAndroid,
  deeplinkIos: w.deeplinkIos,
  imageUrl: w.imageUrl,
  picture: w.picture,
  resizedImages: w.resizedImages == null
      ? null
      : Map<String, String>.unmodifiable(w.resizedImages!),
  price: w.price,
  priceFormatted: w.priceFormatted,
  priceFull: w.priceFull,
  priceFullFormatted: w.priceFullFormatted,
  oldPrice: w.oldPrice,
  oldPriceFormatted: w.oldPriceFormatted,
  oldPriceFull: w.oldPriceFull,
  oldPriceFullFormatted: w.oldPriceFullFormatted,
  currency: w.currency,
  discountPercent: w.discountPercent,
  discountFormatted: w.discountFormatted,
  salesRate: w.salesRate,
  relativeSalesRate: w.relativeSalesRate,
  rating: w.rating,
  isNew: w.isNew,
  stockQuantity: w.stockQuantity,
  categoryIds: _list(w.categoryIds),
  categories: w.categories?.map(productCategoryFromWire).toList(),
  params: w.params?.map(productParamFromWire).toList(),
  locationIds: _list(w.locationIds),
);

List<T>? _list<T>(List<T>? list) =>
    list == null ? null : List<T>.unmodifiable(list);

ProductCategory productCategoryFromWire(pigeon.ProductCategoryWire w) =>
    ProductCategory(
      id: w.id,
      name: w.name,
      url: w.url,
      parentId: w.parentId,
      level: w.level,
      count: w.count,
      alias: w.alias,
    );

Location locationFromWire(pigeon.LocationWire w) =>
    Location(id: w.id, name: w.name, type: w.type);

Brand brandFromWire(pigeon.BrandWire w) => Brand(name: w.name, count: w.count);

SearchFilter searchFilterFromWire(pigeon.SearchFilterWire w) => SearchFilter(
  count: w.count,
  priority: w.priority,
  values: w.values == null ? null : Map<String, int>.unmodifiable(w.values!),
  min: w.min,
  max: w.max,
);

Map<String, SearchFilter>? _filters(Map<String, pigeon.SearchFilterWire>? w) =>
    w == null
    ? null
    : Map<String, SearchFilter>.unmodifiable(
        w.map((name, filter) => MapEntry(name, searchFilterFromWire(filter))),
      );

IndustrialFilters industrialFiltersFromWire(pigeon.IndustrialFiltersWire w) =>
    IndustrialFilters(
      colors: w.colors
          ?.map((c) => ColorFilter(color: c.color, count: c.count))
          .toList(),
      fashionSizes: w.fashionSizes
          ?.map((s) => SizeFilter(size: s.size, count: s.count))
          .toList(),
    );

PriceRange? _priceRange(pigeon.PriceRangeWire? w) =>
    w == null ? null : PriceRange(min: w.min, max: w.max);

ProductsListResponse productsListResponseFromWire(
  pigeon.ProductsListResponseWire w,
) => ProductsListResponse(
  productsTotal: w.productsTotal,
  products: w.products.map(productFromWire).toList(),
  categories: w.categories?.map(productCategoryFromWire).toList(),
  brands: w.brands?.map(brandFromWire).toList(),
  locations: w.locations?.map(locationFromWire).toList(),
  filters: _filters(w.filters),
  industrialFilters: w.industrialFilters == null
      ? null
      : industrialFiltersFromWire(w.industrialFilters!),
  priceRange: _priceRange(w.priceRange),
  priceRanges: w.priceRanges?.map(priceIntervalFromWire).toList(),
  priceMedian: w.priceMedian,
);

CategoryResponse categoryResponseFromWire(pigeon.ProductsListResponseWire w) =>
    CategoryResponse(
      productsTotal: w.productsTotal,
      products: w.products.map(productFromWire).toList(),
      categories: w.categories?.map(productCategoryFromWire).toList(),
      brands: w.brands?.map(brandFromWire).toList(),
      filters: _filters(w.filters),
      priceRange: _priceRange(w.priceRange),
      priceRanges: w.priceRanges?.map(priceIntervalFromWire).toList(),
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
  id: w.id,
  title: w.title,
  link: w.link,
  products: w.products.map(productFromWire).toList(),
  itemIds: List<String>.unmodifiable(w.itemIds),
);

Query _query(pigeon.QueryWire w) =>
    Query(name: w.name, url: w.url, score: w.score);

PopularItem _popular(pigeon.PopularItemWire w) =>
    PopularItem(name: w.name, url: w.url);

SearchBlankResponse searchBlankResponseFromWire(
  pigeon.SearchBlankResponseWire w,
) => SearchBlankResponse(
  products: w.products.map(productFromWire).toList(),
  lastProducts: w.lastProducts,
  lastQueries: w.lastQueries?.map(_query).toList(),
  suggests: w.suggests?.map(_query).toList(),
  popularCategories: w.popularCategories?.map(_popular).toList(),
  popularBrands: w.popularBrands?.map(_popular).toList(),
  popularLinks: w.popularLinks?.map(_popular).toList(),
);

SearchInstantResponse searchInstantResponseFromWire(
  pigeon.SearchInstantResponseWire w,
) => SearchInstantResponse(
  searchQuery: w.searchQuery,
  searchQueryOriginal: w.searchQueryOriginal,
  clarification: w.clarification,
  productsTotal: w.productsTotal,
  products: w.products.map(productFromWire).toList(),
  categories: w.categories?.map(productCategoryFromWire).toList(),
  queries: w.queries?.map(_query).toList(),
  locations: w.locations?.map(locationFromWire).toList(),
  redirect: w.redirect == null ? null : searchRedirectFromWire(w.redirect!),
);

SearchFullResponse searchFullResponseFromWire(
  pigeon.SearchFullResponseWire w,
) => SearchFullResponse(
  searchQuery: w.searchQuery,
  searchQueryOriginal: w.searchQueryOriginal,
  clarification: w.clarification,
  productsTotal: w.productsTotal,
  products: w.products.map(productFromWire).toList(),
  categories: w.categories?.map(productCategoryFromWire).toList(),
  brands: w.brands?.map(brandFromWire).toList(),
  locations: w.locations?.map(locationFromWire).toList(),
  filters: _filters(w.filters),
  industrialFilters: w.industrialFilters == null
      ? null
      : industrialFiltersFromWire(w.industrialFilters!),
  priceRange: _priceRange(w.priceRange),
  priceRanges: w.priceRanges?.map(priceIntervalFromWire).toList(),
  priceMedian: w.priceMedian,
);

// endregion

// region the stories, the released model of the contract

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
