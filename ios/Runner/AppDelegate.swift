import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var assistantChannel: FlutterMethodChannel?
  private var assistantObserver: NSObjectProtocol?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(name: "jospar/assistant_launch", binaryMessenger: controller.binaryMessenger)
      assistantChannel = channel
      channel.setMethodCallHandler { call, result in
        if call.method == "consumePendingLaunch" {
          let pending = UserDefaults.standard.bool(forKey: AssistantLaunchBridge.pendingKey)
          UserDefaults.standard.removeObject(forKey: AssistantLaunchBridge.pendingKey)
          result(pending)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
      assistantObserver = NotificationCenter.default.addObserver(
        forName: AssistantLaunchBridge.notification, object: nil, queue: .main
      ) { [weak self] _ in
        self?.assistantChannel?.invokeMethod("openAssistant", arguments: nil)
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
