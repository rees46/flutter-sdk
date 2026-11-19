import Flutter
import Foundation
import UIKit
@_spi(Bridge) import REES46

// The handle's deprecated methods as the plugin ran them in 1.6.4: each calls the native SDK's released
// method of the same meaning — they still run on the new core — and answers Dart with the JSON 1.6.4
// handed over, built from the native model the same way, or fails with 1.6.4's error code:
// `not_initialized` for a shop the native registry does not have, `bad_args` for an argument it refuses,
// `serialization_failed`, and `<method>_failed` with the native error otherwise. The namespaces are the
// typed contract; these stay as they were until they are removed.
extension PersonalizationHostApiImpl {

  /// [completion] answered on the main thread, where the plugin's replies go.
  fileprivate func onMainCompletion<T>(_ completion: @escaping (Result<T, Error>) -> Void) -> (Result<T, Error>) -> Void {
    { result in onMain { completion(result) } }
  }

  /// The shop's instance, or nil — the released methods' `not_initialized`.
  fileprivate func legacySdk(_ shopId: String?) -> PersonalizationSDK? {
    try? Rees46.instance(for: shopId)
  }

  func legacyGetRecommendation(code: String, paramsJson: String?, shopId: String?, completion: @escaping (Result<String, Error>) -> Void) {
    let completion = onMainCompletion(completion)
    guard let sdk = legacySdk(shopId) else {
      completion(.failure(PigeonError(code: "not_initialized", message: "SDK is not initialized", details: nil)))
      return
    }
    if code.isEmpty {
      completion(.failure(PigeonError(code: "bad_args", message: "code is required", details: nil)))
      return
    }
    let p = parseJsonObject(paramsJson)
    let itemId = p?["item_id"] as? String
    let categoryId = p?["category_id"] as? String
    let locations = p?["locations"] as? String
    let imageSize = (p?["image_size"] as? Int).map { String($0) }
    let withLocations = p?["with_locations"] as? Bool ?? false

    sdk.recommend(
      blockId: code,
      currentProductId: itemId,
      currentCategoryId: categoryId,
      locations: locations,
      imageSize: imageSize,
      timeOut: nil,
      withLocations: withLocations,
      extended: false
    ) { result in
      switch result {
      case .success(let response):
        let dict = Self._recommendationToDict(response)
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let json = String(data: data, encoding: .utf8) else {
          completion(.failure(PigeonError(code: "serialization_failed", message: "Failed to serialize recommendation response", details: nil)))
          return
        }
        completion(.success(json))
      case .failure(let err):
        completion(.failure(PigeonError(code: "recommendation_failed", message: String(describing: err), details: nil)))
      }
    }
  }

  static func _recommendationToDict(_ response: RecommenderResponse) -> [String: Any] {
    return [
      "title": response.title,
      "recommends": response.recommended.map { _productToDict($0) },
    ]
  }

  static func _productToDict(_ p: Recommended) -> [String: Any] {
    var dict: [String: Any] = [
      "id": p.id,
      "name": p.name,
      "brand": p.brand,
      "description": p.description,
      "image_url": p.imageUrl,
      "picture": p.resizedImageUrl,
      "image_url_resized": p.resizedImages,
      "url": p.url,
      "price": p.price,
      "price_full": p.priceFull,
      "currency": p.currency,
      "sales_rate": p.salesRate,
      "relative_sales_rate": p.relativeSalesRate,
      "categories": p.categories.map { _categoryToDict($0) },
    ]
    if let pf = p.priceFormatted { dict["price_formatted"] = pf }
    if let pff = p.priceFullFormatted { dict["price_full_formatted"] = pff }
    _putDiscount(&dict, oldPrice: p.oldPrice, oldPriceFormatted: p.oldPriceFormatted, discount: p.discount)
    if !p.deeplinkIos.isEmpty { dict["deeplink_ios"] = p.deeplinkIos }
    return dict
  }

  /// Old price and discount as the API sends them: only for a discounted product. The
  /// native models fill an absent value with 0 or "", which would read as a real one.
  static func _putDiscount(
    _ dict: inout [String: Any],
    oldPrice: Double,
    oldPriceFormatted: String?,
    discount: Int
  ) {
    if oldPrice > 0 { dict["oldprice"] = oldPrice }
    if let v = oldPriceFormatted, !v.isEmpty { dict["oldprice_formatted"] = v }
    if discount > 0 { dict["discount"] = discount }
  }

  static func _categoryToDict(_ c: REES46.Category) -> [String: Any] {
    var dict: [String: Any] = ["id": c.id, "name": c.name]
    if let parentId = c.parentId { dict["parent_id"] = parentId }
    if let url = c.url { dict["url"] = url }
    return dict
  }

  func legacyGetProductInfo(itemId: String, shopId: String?, completion: @escaping (Result<String, Error>) -> Void) {
    let completion = onMainCompletion(completion)
    guard let sdk = legacySdk(shopId) else {
      completion(.failure(PigeonError(code: "not_initialized", message: "SDK is not initialized", details: nil)))
      return
    }
    if itemId.isEmpty {
      completion(.failure(PigeonError(code: "bad_args", message: "itemId is required", details: nil)))
      return
    }
    sdk.getProductInfo(id: itemId) { result in
      switch result {
      case .success(let product):
        let dict = Self._productInfoToDict(product)
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let json = String(data: data, encoding: .utf8) else {
          completion(.failure(PigeonError(code: "serialization_failed", message: "Failed to serialize product info", details: nil)))
          return
        }
        completion(.success(json))
      case .failure(let err):
        completion(.failure(PigeonError(code: "product_info_failed", message: String(describing: err), details: nil)))
      }
    }
  }

  func legacyGetProductsList(paramsJson: String?, shopId: String?, completion: @escaping (Result<String, Error>) -> Void) {
    let completion = onMainCompletion(completion)
    guard let sdk = legacySdk(shopId) else {
      completion(.failure(PigeonError(code: "not_initialized", message: "SDK is not initialized", details: nil)))
      return
    }
    let p = parseJsonObject(paramsJson)
    let brands = p?["brands"] as? String
    let merchants = p?["merchants"] as? String
    let categories = p?["categories"] as? String
    let locations = p?["locations"] as? String
    let limit = p?["limit"] as? Int
    let page = p?["page"] as? Int
    let filters = p?["filters"] as? [String: Any]

    sdk.getProductsList(
      brands: brands,
      merchants: merchants,
      categories: categories,
      locations: locations,
      limit: limit,
      page: page,
      filters: filters
    ) { result in
      switch result {
      case .success(let response):
        let dict = Self._productsListResponseToDict(response)
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let json = String(data: data, encoding: .utf8) else {
          completion(.failure(PigeonError(code: "serialization_failed", message: "Failed to serialize products list response", details: nil)))
          return
        }
        completion(.success(json))
      case .failure(let err):
        completion(.failure(PigeonError(code: "products_list_failed", message: String(describing: err), details: nil)))
      }
    }
  }

  static func _productsListResponseToDict(_ r: ProductsListResponse) -> [String: Any] {
    // As of REES46 3.24+, ProductsListResponse.products is [Product] (not [ProductInfo]);
    // Product carries no categories, which the Dart parser already treats as optional.
    // The listing's own categories come with the response itself.
    var dict: [String: Any] = [
      "products": r.products.map { _productsListProductToDict($0) },
      "products_total": r.productsTotal,
      "categories": r.categories.map { _categoryToDict($0) },
    ]
    _addFacets(to: &dict, priceRange: r.priceRange, filters: r.filters)
    if let brands = r.brands {
      dict["brands"] = brands
    }
    return dict
  }

  /// A products list item for the Dart `Product`, whose old price and discount are
  /// nullable: they go out only for a discounted product, as on Android. Search keeps
  /// sending the native zeros, which its model reads as "none".
  static func _productsListProductToDict(_ p: Product) -> [String: Any] {
    var dict = _searchProductToDict(p)
    dict.removeValue(forKey: "oldprice")
    dict.removeValue(forKey: "oldprice_formatted")
    dict.removeValue(forKey: "discount")
    _putDiscount(&dict, oldPrice: p.oldPrice, oldPriceFormatted: p.oldPriceFormatted, discount: p.discount)
    return dict
  }

  static func _productInfoToDict(_ p: ProductInfo) -> [String: Any] {
    var dict: [String: Any] = [
      "id": p.id,                          // normalised from "uniqid"
      "name": p.name,
      "brand": p.brand,
      "description": p.description,
      "image_url": p.imageUrl,
      "image_url_resized": p.resizedImages,
      "url": p.url,
      "price": p.price,
      "price_full": p.priceFull,
      "price_formatted": p.priceFormatted,
      "price_full_formatted": p.priceFullFormatted,
      "currency": p.currency,
      "sales_rate": p.salesRate,
      "relative_sales_rate": p.relativeSalesRate,
      "categories": p.categories.map { c -> [String: Any] in
        var d: [String: Any] = ["id": c.id, "name": c.name]
        if let parent = c.parentId { d["parent_id"] = parent }
        if let url = c.url { d["url"] = url }
        return d
      },
    ]
    if !p.resizedImageUrl.isEmpty { dict["picture"] = p.resizedImageUrl }
    _putDiscount(&dict, oldPrice: p.oldPrice, oldPriceFormatted: p.oldPriceFormatted, discount: p.discount)
    if !p.deeplinkIos.isEmpty { dict["deeplink_ios"] = p.deeplinkIos }
    if let isNew = p.isNew { dict["is_new"] = isNew }
    return dict
  }

  func legacySearchBlank(shopId: String?, completion: @escaping (Result<String, Error>) -> Void) {
    let completion = onMainCompletion(completion)
    guard let sdk = legacySdk(shopId) else {
      completion(.failure(PigeonError(code: "not_initialized", message: "SDK is not initialized", details: nil)))
      return
    }
    sdk.searchBlank { result in
      switch result {
      case .success(let response):
        let dict = Self._searchBlankResponseToDict(response)
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let json = String(data: data, encoding: .utf8) else {
          completion(.failure(PigeonError(code: "serialization_failed", message: "Failed to serialize search blank response", details: nil)))
          return
        }
        completion(.success(json))
      case .failure(let err):
        completion(.failure(PigeonError(code: "search_blank_failed", message: String(describing: err), details: nil)))
      }
    }
  }

  static func _searchBlankResponseToDict(_ r: SearchBlankResponse) -> [String: Any] {
    return [
      "products": r.products.map { _searchProductToDict($0) },
      "suggests": r.suggests.map { ["name": $0.name, "url": $0.url] },
      "last_queries": r.lastQueries.map { ["name": $0.name, "url": $0.url] },
      "popular_categories": r.popularCategories.map { ["name": $0.name, "url": $0.url] },
    ]
  }

  func legacySearchInstant(query: String, paramsJson: String?, shopId: String?, completion: @escaping (Result<String, Error>) -> Void) {
    let completion = onMainCompletion(completion)
    guard let sdk = legacySdk(shopId) else {
      completion(.failure(PigeonError(code: "not_initialized", message: "SDK is not initialized", details: nil)))
      return
    }
    if query.isEmpty {
      completion(.failure(PigeonError(code: "bad_args", message: "query is required", details: nil)))
      return
    }
    let p = parseJsonObject(paramsJson)
    let locations = p?["locations"] as? String
    let excludedBrands = p?["excluded_brands"] as? [String]

    // Instant search is the native `suggest` (`type=instant_search`), as on Android; `search`
    // sent the full search.
    sdk.suggest(
      query: query,
      locations: locations,
      excludedMerchants: nil,
      excludedBrands: excludedBrands,
      timeOut: nil,
      extended: nil
    ) { result in
      switch result {
      case .success(let response):
        let dict = Self._searchResponseToDict(response)
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let json = String(data: data, encoding: .utf8) else {
          completion(.failure(PigeonError(code: "serialization_failed", message: "Failed to serialize search instant response", details: nil)))
          return
        }
        completion(.success(json))
      case .failure(let err):
        completion(.failure(PigeonError(code: "search_instant_failed", message: String(describing: err), details: nil)))
      }
    }
  }

  func legacySearchFull(query: String, paramsJson: String?, shopId: String?, completion: @escaping (Result<String, Error>) -> Void) {
    let completion = onMainCompletion(completion)
    guard let sdk = legacySdk(shopId) else {
      completion(.failure(PigeonError(code: "not_initialized", message: "SDK is not initialized", details: nil)))
      return
    }
    if query.isEmpty {
      completion(.failure(PigeonError(code: "bad_args", message: "query is required", details: nil)))
      return
    }
    let p = parseJsonObject(paramsJson)
    let limit = p?["limit"] as? Int
    let page = p?["page"] as? Int
    let categoryLimit = p?["category_limit"] as? Int
    let brandLimit = p?["brand_limit"] as? Int
    let categoriesInt = (p?["categories"] as? [String])?.compactMap { Int($0) }
    let sortBy = p?["sort_by"] as? String
    let sortDir = p?["sort_dir"] as? String
    let locations = p?["locations"] as? String
    let excludedBrands = p?["excluded_brands"] as? [String]
    let brands = p?["brands"] as? String
    let priceMin = p?["price_min"] as? Double
    let priceMax = p?["price_max"] as? Double
    let colors = p?["colors"] as? [String]
    let fashionSizes = p?["fashion_sizes"] as? [String]
    let filters = p?["filters"] as? [String: Any]
    // The native iOS search pages by product offset, while page is 1-based as on Android:
    // page N starts at (N - 1) * limit, and the first page (or page <= 0) has no offset. The
    // server's default page size isn't pinned down anywhere, so a later page without a limit is
    // rejected rather than guessed: no offset would return page 1 again, and the page number as
    // the offset would shift by N products.
    var offset: Int?
    if let page = page, page > 1 {
      guard let limit = limit, limit > 0 else {
        completion(.failure(PigeonError(code: "bad_args", message: "page > 1 requires limit on iOS", details: nil)))
        return
      }
      offset = (page - 1) * limit
    }

    sdk.search(
      query: query,
      limit: limit,
      offset: offset,
      categoryLimit: categoryLimit,
      brandLimit: brandLimit,
      categories: categoriesInt,
      extended: nil,
      sortBy: sortBy,
      sortDir: sortDir,
      locations: locations,
      excludedMerchants: nil,
      excludedBrands: excludedBrands,
      brands: brands,
      filters: filters,
      priceMin: priceMin,
      priceMax: priceMax,
      colors: colors,
      fashionSizes: fashionSizes,
      exclude: nil,
      email: nil,
      timeOut: nil,
      disableClarification: nil
    ) { result in
      switch result {
      case .success(let response):
        let dict = Self._searchResponseToDict(response)
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let json = String(data: data, encoding: .utf8) else {
          completion(.failure(PigeonError(code: "serialization_failed", message: "Failed to serialize search response", details: nil)))
          return
        }
        completion(.success(json))
      case .failure(let err):
        completion(.failure(PigeonError(code: "search_failed", message: String(describing: err), details: nil)))
      }
    }
  }

  static func _searchResponseToDict(_ r: SearchResponse) -> [String: Any] {
    var dict: [String: Any] = [
      "products": r.products.map { _searchProductToDict($0) },
      "categories": r.categories.map { _searchCategoryToDict($0) },
      "products_total": r.productsTotal,
      "queries": r.queries.map { ["name": $0.name, "url": $0.url] },
    ]
    _addFacets(to: &dict, priceRange: r.priceRange, filters: r.filters)
    if let brands = r.brands {
      dict["brands"] = brands
    }
    if let industrial = r.industrialFilters {
      dict["industrial_filters"] = [
        "colors": industrial.fashionColors.map { ["color": $0.color, "count": $0.count] },
        "fashion_sizes": industrial.fashionSizes.map { ["size": $0.size, "count": $0.count] },
      ]
    }
    if let locs = r.locations {
      dict["locations"] = locs.map { loc -> [String: Any] in
        var d: [String: Any] = ["id": loc.id, "name": loc.name]
        if let t = loc.type { d["type"] = t }
        return d
      }
    }
    return dict
  }

  static func _searchProductToDict(_ p: Product) -> [String: Any] {
    var dict: [String: Any] = [
      "id": p.id,
      "name": p.name,
      "brand": p.brand,
      "description": p.description,
      "image_url": p.imageUrl,
      "picture": p.resizedImageUrl,
      "image_url_resized": p.resizedImages,
      "url": p.url,
      "price": p.price,
      "price_full": p.priceFull,
      "price_formatted": p.priceFormatted,
      "price_full_formatted": p.priceFullFormatted,
      "currency": p.currency,
      "sales_rate": p.salesRate,
      "relative_sales_rate": p.relativeSalesRate,
      "oldprice": p.oldPrice,
      "oldprice_formatted": p.oldPriceFormatted,
      "discount": p.discount,
    ]
    if !p.deeplinkIos.isEmpty { dict["deeplink_ios"] = p.deeplinkIos }
    if let isNew = p.isNew { dict["is_new"] = isNew }
    return dict
  }

  static func _searchCategoryToDict(_ c: REES46.Category) -> [String: Any] {
    var dict: [String: Any] = ["id": c.id, "name": c.name]
    if let url = c.url { dict["url"] = url }
    if let parent = c.parentId { dict["parent"] = parent }
    if let count = c.count { dict["count"] = count }
    return dict
  }

  func legacyJoinLoyalty(
    phone: String,
    email: String?,
    firstName: String?,
    lastName: String?,
    shopId: String?,
    completion: @escaping (Result<String, Error>) -> Void
  ) {
    let completion = onMainCompletion(completion)
    guard let sdk = legacySdk(shopId) else {
      completion(.failure(PigeonError(code: "not_initialized", message: "SDK is not initialized", details: nil)))
      return
    }
    if phone.isEmpty {
      completion(.failure(PigeonError(code: "bad_args", message: "phone is required", details: nil)))
      return
    }
    sdk.joinLoyalty(phone: phone, email: email, firstName: firstName, lastName: lastName) { result in
      switch result {
      case .success(let response):
        var dict: [String: Any] = ["payload": response.payload]
        if let status = response.status { dict["status"] = status }
        Self._encodeEnvelope(dict, completion: completion)
      case .failure(let err):
        completion(.failure(PigeonError(code: "join_loyalty_failed", message: String(describing: err), details: nil)))
      }
    }
  }

  func legacyGetLoyaltyStatus(identifier: String, shopId: String?, completion: @escaping (Result<String, Error>) -> Void) {
    let completion = onMainCompletion(completion)
    guard let sdk = legacySdk(shopId) else {
      completion(.failure(PigeonError(code: "not_initialized", message: "SDK is not initialized", details: nil)))
      return
    }
    if identifier.isEmpty {
      completion(.failure(PigeonError(code: "bad_args", message: "identifier is required", details: nil)))
      return
    }
    sdk.getLoyaltyStatus(identifier: identifier) { result in
      switch result {
      case .success(let response):
        var payload: [String: Any] = [:]
        if let member = response.member { payload["member"] = member }
        if let level = response.level {
          var levelDict: [String: Any] = [:]
          if let name = level.name { levelDict["name"] = name }
          if let code = level.code { levelDict["code"] = code }
          if let exp = level.expirationDate { levelDict["expiration_date"] = exp }
          payload["level"] = levelDict
        }
        var dict: [String: Any] = ["payload": payload]
        if let status = response.status { dict["status"] = status }
        Self._encodeEnvelope(dict, completion: completion)
      case .failure(let err):
        completion(.failure(PigeonError(code: "loyalty_status_failed", message: String(describing: err), details: nil)))
      }
    }
  }

  func legacyGetProfile(shopId: String?, completion: @escaping (Result<String, Error>) -> Void) {
    let completion = onMainCompletion(completion)
    guard let sdk = legacySdk(shopId) else {
      completion(.failure(PigeonError(code: "not_initialized", message: "SDK is not initialized", details: nil)))
      return
    }
    sdk.getProfile { result in
      switch result {
      case .success(let response):
        Self._encodeCatalog(Self._profileResponseToDict(response), errorCode: "get_profile_failed", completion: completion)
      case .failure(let err):
        completion(.failure(PigeonError(code: "get_profile_failed", message: String(describing: err), details: nil)))
      }
    }
  }

  func legacyGetProductCounters(item: String, shopId: String?, completion: @escaping (Result<String, Error>) -> Void) {
    let completion = onMainCompletion(completion)
    guard let sdk = legacySdk(shopId) else {
      completion(.failure(PigeonError(code: "not_initialized", message: "SDK is not initialized", details: nil)))
      return
    }
    if item.isEmpty {
      completion(.failure(PigeonError(code: "bad_args", message: "item is required", details: nil)))
      return
    }
    sdk.getProductCounters(item: item) { result in
      switch result {
      case .success(let response):
        Self._encodeCatalog(Self._productCountersToDict(response), errorCode: "product_counters_failed", completion: completion)
      case .failure(let err):
        completion(.failure(PigeonError(code: "product_counters_failed", message: String(describing: err), details: nil)))
      }
    }
  }

  func legacyGetCategory(category: String, limit: Int64?, page: Int64?, paramsJson: String?, shopId: String?, completion: @escaping (Result<String, Error>) -> Void) {
    let completion = onMainCompletion(completion)
    guard let sdk = legacySdk(shopId) else {
      completion(.failure(PigeonError(code: "not_initialized", message: "SDK is not initialized", details: nil)))
      return
    }
    if category.isEmpty {
      completion(.failure(PigeonError(code: "bad_args", message: "category is required", details: nil)))
      return
    }
    let p = parseJsonObject(paramsJson)
    let brands = (p?["brands"] as? String).flatMap { $0.isEmpty ? nil : $0 }
    let locations = (p?["locations"] as? String).flatMap { $0.isEmpty ? nil : $0 }
    let filters = (p?["filters"] as? [String: Any]).flatMap { $0.isEmpty ? nil : $0 }
    let sortBy = (p?["sort_by"] as? String).flatMap { $0.isEmpty ? nil : $0 }
    let sortDir = (p?["sort_dir"] as? String).flatMap { $0.isEmpty ? nil : $0 }
    sdk.getCategory(
      category: category,
      limit: limit.map { Int($0) },
      page: page.map { Int($0) },
      brands: brands,
      locations: locations,
      filters: filters,
      priceMin: p?["price_min"] as? Double,
      priceMax: p?["price_max"] as? Double,
      sortBy: sortBy,
      sortDir: sortDir
    ) { result in
      switch result {
      case .success(let response):
        Self._encodeCatalog(Self._categoryResponseToDict(response), errorCode: "get_category_failed", completion: completion)
      case .failure(let err):
        completion(.failure(PigeonError(code: "get_category_failed", message: String(describing: err), details: nil)))
      }
    }
  }

  func legacyGetCollection(collectionId: String, shopId: String?, completion: @escaping (Result<String, Error>) -> Void) {
    let completion = onMainCompletion(completion)
    guard let sdk = legacySdk(shopId) else {
      completion(.failure(PigeonError(code: "not_initialized", message: "SDK is not initialized", details: nil)))
      return
    }
    if collectionId.isEmpty {
      completion(.failure(PigeonError(code: "bad_args", message: "collectionId is required", details: nil)))
      return
    }
    sdk.getCollection(
      collectionId: collectionId,
      location: nil,
      email: nil,
      phone: nil,
      externalId: nil,
      loyaltyId: nil
    ) { result in
      switch result {
      case .success(let response):
        Self._encodeCatalog(Self._collectionResponseToDict(response), errorCode: "get_collection_failed", completion: completion)
      case .failure(let err):
        completion(.failure(PigeonError(code: "get_collection_failed", message: String(describing: err), details: nil)))
      }
    }
  }

  func legacyGetStories(code: String, shopId: String?, completion: @escaping (Result<String, Error>) -> Void) {
    let completion = onMainCompletion(completion)
    guard let sdk = legacySdk(shopId) else {
      completion(.failure(PigeonError(code: "not_initialized", message: "SDK is not initialized", details: nil)))
      return
    }
    if code.isEmpty {
      completion(.failure(PigeonError(code: "bad_args", message: "code is required", details: nil)))
      return
    }
    // The same request `getStories(code:)` sends, through the SDK's public raw entry point,
    // so the server JSON reaches Dart as is — the payload the Android bridge hands over.
    // `StoryContent` keeps most of the fields internal and drops the rest, so it cannot be
    // re-encoded. Queued on the session queue like `getStories`: it waits for the init that
    // provides the device id.
    sdk.sessionQueue.addOperation {
      let params: [String: String] = ["shop_id": sdk.shopId, "did": sdk.deviceId]
      sdk.getRequest(path: "stories/\(code)", params: params, false) { result in
        switch result {
        case .success(let dict):
          Self._encodeCatalog(dict, errorCode: "get_stories_failed", completion: completion)
        case .failure(let err):
          completion(.failure(PigeonError(code: "get_stories_failed", message: String(describing: err), details: nil)))
        }
      }
    }
  }

  static func _profileResponseToDict(_ p: GetProfileResponse) -> [String: Any] {
    var d: [String: Any] = [:]
    if let v = p.id { d["id"] = v }
    if let v = p.email { d["email"] = v }
    if let v = p.phone { d["phone"] = v }
    if let v = p.firstName { d["first_name"] = v }
    if let v = p.lastName { d["last_name"] = v }
    if let v = p.hasEmail { d["has_email"] = v }
    if let v = p.emailRegisteredAt { d["email_registered_at"] = v }
    if let v = p.gender { d["gender"] = v }
    if let v = p.computedGender { d["computed_gender"] = v }
    if let v = p.boughtSomething { d["bought_something"] = v }
    if JSONSerialization.isValidJSONObject(p.customProperties) {
      d["custom_properties"] = p.customProperties
    }
    return d
  }

  static func _productCountersToDict(_ r: ProductCountersResponse) -> [String: Any] {
    func counterDict(_ c: ProductCounter?) -> [String: Any]? {
      guard let c = c else { return nil }
      return ["view": c.view, "cart": c.cart, "purchase": c.purchase]
    }
    var d: [String: Any] = [:]
    if let v = counterDict(r.daily) { d["daily"] = v }
    if let v = counterDict(r.now) { d["now"] = v }
    if let t = r.triggers {
      d["triggers"] = ["back_in_stock": t.backInStock, "price_drop": t.priceDrop]
    }
    return d
  }

  /// The facets of a listing — its price range and the shop's filters — as the Dart models read
  /// them. The search, the products list and the category send the same shape.
  static func _addFacets(to dict: inout [String: Any], priceRange: PriceRange?, filters: [String: Filter]?) {
    if let pr = priceRange {
      dict["price_range"] = ["min": pr.min, "max": pr.max]
    }
    if let filters = filters {
      dict["filters"] = filters.mapValues { ["count": $0.count, "values": $0.values] as [String: Any] }
    }
  }

  /// The category listing for the Dart `CategoryResponse`: the facets and the price range go
  /// along, as in the search and the products list.
  static func _categoryResponseToDict(_ r: CategoryResponse) -> [String: Any] {
    var dict: [String: Any] = [
      "products_total": r.productsTotal,
      "products": r.products.map { _categoryProductToDict($0) },
      "brands": r.brands.compactMap { b -> [String: Any]? in
        guard let name = b.name, !name.isEmpty else { return nil }
        var d: [String: Any] = ["name": name]
        if let count = b.count { d["count"] = count }
        return d
      },
    ]
    _addFacets(to: &dict, priceRange: r.priceRange, filters: r.filters)
    return dict
  }

  static func _collectionResponseToDict(_ r: CollectionResponse) -> [String: Any] {
    return ["products": r.products.map { _categoryProductToDict($0) }]
  }

  static func _categoryProductToDict(_ p: CategoryProduct) -> [String: Any] {
    var d: [String: Any] = [:]
    if let v = p.id { d["id"] = v }
    if let v = p.name { d["name"] = v }
    if let v = p.brand { d["brand"] = v }
    if let v = p.price { d["price"] = v }
    if let v = p.priceFormatted { d["price_formatted"] = v }
    if let v = p.priceFull { d["price_full"] = v }
    if let v = p.priceFullFormatted { d["price_full_formatted"] = v }
    if let v = p.currency { d["currency"] = v }
    if let v = p.imageUrl { d["image_url"] = v }
    if let v = p.url { d["url"] = v }
    if let v = p.picture { d["picture"] = v }
    return d
  }

  /// Serializes a catalog response dictionary to a JSON string, mirroring the
  /// other JSON-returning host methods.
  static func _encodeCatalog(
    _ dict: [String: Any],
    errorCode: String,
    completion: @escaping (Result<String, Error>) -> Void
  ) {
    guard JSONSerialization.isValidJSONObject(dict),
          let data = try? JSONSerialization.data(withJSONObject: dict),
          let json = String(data: data, encoding: .utf8) else {
      completion(.failure(PigeonError(code: "serialization_failed", message: "Failed to serialize \(errorCode) response", details: nil)))
      return
    }
    completion(.success(json))
  }

  /// Serializes a loyalty response envelope `{ "status": ..., "payload": ... }`
  /// to a JSON string, mirroring the other JSON-returning host methods.
  static func _encodeEnvelope(
    _ dict: [String: Any],
    completion: @escaping (Result<String, Error>) -> Void
  ) {
    guard JSONSerialization.isValidJSONObject(dict),
          let data = try? JSONSerialization.data(withJSONObject: dict),
          let json = String(data: data, encoding: .utf8) else {
      completion(.failure(PigeonError(code: "serialization_failed", message: "Failed to serialize loyalty response", details: nil)))
      return
    }
    completion(.success(json))
  }

  func legacySetProfile(params: ProfileParamsWire, shopId: String?, completion: @escaping (Result<Void, Error>) -> Void) {
    let completion = onMainCompletion(completion)
    guard let sdk = legacySdk(shopId) else {
      completion(.failure(PigeonError(code: "not_initialized", message: "SDK is not initialized", details: nil)))
      return
    }
    // As of REES46 3.24+, `setProfileData` takes individual named parameters
    // instead of a `ProfileData` value.
    var gender: Gender?
    if let genderStr = params.gender {
      gender = genderStr == "m" ? .male : .female
    }
    var birthday: Date?
    if let birthdayStr = params.birthday {
      let fmt = DateFormatter()
      fmt.dateFormat = "yyyy-MM-dd"
      birthday = fmt.date(from: birthdayStr)
    }
    var customProperties: [String: Any?]?
    if let json = params.customPropertiesJson,
       let data = json.data(using: .utf8),
       let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
      customProperties = obj
    }
    sdk.setProfileData(
      userEmail: params.email,
      userPhone: params.phone,
      userLoyaltyId: params.loyaltyId,
      birthday: birthday,
      age: params.age.map { Int($0) },
      firstName: params.firstName,
      lastName: params.lastName,
      location: params.location,
      gender: gender,
      advertisingId: params.advertisingId,
      fbID: params.fbId,
      vkID: params.vkId,
      telegramId: params.telegramId,
      loyaltyCardLocation: params.loyaltyCardLocation,
      loyaltyStatus: params.loyaltyStatus,
      loyaltyBonuses: params.loyaltyBonuses.map { Int($0) },
      loyaltyBonusesToNextLevel: params.loyaltyBonusesToNextLevel.map { Int($0) },
      boughtSomething: params.boughtSomething,
      userId: params.userId,
      customProperties: customProperties
    ) { result in
      switch result {
      case .success:
        completion(.success(()))
      case .failure(let err):
        completion(.failure(PigeonError(code: "set_profile_failed", message: String(describing: err), details: nil)))
      }
    }
  }

  func legacyManageSubscription(params: SubscriptionsUpdateRequestWire, shopId: String?, completion: @escaping (Result<Void, Error>) -> Void) {
    let completion = onMainCompletion(completion)
    guard let sdk = legacySdk(shopId) else {
      completion(.failure(PigeonError(code: "not_initialized", message: "SDK is not initialized", details: nil)))
      return
    }
    sdk.manageSubscription(
      email: params.email,
      phone: params.phone,
      userExternalId: params.externalId,
      userLoyaltyId: params.loyaltyId,
      telegramId: params.telegramId,
      emailBulk: params.emailBulk,
      emailChain: params.emailChain,
      emailTransactional: params.emailTransactional,
      smsBulk: params.smsBulk,
      smsChain: params.smsChain,
      smsTransactional: params.smsTransactional,
      webPushBulk: params.webPushBulk,
      webPushChain: params.webPushChain,
      webPushTransactional: params.webPushTransactional,
      mobilePushBulk: params.mobilePushBulk,
      mobilePushChain: params.mobilePushChain,
      mobilePushTransactional: params.mobilePushTransactional,
      telegramBulk: params.telegramBulk,
      telegramChain: params.telegramChain,
      telegramTransactional: params.telegramTransactional,
      whatsappBulk: params.whatsappBulk,
      whatsappChain: params.whatsappChain,
      whatsappTransactional: params.whatsappTransactional,
      maxBulk: params.maxBulk,
      maxChain: params.maxChain,
      maxTransactional: params.maxTransactional,
      walletBulk: params.walletBulk,
      completion: { result in
        switch result {
        case .success:
          completion(.success(()))
        case .failure(let err):
          completion(.failure(PigeonError(code: "manage_subscription_failed", message: String(describing: err), details: nil)))
        }
      }
    )
  }

  func legacyTrackEvent(
    event: String,
    time: Int64?,
    category: String?,
    label: String?,
    value: Int64?,
    customFieldsJson: String?,
    shopId: String?,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    let completion = onMainCompletion(completion)
    guard let sdk = legacySdk(shopId) else {
      completion(
        .failure(
          PigeonError(
            code: "not_initialized",
            message: "SDK is not initialized",
            details: nil)))
      return
    }
    if event.isEmpty {
      completion(
        .failure(PigeonError(code: "bad_args", message: "event is required", details: nil)))
      return
    }
    let timeInt: Int? = time.map { Int(truncatingIfNeeded: $0) }
    let valueInt: Int? = value.map { Int(truncatingIfNeeded: $0) }
    let customFields = parseJsonObject(customFieldsJson)
    // The same event as `trackEvent`, completed once the shop's queue accepted it: on the new core the
    // server's answer can be days away, and an app awaiting it would wait that long.
    legacyTrack(sdk, failure: "track_event_failed", completion) { tracking in
      try await tracking.custom(
        event: event,
        time: timeInt,
        category: category,
        label: label,
        value: valueInt,
        customFields: customFields
      )
    }
  }

  /// A released tracking call through the shop's tracking line and `tracking.async`: [completion] hears
  /// once the queue accepted the event, or [failure] with the error that kept it out of the queue.
  fileprivate func legacyTrack(
    _ sdk: PersonalizationSDK,
    failure: String,
    _ completion: @escaping (Result<Void, Error>) -> Void,
    _ body: @escaping (TrackingAsyncAPI) async throws -> Void
  ) {
    let tracking = sdk.tracking.async
    trackingLine(sdk.shopId).send {
      do {
        try await body(tracking)
        completion(.success(()))
      } catch {
        completion(.failure(PigeonError(code: failure, message: String(describing: error), details: nil)))
      }
    }
  }

  func legacyTrackPurchase(
    orderId: String,
    orderPrice: Double,
    items: [PurchaseLineItemWire],
    deliveryType: String?,
    deliveryAddress: String?,
    paymentType: String?,
    isTaxFree: Bool,
    isGiftPackage: Bool,
    promocode: String?,
    orderCash: Double?,
    orderBonuses: Double?,
    orderDelivery: Double?,
    orderDiscount: Double?,
    channel: String?,
    customJson: String?,
    recommendedSourceJson: String?,
    stream: String?,
    segment: String?,
    shopId: String?,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    let completion = onMainCompletion(completion)
    guard let sdk = legacySdk(shopId) else {
      completion(
        .failure(
          PigeonError(
            code: "not_initialized",
            message: "SDK is not initialized",
            details: nil)))
      return
    }
    if orderId.isEmpty {
      completion(
        .failure(PigeonError(code: "bad_args", message: "orderId is required", details: nil)))
      return
    }
    if items.isEmpty {
      completion(
        .failure(PigeonError(code: "bad_args", message: "items must be non-empty", details: nil)))
      return
    }
    let itemRequests: [PurchaseItemRequest] = items.map { wire in
      PurchaseItemRequest(
        id: wire.id,
        amount: Int(wire.amount),
        price: wire.price,
        quantity: nil,
        lineId: wire.lineId,
        fashionSize: wire.fashionSize
      )
    }
    let request = PurchaseTrackingRequest(
      orderId: orderId,
      orderPrice: orderPrice,
      items: itemRequests,
      deliveryType: deliveryType,
      deliveryAddress: deliveryAddress,
      paymentType: paymentType,
      isTaxFree: isTaxFree,
      promocode: promocode,
      orderCash: orderCash,
      orderBonuses: orderBonuses,
      orderDelivery: orderDelivery,
      orderDiscount: orderDiscount,
      channel: channel,
      custom: parseJsonObject(customJson),
      recommendedSource: parseJsonObject(recommendedSourceJson),
      stream: stream,
      segment: segment,
      isGiftPackage: isGiftPackage
    )
    // The same request as `trackPurchase`, completed once the shop's queue accepted it: a late server
    // answer must not look like a lost purchase to an app that would send it again.
    legacyTrack(sdk, failure: "track_purchase_failed", completion) { tracking in
      try await tracking.purchase(request, source: nil)
    }
  }

  func legacyGetStoredPushToken(shopId: String?) throws -> String? {
    guard let deviceToken = UserDefaults.standard.data(forKey: Rees46FlutterSdkPlugin.pushTokenKey) else {
      return nil
    }
    let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    return token.isEmpty ? nil : token
  }

  fileprivate func parseJsonObject(_ json: String?) -> [String: Any]? {
    guard let json, !json.isEmpty, let data = json.data(using: .utf8) else { return nil }
    let obj = try? JSONSerialization.jsonObject(with: data)
    return obj as? [String: Any]
  }
}
