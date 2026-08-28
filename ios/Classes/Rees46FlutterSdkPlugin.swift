import Flutter
import UIKit
import REES46
import Foundation
import UserNotifications

public class Rees46FlutterSdkPlugin: NSObject, FlutterPlugin, FlutterApplicationLifeCycleDelegate {
  static var sdk: PersonalizationSDK?
  static var notificationService: NotificationServiceProtocol?
  static let pushTokenKey = "rees46_flutter_push_token"
  private var messenger: FlutterBinaryMessenger?
  private var api: PersonalizationHostApiImpl?
  private var flutterApi: PersonalizationFlutterApi?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = Rees46FlutterSdkPlugin()
    instance.messenger = registrar.messenger()
    instance.api = PersonalizationHostApiImpl()
    instance.flutterApi = PersonalizationFlutterApi(binaryMessenger: registrar.messenger())
    PersonalizationHostApiSetup.setUp(
      binaryMessenger: registrar.messenger(),
      api: instance.api
    )
    registrar.addApplicationDelegate(instance)

    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = instance
    }
  }

  public func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    UserDefaults.standard.set(deviceToken, forKey: Rees46FlutterSdkPlugin.pushTokenKey)
    Rees46FlutterSdkPlugin.notificationService?
      .didRegisterForRemoteNotificationsWithDeviceToken(deviceToken: deviceToken)
  }

  public func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) -> Bool {
    flutterApi?.onPushReceived(
      shopId: Self._shopId(userInfo),
      payload: Self._stringPayload(userInfo)
    ) { _ in }

    Rees46FlutterSdkPlugin.notificationService?
      .didReceiveRemoteNotifications(application, didReceiveRemoteNotification: userInfo) { result, _ in
        completionHandler(result)
      }
    return true
  }
}

@available(iOS 10.0, *)
extension Rees46FlutterSdkPlugin: UNUserNotificationCenterDelegate {
  public func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    var payload = Self._stringPayload(userInfo)
    payload["actionIdentifier"] = response.actionIdentifier
    flutterApi?.onPushClicked(shopId: Self._shopId(userInfo), payload: payload) { _ in }
    completionHandler()
  }

  public func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    flutterApi?.onPushDelivered(
      shopId: Self._shopId(notification.request.content.userInfo),
      payload: Self._stringPayload(notification.request.content.userInfo)
    ) { _ in }
    if #available(iOS 14.0, *) {
      completionHandler([.badge, .sound, .banner, .list])
    } else {
      completionHandler([.badge, .sound, .alert])
    }
  }
}

extension Rees46FlutterSdkPlugin {
  /// The shop the push is addressed to — its `shop_id`, resolved by the Dart
  /// dispatcher to the matching handle's callbacks (nil falls back to the single
  /// default).
  fileprivate static func _shopId(_ userInfo: [AnyHashable: Any]) -> String? {
    return userInfo["shop_id"] as? String
  }

  fileprivate static func _stringPayload(_ userInfo: [AnyHashable: Any]) -> [String: String?] {
    var result: [String: String?] = [:]
    for (keyAny, value) in userInfo {
      let key = String(describing: keyAny)
      if let str = value as? String {
        result[key] = str
      } else if JSONSerialization.isValidJSONObject(value),
                let data = try? JSONSerialization.data(withJSONObject: value, options: []),
                let json = String(data: data, encoding: .utf8) {
        result[key] = json
      } else {
        result[key] = String(describing: value)
      }
    }
    return result
  }
}

final class PersonalizationHostApiImpl: PersonalizationHostApi {
  /// Resolves the SDK instance a call targets via the multi-instance `Rees46`
  /// facade. `shopId == nil` resolves the single default instance; an unknown or
  /// (with no id) ambiguous shop throws, which `try?` turns into `nil` — the
  /// caller then reports `not_initialized`. This is the F3 wiring; requires the
  /// native `Rees46` facade (local `ios-sdk` via Podfile `:path`, or a pod
  /// version that ships it).
  private func sdk(_ shopId: String?) -> PersonalizationSDK? {
    return try? Rees46.instance(for: shopId)
  }

  func getStoredPushToken(shopId: String?) throws -> String? {
    guard let deviceToken = UserDefaults.standard.data(forKey: Rees46FlutterSdkPlugin.pushTokenKey) else {
      return nil
    }
    let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    return token.isEmpty ? nil : token
  }

  func initialize(config: InitConfig, completion: @escaping (Result<Void, Error>) -> Void) {
    if config.shopId.isEmpty {
      completion(.failure(PigeonError(code: "bad_args", message: "shopId is required", details: nil)))
      return
    }

    // F3: initialize (and register) the instance through the multi-instance
    // `Rees46` facade so it is reachable by `shopId` via `Rees46.instance(for:)`.
    let sdk = Rees46.initialize(
      Rees46Config(
        shopId: config.shopId,
        apiDomain: config.apiDomain,
        stream: config.stream,
        enableLogs: config.enableLogs,
        autoSendPushToken: config.autoSendPushToken,
        sendAdvertisingId: config.sendAdvertisingId,
        enableAutoPopupPresentation: config.enableAutoPopupPresentation,
        needReInitialization: config.needReInitialization
      )
    ) { error in
      if let error = error {
        completion(.failure(PigeonError(code: "init_failed", message: String(describing: error), details: nil)))
      } else {
        completion(.success(()))
      }
    }

    // Kept for the AppDelegate push path (device token / remote notification),
    // which still uses the last-initialized instance until F4 routes by shop.
    Rees46FlutterSdkPlugin.sdk = sdk

    // Create notification service to receive AppDelegate callbacks (device token, remote notification).
    let logger = NotificationLogger()
    Rees46FlutterSdkPlugin.notificationService = NotificationService(
      sdk: sdk,
      notificationLogger: logger
    )
  }

  func getPlatformVersion() throws -> String {
    return "iOS " + UIDevice.current.systemVersion
  }

  func getRecommendation(code: String, paramsJson: String?, shopId: String?, completion: @escaping (Result<String, Error>) -> Void) {
    guard let sdk = sdk(shopId) else {
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

  private static func _recommendationToDict(_ response: RecommenderResponse) -> [String: Any] {
    return [
      "title": response.title,
      "recommends": response.recommended.map { _productToDict($0) },
    ]
  }

  private static func _productToDict(_ p: Recommended) -> [String: Any] {
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
    return dict
  }

  private static func _categoryToDict(_ c: REES46.Category) -> [String: Any] {
    var dict: [String: Any] = ["id": c.id, "name": c.name]
    if let parentId = c.parentId { dict["parent_id"] = parentId }
    if let url = c.url { dict["url"] = url }
    return dict
  }

  func getProductInfo(itemId: String, shopId: String?, completion: @escaping (Result<String, Error>) -> Void) {
    guard let sdk = sdk(shopId) else {
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

  func getProductsList(paramsJson: String?, shopId: String?, completion: @escaping (Result<String, Error>) -> Void) {
    guard let sdk = sdk(shopId) else {
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

  private static func _productsListResponseToDict(_ r: ProductsListResponse) -> [String: Any] {
    // As of REES46 3.24+, ProductsListResponse.products is [Product] (not [ProductInfo]);
    // Product carries no categories, which the Dart parser already treats as optional.
    var dict: [String: Any] = [
      "products": r.products.map { _searchProductToDict($0) },
      "products_total": r.productsTotal,
    ]
    if let pr = r.priceRange {
      dict["price_range"] = ["min": pr.min, "max": pr.max]
    }
    return dict
  }

  private static func _productInfoToDict(_ p: ProductInfo) -> [String: Any] {
    return [
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
  }

  func searchBlank(shopId: String?, completion: @escaping (Result<String, Error>) -> Void) {
    guard let sdk = sdk(shopId) else {
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

  private static func _searchBlankResponseToDict(_ r: SearchBlankResponse) -> [String: Any] {
    return [
      "products": r.products.map { _searchProductToDict($0) },
      "suggests": r.suggests.map { ["name": $0.name, "url": $0.url] },
    ]
  }

  func searchInstant(query: String, paramsJson: String?, shopId: String?, completion: @escaping (Result<String, Error>) -> Void) {
    guard let sdk = sdk(shopId) else {
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

    sdk.search(
      query: query,
      limit: nil,
      offset: nil,
      categoryLimit: nil,
      brandLimit: nil,
      categories: nil,
      extended: nil,
      sortBy: nil,
      sortDir: nil,
      locations: locations,
      excludedMerchants: nil,
      excludedBrands: excludedBrands,
      brands: nil,
      filters: nil,
      priceMin: nil,
      priceMax: nil,
      colors: nil,
      fashionSizes: nil,
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
          completion(.failure(PigeonError(code: "serialization_failed", message: "Failed to serialize search instant response", details: nil)))
          return
        }
        completion(.success(json))
      case .failure(let err):
        completion(.failure(PigeonError(code: "search_instant_failed", message: String(describing: err), details: nil)))
      }
    }
  }

  func searchFull(query: String, paramsJson: String?, shopId: String?, completion: @escaping (Result<String, Error>) -> Void) {
    guard let sdk = sdk(shopId) else {
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

    sdk.search(
      query: query,
      limit: limit,
      offset: page,
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
      filters: nil,
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

  private static func _searchResponseToDict(_ r: SearchResponse) -> [String: Any] {
    var dict: [String: Any] = [
      "products": r.products.map { _searchProductToDict($0) },
      "categories": r.categories.map { _searchCategoryToDict($0) },
      "products_total": r.productsTotal,
    ]
    if let pr = r.priceRange {
      dict["price_range"] = ["min": pr.min, "max": pr.max]
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

  private static func _searchProductToDict(_ p: Product) -> [String: Any] {
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
    ]
    _ = dict // suppress unused warning; all fields set above
    return dict
  }

  private static func _searchCategoryToDict(_ c: REES46.Category) -> [String: Any] {
    var dict: [String: Any] = ["id": c.id, "name": c.name]
    if let url = c.url { dict["url"] = url }
    if let parent = c.parentId { dict["parent"] = parent }
    if let count = c.count { dict["count"] = count }
    return dict
  }

  func joinLoyalty(
    phone: String,
    email: String?,
    firstName: String?,
    lastName: String?,
    shopId: String?,
    completion: @escaping (Result<String, Error>) -> Void
  ) {
    guard let sdk = sdk(shopId) else {
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

  func getLoyaltyStatus(identifier: String, shopId: String?, completion: @escaping (Result<String, Error>) -> Void) {
    guard let sdk = sdk(shopId) else {
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

  func getProfile(shopId: String?, completion: @escaping (Result<String, Error>) -> Void) {
    guard let sdk = sdk(shopId) else {
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

  func getProductCounters(item: String, shopId: String?, completion: @escaping (Result<String, Error>) -> Void) {
    guard let sdk = sdk(shopId) else {
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

  func getCategory(category: String, limit: Int64?, page: Int64?, shopId: String?, completion: @escaping (Result<String, Error>) -> Void) {
    guard let sdk = sdk(shopId) else {
      completion(.failure(PigeonError(code: "not_initialized", message: "SDK is not initialized", details: nil)))
      return
    }
    if category.isEmpty {
      completion(.failure(PigeonError(code: "bad_args", message: "category is required", details: nil)))
      return
    }
    sdk.getCategory(
      category: category,
      limit: limit.map { Int($0) },
      page: page.map { Int($0) },
      brands: nil,
      locations: nil,
      filters: nil
    ) { result in
      switch result {
      case .success(let response):
        Self._encodeCatalog(Self._categoryResponseToDict(response), errorCode: "get_category_failed", completion: completion)
      case .failure(let err):
        completion(.failure(PigeonError(code: "get_category_failed", message: String(describing: err), details: nil)))
      }
    }
  }

  func getCollection(collectionId: String, shopId: String?, completion: @escaping (Result<String, Error>) -> Void) {
    guard let sdk = sdk(shopId) else {
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

  private static func _profileResponseToDict(_ p: GetProfileResponse) -> [String: Any] {
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

  private static func _productCountersToDict(_ r: ProductCountersResponse) -> [String: Any] {
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

  private static func _categoryResponseToDict(_ r: CategoryResponse) -> [String: Any] {
    return [
      "products_total": r.productsTotal,
      "products": r.products.map { _categoryProductToDict($0) },
    ]
  }

  private static func _collectionResponseToDict(_ r: CollectionResponse) -> [String: Any] {
    return ["products": r.products.map { _categoryProductToDict($0) }]
  }

  private static func _categoryProductToDict(_ p: CategoryProduct) -> [String: Any] {
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
  private static func _encodeCatalog(
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
  private static func _encodeEnvelope(
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

  func getSid(shopId: String?) throws -> String {
    guard let sdk = sdk(shopId) else {
      throw PigeonError(code: "not_initialized", message: "SDK is not initialized", details: nil)
    }
    return sdk.userSeance
  }

  func getDid(shopId: String?) throws -> String? {
    return sdk(shopId)?.deviceId
  }

  func setProfile(params: ProfileParamsWire, shopId: String?, completion: @escaping (Result<Void, Error>) -> Void) {
    guard let sdk = sdk(shopId) else {
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

  // MARK: - Tracking namespace
  //
  // Each method hands straight to the native `tracking` namespace of the resolved instance;
  // the wire models are translated one to one.

  func trackProductView(
    itemId: String,
    source: TrackingSourceWire?,
    shopId: String?,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    withTracking(shopId, completion) { tracking in
      tracking.productView(id: itemId, source: source?.native) { self.report($0, completion) }
    }
  }

  func trackCategoryView(
    categoryId: String,
    shopId: String?,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    withTracking(shopId, completion) { tracking in
      tracking.categoryView(id: categoryId) { self.report($0, completion) }
    }
  }

  func trackSearch(
    query: String,
    results: [String]?,
    shopId: String?,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    withTracking(shopId, completion) { tracking in
      tracking.search(query: query, results: results) { self.report($0, completion) }
    }
  }

  func trackAddToCart(
    item: TrackingItemWire,
    source: TrackingSourceWire?,
    shopId: String?,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    withTracking(shopId, completion) { tracking in
      tracking.addToCart(item: item.native, source: source?.native) { self.report($0, completion) }
    }
  }

  func trackSyncCart(
    items: [TrackingItemWire],
    shopId: String?,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    withTracking(shopId, completion) { tracking in
      tracking.syncCart(items: items.map { $0.native }) { self.report($0, completion) }
    }
  }

  func trackRemoveFromCart(
    itemId: String,
    shopId: String?,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    withTracking(shopId, completion) { tracking in
      tracking.removeFromCart(id: itemId) { self.report($0, completion) }
    }
  }

  func trackAddToFavorites(
    itemId: String,
    source: TrackingSourceWire?,
    shopId: String?,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    withTracking(shopId, completion) { tracking in
      tracking.addToFavorites(id: itemId, source: source?.native) { self.report($0, completion) }
    }
  }

  func trackSyncFavorites(
    itemIds: [String],
    shopId: String?,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    withTracking(shopId, completion) { tracking in
      tracking.syncFavorites(ids: itemIds) { self.report($0, completion) }
    }
  }

  func trackRemoveFromFavorites(
    itemId: String,
    shopId: String?,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    withTracking(shopId, completion) { tracking in
      tracking.removeFromFavorites(id: itemId) { self.report($0, completion) }
    }
  }

  func trackStoryView(
    storyId: String,
    slideId: String,
    code: String?,
    shopId: String?,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    withTracking(shopId, completion) { tracking in
      tracking.storyView(storyId: storyId, slideId: slideId, code: code) {
        self.report($0, completion)
      }
    }
  }

  func trackStoryClick(
    storyId: String,
    slideId: String,
    code: String?,
    shopId: String?,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    withTracking(shopId, completion) { tracking in
      tracking.storyClick(storyId: storyId, slideId: slideId, code: code) {
        self.report($0, completion)
      }
    }
  }

  func trackSetSource(source: TrackingSourceWire, shopId: String?) throws {
    guard let sdk = sdk(shopId) else {
      throw PigeonError(code: "not_initialized", message: "SDK is not initialized", details: nil)
    }
    guard let native = source.native else {
      throw PigeonError(
        code: "bad_args", message: "unknown source type: \(source.type)", details: nil)
    }
    sdk.tracking.setSource(native)
  }

  /// Resolves the instance, reports a resolution failure through `completion`, then tracks.
  private func withTracking(
    _ shopId: String?,
    _ completion: @escaping (Result<Void, Error>) -> Void,
    _ body: (TrackingAPI) -> Void
  ) {
    guard let sdk = sdk(shopId) else {
      completion(
        .failure(
          PigeonError(code: "not_initialized", message: "SDK is not initialized", details: nil)))
      return
    }
    body(sdk.tracking)
  }

  private func report(
    _ result: Result<Void, SdkError>,
    _ completion: @escaping (Result<Void, Error>) -> Void
  ) {
    switch result {
    case .success:
      completion(.success(()))
    case .failure(let error):
      completion(
        .failure(
          PigeonError(code: "track_failed", message: "\(error)", details: nil)))
    }
  }

  func trackEvent(
    event: String,
    time: Int64?,
    category: String?,
    label: String?,
    value: Int64?,
    customFieldsJson: String?,
    shopId: String?,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    guard let sdk = sdk(shopId) else {
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
    sdk.trackEvent(
      event: event,
      time: timeInt,
      category: category,
      label: label,
      value: valueInt,
      customFields: customFields
    ) { result in
      switch result {
      case .success:
        completion(.success(()))
      case .failure(let err):
        completion(
          .failure(
            PigeonError(
              code: "track_event_failed",
              message: String(describing: err),
              details: nil)))
      }
    }
  }

  func trackPurchase(
    orderId: String,
    orderPrice: Double,
    items: [PurchaseLineItemWire],
    deliveryType: String?,
    deliveryAddress: String?,
    paymentType: String?,
    isTaxFree: Bool,
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
    guard let sdk = sdk(shopId) else {
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
      segment: segment
    )
    sdk.trackPurchase(request, recommendedBy: nil) { result in
      switch result {
      case .success:
        completion(.success(()))
      case .failure(let err):
        completion(
          .failure(
            PigeonError(
              code: "track_purchase_failed",
              message: String(describing: err),
              details: nil)))
      }
    }
  }

  func handlePush(payload: [String: String], event: Int64, completion: @escaping (Result<Void, Error>) -> Void) {
    // Flutter PushEvent index: 0=received, 1=delivered, 2=clicked.
    let pushEvent: PushEvent
    switch event {
    case 1: pushEvent = .delivered
    case 2: pushEvent = .clicked
    default: pushEvent = .received
    }
    Rees46.handlePush(payload as [AnyHashable: Any], event: pushEvent)
    completion(.success(()))
  }

  private func parseJsonObject(_ json: String?) -> [String: Any]? {
    guard let json, !json.isEmpty, let data = json.data(using: .utf8) else { return nil }
    let obj = try? JSONSerialization.jsonObject(with: data)
    return obj as? [String: Any]
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
  /// An unknown source type is dropped rather than guessed — Dart only sends known values.
  /// `stories` has no case in the iOS `RecommendedByCase`, so a story source is dropped here.
  var native: TrackingSource? {
    guard let type = RecommendedByCase(rawValue: type) else { return nil }
    return TrackingSource(type: type, code: code)
  }
}
