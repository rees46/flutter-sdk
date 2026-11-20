import Flutter
import XCTest

@_spi(Bridge) @testable import REES46
@_spi(Bridge) @testable import rees46_sdk

/// The root of a shop's instance through the bridge: `flush`, `release` and `deleteUserCredentials`
/// reach the shop's native instance, answer Dart on the main thread, and a native error keeps its type.
/// A shop the bridge does not know is `notInitialized`, and released already.
final class RootBridgeTests: XCTestCase {

    private let shopId = "root-shop"
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
        Rees46FlutterSdkPlugin.sdk = nil
        super.tearDown()
    }

    private func code(_ error: Error?) -> String? {
        (error as? PigeonError)?.code
    }

    func test_flush_reachesTheShopsInstance() {
        let done = expectation(description: "answered")

        plugin.flush(shopId: shopId) { result in
            XCTAssertTrue(Thread.isMainThread)
            if case .failure(let error) = result { XCTFail("\(error)") }
            done.fulfill()
        }

        wait(for: [done], timeout: 5)
        XCTAssertEqual(native.flushes, 1)
    }

    func test_flush_aNativeErrorKeepsItsType() {
        native.flushError = .notInitialized
        let done = expectation(description: "answered")

        plugin.flush(shopId: shopId) { result in
            if case .failure(let error) = result {
                XCTAssertEqual(self.code(error), "notInitialized")
            } else {
                XCTFail("flush succeeded")
            }
            done.fulfill()
        }

        wait(for: [done], timeout: 5)
    }

    func test_deleteUserCredentials_answersTheShopsStateAfterTheWipe() {
        let done = expectation(description: "answered")

        plugin.deleteUserCredentials(shopId: shopId) { result in
            XCTAssertTrue(Thread.isMainThread)
            switch result {
            case .success(let snapshot):
                XCTAssertEqual(snapshot.shopId, self.shopId)
                XCTAssertEqual(snapshot.state, "initializing")
                XCTAssertNil(snapshot.deviceId)
                XCTAssertNil(snapshot.sessionId)
                XCTAssertEqual(snapshot.segment, "A", "the A/B group is the device's: it stays")
            case .failure(let error):
                XCTFail("\(error)")
            }
            done.fulfill()
        }

        wait(for: [done], timeout: 5)
        XCTAssertEqual(native.deletions, 1)
    }

    func test_release_releasesTheInstanceAndTheBridgeLetsGoOfIt() throws {
        Rees46FlutterSdkPlugin.sdk = native

        try plugin.release(shopId: shopId)

        XCTAssertEqual(native.releases, 1)
        XCTAssertNil(Rees46FlutterSdkPlugin.sdk, "the AppDelegate's push path keeps no released instance")
        XCTAssertThrowsError(try plugin.getSnapshot(shopId: shopId)) { error in
            XCTAssertEqual(self.code(error), "notInitialized")
        }

        try plugin.release(shopId: shopId)
        XCTAssertEqual(native.releases, 1, "a released shop is released already")
    }

    func test_release_leavesTheOtherShopsAlone() throws {
        let other = RecordingSDK(shopId: "other-shop")
        SdkRegistry.shared.register(shopId: "other-shop", sdk: other)
        Rees46FlutterSdkPlugin.sdk = other

        try plugin.release(shopId: shopId)

        XCTAssertEqual(other.releases, 0)
        XCTAssertTrue(Rees46FlutterSdkPlugin.sdk.map { $0 as AnyObject } === other)
        XCTAssertEqual(try plugin.getSnapshot(shopId: "other-shop").shopId, "other-shop")
    }

    func test_theRootOfAShopTheBridgeDoesNotKnow_isNotInitialized() throws {
        let flushed = expectation(description: "flush answered")
        let deleted = expectation(description: "delete answered")

        plugin.flush(shopId: "unknown-shop") { result in
            if case .failure(let error) = result {
                XCTAssertEqual(self.code(error), "notInitialized")
            } else {
                XCTFail("flush succeeded")
            }
            flushed.fulfill()
        }
        plugin.deleteUserCredentials(shopId: "unknown-shop") { result in
            if case .failure(let error) = result {
                XCTAssertEqual(self.code(error), "notInitialized")
            } else {
                XCTFail("deleteUserCredentials succeeded")
            }
            deleted.fulfill()
        }
        try plugin.release(shopId: "unknown-shop")

        wait(for: [flushed, deleted], timeout: 5)
        XCTAssertEqual(native.flushes, 0)
        XCTAssertEqual(native.deletions, 0)
        XCTAssertEqual(native.releases, 0)
    }
}

/// A push event of a shop the SDK does not know yet — a tap that launched the app — waits for the shop's
/// initialize and then goes to the SDK; a stale one, or one that is not the SDK's, does not.
final class PendingPushesTests: XCTestCase {

    private var pending: PendingPushes!
    private var delivered: [(String?, Rees46.PushEvent)] = []
    private var known: Set<String> = []
    private var clock = Date(timeIntervalSince1970: 1_000)

    override func setUp() {
        super.setUp()
        pending = PendingPushes()
        delivered = []
        known = []
        pending.now = { [unowned self] in self.clock }
        pending.deliver = { [unowned self] payload, event in
            let shop = payload["shop_id"] as? String
            guard let shop = shop, self.known.contains(shop) else { return nil }
            self.delivered.append((shop, event))
            return shop
        }
    }

    private func push(_ shop: String, id: String = "m-1") -> [AnyHashable: Any] {
        ["shop_id": shop, "src": ["id": id, "type": "bulk"], "aps": ["alert": ["title": "t"]]]
    }

    func test_aTapBeforeItsShopStarted_goesOnceTheShopIsInitialized() {
        pending.handle(push("shop-a"), event: .clicked)

        XCTAssertTrue(delivered.isEmpty)
        XCTAssertEqual(pending.count("shop-a"), 1)

        known.insert("shop-a")
        pending.release("shop-a")

        XCTAssertEqual(delivered.map { $0.0 }, ["shop-a"])
        XCTAssertEqual(delivered.map { $0.1 }, [.clicked])
        XCTAssertEqual(pending.count("shop-a"), 0)
    }

    func test_anEventOfAKnownShop_goesAtOnce_andIsNotKept() {
        known.insert("shop-a")

        pending.handle(push("shop-a"), event: .opened)

        XCTAssertEqual(delivered.map { $0.1 }, [.opened])
        XCTAssertEqual(pending.count("shop-a"), 0)
    }

    func test_aStaleEvent_isDropped() {
        pending.handle(push("shop-a"), event: .clicked)
        clock = clock.addingTimeInterval(PendingPushes.ttl + 1)
        known.insert("shop-a")

        pending.release("shop-a")

        XCTAssertTrue(delivered.isEmpty)
    }

    func test_aPushThatIsNotTheSdks_isNotKept() {
        pending.handle(["shop_id": "shop-a", "aps": ["alert": "hi"]], event: .clicked)

        XCTAssertEqual(pending.count("shop-a"), 0)
        XCTAssertTrue(PendingPushes.isSdkPush(["src": "{\"id\":\"m\",\"type\":\"bulk\"}"]))
        XCTAssertTrue(PendingPushes.isSdkPush(["id": "m", "type": "bulk"]))
        XCTAssertFalse(PendingPushes.isSdkPush(["src": ["id": "m"]]))
    }

    func test_atMostTheLimitIsKeptPerShop() {
        for i in 0..<(PendingPushes.limit + 5) {
            pending.handle(push("shop-a", id: "m-\(i)"), event: .delivered)
        }

        XCTAssertEqual(pending.count("shop-a"), PendingPushes.limit)
    }
}

/// Whether a stories video has sound: read off the main thread, answered on it; a source that
/// cannot be read is `nil`.
final class StoriesVideoAudioTests: XCTestCase {

    private var original: ((URL) async throws -> Bool)!

    override func setUp() {
        super.setUp()
        original = StoriesVideoAudio.loader
    }

    override func tearDown() {
        StoriesVideoAudio.loader = original
        super.tearDown()
    }

    private func answer(_ source: String, through plugin: Bool = false) -> Bool?? {
        let done = expectation(description: "answer")
        var result: Bool??
        let reply: (Bool?) -> Void = { value in
            XCTAssertTrue(Thread.isMainThread)
            result = .some(value)
            done.fulfill()
        }
        if plugin {
            let impl = PersonalizationHostApiImpl(
                popupApi: PersonalizationPopupFlutterApi(binaryMessenger: SilentMessenger()),
                stateApi: PersonalizationStateFlutterApi(binaryMessenger: SilentMessenger())
            )
            impl.storiesVideoHasAudio(source: source) { reply(try? $0.get()) }
            wait(for: [done], timeout: 5)
            impl.stop()
        } else {
            StoriesVideoAudio.hasAudio(source: source, completion: reply)
            wait(for: [done], timeout: 5)
        }
        return result
    }

    func test_urls_http_andFile_asTheyAre_aPath_asAFile() {
        XCTAssertEqual(StoriesVideoAudio.url(for: "https://cdn.example/v.mp4")?.absoluteString,
                       "https://cdn.example/v.mp4")
        XCTAssertEqual(StoriesVideoAudio.url(for: "file:///tmp/v.mp4")?.path, "/tmp/v.mp4")
        let path = StoriesVideoAudio.url(for: "/var/cache/stories/v.mp4")
        XCTAssertTrue(path?.isFileURL ?? false)
        XCTAssertEqual(path?.path, "/var/cache/stories/v.mp4")
        XCTAssertNil(StoriesVideoAudio.url(for: ""))
    }

    func test_theLoaderDecides_aFailureIsNil() {
        var loaded: [String] = []
        StoriesVideoAudio.loader = { url in
            loaded.append(url.absoluteString)
            if url.absoluteString.hasSuffix("broken.mp4") { throw URLError(.badServerResponse) }
            return url.absoluteString.hasSuffix("sound.mp4")
        }
        XCTAssertEqual(answer("https://cdn.example/sound.mp4"), .some(true))
        XCTAssertEqual(answer("https://cdn.example/mute.mp4", through: true), .some(false))
        XCTAssertEqual(answer("https://cdn.example/broken.mp4"), .some(nil))
        XCTAssertEqual(answer(""), .some(nil))
        XCTAssertEqual(loaded.count, 3)
    }

    func test_aRealFile_audioIsSeen_aNonMediaFileHasNone() throws {
        // A one-second silent WAV: an audio track AVFoundation reads.
        let rate = 8000
        var wav = Data()
        func append<T: FixedWidthInteger>(_ value: T) {
            var little = value.littleEndian
            wav.append(Data(bytes: &little, count: MemoryLayout<T>.size))
        }
        wav.append("RIFF".data(using: .ascii)!)
        append(UInt32(36 + rate * 2))
        wav.append("WAVEfmt ".data(using: .ascii)!)
        append(UInt32(16)); append(UInt16(1)); append(UInt16(1))
        append(UInt32(rate)); append(UInt32(rate * 2)); append(UInt16(2)); append(UInt16(16))
        wav.append("data".data(using: .ascii)!)
        append(UInt32(rate * 2))
        wav.append(Data(count: rate * 2))
        let directory = FileManager.default.temporaryDirectory
        let sound = directory.appendingPathComponent("stories-audio-test.wav")
        let text = directory.appendingPathComponent("stories-audio-test.txt")
        try wav.write(to: sound)
        try Data("not a video".utf8).write(to: text)
        defer {
            try? FileManager.default.removeItem(at: sound)
            try? FileManager.default.removeItem(at: text)
        }
        XCTAssertEqual(answer(sound.path), .some(true))
        XCTAssertNotEqual(answer(text.path), .some(true))
    }
}
