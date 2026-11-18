import XCTest

@_spi(Bridge) @testable import REES46
@_spi(Bridge) @testable import rees46_sdk

/// The Swift side of the Flutter bridge: everything Dart sends arrives as a pigeon wire struct and
/// has to be turned into a native type. That conversion is where the bridge can silently drop or
/// mangle a value — a story source used to be dropped here — so it is pinned rather than trusted.
final class TrackingBridgeTests: XCTestCase {

    private let shopId = "tracking-shop"
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

    // MARK: - Items

    func test_item_carriesEveryFieldThroughUnchanged() {
        let wire = TrackingItemWire(id: "sku-1", quantity: 3, price: 49.9, fashionSize: "M")

        let native = wire.native

        XCTAssertEqual(native.id, "sku-1")
        XCTAssertEqual(native.quantity, 3)
        XCTAssertEqual(native.price, 49.9)
        XCTAssertEqual(native.fashionSize, "M")
    }

    func test_item_withoutOptionalFields_leavesThemNil() {
        let native = TrackingItemWire(id: "sku-1", quantity: 1).native

        XCTAssertEqual(native.id, "sku-1")
        XCTAssertEqual(native.quantity, 1)
        XCTAssertNil(native.price)
        XCTAssertNil(native.fashionSize)
    }

    /// Dart sends the quantity as Int64; the native model takes Int. Large values must not wrap.
    func test_item_quantity_survivesTheInt64Narrowing() {
        XCTAssertEqual(TrackingItemWire(id: "sku-1", quantity: 0).native.quantity, 0)
        XCTAssertEqual(TrackingItemWire(id: "sku-1", quantity: 1_000_000).native.quantity, 1_000_000)
    }

    // MARK: - Sources

    /// The wire values Dart's `TrackingSourceType` can send. Every one of them must resolve: this
    /// list failing is what a divergence between the Dart, Android and iOS enums looks like.
    private let wireValues = [
        "dynamic", "chain", "bulk", "transactional",
        "instant_search", "full_search", "stories", "web_push_digest",
    ]

    func test_everySourceTypeDartCanSend_resolvesToANativeOne() {
        for value in wireValues {
            let native = TrackingSourceWire(type: value, code: "block-1").native
            XCTAssertNotNil(native, "\(value) did not resolve — the bridge would drop it silently")
            XCTAssertEqual(native?.type.rawValue, value)
            XCTAssertEqual(native?.code, "block-1")
        }
    }

    /// `stories` has no case in the older `RecommendedByCase`, which is why the bridge used to drop
    /// a story source on the floor. It must survive now.
    func test_storiesSource_isNotDropped() {
        let native = TrackingSourceWire(type: "stories", code: "main_stories").native

        XCTAssertEqual(native?.type, .stories)
        XCTAssertEqual(native?.code, "main_stories")
    }

    func test_anUnknownSourceType_isDroppedRatherThanGuessed() {
        XCTAssertNil(TrackingSourceWire(type: "not_a_source", code: "x").native)
        XCTAssertNil(TrackingSourceWire(type: "", code: "x").native)
        XCTAssertNil(TrackingSourceWire(type: "DYNAMIC", code: "x").native, "matching is exact")
    }

    /// The native enum must not grow a case Dart cannot produce, or hosts get a source through one
    /// platform and not the other.
    func test_theNativeEnumHasNothingDartCannotSend() {
        let native: [TrackingSourceType] = [
            .dynamic, .chain, .bulk, .transactional,
            .instantSearch, .fullSearch, .stories, .webPushDigest,
        ]

        XCTAssertEqual(Set(native.map(\.rawValue)), Set(wireValues))
    }

    // MARK: - Calls

    func test_productView_reachesTheNativeTrackingWithItsSource() {
        let done = expectation(description: "answered")

        plugin.trackProductView(itemId: "37", source: TrackingSourceWire(type: "dynamic", code: "block"), shopId: shopId) { result in
            XCTAssertTrue(Thread.isMainThread)
            if case .failure(let error) = result { XCTFail("\(error)") }
            done.fulfill()
        }

        wait(for: [done], timeout: 5)
        XCTAssertEqual(native.recordingTracking.productViews.first?.itemId, "37")
        XCTAssertEqual(native.recordingTracking.productViews.first?.source?.type, .dynamic)
    }

    func test_anUnknownSourceOfAnEvent_isAnInvalidArgument_andNothingIsSent() {
        let done = expectation(description: "answered")

        plugin.trackProductView(itemId: "37", source: TrackingSourceWire(type: "nope", code: "x"), shopId: shopId) { result in
            guard case .failure(let error as PigeonError) = result else { return XCTFail("expected a failure") }
            XCTAssertEqual(error.code, "invalidArgument")
            done.fulfill()
        }

        wait(for: [done], timeout: 5)
        XCTAssertTrue(native.recordingTracking.productViews.isEmpty)
    }

    func test_custom_isTheNativeCustomEvent_withItsFreeFormFields() {
        let done = expectation(description: "answered")

        plugin.trackEvent(
            event: "signup", time: 1_700_000_000, category: "c", label: "l", value: 5,
            customFields: ["plan": "pro", "seats": Int64(3), "note": nil, "tags": ["a", nil] as [Any?]],
            shopId: shopId
        ) { _ in done.fulfill() }

        wait(for: [done], timeout: 5)
        let custom = native.recordingTracking.customs.first
        XCTAssertEqual(custom?.event, "signup")
        XCTAssertEqual(custom?.time, 1_700_000_000)
        XCTAssertEqual(custom?.value, 5)
        XCTAssertEqual(custom?.customFields?["plan"] as? String, "pro")
        XCTAssertEqual(custom?.customFields?["seats"] as? Int64, 3)
        XCTAssertTrue(custom?.customFields?["note"] is NSNull, "Dart's null goes as JSON null")
        XCTAssertTrue((custom?.customFields?["tags"] as? [Any])?.last is NSNull)
    }

    func test_purchase_isTheNativePurchaseRequest() {
        let done = expectation(description: "answered")

        plugin.trackPurchase(
            orderId: "o-1", orderPrice: 100, items: [PurchaseLineItemWire(id: "37", amount: 2, price: 50, lineId: "l-1")],
            deliveryType: "courier", deliveryAddress: nil, paymentType: "card", isTaxFree: true, isGiftPackage: true,
            promocode: "SALE", orderCash: 90, orderBonuses: 10, orderDelivery: nil, orderDiscount: nil, channel: "app",
            custom: ["k": "v"], recommendedSource: ["source": ["from": "dynamic", "code": "b"]],
            stream: nil, segment: nil, shopId: shopId
        ) { _ in done.fulfill() }

        wait(for: [done], timeout: 5)
        let request = native.recordingTracking.purchases.first
        XCTAssertEqual(request?.orderId, "o-1")
        XCTAssertEqual(request?.items.first?.amount, 2)
        XCTAssertEqual(request?.items.first?.lineId, "l-1")
        XCTAssertEqual(request?.isTaxFree, true)
        XCTAssertEqual(request?.isGiftPackage, true)
        XCTAssertEqual(request?.custom?["k"] as? String, "v")
        XCTAssertEqual((request?.recommendedSource?["source"] as? [String: Any])?["code"] as? String, "b")
    }

    func test_aFailedEvent_isTheWholeErrorOfTheNativeSdk() {
        native.recordingTracking.answer = .failure(.networkOfflineError)
        let done = expectation(description: "answered")

        plugin.trackCategoryView(categoryId: "7", shopId: shopId) { result in
            guard case .failure(let error as PigeonError) = result else { return XCTFail("expected a failure") }
            XCTAssertEqual(error.code, "network")
            done.fulfill()
        }

        wait(for: [done], timeout: 5)
    }

    func test_setSource_storesTheSource_andRefusesAnUnknownOne() throws {
        try plugin.trackSetSource(source: TrackingSourceWire(type: "chain", code: "c-1"), shopId: shopId)

        XCTAssertEqual(native.recordingTracking.sources.first?.type, .chain)
        XCTAssertThrowsError(try plugin.trackSetSource(source: TrackingSourceWire(type: "?", code: "c"), shopId: shopId)) { error in
            XCTAssertEqual((error as? PigeonError)?.code, "invalidArgument")
        }
    }

    func test_anEventOfAShopTheBridgeDoesNotKnow_isNotInitialized() {
        let done = expectation(description: "answered")

        plugin.trackSearch(query: "q", results: nil, shopId: "no-such-shop") { result in
            guard case .failure(let error as PigeonError) = result else { return XCTFail("expected a failure") }
            XCTAssertEqual(error.code, "notInitialized")
            done.fulfill()
        }

        wait(for: [done], timeout: 5)
    }
}
