import XCTest

@testable import REES46
@testable import rees46_sdk

/// The Swift side of the Flutter bridge: everything Dart sends arrives as a pigeon wire struct and
/// has to be turned into a native type. That conversion is where the bridge can silently drop or
/// mangle a value — a story source used to be dropped here — so it is pinned rather than trusted.
final class TrackingBridgeTests: XCTestCase {

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
}
