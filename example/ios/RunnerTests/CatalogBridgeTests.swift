import Flutter
import UIKit
import XCTest

@testable import REES46
@testable import rees46_sdk

/// The catalog calls of the Swift bridge: which native call a Dart call reaches, and what of the
/// native answer reaches Dart.
final class CatalogBridgeTests: XCTestCase {

    private let shopId = "bridge-shop"
    private var native: RecordingSDK!
    private var plugin: PersonalizationHostApiImpl!

    override func setUp() {
        super.setUp()
        native = RecordingSDK(shopId: shopId)
        SdkRegistry.shared.register(shopId: shopId, sdk: native)
        plugin = PersonalizationHostApiImpl(popupApi: PersonalizationPopupFlutterApi(binaryMessenger: SilentMessenger()))
    }

    override func tearDown() {
        SdkRegistry.shared.reset()
        super.tearDown()
    }

    func test_instantSearch_isTheNativeSuggest_notTheFullSearch() {
        plugin.searchInstant(query: "shoes", paramsJson: #"{"locations":"msk","excluded_brands":["b1"]}"#, shopId: shopId) { _ in }

        XCTAssertEqual(native.suggestCalls.map(\.query), ["shoes"])
        XCTAssertEqual(native.suggestCalls.first?.locations, "msk")
        XCTAssertEqual(native.suggestCalls.first?.excludedBrands ?? [], ["b1"])
        XCTAssertTrue(native.searchQueries.isEmpty, "instant search went out as the full search")
    }

    func test_categoryAnswer_carriesTheFacetsAndThePriceRange() {
        let answer = CategoryResponse(json: [
            "products_total": 2,
            "products": [],
            "brands": [["name": "Acme", "count": 2]],
            "filters": ["Цвет": ["count": 2, "values": ["Красный": 2]]],
            "price_range": ["min": 100.0, "max": 900.0],
            "categories": [["id": "7", "name": "Обувь", "count": 2]],
        ])

        let dict = PersonalizationHostApiImpl._categoryResponseToDict(answer)

        let filters = dict["filters"] as? [String: [String: Any]]
        XCTAssertEqual(filters?["Цвет"]?["values"] as? [String: Int], ["Красный": 2])
        let priceRange = dict["price_range"] as? [String: Double]
        XCTAssertEqual(priceRange?["min"], 100)
        XCTAssertEqual(priceRange?["max"], 900)
        XCTAssertTrue(JSONSerialization.isValidJSONObject(dict))
    }
}

/// Takes the popup channel's messages and answers none: the catalog calls do not use it.
private final class SilentMessenger: NSObject, FlutterBinaryMessenger {
    func send(onChannel channel: String, message: Data?) {}
    func send(onChannel channel: String, message: Data?, binaryReply callback: FlutterBinaryReply? = nil) {}
    func setMessageHandlerOnChannel(_ channel: String, binaryMessageHandler handler: FlutterBinaryMessageHandler? = nil) -> FlutterBinaryMessengerConnection { 0 }
    func cleanUpConnection(_ connection: FlutterBinaryMessengerConnection) {}
}

/// A native SDK that records the search calls and answers none; the rest is a no-op.
private final class RecordingSDK: PersonalizationSDK {
    struct Suggest {
        let query: String
        let locations: String?
        let excludedBrands: [String]?
    }

    private(set) var suggestCalls: [Suggest] = []
    private(set) var searchQueries: [String] = []

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

    init(shopId: String) { self.shopId = shopId }

    func suggest(query: String, locations: String?, excludedMerchants: [String]?, excludedBrands: [String]?, timeOut: Double?, extended: String?, completion: @escaping (Result<SearchResponse, SdkError>) -> Void) {
        suggestCalls.append(Suggest(query: query, locations: locations, excludedBrands: excludedBrands))
    }

    func search(query: String, limit: Int?, offset: Int?, categoryLimit: Int?, brandLimit: Int?, categories: [Int]?, extended: String?, sortBy: String?, sortDir: String?, locations: String?, excludedMerchants: [String]?, excludedBrands: [String]?, brands: String?, filters: [String: Any]?, priceMin: Double?, priceMax: Double?, colors: [String]?, fashionSizes: [String]?, exclude: String?, email: String?, timeOut: Double?, disableClarification: Bool?, completion: @escaping (Result<SearchResponse, SdkError>) -> Void) {
        searchQueries.append(query)
    }

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
