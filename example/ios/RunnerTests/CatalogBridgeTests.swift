import Flutter
import UIKit
import XCTest

@_spi(Bridge) @testable import REES46
@_spi(Bridge) @testable import rees46_sdk

/// The host side of the channel: which shop a Dart call reaches, what a failure looks like to Dart,
/// and the state Dart mirrors. Offline: no instance here runs the new core or makes a request.
final class CatalogBridgeTests: XCTestCase {

    private let shopId = "bridge-shop"
    private var native: RecordingSDK!
    private var plugin: PersonalizationHostApiImpl!

    override func setUp() {
        super.setUp()
        native = RecordingSDK(shopId: shopId)
        SdkRegistry.shared.register(shopId: shopId, sdk: native)
        plugin = PersonalizationHostApiImpl(
            popupApi: PersonalizationPopupFlutterApi(binaryMessenger: SilentMessenger()),
            stateApi: PersonalizationStateFlutterApi(binaryMessenger: SilentMessenger())
        )
    }

    override func tearDown() {
        plugin.stop()
        SdkRegistry.shared.reset()
        super.tearDown()
    }

    func test_aShopTheBridgeDoesNotKnow_isNotInitialized() {
        let done = expectation(description: "answered")
        plugin.productsGetInfo(itemId: "37", shopId: "no-such-shop") { result in
            XCTAssertTrue(Thread.isMainThread, "Dart is answered on the main thread")
            guard case .failure(let error as PigeonError) = result else {
                return XCTFail("expected a failure, got \(result)")
            }
            XCTAssertEqual(error.code, "notInitialized")
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
    }

    func test_aNamespaceOfAnInstanceOffTheNewCore_failsAsTheNativeSdkSays() {
        let done = expectation(description: "answered")
        plugin.cartGet(shopId: shopId) { result in
            guard case .failure(let error as PigeonError) = result else {
                return XCTFail("expected a failure, got \(result)")
            }
            XCTAssertEqual(error.code, "notInitialized")
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
    }

    func test_aSyncCall_forAShopTheBridgeDoesNotKnow_throwsNotInitialized() {
        XCTAssertThrowsError(try plugin.getSid(shopId: "no-such-shop")) { error in
            XCTAssertEqual((error as? PigeonError)?.code, "notInitialized")
        }
        XCTAssertThrowsError(try plugin.getSnapshot(shopId: "no-such-shop"))
        XCTAssertNil(try plugin.getDid(shopId: "no-such-shop"))
    }

    func test_snapshot_mirrorsTheInstance() throws {
        let snapshot = try plugin.getSnapshot(shopId: shopId)

        XCTAssertEqual(snapshot.shopId, shopId)
        XCTAssertEqual(snapshot.state, "ready")
        XCTAssertEqual(snapshot.deviceId, "bridge-device")
        XCTAssertEqual(snapshot.segment, "A")
        XCTAssertFalse(snapshot.agentEnabled)
        XCTAssertNil(snapshot.pushToken, "an instance off the new core keeps no token for the bridge")
        XCTAssertEqual(snapshot.pushTokens, [])
    }

    func test_snapshot_ofANewDevice_hasNoDeviceIdAndTheGivenState() {
        native.deviceId = ""
        native.segment = ""

        let snapshot = PersonalizationHostApiImpl.snapshot(native, state: .retrying)

        XCTAssertEqual(snapshot.state, "retrying")
        XCTAssertNil(snapshot.deviceId, "an empty did is none")
        XCTAssertNil(snapshot.segment)
    }

    func test_initialize_withoutAShopId_isAnInvalidArgument() {
        let config = InitConfig(
            shopId: "  ", apiDomain: "api.rees46.ru", stream: "flutter", enableLogs: false,
            autoSendPushToken: false, sendAdvertisingId: false, enableAutoPopupPresentation: true,
            needReInitialization: false
        )
        var answer: Result<SdkSnapshotWire, Error>?

        plugin.initialize(config: config) { answer = $0 }

        guard case .failure(let error as PigeonError)? = answer else {
            return XCTFail("expected a failure, got \(String(describing: answer))")
        }
        XCTAssertEqual(error.code, "invalidArgument")
    }

    func test_apiHost_isAHostOnly() {
        XCTAssertEqual(PersonalizationHostApiImpl.apiHost("https://api.rees46.ru/"), "api.rees46.ru")
        XCTAssertEqual(PersonalizationHostApiImpl.apiHost("HTTP://api.test//"), "api.test")
        XCTAssertEqual(PersonalizationHostApiImpl.apiHost("api.test"), "api.test")
        XCTAssertNil(PersonalizationHostApiImpl.apiHost(" https:// "))
    }

    func test_dartPushEvents_areTheNativeOnes() {
        XCTAssertEqual(PersonalizationHostApiImpl.pushEvent(0), .delivered, "Dart's received")
        XCTAssertEqual(PersonalizationHostApiImpl.pushEvent(1), .opened, "Dart's delivered: on screen")
        XCTAssertEqual(PersonalizationHostApiImpl.pushEvent(2), .clicked)
        XCTAssertNil(PersonalizationHostApiImpl.pushEvent(3))
    }

    func test_handlePush_withAnUnknownEvent_isAnInvalidArgument() {
        var answer: Result<Void, Error>?

        plugin.handlePush(payload: ["id": "c", "type": "bulk"], event: 7) { answer = $0 }

        guard case .failure(let error as PigeonError)? = answer else {
            return XCTFail("expected a failure")
        }
        XCTAssertEqual(error.code, "invalidArgument")
    }

    func test_aResponseToANotification_isClickedOrClosed() {
        XCTAssertEqual(Rees46FlutterSdkPlugin.responseEvent(UNNotificationDefaultActionIdentifier), .clicked)
        XCTAssertEqual(Rees46FlutterSdkPlugin.responseEvent("carousel_next"), .clicked)
        XCTAssertEqual(Rees46FlutterSdkPlugin.responseEvent(UNNotificationDismissActionIdentifier), .closed)
    }

    func test_anUnknownPushProvider_isAnInvalidArgument() {
        XCTAssertThrowsError(try plugin.notificationsGetPushToken(provider: "gcm", shopId: shopId)) { error in
            XCTAssertEqual((error as? PigeonError)?.code, "invalidArgument")
        }
    }
}

/// Takes the channels' messages and answers none.
final class SilentMessenger: NSObject, FlutterBinaryMessenger {
    func send(onChannel channel: String, message: Data?) {}
    func send(onChannel channel: String, message: Data?, binaryReply callback: FlutterBinaryReply? = nil) {}
    func setMessageHandlerOnChannel(_ channel: String, binaryMessageHandler handler: FlutterBinaryMessageHandler? = nil) -> FlutterBinaryMessengerConnection { 0 }
    func cleanUpConnection(_ connection: FlutterBinaryMessengerConnection) {}
}

/// A native SDK that is not the SDK's own instance: its namespaces have no new core behind them. Its
/// `tracking` records what reaches it.
final class RecordingSDK: PersonalizationSDK {
    var shopId: String
    var deviceId = "bridge-device"
    var userSeance = "bridge-seance"
    var segment = "A"
    var storiesCode: String?
    let sessionQueue = SessionQueue(name: "bridge-tests")
    var parentViewController: UIViewController?
    var urlSession: URLSession = .shared
    var popupPresentationDelegate: PopupPresentationDelegate?
    var enableAutoPopupPresentation = false
    lazy var popupPresenter: PopupPresenter = PopupPresenter(sdk: self)
    let recordingTracking = RecordingTracking()
    var tracking: TrackingAPI { recordingTracking }

    init(shopId: String) { self.shopId = shopId }

    func suggest(query: String, locations: String?, excludedMerchants: [String]?, excludedBrands: [String]?, timeOut: Double?, extended: String?, completion: @escaping (Result<SearchResponse, SdkError>) -> Void) {}
    func search(query: String, limit: Int?, offset: Int?, categoryLimit: Int?, brandLimit: Int?, categories: [Int]?, extended: String?, sortBy: String?, sortDir: String?, locations: String?, excludedMerchants: [String]?, excludedBrands: [String]?, brands: String?, filters: [String: Any]?, priceMin: Double?, priceMax: Double?, colors: [String]?, fashionSizes: [String]?, exclude: String?, email: String?, timeOut: Double?, disableClarification: Bool?, completion: @escaping (Result<SearchResponse, SdkError>) -> Void) {}
    func postRequest(path: String, params: [String: Any], completion: @escaping (Result<[String: Any], SdkError>) -> Void) {}
    func getRequest(path: String, params: [String: String], _ isInit: Bool, completion: @escaping (Result<[String: Any], SdkError>) -> Void) {}
    func configureURLSession(configuration: URLSessionConfiguration) {}
    func generateString(array: [String]) -> String { "" }
    func trackPurchase(_ request: PurchaseTrackingRequest, recommendedBy: RecomendedBy?, completion: @escaping (Result<Void, SdkError>) -> Void) {}
    func trackSource(source: RecommendedByCase, code: String) {}
    func trackPopupShown(popupId: Int, completion: @escaping (Result<Void, SdkError>) -> Void) {}
    func getProductInfo(id: String, completion: @escaping (Result<ProductInfo, SdkError>) -> Void) {}
    func getLastOrderProducts(completion: @escaping (Result<LastOrderProductsResponse, SdkError>) -> Void) {}
    func getLoyaltyStatus(identifier: String, completion: @escaping (Result<LoyaltyStatusResponse, SdkError>) -> Void) {}
    func getProfile(completion: @escaping (Result<GetProfileResponse, SdkError>) -> Void) {}
    func getProductCounters(item: String, completion: @escaping (Result<ProductCountersResponse, SdkError>) -> Void) {}
    func getDeviceId() -> String { deviceId }
    func setParentViewController(controller: UIViewController, completion: @escaping () -> Void) {}
    func getNotificationWidget() -> NotificationWidget? { nil }
    func getSession() -> String { userSeance }
    func getCurrentSegment() -> String { segment }
    func getShopId() -> String { shopId }
    func searchBlank(completion: @escaping (Result<SearchBlankResponse, SdkError>) -> Void) {}
    func notificationDelivered(type: String, code: String, completion: @escaping (Result<Void, SdkError>) -> Void) {}
    func notificationReceived(type: String, code: String, completion: @escaping (Result<Void, SdkError>) -> Void) {}
    func getStories(code: String, completion: @escaping (Result<StoryContent, SdkError>) -> Void) {}
    func configuration() -> SdkConfiguration.Type { SdkConfiguration.self }
    func sendIDFARequest(idfa: UUID, completion: @escaping (Result<InitResponse, SdkError>) -> Void) {}
}

/// Records each tracking call and answers it with `answer`.
final class RecordingTracking: TrackingAPI {
    struct Custom {
        let event: String
        let time: Int?
        let value: Int?
        let customFields: [String: Any]?
    }

    var answer: Result<Void, SdkError> = .success(())
    private(set) var productViews: [(itemId: String, source: TrackingSource?)] = []
    private(set) var customs: [Custom] = []
    private(set) var purchases: [PurchaseTrackingRequest] = []
    private(set) var sources: [TrackingSource] = []

    func productView(itemId: String, source: TrackingSource?, completion: @escaping (Result<Void, SdkError>) -> Void) {
        productViews.append((itemId, source))
        completion(answer)
    }
    func categoryView(categoryId: String, completion: @escaping (Result<Void, SdkError>) -> Void) { completion(answer) }
    func search(query: String, results: [String]?, completion: @escaping (Result<Void, SdkError>) -> Void) { completion(answer) }
    func addToCart(item: TrackingItem, source: TrackingSource?, completion: @escaping (Result<Void, SdkError>) -> Void) { completion(answer) }
    func syncCart(items: [TrackingItem], completion: @escaping (Result<Void, SdkError>) -> Void) { completion(answer) }
    func removeFromCart(itemId: String, completion: @escaping (Result<Void, SdkError>) -> Void) { completion(answer) }
    func addToFavorites(itemId: String, source: TrackingSource?, completion: @escaping (Result<Void, SdkError>) -> Void) { completion(answer) }
    func syncFavorites(itemIds: [String], completion: @escaping (Result<Void, SdkError>) -> Void) { completion(answer) }
    func removeFromFavorites(itemId: String, completion: @escaping (Result<Void, SdkError>) -> Void) { completion(answer) }
    func storyView(storyId: String, slideId: String, code: String?, completion: @escaping (Result<Void, SdkError>) -> Void) { completion(answer) }
    func storyClick(storyId: String, slideId: String, code: String?, completion: @escaping (Result<Void, SdkError>) -> Void) { completion(answer) }
    func purchase(_ request: PurchaseTrackingRequest, source: TrackingSource?, completion: @escaping (Result<Void, SdkError>) -> Void) {
        purchases.append(request)
        completion(answer)
    }
    func custom(event: String, time: Int?, category: String?, label: String?, value: Int?, customFields: [String: Any]?, completion: @escaping (Result<Void, SdkError>) -> Void) {
        customs.append(Custom(event: event, time: time, value: value, customFields: customFields))
        completion(answer)
    }
    func setSource(_ source: TrackingSource) {
        sources.append(source)
    }
}
