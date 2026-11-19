import Foundation
@_spi(Bridge) import REES46

// What Dart sends, as the native SDK's request models. A value Dart may only send from a closed set
// (a sort direction, a gender, a push provider) that the native SDK does not know is refused as
// `invalidArgument` (`BridgeFailure.invalidArgument`), never guessed.

extension ProductsListRequestWire {
  func native() throws -> Rees46.ProductsListRequest {
    Rees46.ProductsListRequest(
      categoryIds: categoryIds,
      brands: brands,
      merchants: merchants,
      locations: locations,
      priceMin: priceMin,
      priceMax: priceMax,
      filters: filters,
      sortBy: sortBy.map { Rees46.SortBy(rawValue: $0) },
      sortDir: try sortDir.map(nativeSortDirection),
      limit: try limit.map(nativeInt),
      page: try page.map(nativeInt)
    )
  }

  /// `products.getCategory` takes the listing's request without `categoryIds` and `merchants`.
  func nativeCategory() throws -> Rees46.CategoryRequest {
    Rees46.CategoryRequest(
      brands: brands,
      locations: locations,
      filters: filters,
      priceMin: priceMin,
      priceMax: priceMax,
      sortBy: sortBy.map { Rees46.SortBy(rawValue: $0) },
      sortDir: try sortDir.map(nativeSortDirection),
      limit: try limit.map(nativeInt),
      page: try page.map(nativeInt)
    )
  }
}

extension RecommendationRequestWire {
  func native() throws -> Rees46.RecommendationRequest {
    Rees46.RecommendationRequest(
      itemId: itemId,
      categoryId: categoryId,
      searchQuery: searchQuery,
      excludedItemIds: excludedItemIds,
      brands: brands,
      locations: locations,
      limit: try limit.map(nativeInt),
      extended: extended,
      withLocations: withLocations
    )
  }
}

extension SearchFullRequestWire {
  func native() throws -> Rees46.SearchFullRequest {
    Rees46.SearchFullRequest(
      categoryIds: categoryIds,
      brands: brands,
      excludedBrands: excludedBrands,
      merchants: merchants,
      excludedMerchants: excludedMerchants,
      locations: locations,
      priceMin: priceMin,
      priceMax: priceMax,
      colors: colors,
      fashionSizes: fashionSizes,
      excludedItemIds: excludedItemIds,
      filters: filters,
      sortBy: sortBy.map { Rees46.SortBy(rawValue: $0) },
      sortDir: try sortDir.map(nativeSortDirection),
      disableClarification: disableClarification,
      categoryLimit: try categoryLimit.map(nativeInt),
      brandLimit: try brandLimit.map(nativeInt),
      limit: try limit.map(nativeInt),
      page: try page.map(nativeInt)
    )
  }
}

extension ProfileUpdateRequestWire {
  func native() throws -> Rees46.ProfileUpdateRequest {
    Rees46.ProfileUpdateRequest(
      email: email,
      phone: phone,
      externalId: externalId,
      loyaltyId: loyaltyId,
      telegramId: telegramId,
      fbId: fbId,
      vkId: vkId,
      firstName: firstName,
      lastName: lastName,
      gender: try gender.map(nativeGender),
      birthday: birthday,
      age: try age.map(nativeInt),
      location: location,
      kids: try kids?.map { kid in
        Rees46.ProfileKid(gender: try kid.gender.map(nativeGender), birthday: kid.birthday)
      },
      cars: cars?.map { Rees46.ProfileCar(brand: $0.brand, model: $0.model, vds: $0.vds) },
      customProperties: customProperties.map(nativeObject)
    )
  }
}

extension SubscriptionsUpdateRequestWire {
  var native: Rees46.SubscriptionsUpdateRequest {
    Rees46.SubscriptionsUpdateRequest(
      email: email,
      phone: phone,
      externalId: externalId,
      loyaltyId: loyaltyId,
      telegramId: telegramId,
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
      walletTransactional: walletTransactional
    )
  }
}

extension BackInStockPropertiesWire {
  var native: Rees46.BackInStockProperties {
    Rees46.BackInStockProperties(fashionSize: fashionSize, fashionColor: fashionColor, barcode: barcode)
  }
}

extension TrackingItemWire {
  var native: TrackingItem {
    TrackingItem(
      id: id,
      quantity: Int(quantity),
      price: price,
      fashionSize: fashionSize
    )
  }
}

extension TrackingSourceWire {
  /// An unknown source type is dropped rather than guessed — Dart only sends known values, and the
  /// Dart, Android and iOS `TrackingSourceType` enums carry the same set.
  var native: TrackingSource? {
    // The contract's `slider` and `agent_search` wait for the native SDK's bridge source.
    guard !Self.notYetNative.contains(type), let type = TrackingSourceType(rawValue: type) else { return nil }
    return TrackingSource(type: type, code: code)
  }

  /// The contract's source types the native SDK cannot send yet: `invalidArgument` until it can.
  static let notYetNative: Set<String> = ["slider", "agent_search"]
}

extension PurchaseLineItemWire {
  var native: PurchaseItemRequest {
    PurchaseItemRequest(
      id: id,
      amount: Int(amount),
      price: price,
      quantity: nil,
      lineId: lineId,
      fashionSize: fashionSize
    )
  }
}

/// `asc` or `desc`.
func nativeSortDirection(_ value: String) throws -> Rees46.SortDirection {
  guard let direction = Rees46.SortDirection(rawValue: value) else {
    throw BridgeFailure.invalidArgument("unknown sort direction: \(value)")
  }
  return direction
}

/// `m` or `f`, the wire values of the API.
func nativeGender(_ value: String) throws -> Gender {
  switch value {
  case "m": return .male
  case "f": return .female
  default: throw BridgeFailure.invalidArgument("unknown gender: \(value)")
  }
}

/// `apns`, `fcm` or `hms`.
func nativePushProvider(_ value: String) throws -> Rees46.PushProvider {
  guard let provider = Rees46.PushProvider(rawValue: value) else {
    throw BridgeFailure.invalidArgument("unknown push provider: \(value)")
  }
  return provider
}

/// A Dart `int` as the native `Int`; one that does not fit is refused, not wrapped.
func nativeInt(_ value: Int64) throws -> Int {
  guard let int = Int(exactly: value) else {
    throw BridgeFailure.invalidArgument("\(value) is out of range")
  }
  return int
}

/// A free-form Dart map (custom fields, `customProperties`) as the native SDK takes it: a JSON-like
/// dictionary, where Dart's `null` is `NSNull` and nested maps and lists are unwrapped the same way.
func nativeObject(_ map: [String: Any?]) -> [String: Any] {
  var out: [String: Any] = [:]
  for (key, value) in map {
    out[key] = nativeValue(value)
  }
  return out
}

func nativeValue(_ value: Any?) -> Any {
  guard let value = value else { return NSNull() }
  switch value {
  case let map as [AnyHashable: Any?]:
    var out: [String: Any] = [:]
    for (key, item) in map {
      out[(key as? String) ?? String(describing: key)] = nativeValue(item)
    }
    return out
  case let list as [Any?]:
    return list.map(nativeValue)
  default:
    return value
  }
}
