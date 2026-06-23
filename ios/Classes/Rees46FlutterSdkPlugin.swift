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
    flutterApi?.onPushReceived(payload: Self._stringPayload(userInfo)) { _ in }

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
    var payload = Self._stringPayload(response.notification.request.content.userInfo)
    payload["actionIdentifier"] = response.actionIdentifier
    flutterApi?.onPushClicked(payload: payload) { _ in }
    completionHandler()
  }

  public func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    flutterApi?.onPushDelivered(payload: Self._stringPayload(notification.request.content.userInfo)) { _ in }
    if #available(iOS 14.0, *) {
      completionHandler([.badge, .sound, .banner, .list])
    } else {
      completionHandler([.badge, .sound, .alert])
    }
  }
}

extension Rees46FlutterSdkPlugin {
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
  func getStoredPushToken() throws -> String? {
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

    let sdk = createPersonalizationSDK(
      shopId: config.shopId,
      apiDomain: config.apiDomain,
      stream: config.stream,
      enableLogs: config.enableLogs,
      autoSendPushToken: config.autoSendPushToken,
      sendAdvertisingId: config.sendAdvertisingId,
      parentViewController: nil,
      enableAutoPopupPresentation: config.enableAutoPopupPresentation,
      needReInitialization: config.needReInitialization
    ) { error in
      if let error = error {
        completion(.failure(PigeonError(code: "init_failed", message: String(describing: error), details: nil)))
      } else {
        completion(.success(()))
      }
    }

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

  func getRecommendation(code: String, paramsJson: String?, completion: @escaping (Result<String, Error>) -> Void) {
    guard let sdk = Rees46FlutterSdkPlugin.sdk else {
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

  func getProductInfo(itemId: String, completion: @escaping (Result<String, Error>) -> Void) {
    guard let sdk = Rees46FlutterSdkPlugin.sdk else {
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

  func getProductsList(paramsJson: String?, completion: @escaping (Result<String, Error>) -> Void) {
    guard let sdk = Rees46FlutterSdkPlugin.sdk else {
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

  func searchBlank(completion: @escaping (Result<String, Error>) -> Void) {
    guard let sdk = Rees46FlutterSdkPlugin.sdk else {
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

  func searchInstant(query: String, paramsJson: String?, completion: @escaping (Result<String, Error>) -> Void) {
    guard let sdk = Rees46FlutterSdkPlugin.sdk else {
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

  func searchFull(query: String, paramsJson: String?, completion: @escaping (Result<String, Error>) -> Void) {
    guard let sdk = Rees46FlutterSdkPlugin.sdk else {
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
    completion: @escaping (Result<String, Error>) -> Void
  ) {
    guard let sdk = Rees46FlutterSdkPlugin.sdk else {
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

  func getLoyaltyStatus(identifier: String, completion: @escaping (Result<String, Error>) -> Void) {
    guard let sdk = Rees46FlutterSdkPlugin.sdk else {
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

  func getSid() throws -> String {
    guard let sdk = Rees46FlutterSdkPlugin.sdk else {
      throw PigeonError(code: "not_initialized", message: "SDK is not initialized", details: nil)
    }
    return sdk.userSeance
  }

  func getDid() throws -> String? {
    return Rees46FlutterSdkPlugin.sdk?.deviceId
  }

  func setProfile(params: ProfileParamsWire, completion: @escaping (Result<Void, Error>) -> Void) {
    guard let sdk = Rees46FlutterSdkPlugin.sdk else {
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

  func trackEvent(
    event: String,
    time: Int64?,
    category: String?,
    label: String?,
    value: Int64?,
    customFieldsJson: String?,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    guard let sdk = Rees46FlutterSdkPlugin.sdk else {
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
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    guard let sdk = Rees46FlutterSdkPlugin.sdk else {
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

  private func parseJsonObject(_ json: String?) -> [String: Any]? {
    guard let json, !json.isEmpty, let data = json.data(using: .utf8) else { return nil }
    let obj = try? JSONSerialization.jsonObject(with: data)
    return obj as? [String: Any]
  }
}
