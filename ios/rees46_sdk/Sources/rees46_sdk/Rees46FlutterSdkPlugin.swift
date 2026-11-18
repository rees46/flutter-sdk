import Flutter
import Foundation
import UIKit
import UserNotifications
@_spi(Bridge) import REES46

public class Rees46FlutterSdkPlugin: NSObject, FlutterPlugin, FlutterApplicationLifeCycleDelegate {
  static var sdk: PersonalizationSDK?
  static var notificationService: NotificationServiceProtocol?
  static let pushTokenKey = "rees46_flutter_push_token"
  private var api: PersonalizationHostApiImpl?
  private var flutterApi: PersonalizationFlutterApi?
  private var storiesApi: PersonalizationStoriesFlutterApi?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = Rees46FlutterSdkPlugin()
    let messenger = registrar.messenger()
    let api = PersonalizationHostApiImpl(
      popupApi: PersonalizationPopupFlutterApi(binaryMessenger: messenger),
      stateApi: PersonalizationStateFlutterApi(binaryMessenger: messenger)
    )
    api.startPushSinks()
    instance.api = api
    instance.flutterApi = PersonalizationFlutterApi(binaryMessenger: messenger)
    let storiesApi = PersonalizationStoriesFlutterApi(binaryMessenger: messenger)
    instance.storiesApi = storiesApi
    StoriesAudio.shared.onVolumeUp = { storiesApi.onStoriesVolumeUp { _ in } }
    PersonalizationHostApiSetup.setUp(binaryMessenger: messenger, api: api)
    registrar.addApplicationDelegate(instance)
    registrar.publish(instance)

    UNUserNotificationCenter.current().delegate = instance
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    api?.stop()
    PersonalizationHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: nil)
  }

  public func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    // Kept for `notifications.getPushToken` of an app that sends the token itself
    // (`autoSendPushToken: false`), as `getStoredPushToken` always read it.
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

    guard let notificationService = Rees46FlutterSdkPlugin.notificationService else {
      // No notification service (the app sends the push token itself): the delivery is still
      // tracked, and the system is told the push is handled.
      Rees46.handlePush(userInfo, event: Rees46.PushEvent.delivered)
      completionHandler(.newData)
      return true
    }
    // The SDK's service sends `delivered`, and `opened` or `clicked` by the app's state.
    notificationService.didReceiveRemoteNotifications(application, didReceiveRemoteNotification: userInfo) { result, _ in
      completionHandler(result)
    }
    return true
  }
}

extension Rees46FlutterSdkPlugin: UNUserNotificationCenterDelegate {
  /// A tap on the notification is `clicked`; its dismissal (reported only for a category with
  /// `customDismissAction`) is `closed`. The SDK sends each event once per message.
  public func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    var payload = Self._stringPayload(userInfo)
    payload["actionIdentifier"] = response.actionIdentifier
    flutterApi?.onPushClicked(shopId: Self._shopId(userInfo), payload: payload) { _ in }
    Rees46.handlePush(userInfo, event: Self.responseEvent(response.actionIdentifier))
    completionHandler()
  }

  /// A push shown while the app is open: the notification is on screen, `opened`.
  public func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let userInfo = notification.request.content.userInfo
    flutterApi?.onPushDelivered(
      shopId: Self._shopId(userInfo),
      payload: Self._stringPayload(userInfo)
    ) { _ in }
    Rees46.handlePush(userInfo, event: Rees46.PushEvent.opened)
    completionHandler([.badge, .sound, .banner, .list])
  }

  /// The event of the user's response to a notification.
  static func responseEvent(_ actionIdentifier: String) -> Rees46.PushEvent {
    actionIdentifier == UNNotificationDismissActionIdentifier ? .closed : .clicked
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

/// The host side of the Pigeon channel: each call goes to the native SDK's method of the same meaning
/// on the shop's instance, on the new core (`Rees46.initializeBridge`), and its result goes back as the
/// wire types. The native registry holds the instances; the bridge keeps no request, storage or queue
/// of its own — only its subscriptions to each shop's state and session, and to the pushes, to tell
/// Dart.
final class PersonalizationHostApiImpl: PersonalizationHostApi {
  private let popupApi: PersonalizationPopupFlutterApi
  private let stateApi: PersonalizationStateFlutterApi

  private let lock = NSLock()
  /// One per shop: the SDK holds its popup delegate weakly.
  private var popupForwarders: [String: PopupForwarder] = [:]
  /// Per shop, the subscriptions that tell Dart the instance's state and session.
  private var subscriptions: [String: [Cancellable]] = [:]
  /// The pushes and tokens of every shop.
  private var pushSinks: [Cancellable] = []

  init(popupApi: PersonalizationPopupFlutterApi, stateApi: PersonalizationStateFlutterApi) {
    self.popupApi = popupApi
    self.stateApi = stateApi
  }

  // MARK: - Instances and their state

  /// The shop's instance; a shop the native registry does not have — never initialized, released,
  /// or no id while several shops are live — is `notInitialized`.
  func instance(_ shopId: String?) throws -> PersonalizationSDK {
    do {
      return try Rees46.instance(for: shopId)
    } catch {
      throw BridgeFailure.notInitialized
    }
  }

  /// Tells Dart every push event and push token the native SDK sees, of every shop.
  func startPushSinks() {
    let events = Rees46.onPushEvent { [weak self] event, payload in
      self?.stateApi.onPushEvent(shopId: payload.shopId, event: event.rawValue, payload: payload.toWire()) { _ in }
    }
    let tokens = Rees46.onPushToken { [weak self] token in
      self?.stateApi.onPushToken(token: token.toWire()) { _ in }
      // Each initialized shop's own token may have changed with it.
      self?.emitAll()
    }
    lock.lock()
    pushSinks = [events, tokens]
    lock.unlock()
  }

  /// Drops every subscription: the engine went away.
  func stop() {
    lock.lock()
    let all = pushSinks + subscriptions.values.flatMap { $0 }
    pushSinks = []
    subscriptions = [:]
    lock.unlock()
    all.forEach { $0.cancel() }
  }

  /// Tells Dart the shop's state on every change of its state and session. A second initialization
  /// of the shop (a Dart hot restart) replaces the subscriptions, the state one telling the current
  /// state at once.
  private func subscribe(_ sdk: PersonalizationSDK) {
    let fresh = [
      sdk.onStateChange { [weak self] state in self?.emit(sdk, state: state) },
      sdk.onSessionChange { [weak self] _ in self?.emit(sdk) },
    ]
    lock.lock()
    let stale = subscriptions[sdk.shopId] ?? []
    subscriptions[sdk.shopId] = fresh
    lock.unlock()
    stale.forEach { $0.cancel() }
  }

  private func emit(_ sdk: PersonalizationSDK, state: Rees46.SdkState? = nil) {
    let snapshot = Self.snapshot(sdk, state: state)
    onMain { [stateApi] in stateApi.onSnapshot(snapshot: snapshot) { _ in } }
  }

  private func emitAll() {
    lock.lock()
    let shopIds = Array(subscriptions.keys)
    lock.unlock()
    for shopId in shopIds {
      if let sdk = try? Rees46.instance(for: shopId) {
        emit(sdk)
      }
    }
  }

  /// The shop's state as Dart mirrors it.
  static func snapshot(_ sdk: PersonalizationSDK, state: Rees46.SdkState? = nil) -> SdkSnapshotWire {
    let notifications = sdk.notifications
    let tokens = [Rees46.PushProvider.apns, .fcm].compactMap { notifications.getPushToken(provider: $0) }
    return SdkSnapshotWire(
      shopId: sdk.shopId,
      state: (state ?? sdk.state).rawValue,
      deviceId: nonEmpty(sdk.deviceId),
      sessionId: nonEmpty(sdk.sessionId),
      segment: nonEmpty(sdk.segment),
      agentEnabled: sdk.search.agentEnabled,
      pushToken: notifications.getPushToken(provider: nil)?.toWire(),
      pushTokens: tokens.map { $0.toWire() }
    )
  }

  /// The API's host: the SDK takes a host only, so a scheme and a trailing slash go, as on Android.
  static func apiHost(_ domain: String) -> String? {
    var host = domain.trimmingCharacters(in: .whitespacesAndNewlines)
    if let scheme = host.range(of: "^https?://", options: [.regularExpression, .caseInsensitive]) {
      host.removeSubrange(scheme)
    }
    while host.hasSuffix("/") { host.removeLast() }
    return host.isEmpty ? nil : host
  }

  // MARK: - Calls

  /// Calls a namespace method of the shop's instance and answers Dart on the main thread: the value
  /// as `map` makes it, or the native error.
  private func call<Value, Wire>(
    _ shopId: String?,
    _ completion: @escaping (Result<Wire, Error>) -> Void,
    map: @escaping (Value) -> Wire,
    _ body: (PersonalizationSDK, @escaping (Result<Value, Rees46.SdkError>) -> Void) throws -> Void
  ) {
    let finish: (Result<Value, Rees46.SdkError>) -> Void = { result in
      onMain {
        switch result {
        case .success(let value): completion(.success(map(value)))
        case .failure(let error): completion(.failure(BridgeFailure.error(error)))
        }
      }
    }
    do {
      try body(try instance(shopId), finish)
    } catch {
      let failure = BridgeFailure.error(error)
      onMain { completion(.failure(failure)) }
    }
  }

  /// `call` for a method with no value.
  private func run(
    _ shopId: String?,
    _ completion: @escaping (Result<Void, Error>) -> Void,
    _ body: (PersonalizationSDK, @escaping (Result<Void, Rees46.SdkError>) -> Void) throws -> Void
  ) {
    call(shopId, completion, map: { $0 }, body)
  }

  /// A `tracking` call, whose completion carries the SDK's old error: the whole error behind it is
  /// read on the thread the SDK answers on, before the answer goes to the main thread.
  private func track(
    _ shopId: String?,
    _ completion: @escaping (Result<Void, Error>) -> Void,
    _ body: (TrackingAPI, @escaping (Result<Void, LegacySdkError>) -> Void) throws -> Void
  ) {
    let finish: (Result<Void, LegacySdkError>) -> Void = { result in
      let mapped: Result<Void, Error> = result.mapError { BridgeFailure.error(legacy: $0) }
      onMain { completion(mapped) }
    }
    do {
      try body(try instance(shopId).tracking, finish)
    } catch {
      let failure = BridgeFailure.error(error)
      onMain { completion(.failure(failure)) }
    }
  }

  // MARK: - Root

  func initialize(config: InitConfig, completion: @escaping (Result<SdkSnapshotWire, Error>) -> Void) {
    let shopId = config.shopId.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !shopId.isEmpty else {
      completion(.failure(BridgeFailure.error(.invalidArgument("shopId must not be empty"))))
      return
    }
    // The bridges' entry: the new core. Flutter kept no A/B group of its own — the native SDK kept it,
    // and the new core takes it from its storage — so none is handed over.
    var sdk = Rees46.initializeBridge(
      Rees46Config(
        shopId: shopId,
        apiDomain: Self.apiHost(config.apiDomain) ?? "api.rees46.ru",
        stream: config.stream,
        enableLogs: config.enableLogs,
        autoSendPushToken: config.autoSendPushToken,
        sendAdvertisingId: config.sendAdvertisingId,
        enableAutoPopupPresentation: config.enableAutoPopupPresentation,
        needReInitialization: config.needReInitialization
      ),
      segment: nil
    )

    // Dart draws popups with the UI kit: every popup is kept back from the native SDK
    // (nil — not shown, not reported, not remembered) and handed over. Dart decides
    // whether to show it, and reports it once it is on screen.
    let forwarder = PopupForwarder(shopId: shopId, api: popupApi)
    lock.lock()
    popupForwarders[shopId] = forwarder
    lock.unlock()
    sdk.popupPresentationDelegate = forwarder

    // Kept for the AppDelegate push path (device token / remote notification).
    Rees46FlutterSdkPlugin.sdk = sdk

    // The notification service asks for notification permission as it is created and sends the
    // device token it gets, so it is created only for a shop that sends the token itself, as the
    // native SDK asks for permission only then. Otherwise the app asks and sends the token.
    if config.autoSendPushToken {
      Rees46FlutterSdkPlugin.notificationService = NotificationService(
        sdk: sdk,
        notificationLogger: NotificationLogger()
      )
    }

    subscribe(sdk)
    completion(.success(Self.snapshot(sdk)))
  }

  func getPlatformVersion() throws -> String {
    return "iOS " + UIDevice.current.systemVersion
  }

  func getSnapshot(shopId: String?) throws -> SdkSnapshotWire {
    Self.snapshot(try instance(shopId))
  }

  func getSid(shopId: String?) throws -> String {
    try instance(shopId).sessionId ?? ""
  }

  func getDid(shopId: String?) throws -> String? {
    (try? instance(shopId))?.deviceId
  }

  // MARK: - Tracking
  //
  // Each method goes to the native `tracking` namespace of the shop's instance. On the new core its
  // completion comes once the queue took the event.

  func trackEvent(
    event: String,
    time: Int64?,
    category: String?,
    label: String?,
    value: Int64?,
    customFields: [String: Any?]?,
    shopId: String?,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    track(shopId, completion) { tracking, done in
      tracking.custom(
        event: event,
        time: try time.map(nativeInt),
        category: category,
        label: label,
        value: try value.map(nativeInt),
        customFields: customFields.map(nativeObject),
        completion: done
      )
    }
  }

  func trackProductView(itemId: String, source: TrackingSourceWire?, shopId: String?, completion: @escaping (Result<Void, Error>) -> Void) {
    track(shopId, completion) { tracking, done in
      tracking.productView(itemId: itemId, source: try Self.source(source), completion: done)
    }
  }

  func trackCategoryView(categoryId: String, shopId: String?, completion: @escaping (Result<Void, Error>) -> Void) {
    track(shopId, completion) { tracking, done in
      tracking.categoryView(categoryId: categoryId, completion: done)
    }
  }

  func trackSearch(query: String, results: [String]?, shopId: String?, completion: @escaping (Result<Void, Error>) -> Void) {
    track(shopId, completion) { tracking, done in
      tracking.search(query: query, results: results, completion: done)
    }
  }

  func trackAddToCart(item: TrackingItemWire, source: TrackingSourceWire?, shopId: String?, completion: @escaping (Result<Void, Error>) -> Void) {
    track(shopId, completion) { tracking, done in
      tracking.addToCart(item: item.native, source: try Self.source(source), completion: done)
    }
  }

  func trackSyncCart(items: [TrackingItemWire], shopId: String?, completion: @escaping (Result<Void, Error>) -> Void) {
    track(shopId, completion) { tracking, done in
      tracking.syncCart(items: items.map(\.native), completion: done)
    }
  }

  func trackRemoveFromCart(itemId: String, shopId: String?, completion: @escaping (Result<Void, Error>) -> Void) {
    track(shopId, completion) { tracking, done in
      tracking.removeFromCart(itemId: itemId, completion: done)
    }
  }

  func trackAddToFavorites(itemId: String, source: TrackingSourceWire?, shopId: String?, completion: @escaping (Result<Void, Error>) -> Void) {
    track(shopId, completion) { tracking, done in
      tracking.addToFavorites(itemId: itemId, source: try Self.source(source), completion: done)
    }
  }

  func trackSyncFavorites(itemIds: [String], shopId: String?, completion: @escaping (Result<Void, Error>) -> Void) {
    track(shopId, completion) { tracking, done in
      tracking.syncFavorites(itemIds: itemIds, completion: done)
    }
  }

  func trackRemoveFromFavorites(itemId: String, shopId: String?, completion: @escaping (Result<Void, Error>) -> Void) {
    track(shopId, completion) { tracking, done in
      tracking.removeFromFavorites(itemId: itemId, completion: done)
    }
  }

  func trackStoryView(storyId: String, slideId: String, code: String?, shopId: String?, completion: @escaping (Result<Void, Error>) -> Void) {
    track(shopId, completion) { tracking, done in
      tracking.storyView(storyId: storyId, slideId: slideId, code: code, completion: done)
    }
  }

  func trackStoryClick(storyId: String, slideId: String, code: String?, shopId: String?, completion: @escaping (Result<Void, Error>) -> Void) {
    track(shopId, completion) { tracking, done in
      tracking.storyClick(storyId: storyId, slideId: slideId, code: code, completion: done)
    }
  }

  func trackBannerView(bannerId: String, code: String, shopId: String?, completion: @escaping (Result<Void, Error>) -> Void) {
    run(shopId, completion) { sdk, done in
      sdk.tracking.bannerView(bannerId: bannerId, code: code, completion: done)
    }
  }

  func trackBannerClick(bannerId: String, code: String, shopId: String?, completion: @escaping (Result<Void, Error>) -> Void) {
    run(shopId, completion) { sdk, done in
      sdk.tracking.bannerClick(bannerId: bannerId, code: code, completion: done)
    }
  }

  func trackSetSource(source: TrackingSourceWire, shopId: String?) throws {
    let sdk = try instance(shopId)
    guard let native = source.native else {
      throw BridgeFailure.error(.invalidArgument("unknown source type: \(source.type)"))
    }
    sdk.tracking.setSource(native)
  }

  func trackPurchase(
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
    custom: [String: Any?]?,
    recommendedSource: [String: Any?]?,
    stream: String?,
    segment: String?,
    shopId: String?,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    let request = PurchaseTrackingRequest(
      orderId: orderId,
      orderPrice: orderPrice,
      items: items.map(\.native),
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
      custom: custom.map(nativeObject),
      recommendedSource: recommendedSource.map(nativeObject),
      stream: stream,
      segment: segment,
      isGiftPackage: isGiftPackage
    )
    // No per-call source: Dart only stores one through `setSource`, which the SDK attaches itself.
    track(shopId, completion) { tracking, done in
      tracking.purchase(request, source: nil, completion: done)
    }
  }

  func trackPopupShown(popupId: Int64, shopId: String?, completion: @escaping (Result<Void, Error>) -> Void) {
    run(shopId, completion) { sdk, done in
      sdk.tracking.popupShown(popupId: try nativeInt(popupId), completion: done)
    }
  }

  /// A source Dart sent: none, or one the native SDK knows; an unknown type is refused.
  private static func source(_ wire: TrackingSourceWire?) throws -> TrackingSource? {
    guard let wire = wire else { return nil }
    guard let native = wire.native else {
      throw BridgeFailure.invalidArgument("unknown source type: \(wire.type)")
    }
    return native
  }

  // MARK: - products, collections, recommendations

  func productsGetInfo(itemId: String, shopId: String?, completion: @escaping (Result<ProductWire?, Error>) -> Void) {
    call(shopId, completion, map: { $0?.toWire() }) { sdk, done in
      sdk.products.getInfo(itemId: itemId, completion: done)
    }
  }

  func productsGetList(request: ProductsListRequestWire, shopId: String?, completion: @escaping (Result<ProductsListResponseWire, Error>) -> Void) {
    call(shopId, completion, map: { $0.toWire() }) { sdk, done in
      sdk.products.getList(try request.native(), completion: done)
    }
  }

  func productsGetCounters(itemId: String, shopId: String?, completion: @escaping (Result<ProductCountersResponseWire, Error>) -> Void) {
    call(shopId, completion, map: { $0.toWire() }) { sdk, done in
      sdk.products.getCounters(itemId: itemId, completion: done)
    }
  }

  func productsGetCategory(categoryId: String, request: ProductsListRequestWire, shopId: String?, completion: @escaping (Result<ProductsListResponseWire, Error>) -> Void) {
    call(shopId, completion, map: { $0.toWire() }) { sdk, done in
      sdk.products.getCategory(categoryId: categoryId, request: try request.nativeCategory(), completion: done)
    }
  }

  func collectionsGet(collectionId: String, shopId: String?, completion: @escaping (Result<CollectionResponseWire, Error>) -> Void) {
    call(shopId, completion, map: { $0.toWire() }) { sdk, done in
      sdk.collections.get(collectionId: collectionId, completion: done)
    }
  }

  func recommendationsGet(code: String, request: RecommendationRequestWire, shopId: String?, completion: @escaping (Result<RecommendationResponseWire, Error>) -> Void) {
    call(shopId, completion, map: { $0.toWire() }) { sdk, done in
      sdk.recommendations.get(code: code, request: try request.native(), completion: done)
    }
  }

  // MARK: - search

  func searchAgentEnabled(shopId: String?) throws -> Bool {
    try instance(shopId).search.agentEnabled
  }

  func searchBlank(shopId: String?, completion: @escaping (Result<SearchBlankResponseWire, Error>) -> Void) {
    call(shopId, completion, map: { $0.toWire() }) { sdk, done in
      sdk.search.blank(completion: done)
    }
  }

  func searchInstant(query: String, locations: [String]?, excludedMerchants: [String]?, excludedBrands: [String]?, shopId: String?, completion: @escaping (Result<SearchInstantResponseWire, Error>) -> Void) {
    call(shopId, completion, map: { $0.toWire() }) { sdk, done in
      sdk.search.instant(
        query: query,
        locations: locations,
        excludedMerchants: excludedMerchants,
        excludedBrands: excludedBrands,
        completion: done
      )
    }
  }

  func searchFull(query: String, request: SearchFullRequestWire, shopId: String?, completion: @escaping (Result<SearchFullResponseWire, Error>) -> Void) {
    call(shopId, completion, map: { $0.toWire() }) { sdk, done in
      sdk.search.full(query: query, request: try request.native(), completion: done)
    }
  }

  func searchAgentDialog(sessionId: Int64?, locations: [String]?, shopId: String?, completion: @escaping (Result<AgentDialogResponseWire, Error>) -> Void) {
    call(shopId, completion, map: { $0.toWire() }) { sdk, done in
      sdk.search.agentDialog(sessionId: try sessionId.map(nativeInt), locations: locations, completion: done)
    }
  }

  func searchAgent(message: String, sessionId: Int64?, locations: [String]?, shopId: String?, completion: @escaping (Result<AgentResponseWire, Error>) -> Void) {
    call(shopId, completion, map: { $0.toWire() }) { sdk, done in
      sdk.search.agent(message: message, sessionId: try sessionId.map(nativeInt), locations: locations, completion: done)
    }
  }

  // MARK: - cart, profile

  func cartGet(shopId: String?, completion: @escaping (Result<[CartItemWire], Error>) -> Void) {
    call(shopId, completion, map: { $0.map { $0.toWire() } }) { sdk, done in
      sdk.cart.get(completion: done)
    }
  }

  func cartClear(shopSecret: String, email: String?, phone: String?, loyaltyId: String?, externalId: String?, telegramId: String?, shopId: String?, completion: @escaping (Result<Void, Error>) -> Void) {
    run(shopId, completion) { sdk, done in
      sdk.cart.clear(
        shopSecret: shopSecret,
        email: email,
        phone: phone,
        loyaltyId: loyaltyId,
        externalId: externalId,
        telegramId: telegramId,
        completion: done
      )
    }
  }

  func profileGet(shopId: String?, completion: @escaping (Result<ProfileWire, Error>) -> Void) {
    call(shopId, completion, map: { $0.toWire() }) { sdk, done in
      sdk.profile.get(completion: done)
    }
  }

  func profileSet(request: ProfileUpdateRequestWire, shopId: String?, completion: @escaping (Result<Void, Error>) -> Void) {
    run(shopId, completion) { sdk, done in
      sdk.profile.set(try request.native(), completion: done)
    }
  }

  func profileGetLastOrder(shopId: String?, completion: @escaping (Result<[ProductWire], Error>) -> Void) {
    call(shopId, completion, map: { $0.map { $0.toWire() } }) { sdk, done in
      sdk.profile.getLastOrder(completion: done)
    }
  }

  func profileGetOrders(shopSecret: String, did: String?, email: String?, phone: String?, loyaltyId: String?, externalId: String?, dateFrom: String?, shopId: String?, completion: @escaping (Result<[OrderWire], Error>) -> Void) {
    call(shopId, completion, map: { $0.map { $0.toWire() } }) { sdk, done in
      sdk.profile.getOrders(
        shopSecret: shopSecret,
        did: did,
        email: email,
        phone: phone,
        loyaltyId: loyaltyId,
        externalId: externalId,
        dateFrom: dateFrom,
        completion: done
      )
    }
  }

  // MARK: - subscriptions, segments

  func subscriptionsManage(request: SubscriptionsUpdateRequestWire, shopId: String?, completion: @escaping (Result<Void, Error>) -> Void) {
    run(shopId, completion) { sdk, done in
      sdk.subscriptions.manage(request.native, completion: done)
    }
  }

  func subscriptionsCheck(shopId: String?, completion: @escaping (Result<SubscriptionStatusWire, Error>) -> Void) {
    call(shopId, completion, map: { $0.toWire() }) { sdk, done in
      sdk.subscriptions.check(completion: done)
    }
  }

  func subscriptionsSubscribeForPriceDrop(itemId: String, currentPrice: Double, email: String?, phone: String?, shopId: String?, completion: @escaping (Result<Void, Error>) -> Void) {
    run(shopId, completion) { sdk, done in
      sdk.subscriptions.subscribeForPriceDrop(itemId: itemId, currentPrice: currentPrice, email: email, phone: phone, completion: done)
    }
  }

  func subscriptionsUnsubscribeFromPriceDrop(itemIds: [String], email: String?, phone: String?, shopId: String?, completion: @escaping (Result<Void, Error>) -> Void) {
    run(shopId, completion) { sdk, done in
      sdk.subscriptions.unsubscribeFromPriceDrop(itemIds: itemIds, email: email, phone: phone, completion: done)
    }
  }

  func subscriptionsSubscribeForBackInStock(itemId: String, properties: BackInStockPropertiesWire?, email: String?, phone: String?, shopId: String?, completion: @escaping (Result<Void, Error>) -> Void) {
    run(shopId, completion) { sdk, done in
      sdk.subscriptions.subscribeForBackInStock(
        itemId: itemId,
        properties: properties?.native,
        email: email,
        phone: phone,
        completion: done
      )
    }
  }

  func subscriptionsUnsubscribeFromBackInStock(itemIds: [String], email: String?, phone: String?, shopId: String?, completion: @escaping (Result<Void, Error>) -> Void) {
    run(shopId, completion) { sdk, done in
      sdk.subscriptions.unsubscribeFromBackInStock(itemIds: itemIds, email: email, phone: phone, completion: done)
    }
  }

  func segmentsAdd(segmentId: Int64, email: String?, phone: String?, shopId: String?, completion: @escaping (Result<Void, Error>) -> Void) {
    run(shopId, completion) { sdk, done in
      sdk.segments.add(segmentId: try nativeInt(segmentId), email: email, phone: phone, completion: done)
    }
  }

  func segmentsRemove(segmentId: Int64, email: String?, phone: String?, shopId: String?, completion: @escaping (Result<Void, Error>) -> Void) {
    run(shopId, completion) { sdk, done in
      sdk.segments.remove(segmentId: try nativeInt(segmentId), email: email, phone: phone, completion: done)
    }
  }

  func segmentsGet(shopId: String?, completion: @escaping (Result<[SegmentWire], Error>) -> Void) {
    call(shopId, completion, map: { $0.map { $0.toWire() } }) { sdk, done in
      sdk.segments.get(completion: done)
    }
  }

  // MARK: - notifications

  func notificationsTrackDelivered(code: String, type: String, shopId: String?, completion: @escaping (Result<Void, Error>) -> Void) {
    run(shopId, completion) { sdk, done in
      sdk.notifications.trackDelivered(code: code, type: type, completion: done)
    }
  }

  func notificationsTrackOpened(code: String, type: String, shopId: String?, completion: @escaping (Result<Void, Error>) -> Void) {
    run(shopId, completion) { sdk, done in
      sdk.notifications.trackOpened(code: code, type: type, completion: done)
    }
  }

  func notificationsTrackClicked(code: String, type: String, shopId: String?, completion: @escaping (Result<Void, Error>) -> Void) {
    run(shopId, completion) { sdk, done in
      sdk.notifications.trackClicked(code: code, type: type, completion: done)
    }
  }

  func notificationsTrackClosed(code: String, type: String, shopId: String?, completion: @escaping (Result<Void, Error>) -> Void) {
    run(shopId, completion) { sdk, done in
      sdk.notifications.trackClosed(code: code, type: type, completion: done)
    }
  }

  /// The token the SDK keeps for the shop. An app that sends the token itself (`autoSendPushToken:
  /// false`) gave the SDK none: then, without a provider or for APNs, the device token the plugin
  /// kept is the answer, as `getStoredPushToken` always gave it.
  func notificationsGetPushToken(provider: String?, shopId: String?) throws -> PushTokenWire? {
    // A synchronous call hands Dart what it throws as it is: only a `PigeonError` keeps its type.
    let native: Rees46.PushProvider?
    do {
      native = try provider.map(nativePushProvider)
    } catch {
      throw BridgeFailure.error(error)
    }
    if let token = try instance(shopId).notifications.getPushToken(provider: native) {
      return token.toWire()
    }
    guard native == nil || native == .apns,
          let deviceToken = UserDefaults.standard.data(forKey: Rees46FlutterSdkPlugin.pushTokenKey) else {
      return nil
    }
    let hex = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    return hex.isEmpty ? nil : PushTokenWire(token: hex, provider: Rees46.PushProvider.apns.rawValue)
  }

  func notificationsSetPushToken(token: String, provider: String, shopId: String?, completion: @escaping (Result<Void, Error>) -> Void) {
    run(shopId, completion) { sdk, done in
      sdk.notifications.setPushToken(token, provider: try nativePushProvider(provider), completion: done)
    }
  }

  func notificationsGetHistory(shopSecret: String, type: String, phone: String?, email: String?, externalId: String?, loyaltyId: String?, channel: String?, limit: Int64?, page: Int64?, dateFrom: String?, did: String?, shopId: String?, completion: @escaping (Result<NotificationHistoryWire, Error>) -> Void) {
    call(shopId, completion, map: { $0.toWire() }) { sdk, done in
      sdk.notifications.getHistory(
        shopSecret: shopSecret,
        type: type,
        phone: phone,
        email: email,
        externalId: externalId,
        loyaltyId: loyaltyId,
        channel: channel,
        limit: try limit.map(nativeInt),
        page: try page.map(nativeInt),
        dateFrom: dateFrom,
        did: did,
        completion: done
      )
    }
  }

  func handlePush(payload: [String: String], event: Int64, completion: @escaping (Result<Void, Error>) -> Void) {
    guard let native = Self.pushEvent(event) else {
      completion(.failure(BridgeFailure.error(.invalidArgument("unknown push event: \(event)"))))
      return
    }
    Rees46.handlePush(payload as [AnyHashable: Any], event: native)
    completion(.success(()))
  }

  /// The index of Dart's `PushEvent`: `received` is the native `delivered`, Dart's `delivered` (the
  /// notification is on screen) the native `opened`, `clicked` the same.
  static func pushEvent(_ index: Int64) -> Rees46.PushEvent? {
    switch index {
    case 0: return .delivered
    case 1: return .opened
    case 2: return .clicked
    default: return nil
    }
  }

  // MARK: - stories, predict, loyalty, sliders

  func storiesGet(code: String, shopId: String?, completion: @escaping (Result<StoriesBlockWire, Error>) -> Void) {
    call(shopId, completion, map: { $0.toWire() }) { sdk, done in
      sdk.stories.get(code: code, completion: done)
    }
  }

  func predictGetProbabilityToPurchase(shopId: String?, completion: @escaping (Result<PurchaseProbabilityWire, Error>) -> Void) {
    call(shopId, completion, map: { $0.toWire() }) { sdk, done in
      sdk.predict.getProbabilityToPurchase(completion: done)
    }
  }

  func loyaltyJoin(phone: String, firstName: String?, lastName: String?, gender: String?, birthday: String?, shopId: String?, completion: @escaping (Result<LoyaltyMemberWire, Error>) -> Void) {
    call(shopId, completion, map: { $0.toWire() }) { sdk, done in
      sdk.loyalty.join(
        phone: phone,
        firstName: firstName,
        lastName: lastName,
        gender: try gender.map(nativeGender),
        birthday: birthday,
        completion: done
      )
    }
  }

  func loyaltyGetStatus(phone: String, shopId: String?, completion: @escaping (Result<LoyaltyStatusWire, Error>) -> Void) {
    call(shopId, completion, map: { $0.toWire() }) { sdk, done in
      sdk.loyalty.getStatus(phone: phone, completion: done)
    }
  }

  func loyaltyGetPromotions(locationId: String?, promoCodes: [String]?, chargeBonuses: Bool?, currentTime: String?, shopId: String?, completion: @escaping (Result<[LoyaltyPromotionWire], Error>) -> Void) {
    call(shopId, completion, map: { $0.map { $0.toWire() } }) { sdk, done in
      sdk.loyalty.getPromotions(
        locationId: locationId,
        promoCodes: promoCodes,
        chargeBonuses: chargeBonuses,
        currentTime: currentTime,
        completion: done
      )
    }
  }

  func slidersGet(code: String, tags: [String]?, locationId: String?, shopId: String?, completion: @escaping (Result<SliderWire, Error>) -> Void) {
    call(shopId, completion, map: { $0.toWire() }) { sdk, done in
      sdk.sliders.get(code: code, tags: tags, locationId: locationId, completion: done)
    }
  }

  // MARK: - reviews

  func reviewsCreateNps(rate: Int64, channel: String, category: String, orderId: String?, comment: String?, label: String?, shopId: String?, completion: @escaping (Result<PollReviewWire, Error>) -> Void) {
    call(shopId, completion, map: { $0.toWire() }) { sdk, done in
      sdk.reviews.createNps(
        rate: try nativeInt(rate), channel: channel, category: category,
        orderId: orderId, comment: comment, label: label, completion: done
      )
    }
  }

  func reviewsCreateCsat(rate: Int64, channel: String, campaign: String, orderId: String?, comment: String?, label: String?, shopId: String?, completion: @escaping (Result<PollReviewWire, Error>) -> Void) {
    call(shopId, completion, map: { $0.toWire() }) { sdk, done in
      sdk.reviews.createCsat(
        rate: try nativeInt(rate), channel: channel, campaign: campaign,
        orderId: orderId, comment: comment, label: label, completion: done
      )
    }
  }

  func reviewsCreateCes(rate: Int64, channel: String, campaign: String, orderId: String?, comment: String?, label: String?, shopId: String?, completion: @escaping (Result<PollReviewWire, Error>) -> Void) {
    call(shopId, completion, map: { $0.toWire() }) { sdk, done in
      sdk.reviews.createCes(
        rate: try nativeInt(rate), channel: channel, campaign: campaign,
        orderId: orderId, comment: comment, label: label, completion: done
      )
    }
  }

  func reviewsGetNpsCategories(shopId: String?, completion: @escaping (Result<[NpsCategoryWire], Error>) -> Void) {
    call(shopId, completion, map: { $0.map { $0.toWire() } }) { sdk, done in
      sdk.reviews.getNpsCategories(completion: done)
    }
  }

  func reviewsGetNpsChannels(shopId: String?, completion: @escaping (Result<[PollChannelWire], Error>) -> Void) {
    call(shopId, completion, map: { $0.map { $0.toWire() } }) { sdk, done in
      sdk.reviews.getNpsChannels(completion: done)
    }
  }

  func reviewsGetCsatCampaigns(shopId: String?, completion: @escaping (Result<[CsatCampaignWire], Error>) -> Void) {
    call(shopId, completion, map: { $0.map { $0.toWire() } }) { sdk, done in
      sdk.reviews.getCsatCampaigns(completion: done)
    }
  }

  func reviewsGetCesCampaigns(shopId: String?, completion: @escaping (Result<[CesCampaignWire], Error>) -> Void) {
    call(shopId, completion, map: { $0.map { $0.toWire() } }) { sdk, done in
      sdk.reviews.getCesCampaigns(completion: done)
    }
  }

  func reviewsGetProductReviews(itemId: String, limit: Int64?, offset: Int64?, shopId: String?, completion: @escaping (Result<ProductReviewsResponseWire, Error>) -> Void) {
    call(shopId, completion, map: { $0.toWire() }) { sdk, done in
      sdk.reviews.getProductReviews(
        itemId: itemId,
        limit: try limit.map(nativeInt),
        offset: try offset.map(nativeInt),
        completion: done
      )
    }
  }

  func reviewsGetClientReviews(orderId: String, shopId: String?, completion: @escaping (Result<[ClientReviewWire], Error>) -> Void) {
    call(shopId, completion, map: { $0.map { $0.toWire() } }) { sdk, done in
      sdk.reviews.getClientReviews(orderId: orderId, completion: done)
    }
  }

  // MARK: - UI plumbing (the kit's own needs, not the SDK contract)

  func openUrl(url: String, completion: @escaping (Result<Bool, Error>) -> Void) {
    guard let target = URL(string: url), target.scheme?.isEmpty == false else {
      completion(.success(false))
      return
    }
    DispatchQueue.main.async {
      UIApplication.shared.open(target, options: [:]) { opened in
        completion(.success(opened))
      }
    }
  }

  func shareUrl(
    url: String,
    anchorX: Double,
    anchorY: Double,
    anchorWidth: Double,
    anchorHeight: Double,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    guard let target = URL(string: url) else {
      completion(.failure(PigeonError(code: "bad_args", message: "invalid url", details: nil)))
      return
    }
    DispatchQueue.main.async {
      guard let presenter = Self._topViewController() else {
        completion(.failure(PigeonError(code: "share_failed", message: "no view controller to present from", details: nil)))
        return
      }
      let sheet = UIActivityViewController(activityItems: [target], applicationActivities: nil)
      // The handler may come more than once (an activity done, then the sheet gone): one reply.
      var replied = false
      sheet.completionWithItemsHandler = { _, _, _, _ in
        if replied { return }
        replied = true
        completion(.success(()))
      }
      // iPad shows the sheet as a popover, and a popover without a source crashes. The anchor
      // is the button in the Flutter view's points; without one the popover sits in the middle.
      if let popover = sheet.popoverPresentationController {
        let source = Self._flutterView() ?? presenter.view!
        let anchor = CGRect(x: anchorX, y: anchorY, width: anchorWidth, height: anchorHeight)
        popover.sourceView = source
        if anchor.isEmpty {
          popover.sourceRect = CGRect(x: source.bounds.midX, y: source.bounds.midY, width: 0, height: 0)
          popover.permittedArrowDirections = []
        } else {
          popover.sourceRect = anchor
        }
      }
      presenter.present(sheet, animated: true)
    }
  }

  /// The key window of the app.
  private static func _keyWindow() -> UIWindow? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    return scenes.flatMap { $0.windows }.first { $0.isKeyWindow }
      ?? (UIApplication.shared.delegate?.window ?? nil)
  }

  /// The controller on top of the key window: the one a sheet is presented from.
  private static func _topViewController() -> UIViewController? {
    var top = _keyWindow()?.rootViewController
    while let presented = top?.presentedViewController, !presented.isBeingDismissed {
      top = presented
    }
    return top
  }

  /// The view Flutter draws into: the coordinates Dart measures the anchor in.
  private static func _flutterView() -> UIView? {
    return (_keyWindow()?.rootViewController as? FlutterViewController)?.view
  }

  // MARK: - Stories viewer (UI kit)

  func getStoriesSeen(shop: String) throws -> [String: [Any?]] {
    return StoriesSeenStore.read(shop: shop).mapValues { $0 as [Any?] }
  }

  func setStorySlideSeen(shop: String, storyId: String, slideId: String) throws {
    StoriesSeenStore.add(shop: shop, storyId: storyId, slideId: slideId)
  }

  func getCacheDirectory() throws -> String {
    let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
    return (caches ?? FileManager.default.temporaryDirectory).path
  }

  func beginStoriesAudio() throws {
    StoriesAudio.shared.begin()
  }

  func updateStoriesAudio(muted: Bool) throws {
    StoriesAudio.shared.update(muted: muted)
  }

  func endStoriesAudio() throws {
    StoriesAudio.shared.end()
  }

  func openNotificationSettings() throws {
    // The app's notification settings where iOS has a link to them, its Settings page before.
    let target: String
    if #available(iOS 16.0, *) {
      target = UIApplication.openNotificationSettingsURLString
    } else {
      target = UIApplication.openSettingsURLString
    }
    guard let url = URL(string: target) else { return }
    DispatchQueue.main.async {
      UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
  }
}

/// Keeps every popup of one shop back from the native SDK and hands it to Dart.
final class PopupForwarder: PopupPresentationDelegate {
  private let shopId: String
  private let api: PersonalizationPopupFlutterApi

  init(shopId: String, api: PersonalizationPopupFlutterApi) {
    self.shopId = shopId
    self.api = api
  }

  func sdk(_ sdk: PersonalizationSDK, shouldPresentPopup popup: Popup) -> UIViewController? {
    if let json = Self.json(popup) {
      // The SDK asks from its own queue; the Pigeon channel is called on the main thread.
      DispatchQueue.main.async { [api, shopId] in
        api.onPopup(shopId: shopId, popupJson: json) { _ in }
      }
    }
    return nil
  }

  /// The popup as the server sends it. `Popup` carries `popup_actions` as a JSON string;
  /// it goes out as an object, like on Android.
  static func json(_ popup: Popup) -> String? {
    guard let data = try? JSONEncoder().encode(popup),
          var object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    else { return nil }
    if let actions = object["popup_actions"] as? String,
       let actionsData = actions.data(using: .utf8),
       let parsed = try? JSONSerialization.jsonObject(with: actionsData) {
      object["popup_actions"] = parsed
    }
    guard let out = try? JSONSerialization.data(withJSONObject: object) else { return nil }
    return String(data: out, encoding: .utf8)
  }
}

