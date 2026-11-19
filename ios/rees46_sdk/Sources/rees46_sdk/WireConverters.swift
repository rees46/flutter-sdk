import Foundation
@_spi(Bridge) import REES46

// The native SDK's models as the Pigeon wire types Dart reads: one `toWire()` per model, field for
// field under the contract's names. Enum values go as their wire values, integers as `Int64`, and
// free-form values (`customProperties`, a push target's `payload`) as standard codec values only.

extension Rees46.Product {
  func toWire() -> ProductWire {
    ProductWire(
      id: id,
      groupId: groupId,
      name: name,
      brand: brand,
      model: model,
      description: description,
      barcode: barcode,
      url: url,
      deeplinkAndroid: deeplinkAndroid,
      deeplinkIos: deeplinkIos,
      imageUrl: imageUrl,
      picture: picture,
      resizedImages: resizedImages,
      price: price,
      priceFormatted: priceFormatted,
      priceFull: priceFull,
      priceFullFormatted: priceFullFormatted,
      oldPrice: oldPrice,
      oldPriceFormatted: oldPriceFormatted,
      oldPriceFull: oldPriceFull,
      oldPriceFullFormatted: oldPriceFullFormatted,
      currency: currency,
      discountPercent: discountPercent.map { Int64($0) },
      discountFormatted: discountFormatted,
      salesRate: salesRate.map { Int64($0) },
      relativeSalesRate: relativeSalesRate,
      rating: rating.map { Int64($0) },
      isNew: isNew,
      stockQuantity: stockQuantity.map { Int64($0) },
      categoryIds: categoryIds,
      categories: categories?.map { $0.toWire() },
      params: params?.map { $0.toWire() },
      locationIds: locationIds
    )
  }
}

extension Rees46.ProductCategory {
  func toWire() -> ProductCategoryWire {
    ProductCategoryWire(
      id: id,
      name: name,
      url: url,
      parentId: parentId,
      level: level.map { Int64($0) },
      count: count.map { Int64($0) },
      alias: alias
    )
  }
}

extension Rees46.ProductParam {
  func toWire() -> ProductParamWire {
    ProductParamWire(
      key: key,
      values: values
    )
  }
}

extension Rees46.Location {
  func toWire() -> LocationWire {
    LocationWire(
      id: id,
      name: name,
      type: type
    )
  }
}

extension Rees46.Brand {
  func toWire() -> BrandWire {
    BrandWire(
      name: name,
      count: Int64(count)
    )
  }
}

extension Rees46.SearchFilter {
  func toWire() -> SearchFilterWire {
    SearchFilterWire(
      count: count.map { Int64($0) },
      priority: priority.map { Int64($0) },
      values: values?.mapValues { Int64($0) },
      min: self.min,
      max: self.max
    )
  }
}

extension Rees46.ColorFilter {
  func toWire() -> ColorFilterWire {
    ColorFilterWire(
      color: color,
      count: Int64(count)
    )
  }
}

extension Rees46.SizeFilter {
  func toWire() -> SizeFilterWire {
    SizeFilterWire(
      size: size,
      count: Int64(count)
    )
  }
}

extension Rees46.IndustrialFilters {
  func toWire() -> IndustrialFiltersWire {
    IndustrialFiltersWire(
      colors: colors?.map { $0.toWire() },
      fashionSizes: fashionSizes?.map { $0.toWire() }
    )
  }
}

extension Rees46.PriceRange {
  func toWire() -> PriceRangeWire {
    PriceRangeWire(
      min: self.min,
      max: self.max
    )
  }
}

extension Rees46.PriceInterval {
  func toWire() -> PriceIntervalWire {
    PriceIntervalWire(
      from: from,
      to: to,
      count: count.map { Int64($0) }
    )
  }
}

extension Rees46.ProductsListResponse {
  func toWire() -> ProductsListResponseWire {
    ProductsListResponseWire(
      productsTotal: productsTotal.map { Int64($0) },
      products: products.map { $0.toWire() },
      categories: categories?.map { $0.toWire() },
      brands: brands?.map { $0.toWire() },
      locations: locations?.map { $0.toWire() },
      filters: filters?.mapValues { $0.toWire() },
      industrialFilters: industrialFilters?.toWire(),
      priceRange: priceRange?.toWire(),
      priceRanges: priceRanges?.map { $0.toWire() },
      priceMedian: priceMedian
    )
  }
}

extension ProductCounter {
  func toWire() -> ProductCounterWire {
    ProductCounterWire(
      view: Int64(view),
      cart: Int64(cart),
      purchase: Int64(purchase)
    )
  }
}

extension ProductCounterTriggers {
  func toWire() -> ProductCounterTriggersWire {
    ProductCounterTriggersWire(
      backInStock: Int64(backInStock),
      priceDrop: Int64(priceDrop)
    )
  }
}

extension ProductCountersResponse {
  func toWire() -> ProductCountersResponseWire {
    ProductCountersResponseWire(
      daily: daily?.toWire(),
      now: now?.toWire(),
      triggers: triggers?.toWire()
    )
  }
}

extension Rees46.CollectionResponse {
  func toWire() -> CollectionResponseWire {
    CollectionResponseWire(
      products: products.map { $0.toWire() }
    )
  }
}

extension Rees46.RecommendationResponse {
  func toWire() -> RecommendationResponseWire {
    RecommendationResponseWire(
      id: id.map { Int64($0) },
      title: title,
      link: link,
      products: products.map { $0.toWire() },
      itemIds: itemIds
    )
  }
}

extension Rees46.Query {
  func toWire() -> QueryWire {
    QueryWire(
      name: name,
      url: url,
      score: score
    )
  }
}

extension Rees46.PopularItem {
  func toWire() -> PopularItemWire {
    PopularItemWire(
      name: name,
      url: url
    )
  }
}

extension Rees46.SearchRedirect {
  func toWire() -> SearchRedirectWire {
    SearchRedirectWire(
      query: query,
      url: url,
      deeplink: deeplink
    )
  }
}

extension Rees46.SearchBlankResponse {
  func toWire() -> SearchBlankResponseWire {
    SearchBlankResponseWire(
      products: products.map { $0.toWire() },
      lastProducts: lastProducts,
      lastQueries: lastQueries?.map { $0.toWire() },
      suggests: suggests?.map { $0.toWire() },
      popularCategories: popularCategories?.map { $0.toWire() },
      popularBrands: popularBrands?.map { $0.toWire() },
      popularLinks: popularLinks?.map { $0.toWire() }
    )
  }
}

extension Rees46.SearchInstantResponse {
  func toWire() -> SearchInstantResponseWire {
    SearchInstantResponseWire(
      searchQuery: searchQuery,
      searchQueryOriginal: searchQueryOriginal,
      clarification: clarification,
      productsTotal: productsTotal.map { Int64($0) },
      products: products.map { $0.toWire() },
      categories: categories?.map { $0.toWire() },
      queries: queries?.map { $0.toWire() },
      locations: locations?.map { $0.toWire() },
      redirect: redirect?.toWire()
    )
  }
}

extension Rees46.SearchFullResponse {
  func toWire() -> SearchFullResponseWire {
    SearchFullResponseWire(
      searchQuery: searchQuery,
      searchQueryOriginal: searchQueryOriginal,
      clarification: clarification,
      productsTotal: productsTotal.map { Int64($0) },
      products: products.map { $0.toWire() },
      categories: categories?.map { $0.toWire() },
      brands: brands?.map { $0.toWire() },
      locations: locations?.map { $0.toWire() },
      filters: filters?.mapValues { $0.toWire() },
      industrialFilters: industrialFilters?.toWire(),
      priceRange: priceRange?.toWire(),
      priceRanges: priceRanges?.map { $0.toWire() },
      priceMedian: priceMedian
    )
  }
}

extension Rees46.AgentProduct {
  func toWire() -> AgentProductWire {
    AgentProductWire(
      id: id,
      name: name,
      price: price,
      oldPrice: oldPrice,
      priceFormatted: priceFormatted,
      oldPriceFormatted: oldPriceFormatted,
      picture: picture,
      url: url,
      reason: reason
    )
  }
}

extension Rees46.AgentMessage {
  func toWire() -> AgentMessageWire {
    AgentMessageWire(
      // A message without an id stays without one, as the contract has it.
      id: id.map(Int64.init),
      role: role?.rawValue,
      content: content,
      createdAt: createdAt,
      products: products.map { $0.toWire() }
    )
  }
}

extension Rees46.AgentSession {
  func toWire() -> AgentSessionWire {
    AgentSessionWire(
      id: Int64(id),
      title: title,
      updatedAt: updatedAt,
      messages: messages.map { $0.toWire() }
    )
  }
}

extension Rees46.AgentDialogResponse {
  func toWire() -> AgentDialogResponseWire {
    AgentDialogResponseWire(
      sessions: sessions.map { $0.toWire() },
      session: session?.toWire()
    )
  }
}

extension Rees46.AgentResponse {
  func toWire() -> AgentResponseWire {
    AgentResponseWire(
      session: session.toWire(),
      message: message.toWire()
    )
  }
}

extension CartItem {
  func toWire() -> CartItemWire {
    CartItemWire(
      id: id,
      quantity: Int64(quantity)
    )
  }
}

extension Rees46.Profile {
  func toWire() -> ProfileWire {
    ProfileWire(
      id: id,
      hasEmail: hasEmail,
      emailRegisteredAt: emailRegisteredAt,
      gender: gender.map(wireGender),
      computedGender: computedGender.map(wireGender),
      boughtSomething: boughtSomething,
      customProperties: customProperties?.mapValues { standard($0) }
    )
  }
}

extension OrderItem {
  func toWire() -> OrderItemWire {
    OrderItemWire(
      amount: Int64(amount),
      price: price,
      status: status,
      originalPrice: originalPrice,
      barcode: barcode,
      lineId: lineId,
      cancelReason: cancelReason,
      item: item.map(legacyProductWire)
    )
  }
}

extension Order {
  func toWire() -> OrderWire {
    OrderWire(
      internalId: Int64(internalId),
      id: id,
      date: date,
      value: value,
      cashValue: cashValue,
      bonusesValue: bonusesValue,
      deliveryValue: deliveryValue,
      promocode: promocode,
      deliveryDate: deliveryDate,
      internalStatus: internalStatus,
      stream: stream,
      channel: channel,
      taxFree: taxFree,
      deliveryType: deliveryType,
      deliveryAddress: deliveryAddress,
      orderStatus: orderStatus,
      paymentType: paymentType,
      items: items.map { $0.toWire() }
    )
  }
}

extension Rees46.SubscriptionStatus {
  func toWire() -> SubscriptionStatusWire {
    SubscriptionStatusWire(
      exists: exists,
      emailBulk: emailBulk,
      emailChain: emailChain,
      emailTransactional: emailTransactional,
      smsBulk: smsBulk,
      smsChain: smsChain,
      smsTransactional: smsTransactional,
      webPushBulk: webPushBulk,
      webPushChain: webPushChain,
      webPushTransactional: webPushTransactional,
      mobilePushBulk: mobilePushBulk,
      mobilePushChain: mobilePushChain,
      mobilePushTransactional: mobilePushTransactional,
      telegramBulk: telegramBulk,
      telegramChain: telegramChain,
      telegramTransactional: telegramTransactional,
      whatsappBulk: whatsappBulk,
      whatsappChain: whatsappChain,
      whatsappTransactional: whatsappTransactional,
      maxBulk: maxBulk,
      maxChain: maxChain,
      maxTransactional: maxTransactional,
      walletBulk: walletBulk,
      walletChain: walletChain,
      walletTransactional: walletTransactional,
      hasWebPush: hasWebPush,
      hasMobilePush: hasMobilePush,
      emailInvalid: emailInvalid,
      emailBlacklisted: emailBlacklisted,
      emailBounced: emailBounced,
      emailSuppressed: emailSuppressed,
      emailConfirmed: emailConfirmed
    )
  }
}

extension Rees46.Segment {
  func toWire() -> SegmentWire {
    SegmentWire(
      id: Int64(id),
      type: type
    )
  }
}

extension Rees46.PushToken {
  func toWire() -> PushTokenWire {
    PushTokenWire(
      token: token,
      provider: provider.rawValue
    )
  }
}

extension Rees46.PushAction {
  func toWire() -> PushActionWire {
    PushActionWire(
      id: id,
      title: title,
      url: url
    )
  }
}

extension Rees46.PushTarget {
  func toWire() -> PushTargetWire {
    PushTargetWire(
      type: type.rawValue,
      uri: uri,
      payload: payload.mapValues { standard($0) }
    )
  }
}

extension Rees46.PushPayload {
  func toWire() -> PushPayloadWire {
    PushPayloadWire(
      shopId: shopId,
      code: code,
      type: type,
      title: title,
      body: body,
      icon: icon,
      image: image,
      actions: actions.map { $0.toWire() },
      target: target?.toWire(),
      source: source,
      sound: sound,
      data: data.mapValues { $0 as Any? }
    )
  }
}

extension StoriesBlock {
  func toWire() -> StoriesBlockWire {
    StoriesBlockWire(
      id: id,
      stories: stories.map { $0.toWire() }
    )
  }
}

extension Story {
  func toWire() -> StoryWire {
    StoryWire(
      id: id,
      name: name,
      avatar: avatar,
      viewed: viewed,
      pinned: pinned,
      startPosition: Int64(startPosition),
      slides: slides.map { $0.toWire() }
    )
  }
}

extension StorySlide {
  func toWire() -> StorySlideWire {
    StorySlideWire(
      id: id,
      type: wireSlideType(type),
      background: background,
      backgroundColor: backgroundColor,
      preview: preview,
      duration: Int64(duration),
      elements: elements.map { $0.toWire() }
    )
  }
}

extension StoryProduct {
  func toWire() -> StoryProductWire {
    StoryProductWire(
      id: id,
      name: name,
      brand: brand,
      picture: picture,
      imageUrl: imageUrl,
      price: price,
      priceFormatted: priceFormatted,
      oldPrice: oldPrice,
      oldPriceFormatted: oldPriceFormatted,
      discountPercent: discountPercent,
      promocode: promocode,
      priceWithPromocode: priceWithPromocode,
      priceWithPromocodeFormatted: priceWithPromocodeFormatted,
      currency: currency,
      url: url,
      deeplinkAndroid: deeplinkAndroid,
      deeplinkIos: deeplinkIos
    )
  }
}

extension PurchaseProbability {
  func toWire() -> PurchaseProbabilityWire {
    PurchaseProbabilityWire(
      probability: probability,
      clientId: clientId
    )
  }
}

extension LoyaltyMember {
  func toWire() -> LoyaltyMemberWire {
    LoyaltyMemberWire(
      identifier: identifier
    )
  }
}

extension LoyaltyLevel {
  /// Nil for a level without a code: the contract's base level, which is no level.
  func toWire() -> LoyaltyLevelWire? {
    guard let code else { return nil }
    return LoyaltyLevelWire(
      code: code,
      name: name,
      expirationDate: expirationDate
    )
  }
}

extension LoyaltyStatus {
  func toWire() -> LoyaltyStatusWire {
    LoyaltyStatusWire(
      isMember: isMember,
      level: level?.toWire()
    )
  }
}

extension LoyaltyPromotion {
  func toWire() -> LoyaltyPromotionWire {
    LoyaltyPromotionWire(
      id: Int64(id),
      name: name,
      description: description,
      startDate: startDate,
      finishDate: finishDate,
      stream: stream,
      badgeLabel: badgeLabel,
      badgeColor: badgeColor,
      rewardType: rewardType?.rawValue
    )
  }
}

extension Slider {
  func toWire() -> SliderWire {
    SliderWire(
      code: code,
      width: Int64(width),
      height: Int64(height),
      banners: banners.map { $0.toWire() }
    )
  }
}

extension SliderBanner {
  func toWire() -> SliderBannerWire {
    SliderBannerWire(
      id: id,
      code: code,
      imageUrl: imageUrl,
      url: url,
      deeplinkIos: deeplinkIos,
      deeplinkAndroid: deeplinkAndroid,
      html: html
    )
  }
}

extension PollReview {
  func toWire() -> PollReviewWire {
    PollReviewWire(
      id: Int64(id)
    )
  }
}

extension NpsCategory {
  func toWire() -> NpsCategoryWire {
    NpsCategoryWire(
      code: code,
      name: name,
      detractorQuestion: detractorQuestion,
      passiveQuestion: passiveQuestion,
      promoterQuestion: promoterQuestion,
      detractorSuccess: detractorSuccess,
      passiveSuccess: passiveSuccess,
      promoterSuccess: promoterSuccess,
      buttonLabel: buttonLabel
    )
  }
}

extension CsatCampaign {
  func toWire() -> CsatCampaignWire {
    CsatCampaignWire(
      code: code,
      name: name,
      dissatisfiedQuestion: dissatisfiedQuestion,
      neutralQuestion: neutralQuestion,
      satisfiedQuestion: satisfiedQuestion,
      dissatisfiedSuccess: dissatisfiedSuccess,
      neutralSuccess: neutralSuccess,
      satisfiedSuccess: satisfiedSuccess,
      buttonLabel: buttonLabel
    )
  }
}

extension CesCampaign {
  func toWire() -> CesCampaignWire {
    CesCampaignWire(
      code: code,
      name: name,
      difficultQuestion: difficultQuestion,
      neutralQuestion: neutralQuestion,
      easyQuestion: easyQuestion,
      difficultSuccess: difficultSuccess,
      neutralSuccess: neutralSuccess,
      easySuccess: easySuccess,
      buttonLabel: buttonLabel
    )
  }
}

extension PollChannel {
  func toWire() -> PollChannelWire {
    PollChannelWire(
      code: code,
      name: name
    )
  }
}

extension ProductRatingSummary {
  func toWire() -> ProductRatingSummaryWire {
    ProductRatingSummaryWire(
      count: Int64(count),
      averageRating: averageRating,
      ratings: Dictionary(uniqueKeysWithValues: ratings.map { (Int64($0.key), Int64($0.value)) })
    )
  }
}

extension ProductReview {
  func toWire() -> ProductReviewWire {
    ProductReviewWire(
      id: Int64(id),
      rating: Int64(rating),
      comment: comment,
      author: author,
      createdAt: createdAt
    )
  }
}

extension ProductReviewsResponse {
  func toWire() -> ProductReviewsResponseWire {
    ProductReviewsResponseWire(
      summary: summary.toWire(),
      reviews: reviews.map { $0.toWire() }
    )
  }
}

extension ClientReview {
  func toWire() -> ClientReviewWire {
    ClientReviewWire(
      id: Int64(id),
      itemId: itemId,
      orderId: orderId,
      rating: Int64(rating),
      comment: comment,
      state: state?.rawValue,
      createdAt: createdAt
    )
  }
}

extension Rees46.CategoryResponse {
  /// A category's screen goes over the wire of a listing: `CategoryResponse` is its subset.
  func toWire() -> ProductsListResponseWire {
    ProductsListResponseWire(
      productsTotal: productsTotal.map { Int64($0) },
      products: products.map { $0.toWire() },
      categories: categories?.map { $0.toWire() },
      brands: brands?.map { $0.toWire() },
      filters: filters?.mapValues { $0.toWire() },
      priceRange: priceRange?.toWire(),
      priceRanges: priceRanges?.map { $0.toWire() },
      priceMedian: priceMedian
    )
  }
}

extension StoryElement {
  /// One wire element per kind: `type` names it and only that kind's fields are set.
  func toWire() -> StoryElementWire {
    switch self {
    case .button(let button):
      return StoryElementWire(
        type: "button",
        title: button.title,
        link: button.link,
        linkAndroid: button.linkAndroid,
        linkIos: button.linkIos,
        background: button.background,
        color: button.color,
        textBold: button.textBold
      )
    case .product(let product):
      return StoryElementWire(type: "product", title: product.title, item: product.item?.toWire())
    case .products(let products):
      return StoryElementWire(
        type: "products",
        showLabel: products.showLabel,
        hideLabel: products.hideLabel,
        products: products.products.map { $0.toWire() }
      )
    case .textBlock(let text):
      return StoryElementWire(
        type: "text_block",
        text: text.text,
        fontSize: text.fontSize,
        fontType: text.fontType,
        bold: text.bold,
        italic: text.italic,
        textAlign: text.textAlign,
        textColor: text.textColor,
        backgroundColor: text.backgroundColor,
        backgroundOpacity: text.backgroundOpacity,
        lineSpacing: text.lineSpacing,
        yOffset: text.yOffset,
        promocode: text.promocode
      )
    }
  }
}

extension UserPayloadResponse {
  /// The history of messages: the answer's `status` and its messages, as Android hands them over.
  func toWire() -> NotificationHistoryWire {
    NotificationHistoryWire(status: nonEmpty(status), messages: notifications.map { $0.toWire() })
  }
}

extension UserNotificationsResponse {
  /// A message: the native model reads the server's one `statistics` object as the one element of
  /// its list; none is nil.
  func toWire() -> NotificationMessageWire {
    NotificationMessageWire(
      body: nonEmpty(bodyData),
      campaignId: campaignId.map(Int64.init),
      channel: nonEmpty(channel),
      code: nonEmpty(codeId),
      date: nonEmpty(dateString),
      icon: nonEmpty(icon),
      picture: nonEmpty(picture),
      sentAt: nonEmpty(dateSentAt),
      statistics: statistics.first?.toWire(),
      subject: nonEmpty(subject),
      type: nonEmpty(type),
      url: nonEmpty(url)
    )
  }
}

extension UserNotificationsStatistics {
  /// What the customer did with the message; a field the answer does not have is `false`, as Android
  /// reads it.
  func toWire() -> NotificationStatisticsWire {
    NotificationStatisticsWire(
      clicked: clicked ?? false,
      complained: complained ?? false,
      hardBounced: hardBounced ?? false,
      opened: opened ?? false,
      purchased: purchased ?? false,
      softBounced: softBounced ?? false,
      unsubscribed: unsubscribed ?? false
    )
  }
}

/// The wire value of a gender: `m` or `f`, as the API and Dart name them.
func wireGender(_ gender: Gender) -> String {
  switch gender {
  case .male: return "m"
  case .female: return "f"
  }
}

func wireSlideType(_ type: StorySlideType) -> String {
  switch type {
  case .image: return "image"
  case .video: return "video"
  case .product: return "product"
  }
}

/// A product of an order: the SDK's older search model, which fills an absent field with `""` or 0.
func legacyProductWire(_ product: Product) -> ProductWire {
  ProductWire(
    id: product.id,
    name: product.name,
    brand: nonEmpty(product.brand),
    model: nonEmpty(product.model),
    description: nonEmpty(product.description),
    barcode: nonEmpty(product.barcode),
    url: product.url,
    deeplinkIos: nonEmpty(product.deeplinkIos),
    imageUrl: nonEmpty(product.imageUrl),
    picture: nonEmpty(product.resizedImageUrl),
    resizedImages: product.resizedImages.isEmpty ? nil : product.resizedImages,
    price: product.price,
    priceFormatted: nonEmpty(product.priceFormatted),
    priceFull: product.priceFull,
    priceFullFormatted: nonEmpty(product.priceFullFormatted),
    oldPrice: product.oldPrice > 0 ? product.oldPrice : nil,
    oldPriceFormatted: nonEmpty(product.oldPriceFormatted),
    oldPriceFull: product.oldPriceFull > 0 ? product.oldPriceFull : nil,
    oldPriceFullFormatted: nonEmpty(product.oldPriceFullFormatted),
    currency: product.currency,
    discountPercent: product.discountPercent.map { Int64($0) },
    discountFormatted: product.discountFormatted,
    salesRate: Int64(product.salesRate),
    relativeSalesRate: Double(product.relativeSalesRate),
    isNew: product.isNew ?? false
  )
}

func nonEmpty(_ text: String?) -> String? {
  guard let text = text, !text.isEmpty else { return nil }
  return text
}

/// A free-form native value as the standard codec takes it: strings, numbers, booleans, lists and
/// maps of them, nil for `NSNull` and for anything else.
func standard(_ value: Any?) -> Any? {
  guard let value = value else { return nil }
  switch value {
  case is NSNull:
    return nil
  case let string as String:
    return string
  case let number as NSNumber:
    // A JSON boolean is an NSNumber too: keep it a Bool.
    if CFGetTypeID(number) == CFBooleanGetTypeID() { return number.boolValue }
    if CFNumberIsFloatType(number) { return number.doubleValue }
    return number.int64Value
  case let bool as Bool:
    return bool
  case let int as Int:
    return Int64(int)
  case let double as Double:
    return double
  case let list as [Any?]:
    return list.map { standard($0) }
  case let map as [AnyHashable: Any?]:
    var out: [String: Any?] = [:]
    for (key, item) in map {
      out[(key as? String) ?? String(describing: key)] = standard(item)
    }
    return out
  default:
    return String(describing: value)
  }
}
