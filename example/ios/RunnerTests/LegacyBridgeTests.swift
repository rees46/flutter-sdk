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

    /// The token 1.6.4 kept from the AppDelegate, as hex; none is nil.
    func test_storedPushToken_isTheDeviceTokenAsHex() throws {
        XCTAssertNil(try plugin.legacyGetStoredPushToken(shopId: shopId))

        UserDefaults.standard.set(Data([0x0a, 0xff, 0x01]), forKey: Rees46FlutterSdkPlugin.pushTokenKey)

        XCTAssertEqual(try plugin.legacyGetStoredPushToken(shopId: shopId), "0aff01")
    }
}
