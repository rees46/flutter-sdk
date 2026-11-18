import Foundation
@_spi(Bridge) import REES46

/// Every failure the bridge hands Dart, as the `PigeonError` Dart turns into an `SdkException`:
/// `code` is the type of the native `Rees46.SdkError` (`notInitialized`, `shopBlocked`,
/// `invalidArgument`, `network`, `timeout`, `http`, `decoding`, `cancelled`), `message` its message,
/// `details` `{"httpCode": Int?, "serverCode": String?}`. The bridge makes up no type of its own: a
/// shop it does not know is `notInitialized`. No message carries a secret, a token or personal data.
enum BridgeFailure: Error {
  case invalidArgument(String)

  /// The native SDK's error.
  static func error(_ error: Rees46.SdkError) -> PigeonError {
    let code: String
    var httpCode: Int?
    var serverCode: String?
    switch error {
    case .notInitialized: code = "notInitialized"
    case .shopBlocked: code = "shopBlocked"
    case .invalidArgument: code = "invalidArgument"
    case .network: code = "network"
    case .timeout: code = "timeout"
    case .http(let status, let server):
      code = "http"
      httpCode = status
      serverCode = server
    case .decoding: code = "decoding"
    case .cancelled: code = "cancelled"
    }
    let details: [String: (any Sendable)?] = ["httpCode": httpCode, "serverCode": serverCode]
    return PigeonError(code: code, message: error.message, details: details)
  }

  /// The error behind an old-style failure of the native SDK (the `tracking` namespace's callbacks):
  /// the whole error when the SDK knows it on this thread, otherwise one made from the old error.
  static func error(legacy: LegacySdkError) -> PigeonError {
    error(Rees46.BridgeErrors.error(of: legacy))
  }

  /// No instance for the shop: never initialized, released, or no shop id while several are live.
  static var notInitialized: PigeonError {
    error(.notInitialized)
  }

  /// Anything else that went wrong in the bridge itself: an argument it could not take is
  /// `invalidArgument`, the rest `decoding`.
  static func error(_ any: Error) -> PigeonError {
    switch any {
    case let pigeon as PigeonError:
      return pigeon
    case let sdk as Rees46.SdkError:
      return error(sdk)
    case BridgeFailure.invalidArgument(let what):
      return error(.invalidArgument(what))
    default:
      return PigeonError(
        code: "decoding",
        message: "the bridge could not handle the call: \(type(of: any))",
        details: ["httpCode": nil, "serverCode": nil] as [String: (any Sendable)?]
      )
    }
  }
}

/// Calls `body` on the main thread: Pigeon replies and Flutter API calls go there.
func onMain(_ body: @escaping () -> Void) {
  if Thread.isMainThread {
    body()
  } else {
    DispatchQueue.main.async(execute: body)
  }
}
