import Flutter
import XCTest

@_spi(Bridge) @testable import REES46
@_spi(Bridge) @testable import rees46_sdk

/// The handle's deprecated methods go to the native SDK's released methods and answer with the JSON
/// 1.6.4 handed Dart, or fail with 1.6.4's error codes.
final class LegacyBridgeTests: XCTestCase {

    private let shopId = "legacy-shop"
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
        UserDefaults.standard.removeObject(forKey: Rees46FlutterSdkPlugin.pushTokenKey)
        super.tearDown()
    }

    private func code(_ result: Result<String, Error>) -> String? {
        if case .failure(let error) = result { return (error as? PigeonError)?.code }
        return nil
    }

    /// The recommendation block keeps the API's own `discount`, not the percent the namespace model holds.
    func test_recommendation_keepsTheApisDiscountAndOldPrice() {
        let response = RecommenderResponse(json: [
            "title": "Hits",
            "recommends": [[
                "id": "37", "name": "Kettle", "price": 900, "oldprice": 1000,
                "oldprice_formatted": "1 000 ₽", "discount": 15, "discount_percent": 10,
            ]],
        ])

        let dict = PersonalizationHostApiImpl._recommendationToDict(response)
        let product = (dict["recommends"] as? [[String: Any]])?.first

        XCTAssertEqual(dict["title"] as? String, "Hits")
        XCTAssertEqual(product?["discount"] as? Int, 15)
        XCTAssertNil(product?["discount_percent"])
        XCTAssertEqual(product?["oldprice"] as? Double, 1000)
        XCTAssertEqual(product?["oldprice_formatted"] as? String, "1 000 ₽")
    }

    func test_aShopTheRegistryDoesNotHave_isNotInitialized() {
        let done = expectation(description: "answered")
        done.expectedFulfillmentCount = 2
        var codes: [String?] = []

        plugin.legacyGetProductInfo(itemId: "37", shopId: "no-such-shop") { codes.append(self.code($0)); done.fulfill() }
        plugin.legacyJoinLoyalty(phone: "+7", email: nil, firstName: nil, lastName: nil, shopId: "no-such-shop") {
            codes.append(self.code($0)); done.fulfill()
        }

        wait(for: [done], timeout: 5)
        XCTAssertEqual(codes, ["not_initialized", "not_initialized"])
    }

    func test_anEmptyArgument_isBadArgs() {
        let done = expectation(description: "answered")
        done.expectedFulfillmentCount = 3
        var codes: [String?] = []

        plugin.legacyGetProductInfo(itemId: "", shopId: shopId) { codes.append(self.code($0)); done.fulfill() }
        plugin.legacySearchInstant(query: "", paramsJson: nil, shopId: shopId) { codes.append(self.code($0)); done.fulfill() }
        plugin.legacyJoinLoyalty(phone: "", email: nil, firstName: nil, lastName: nil, shopId: shopId) {
            codes.append(self.code($0)); done.fulfill()
        }

        wait(for: [done], timeout: 5)
        XCTAssertEqual(codes, ["bad_args", "bad_args", "bad_args"])
    }

    private func code(_ result: Result<Void, Error>) -> String? {
        if case .failure(let error) = result { return (error as? PigeonError)?.code }
        return nil
    }

    /// The released purchase goes to the shop's queue with its 1.6.4 request — the free-form source, stream
    /// and segment included — and answers once the queue took it, not once the server did.
    func test_trackPurchase_goesThroughTheQueue_andAnswersOnAcceptance() {
        let done = expectation(description: "answered")
        var result: Result<Void, Error>?

        plugin.legacyTrackPurchase(
            orderId: "o-1", orderPrice: 10, items: [PurchaseLineItemWire(id: "37", amount: 1, price: 10)],
            deliveryType: nil, deliveryAddress: nil, paymentType: nil, isTaxFree: false, isGiftPackage: true,
            promocode: nil, orderCash: nil, orderBonuses: nil, orderDelivery: nil, orderDiscount: nil, channel: nil,
            customJson: #"{"k":"v"}"#, recommendedSourceJson: #"{"from":"dynamic","code":"b"}"#,
            stream: "flutter", segment: "A", shopId: shopId
        ) {
            XCTAssertTrue(Thread.isMainThread)
            result = $0
            done.fulfill()
        }

        wait(for: [done], timeout: 5)
        XCTAssertNil(code(result!))
        let request = native.recordingTracking.purchases.first
        XCTAssertEqual(request?.orderId, "o-1")
        XCTAssertEqual(request?.isGiftPackage, true)
        XCTAssertEqual(request?.custom?["k"] as? String, "v")
        XCTAssertEqual(request?.recommendedSource?["from"] as? String, "dynamic")
        XCTAssertEqual(request?.segment, "A")
        XCTAssertNil(native.recordingTracking.purchaseSources.first ?? nil, "no source of its own")
    }

    func test_trackEvent_goesThroughTheQueue_andAnswersOnAcceptance() {
        let done = expectation(description: "answered")
        var result: Result<Void, Error>?

        plugin.legacyTrackEvent(
            event: "signup", time: 1_700_000_000, category: "c", label: nil, value: 5,
            customFieldsJson: #"{"plan":"pro"}"#, shopId: shopId
        ) {
            result = $0
            done.fulfill()
        }

        wait(for: [done], timeout: 5)
        XCTAssertNil(code(result!))
        let custom = native.recordingTracking.customs.first
        XCTAssertEqual(custom?.event, "signup")
        XCTAssertEqual(custom?.time, 1_700_000_000)
        XCTAssertEqual(custom?.value, 5)
        XCTAssertEqual(custom?.customFields?["plan"] as? String, "pro")
    }

    /// An event the queue refuses fails with 1.6.4's codes; an empty argument is `bad_args` before it.
    func test_aRefusedEvent_keepsTheReleasedCodes() {
        native.recordingTracking.answer = .failure(.custom(error: "refused"))
        let done = expectation(description: "answered")
        done.expectedFulfillmentCount = 4
        var codes: [String: String?] = [:]

        plugin.legacyTrackPurchase(
            orderId: "o-1", orderPrice: 10, items: [PurchaseLineItemWire(id: "37", amount: 1, price: 10)],
            deliveryType: nil, deliveryAddress: nil, paymentType: nil, isTaxFree: false, isGiftPackage: false,
            promocode: nil, orderCash: nil, orderBonuses: nil, orderDelivery: nil, orderDiscount: nil, channel: nil,
            customJson: nil, recommendedSourceJson: nil, stream: nil, segment: nil, shopId: shopId
        ) { codes["purchase"] = self.code($0); done.fulfill() }
        plugin.legacyTrackEvent(
            event: "e", time: nil, category: nil, label: nil, value: nil, customFieldsJson: nil, shopId: shopId
        ) { codes["event"] = self.code($0); done.fulfill() }
        plugin.legacyTrackPurchase(
            orderId: "o-1", orderPrice: 10, items: [],
            deliveryType: nil, deliveryAddress: nil, paymentType: nil, isTaxFree: false, isGiftPackage: false,
            promocode: nil, orderCash: nil, orderBonuses: nil, orderDelivery: nil, orderDiscount: nil, channel: nil,
            customJson: nil, recommendedSourceJson: nil, stream: nil, segment: nil, shopId: shopId
        ) { codes["no lines"] = self.code($0); done.fulfill() }
        plugin.legacyTrackEvent(
            event: "", time: nil, category: nil, label: nil, value: nil, customFieldsJson: nil, shopId: shopId
        ) { codes["no event"] = self.code($0); done.fulfill() }

        wait(for: [done], timeout: 5)
        XCTAssertEqual(codes["purchase"], "track_purchase_failed")
        XCTAssertEqual(codes["event"], "track_event_failed")
        XCTAssertEqual(codes["no lines"], "bad_args")
        XCTAssertEqual(codes["no event"], "bad_args")
        XCTAssertEqual(native.recordingTracking.purchases.count, 1, "the refused arguments never reach the queue")
    }

    /// The token 1.6.4 kept from the AppDelegate, as hex; none is nil.
    func test_storedPushToken_isTheDeviceTokenAsHex() throws {
        XCTAssertNil(try plugin.legacyGetStoredPushToken(shopId: shopId))

        UserDefaults.standard.set(Data([0x0a, 0xff, 0x01]), forKey: Rees46FlutterSdkPlugin.pushTokenKey)

        XCTAssertEqual(try plugin.legacyGetStoredPushToken(shopId: shopId), "0aff01")
    }
}
