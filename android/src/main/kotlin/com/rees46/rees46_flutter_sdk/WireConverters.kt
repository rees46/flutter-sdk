package com.rees46.rees46_flutter_sdk

import com.personalization.PushProvider
import com.personalization.api.models.collections.CollectionResponse
import com.personalization.api.models.loyalty.LoyaltyLevel
import com.personalization.api.models.loyalty.LoyaltyMember
import com.personalization.api.models.loyalty.LoyaltyPromotion
import com.personalization.api.models.loyalty.LoyaltyStatus
import com.personalization.api.models.predict.PurchaseProbability
import com.personalization.api.models.products.CategoryResponse
import com.personalization.api.models.products.PriceInterval
import com.personalization.api.models.products.Product
import com.personalization.api.models.products.ProductCategory
import com.personalization.api.models.products.ProductsListResponse
import com.personalization.api.models.products.SearchFilter
import com.personalization.api.models.profile.Profile
import com.personalization.api.models.recommendations.RecommendationResponse
import com.personalization.api.models.search.AgentDialogResponse
import com.personalization.api.models.search.AgentMessage
import com.personalization.api.models.search.AgentProduct
import com.personalization.api.models.search.AgentResponse
import com.personalization.api.models.search.AgentSession
import com.personalization.api.models.search.Query
import com.personalization.api.models.search.SearchBlankResponse
import com.personalization.api.models.search.SearchFullResponse
import com.personalization.api.models.search.SearchInstantResponse
import com.personalization.api.models.search.SearchRedirect
import com.personalization.api.models.segments.Segment
import com.personalization.api.models.sliders.Slider
import com.personalization.api.models.sliders.SliderBanner
import com.personalization.api.models.stories.StoriesBlock
import com.personalization.api.models.stories.Story
import com.personalization.api.models.stories.StoryButtonElement
import com.personalization.api.models.stories.StoryElement
import com.personalization.api.models.stories.StoryProduct
import com.personalization.api.models.stories.StoryProductElement
import com.personalization.api.models.stories.StoryProductsElement
import com.personalization.api.models.stories.StorySlide
import com.personalization.api.models.stories.StoryTextBlockElement
import com.personalization.api.models.subscriptions.SubscriptionStatus
import com.personalization.api.responses.cart.CartItem
import com.personalization.api.responses.notifications.GetAllNotificationsResponse
import com.personalization.api.responses.notifications.Message
import com.personalization.api.responses.notifications.Statistics
import com.personalization.api.responses.orders.Order
import com.personalization.api.responses.orders.OrderItem
import com.personalization.api.responses.product.Category as LegacyCategory
import com.personalization.api.responses.product.Product as LegacyProduct
import com.personalization.api.responses.products.counters.ProductCounter
import com.personalization.api.responses.products.counters.ProductCounterTriggers
import com.personalization.api.responses.products.counters.ProductCountersResponse
import com.personalization.api.responses.products.product.ProductParam
import com.personalization.api.responses.reviews.CesCampaign
import com.personalization.api.responses.reviews.ClientReview
import com.personalization.api.responses.reviews.CsatCampaign
import com.personalization.api.responses.reviews.NpsCategory
import com.personalization.api.responses.reviews.PollChannel
import com.personalization.api.responses.reviews.PollReview
import com.personalization.api.responses.reviews.ProductRatingSummary
import com.personalization.api.responses.reviews.ProductReview
import com.personalization.api.responses.reviews.ProductReviewsResponse
import com.personalization.api.responses.search.Brand
import com.personalization.api.responses.search.ColorFilter
import com.personalization.api.responses.search.IndustrialFilters
import com.personalization.api.responses.search.Location
import com.personalization.api.responses.search.PopularItem
import com.personalization.api.responses.search.PriceRange
import com.personalization.api.responses.search.SizeFilter
import com.personalization.core.PushAction
import com.personalization.core.PushPayload
import com.personalization.core.PushTarget
import com.personalization.core.PushToken
import com.rees46.rees46_flutter_sdk.pigeon.AgentDialogResponseWire
import com.rees46.rees46_flutter_sdk.pigeon.AgentMessageWire
import com.rees46.rees46_flutter_sdk.pigeon.AgentProductWire
import com.rees46.rees46_flutter_sdk.pigeon.AgentResponseWire
import com.rees46.rees46_flutter_sdk.pigeon.AgentSessionWire
import com.rees46.rees46_flutter_sdk.pigeon.BrandWire
import com.rees46.rees46_flutter_sdk.pigeon.CartItemWire
import com.rees46.rees46_flutter_sdk.pigeon.CesCampaignWire
import com.rees46.rees46_flutter_sdk.pigeon.ClientReviewWire
import com.rees46.rees46_flutter_sdk.pigeon.CollectionResponseWire
import com.rees46.rees46_flutter_sdk.pigeon.ColorFilterWire
import com.rees46.rees46_flutter_sdk.pigeon.CsatCampaignWire
import com.rees46.rees46_flutter_sdk.pigeon.IndustrialFiltersWire
import com.rees46.rees46_flutter_sdk.pigeon.LocationWire
import com.rees46.rees46_flutter_sdk.pigeon.LoyaltyLevelWire
import com.rees46.rees46_flutter_sdk.pigeon.LoyaltyMemberWire
import com.rees46.rees46_flutter_sdk.pigeon.LoyaltyPromotionWire
import com.rees46.rees46_flutter_sdk.pigeon.LoyaltyStatusWire
import com.rees46.rees46_flutter_sdk.pigeon.NotificationHistoryWire
import com.rees46.rees46_flutter_sdk.pigeon.NotificationMessageWire
import com.rees46.rees46_flutter_sdk.pigeon.NotificationStatisticsWire
import com.rees46.rees46_flutter_sdk.pigeon.NpsCategoryWire
import com.rees46.rees46_flutter_sdk.pigeon.OrderItemWire
import com.rees46.rees46_flutter_sdk.pigeon.OrderWire
import com.rees46.rees46_flutter_sdk.pigeon.PollChannelWire
import com.rees46.rees46_flutter_sdk.pigeon.PollReviewWire
import com.rees46.rees46_flutter_sdk.pigeon.PopularItemWire
import com.rees46.rees46_flutter_sdk.pigeon.PriceIntervalWire
import com.rees46.rees46_flutter_sdk.pigeon.PriceRangeWire
import com.rees46.rees46_flutter_sdk.pigeon.ProductCategoryWire
import com.rees46.rees46_flutter_sdk.pigeon.ProductCounterTriggersWire
import com.rees46.rees46_flutter_sdk.pigeon.ProductCounterWire
import com.rees46.rees46_flutter_sdk.pigeon.ProductCountersResponseWire
import com.rees46.rees46_flutter_sdk.pigeon.ProductParamWire
import com.rees46.rees46_flutter_sdk.pigeon.ProductRatingSummaryWire
import com.rees46.rees46_flutter_sdk.pigeon.ProductReviewWire
import com.rees46.rees46_flutter_sdk.pigeon.ProductReviewsResponseWire
import com.rees46.rees46_flutter_sdk.pigeon.ProductWire
import com.rees46.rees46_flutter_sdk.pigeon.ProductsListResponseWire
import com.rees46.rees46_flutter_sdk.pigeon.ProfileWire
import com.rees46.rees46_flutter_sdk.pigeon.PurchaseProbabilityWire
import com.rees46.rees46_flutter_sdk.pigeon.PushActionWire
import com.rees46.rees46_flutter_sdk.pigeon.PushPayloadWire
import com.rees46.rees46_flutter_sdk.pigeon.PushTargetWire
import com.rees46.rees46_flutter_sdk.pigeon.PushTokenWire
import com.rees46.rees46_flutter_sdk.pigeon.QueryWire
import com.rees46.rees46_flutter_sdk.pigeon.RecommendationResponseWire
import com.rees46.rees46_flutter_sdk.pigeon.SearchBlankResponseWire
import com.rees46.rees46_flutter_sdk.pigeon.SearchFilterWire
import com.rees46.rees46_flutter_sdk.pigeon.SearchFullResponseWire
import com.rees46.rees46_flutter_sdk.pigeon.SearchInstantResponseWire
import com.rees46.rees46_flutter_sdk.pigeon.SearchRedirectWire
import com.rees46.rees46_flutter_sdk.pigeon.SegmentWire
import com.rees46.rees46_flutter_sdk.pigeon.SizeFilterWire
import com.rees46.rees46_flutter_sdk.pigeon.SliderBannerWire
import com.rees46.rees46_flutter_sdk.pigeon.SliderWire
import com.rees46.rees46_flutter_sdk.pigeon.StoriesBlockWire
import com.rees46.rees46_flutter_sdk.pigeon.StoryElementWire
import com.rees46.rees46_flutter_sdk.pigeon.StoryProductWire
import com.rees46.rees46_flutter_sdk.pigeon.StorySlideWire
import com.rees46.rees46_flutter_sdk.pigeon.StoryWire
import com.rees46.rees46_flutter_sdk.pigeon.SubscriptionStatusWire
import org.json.JSONArray
import org.json.JSONObject

/*
 * The native SDK's models as the Pigeon wire types: field for field, by the contract's names, which the
 * native models already carry. Whole numbers go as `Long` (Pigeon's `int`), enums and open sets as their
 * wire values, and free-form values ([standard]) as the codec's own types.
 */

// region catalog

internal fun Product.toWire(): ProductWire = ProductWire(
    id = id,
    groupId = groupId,
    name = name,
    brand = brand,
    model = model,
    description = description,
    barcode = barcode,
    url = url,
    deeplinkAndroid = deeplinkAndroid,
    deeplinkIos = deeplinkIos,
    imageUrl = imageUrl,
    picture = picture,
    resizedImages = resizedImages,
    price = price,
    priceFormatted = priceFormatted,
    priceFull = priceFull,
    priceFullFormatted = priceFullFormatted,
    oldPrice = oldPrice,
    oldPriceFormatted = oldPriceFormatted,
    oldPriceFull = oldPriceFull,
    oldPriceFullFormatted = oldPriceFullFormatted,
    currency = currency,
    discountPercent = discountPercent?.toLong(),
    discountFormatted = discountFormatted,
    salesRate = salesRate?.toLong(),
    relativeSalesRate = relativeSalesRate,
    rating = rating?.toLong(),
    isNew = isNew,
    stockQuantity = stockQuantity?.toLong(),
    categoryIds = categoryIds,
    categories = categories?.map { it.toWire() },
    params = params?.map { it.toWire() },
    locationIds = locationIds,
)

internal fun ProductCategory.toWire(): ProductCategoryWire = ProductCategoryWire(
    id = id,
    name = name,
    url = url,
    parentId = parentId,
    level = level?.toLong(),
    count = count?.toLong(),
    alias = alias,
)

internal fun ProductParam.toWire(): ProductParamWire = ProductParamWire(key = key, values = values)

internal fun Location.toWire(): LocationWire = LocationWire(id = id, name = name, type = type)

internal fun Brand.toWire(): BrandWire = BrandWire(name = name, count = count.toLong())

internal fun SearchFilter.toWire(): SearchFilterWire = SearchFilterWire(
    count = count?.toLong(),
    priority = priority?.toLong(),
    values = values?.mapValues { it.value.toLong() },
    min = min,
    max = max,
)

internal fun ColorFilter.toWire(): ColorFilterWire = ColorFilterWire(color = color, count = count.toLong())

internal fun SizeFilter.toWire(): SizeFilterWire = SizeFilterWire(size = size, count = count.toLong())

internal fun IndustrialFilters.toWire(): IndustrialFiltersWire = IndustrialFiltersWire(
    colors = colors?.map { it.toWire() },
    fashionSizes = fashionSizes?.map { it.toWire() },
)

internal fun PriceRange.toWire(): PriceRangeWire = PriceRangeWire(min = min, max = max)

internal fun PriceInterval.toWire(): PriceIntervalWire =
    PriceIntervalWire(from = from, to = to, count = count?.toLong())

internal fun ProductsListResponse.toWire(): ProductsListResponseWire = ProductsListResponseWire(
    productsTotal = productsTotal?.toLong(),
    products = products.map { it.toWire() },
    categories = categories?.map { it.toWire() },
    brands = brands?.map { it.toWire() },
    locations = locations?.map { it.toWire() },
    filters = filters?.mapValues { it.value.toWire() },
    industrialFilters = industrialFilters?.toWire(),
    priceRange = priceRange?.toWire(),
    priceRanges = priceRanges?.map { it.toWire() },
    priceMedian = priceMedian,
)

/** `CategoryResponse` is the subset of the listing's answer: the same wire type, without its extra fields. */
internal fun CategoryResponse.toWire(): ProductsListResponseWire = ProductsListResponseWire(
    productsTotal = productsTotal?.toLong(),
    products = products.map { it.toWire() },
    categories = categories?.map { it.toWire() },
    brands = brands?.map { it.toWire() },
    filters = filters?.mapValues { it.value.toWire() },
    priceRange = priceRange?.toWire(),
    priceRanges = priceRanges?.map { it.toWire() },
    priceMedian = priceMedian,
)

internal fun ProductCounter.toWire(): ProductCounterWire =
    ProductCounterWire(view = view.toLong(), cart = cart.toLong(), purchase = purchase.toLong())

internal fun ProductCounterTriggers.toWire(): ProductCounterTriggersWire =
    ProductCounterTriggersWire(backInStock = backInStock.toLong(), priceDrop = priceDrop.toLong())

internal fun ProductCountersResponse.toWire(): ProductCountersResponseWire = ProductCountersResponseWire(
    daily = daily?.toWire(),
    now = now?.toWire(),
    triggers = triggers?.toWire(),
)

internal fun CollectionResponse.toWire(): CollectionResponseWire =
    CollectionResponseWire(products = products.map { it.toWire() })

internal fun RecommendationResponse.toWire(): RecommendationResponseWire = RecommendationResponseWire(
    id = id?.toLong(),
    title = title,
    link = link,
    products = products.map { it.toWire() },
    itemIds = itemIds,
)

// endregion

// region search

internal fun Query.toWire(): QueryWire = QueryWire(name = name, url = url, score = score)

internal fun PopularItem.toWire(): PopularItemWire = PopularItemWire(name = name, url = url)

internal fun SearchRedirect.toWire(): SearchRedirectWire =
    SearchRedirectWire(query = query, url = url, deeplink = deeplink)

internal fun SearchBlankResponse.toWire(): SearchBlankResponseWire = SearchBlankResponseWire(
    products = products.map { it.toWire() },
    lastProducts = lastProducts,
    lastQueries = lastQueries?.map { it.toWire() },
    suggests = suggests?.map { it.toWire() },
    popularCategories = popularCategories?.map { it.toWire() },
    popularBrands = popularBrands?.map { it.toWire() },
    popularLinks = popularLinks?.map { it.toWire() },
)

internal fun SearchInstantResponse.toWire(): SearchInstantResponseWire = SearchInstantResponseWire(
    searchQuery = searchQuery,
    searchQueryOriginal = searchQueryOriginal,
    clarification = clarification,
    productsTotal = productsTotal?.toLong(),
    products = products.map { it.toWire() },
    categories = categories?.map { it.toWire() },
    queries = queries?.map { it.toWire() },
    locations = locations?.map { it.toWire() },
    redirect = redirect?.toWire(),
)

internal fun SearchFullResponse.toWire(): SearchFullResponseWire = SearchFullResponseWire(
    searchQuery = searchQuery,
    searchQueryOriginal = searchQueryOriginal,
    clarification = clarification,
    productsTotal = productsTotal?.toLong(),
    products = products.map { it.toWire() },
    categories = categories?.map { it.toWire() },
    brands = brands?.map { it.toWire() },
    locations = locations?.map { it.toWire() },
    filters = filters?.mapValues { it.value.toWire() },
    industrialFilters = industrialFilters?.toWire(),
    priceRange = priceRange?.toWire(),
    priceRanges = priceRanges?.map { it.toWire() },
    priceMedian = priceMedian,
)

internal fun AgentProduct.toWire(): AgentProductWire = AgentProductWire(
    id = id,
    name = name,
    price = price,
    oldPrice = oldPrice,
    priceFormatted = priceFormatted,
    oldPriceFormatted = oldPriceFormatted,
    picture = picture,
    url = url,
    reason = reason,
)

internal fun AgentMessage.toWire(): AgentMessageWire = AgentMessageWire(
    id = id,
    role = role?.value,
    content = content,
    createdAt = createdAt,
    products = products.map { it.toWire() },
)

internal fun AgentSession.toWire(): AgentSessionWire = AgentSessionWire(
    id = id,
    title = title,
    updatedAt = updatedAt,
    messages = messages.map { it.toWire() },
)

internal fun AgentDialogResponse.toWire(): AgentDialogResponseWire = AgentDialogResponseWire(
    sessions = sessions.map { it.toWire() },
    session = session?.toWire(),
)

internal fun AgentResponse.toWire(): AgentResponseWire =
    AgentResponseWire(session = session.toWire(), message = message.toWire())

// endregion

// region customer

internal fun CartItem.toWire(): CartItemWire = CartItemWire(id = id, quantity = quantity.toLong())

internal fun Profile.toWire(): ProfileWire = ProfileWire(
    id = id,
    hasEmail = hasEmail,
    emailRegisteredAt = emailRegisteredAt,
    gender = gender?.value,
    computedGender = computedGender?.value,
    boughtSomething = boughtSomething,
    customProperties = customProperties?.mapValues { standard(it.value) },
)

internal fun OrderItem.toWire(): OrderItemWire = OrderItemWire(
    amount = amount?.toLong(),
    price = price,
    status = status,
    originalPrice = originalPrice,
    barcode = barcode,
    lineId = lineId,
    cancelReason = cancelReason,
    item = item?.toWire(),
)

internal fun Order.toWire(): OrderWire = OrderWire(
    internalId = internalId,
    id = id,
    date = date,
    value = value,
    cashValue = cashValue,
    bonusesValue = bonusesValue,
    deliveryValue = deliveryValue,
    promocode = promocode,
    deliveryDate = deliveryDate,
    internalStatus = internalStatus,
    stream = stream,
    channel = channel,
    taxFree = taxFree,
    deliveryType = deliveryType,
    deliveryAddress = deliveryAddress,
    orderStatus = orderStatus,
    paymentType = paymentType,
    // Gson fills the model and leaves a field out of the answer null, whatever its declared type.
    items = (items as List<OrderItem>?).orEmpty().map { it.toWire() },
)

/**
 * The product of an order's item: the released model the server's orders answer fills through Gson, so
 * any of its fields may be null despite its declared type. The contract's required fields fall back to
 * empty values.
 */
@Suppress("USELESS_CAST")
internal fun LegacyProduct.toWire(): ProductWire = ProductWire(
    id = (id as String?).orEmpty(),
    name = (name as String?).orEmpty(),
    brand = (brand as String?)?.ifEmpty { null },
    description = (description as String?)?.ifEmpty { null },
    url = (url as String?).orEmpty(),
    deeplinkAndroid = deeplinkAndroid,
    deeplinkIos = deeplinkIos,
    imageUrl = (imageUrl as String?)?.ifEmpty { null },
    picture = (picture as String?)?.ifEmpty { null },
    price = (price as Double?) ?: 0.0,
    priceFormatted = priceFormatted as String?,
    priceFull = priceFull as Double?,
    priceFullFormatted = priceFullFormatted as String?,
    oldPrice = oldPrice,
    oldPriceFormatted = oldPriceFormatted,
    currency = (currency as String?).orEmpty(),
    discountPercent = discountPercent?.toLong(),
    discountFormatted = discountFormatted,
    salesRate = (salesRate as Int?)?.toLong(),
    relativeSalesRate = relativeSalesRate as Double?,
    isNew = isNew == true,
    categoryIds = categoryIds as List<String>?,
    categories = (categories as List<LegacyCategory>?)?.map { it.toWire() },
    locationIds = locationIds as List<String>?,
)

@Suppress("USELESS_CAST")
internal fun LegacyCategory.toWire(): ProductCategoryWire = ProductCategoryWire(
    id = (id as String?).orEmpty(),
    name = name as String?,
    url = url as String?,
    parentId = (parentId as String?)?.ifEmpty { null },
    level = (level as String?)?.toLongOrNull(),
)

internal fun SubscriptionStatus.toWire(): SubscriptionStatusWire = SubscriptionStatusWire(
    exists = exists,
    emailBulk = emailBulk,
    emailChain = emailChain,
    emailTransactional = emailTransactional,
    smsBulk = smsBulk,
    smsChain = smsChain,
    smsTransactional = smsTransactional,
    webPushBulk = webPushBulk,
    webPushChain = webPushChain,
    webPushTransactional = webPushTransactional,
    mobilePushBulk = mobilePushBulk,
    mobilePushChain = mobilePushChain,
    mobilePushTransactional = mobilePushTransactional,
    telegramBulk = telegramBulk,
    telegramChain = telegramChain,
    telegramTransactional = telegramTransactional,
    whatsappBulk = whatsappBulk,
    whatsappChain = whatsappChain,
    whatsappTransactional = whatsappTransactional,
    maxBulk = maxBulk,
    maxChain = maxChain,
    maxTransactional = maxTransactional,
    walletBulk = walletBulk,
    walletChain = walletChain,
    walletTransactional = walletTransactional,
    hasWebPush = hasWebPush,
    hasMobilePush = hasMobilePush,
    emailInvalid = emailInvalid,
    emailBlacklisted = emailBlacklisted,
    emailBounced = emailBounced,
    emailSuppressed = emailSuppressed,
    emailConfirmed = emailConfirmed,
)

internal fun Segment.toWire(): SegmentWire = SegmentWire(id = id.toLong(), type = type)

internal fun PurchaseProbability.toWire(): PurchaseProbabilityWire =
    PurchaseProbabilityWire(probability = probability, clientId = clientId)

internal fun LoyaltyMember.toWire(): LoyaltyMemberWire = LoyaltyMemberWire(identifier = identifier)

internal fun LoyaltyLevel.toWire(): LoyaltyLevelWire =
    LoyaltyLevelWire(code = code, name = name, expirationDate = expirationDate)

internal fun LoyaltyStatus.toWire(): LoyaltyStatusWire =
    LoyaltyStatusWire(isMember = isMember, level = level?.toWire())

internal fun LoyaltyPromotion.toWire(): LoyaltyPromotionWire = LoyaltyPromotionWire(
    id = id,
    name = name,
    description = description,
    startDate = startDate,
    finishDate = finishDate,
    stream = stream,
    badgeLabel = badgeLabel,
    badgeColor = badgeColor,
    rewardType = rewardType?.value,
)

// endregion

// region pushes

internal fun PushProvider.wireValue(): String = id

internal fun PushToken.toWire(): PushTokenWire = PushTokenWire(token = token, provider = provider.wireValue())

internal fun PushAction.toWire(): PushActionWire = PushActionWire(id = id, title = title, url = url)

internal fun PushTarget.toWire(): PushTargetWire = PushTargetWire(
    type = type.value,
    uri = uri,
    payload = payload.mapValues { standard(it.value) },
)

internal fun PushPayload.toWire(): PushPayloadWire = PushPayloadWire(
    shopId = shopId,
    code = code,
    type = type,
    title = title,
    body = body,
    icon = icon,
    image = image,
    actions = actions.map { it.toWire() },
    target = target?.toWire(),
    source = source,
    sound = sound,
    data = data.mapValues { it.value },
)

internal fun Statistics.toWire(): NotificationStatisticsWire = NotificationStatisticsWire(
    clicked = clicked,
    complained = complained,
    hardBounced = hardBounced,
    opened = opened,
    purchased = purchased,
    softBounced = softBounced,
    unsubscribed = unsubscribed,
)

@Suppress("USELESS_CAST")
internal fun Message.toWire(): NotificationMessageWire = NotificationMessageWire(
    body = body,
    campaignId = (campaignId as Int?)?.toLong(),
    channel = channel as String?,
    code = code,
    date = date,
    icon = icon,
    picture = picture,
    sentAt = sentAt,
    statistics = (statistics as Statistics?)?.toWire(),
    subject = subject,
    type = type as String?,
    url = url,
)

@Suppress("USELESS_CAST")
internal fun GetAllNotificationsResponse.toWire(): NotificationHistoryWire = NotificationHistoryWire(
    status = status as String?,
    messages = (payload as com.personalization.api.responses.notifications.Payload?)?.messages
        .let { it as List<Message>? }
        .orEmpty()
        .map { it.toWire() },
)

// endregion

// region stories

internal fun StoriesBlock.toWire(): StoriesBlockWire = StoriesBlockWire(id = id, stories = stories.map { it.toWire() })

internal fun Story.toWire(): StoryWire = StoryWire(
    id = id,
    name = name,
    avatar = avatar,
    viewed = viewed,
    pinned = pinned,
    startPosition = startPosition.toLong(),
    slides = slides.map { it.toWire() },
)

internal fun StorySlide.toWire(): StorySlideWire = StorySlideWire(
    id = id,
    type = type.name.lowercase(),
    background = background,
    backgroundColor = backgroundColor,
    preview = preview,
    duration = duration.toLong(),
    elements = elements.map { it.toWire() },
)

internal fun StoryElement.toWire(): StoryElementWire = when (this) {
    is StoryButtonElement -> StoryElementWire(
        type = "button",
        title = title,
        link = link,
        linkAndroid = linkAndroid,
        linkIos = linkIos,
        background = background,
        color = color,
        textBold = textBold,
    )
    is StoryProductElement -> StoryElementWire(type = "product", title = title, item = item?.toWire())
    is StoryProductsElement -> StoryElementWire(
        type = "products",
        showLabel = showLabel,
        hideLabel = hideLabel,
        products = products.map { it.toWire() },
    )
    is StoryTextBlockElement -> StoryElementWire(
        type = "text_block",
        text = text,
        fontSize = fontSize,
        fontType = fontType,
        bold = bold,
        italic = italic,
        textAlign = textAlign,
        textColor = textColor,
        backgroundColor = backgroundColor,
        backgroundOpacity = backgroundOpacity,
        lineSpacing = lineSpacing,
        yOffset = yOffset,
        promocode = promocode,
    )
}

internal fun StoryProduct.toWire(): StoryProductWire = StoryProductWire(
    id = id,
    name = name,
    brand = brand,
    picture = picture,
    imageUrl = imageUrl,
    price = price,
    priceFormatted = priceFormatted,
    oldPrice = oldPrice,
    oldPriceFormatted = oldPriceFormatted,
    discountPercent = discountPercent,
    promocode = promocode,
    priceWithPromocode = priceWithPromocode,
    priceWithPromocodeFormatted = priceWithPromocodeFormatted,
    currency = currency,
    url = url,
    deeplinkAndroid = deeplinkAndroid,
    deeplinkIos = deeplinkIos,
)

// endregion

// region sliders and reviews

internal fun SliderBanner.toWire(): SliderBannerWire = SliderBannerWire(
    id = id,
    code = code,
    imageUrl = imageUrl,
    url = url,
    deeplinkIos = deeplinkIos,
    deeplinkAndroid = deeplinkAndroid,
    html = html,
)

internal fun Slider.toWire(): SliderWire = SliderWire(
    code = code,
    width = width.toLong(),
    height = height.toLong(),
    banners = banners.map { it.toWire() },
)

internal fun PollReview.toWire(): PollReviewWire = PollReviewWire(id = id)

internal fun NpsCategory.toWire(): NpsCategoryWire = NpsCategoryWire(
    code = code,
    name = name,
    detractorQuestion = detractorQuestion,
    passiveQuestion = passiveQuestion,
    promoterQuestion = promoterQuestion,
    detractorSuccess = detractorSuccess,
    passiveSuccess = passiveSuccess,
    promoterSuccess = promoterSuccess,
    buttonLabel = buttonLabel,
)

internal fun CsatCampaign.toWire(): CsatCampaignWire = CsatCampaignWire(
    code = code,
    name = name,
    dissatisfiedQuestion = dissatisfiedQuestion,
    neutralQuestion = neutralQuestion,
    satisfiedQuestion = satisfiedQuestion,
    dissatisfiedSuccess = dissatisfiedSuccess,
    neutralSuccess = neutralSuccess,
    satisfiedSuccess = satisfiedSuccess,
    buttonLabel = buttonLabel,
)

internal fun CesCampaign.toWire(): CesCampaignWire = CesCampaignWire(
    code = code,
    name = name,
    difficultQuestion = difficultQuestion,
    neutralQuestion = neutralQuestion,
    easyQuestion = easyQuestion,
    difficultSuccess = difficultSuccess,
    neutralSuccess = neutralSuccess,
    easySuccess = easySuccess,
    buttonLabel = buttonLabel,
)

internal fun PollChannel.toWire(): PollChannelWire = PollChannelWire(code = code, name = name)

internal fun ProductRatingSummary.toWire(): ProductRatingSummaryWire = ProductRatingSummaryWire(
    count = count.toLong(),
    averageRating = averageRating,
    ratings = ratings.entries.associate { it.key.toLong() to it.value.toLong() },
)

internal fun ProductReview.toWire(): ProductReviewWire = ProductReviewWire(
    id = id,
    rating = rating.toLong(),
    comment = comment,
    author = author,
    createdAt = createdAt,
)

internal fun ProductReviewsResponse.toWire(): ProductReviewsResponseWire =
    ProductReviewsResponseWire(summary = summary.toWire(), reviews = reviews.map { it.toWire() })

internal fun ClientReview.toWire(): ClientReviewWire = ClientReviewWire(
    id = id,
    itemId = itemId,
    orderId = orderId,
    rating = rating.toLong(),
    comment = comment,
    state = state?.value,
    createdAt = createdAt,
)

// endregion

/**
 * A free-form value as the types Pigeon's codec carries — `String`, `Boolean`, `Long`, `Double`, `List`,
 * `Map` with string keys, null: JSON objects and arrays become maps and lists, JSON's null becomes null,
 * smaller whole numbers widen to `Long`, other numbers to `Double`. Anything else goes as its text.
 */
internal fun standard(value: Any?): Any? = when (value) {
    null -> null
    JSONObject.NULL -> null
    is String, is Boolean, is Long, is Double -> value
    is Int -> value.toLong()
    is Short -> value.toLong()
    is Byte -> value.toLong()
    is Float -> value.toDouble()
    is Number -> value.toDouble()
    is JSONObject -> value.keys().asSequence().associateWith { key -> standard(value.opt(key)) }
    is JSONArray -> (0 until value.length()).map { index -> standard(value.opt(index)) }
    is Map<*, *> -> value.entries.associate { (key, item) -> key.toString() to standard(item) }
    is Iterable<*> -> value.map(::standard)
    is Array<*> -> value.map(::standard)
    else -> value.toString()
}
