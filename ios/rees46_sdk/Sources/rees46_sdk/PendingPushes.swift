import Foundation
@_spi(Bridge) import REES46

/// The push events of a shop the native SDK does not know yet. A tap on a notification that launched
/// the app reaches the plugin before Dart initializes the shop, and the SDK would drop it: it is kept
/// here and handed to the SDK when the shop is initialized, so its `clicked` and the app's callbacks
/// are not lost. An event kept longer than `ttl` is dropped, and at most `limit` are kept per shop. A
/// push that is not the SDK's — no `src.id` and `src.type`, no `id` and `type` — is not kept.
final class PendingPushes {

  static let shared = PendingPushes()

  /// How long an event waits for its shop.
  static let ttl: TimeInterval = 300
  static let limit = 50

  private struct Held {
    let payload: [AnyHashable: Any]
    let event: Rees46.PushEvent
    let at: Date
  }

  private let lock = NSLock()
  private var held: [String: [Held]] = [:]

  /// The seams: the clock and the SDK's routing. Tests set their own.
  var now: () -> Date = Date.init
  var deliver: ([AnyHashable: Any], Rees46.PushEvent) -> String? = { payload, event in
    Rees46.handlePush(payload, event: event)
  }

  /// Hands the event to the SDK; one of a shop the SDK does not know yet is kept for it.
  func handle(_ payload: [AnyHashable: Any], event: Rees46.PushEvent) {
    if deliver(payload, event) != nil { return }
    guard let shopId = payload["shop_id"] as? String, !shopId.isEmpty, Self.isSdkPush(payload) else { return }
    lock.lock()
    var list = (held[shopId] ?? []).filter { now().timeIntervalSince($0.at) <= Self.ttl }
    list.append(Held(payload: payload, event: event, at: now()))
    if list.count > Self.limit { list.removeFirst(list.count - Self.limit) }
    held[shopId] = list
    lock.unlock()
  }

  /// `shopId` is initialized: the events kept for it go to the SDK now, in the order they came.
  func release(_ shopId: String) {
    lock.lock()
    let list = held.removeValue(forKey: shopId) ?? []
    lock.unlock()
    for item in list where now().timeIntervalSince(item.at) <= Self.ttl {
      _ = deliver(item.payload, item.event)
    }
  }

  /// The events kept for `shopId` (tests).
  func count(_ shopId: String) -> Int {
    lock.lock()
    defer { lock.unlock() }
    return held[shopId]?.count ?? 0
  }

  /// Whether `payload` is an SDK push: its code and type in `src` (APNs, an object or its JSON) or at the
  /// top level (FCM).
  static func isSdkPush(_ payload: [AnyHashable: Any]) -> Bool {
    var src = payload["src"] as? [String: Any]
    if src == nil, let text = payload["src"] as? String, let data = text.data(using: .utf8) {
      src = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
    if let src = src, nonEmptyValue(src["id"]), nonEmptyValue(src["type"]) { return true }
    return nonEmptyValue(payload["id"]) && nonEmptyValue(payload["type"])
  }

  private static func nonEmptyValue(_ value: Any?) -> Bool {
    switch value {
    case let text as String: return !text.isEmpty
    case is NSNumber: return true
    default: return false
    }
  }

  /// Test-only.
  func reset() {
    lock.lock()
    held = [:]
    lock.unlock()
  }
}
