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
    let channel = FlutterMethodChannel(
      name: "viateria/diploma_share",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "shareInstagramStory",
            let args = call.arguments as? [String: Any],
            let bytes = args["bytes"] as? FlutterStandardTypedData,
            let appId = args["appId"] as? String,
            !appId.isEmpty
      else {
        if call.method == "shareInstagramStory" {
          result(false)
        } else {
          result(FlutterMethodNotImplemented)
        }
        return
      }
      result(Self.shareInstagramStory(bytes: bytes.data, appId: appId))
    }
  }

  /// Instagram Stories consumes the PNG from the pasteboard. Without a
  /// Facebook App ID, or when Instagram is not installed, this returns false
  /// and Dart falls back to the system share sheet.
  private static func shareInstagramStory(bytes: Data, appId: String) -> Bool {
    var components = URLComponents()
    components.scheme = "instagram-stories"
    components.host = "share"
    components.queryItems = [
      URLQueryItem(name: "source_application", value: appId),
    ]
    guard let url = components.url, UIApplication.shared.canOpenURL(url) else {
      return false
    }
    let items: [[String: Any]] = [
      ["com.instagram.sharedSticker.backgroundImage": bytes],
    ]
    UIPasteboard.general.setItems(
      items,
      options: [
        .expirationDate: Date().addingTimeInterval(5 * 60),
      ]
    )
    UIApplication.shared.open(url, options: [:], completionHandler: nil)
    return true
  }
}
