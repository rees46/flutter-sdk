import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "DemoStoriesLinks") {
      DemoStoriesLinks.register(with: registrar)
    }
  }
}

/// Stories "Share" links in the demo scheme, any host and path:
/// `rees46flutter://<site>/?r46_stories=<code>&r46_story=<id>[&r46_slide=<id>]`.
///
/// Gets them from the scene (Flutter's deep linking is off in Info.plist: it would push them
/// to the Navigator as routes) and hands them to Dart over `rees46_sdk_example/links`: the
/// link the app was started with on request (`getInitialLink`), later ones as `onLink`.
final class DemoStoriesLinks: NSObject, FlutterPlugin, FlutterSceneLifeCycleDelegate {
  private static let shared = DemoStoriesLinks()

  private var channel: FlutterMethodChannel?

  /// The link of the cold start, until Dart takes it.
  private var initialLink: String?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "rees46_sdk_example/links",
      binaryMessenger: registrar.messenger()
    )
    shared.channel = channel
    channel.setMethodCallHandler { call, result in
      guard call.method == "getInitialLink" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(shared.initialLink)
      shared.initialLink = nil
    }
    registrar.addSceneDelegate(shared)
  }

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions?
  ) -> Bool {
    if let url = connectionOptions?.urlContexts.map(\.url).first(where: Self.isStoriesLink) {
      initialLink = url.absoluteString
    }
    return false
  }

  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) -> Bool {
    guard let url = URLContexts.map(\.url).first(where: Self.isStoriesLink) else { return false }
    channel?.invokeMethod("onLink", arguments: url.absoluteString)
    return true
  }

  /// A link with `r46_stories`, whatever its host and path.
  private static func isStoriesLink(_ url: URL) -> Bool {
    let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    return items.contains { $0.name == "r46_stories" }
  }
}
