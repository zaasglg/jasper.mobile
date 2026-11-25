import Flutter
import home_widget
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var pushNotifications: IOSPushNotifications?
  private var systemIncomingCall: SystemIncomingCall?
  private var assistantChannel: FlutterMethodChannel?
  private var assistantObserver: NSObjectProtocol?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if #available(iOS 17, *) {
      HomeWidgetBackgroundWorker.setPluginRegistrantCallback { registry in
        GeneratedPluginRegistrant.register(with: registry)
      }
    }
    if let controller = window?.rootViewController as? FlutterViewController {
      pushNotifications = IOSPushNotifications(messenger: controller.binaryMessenger)
      UNUserNotificationCenter.current().delegate = self
      systemIncomingCall = SystemIncomingCall(messenger: controller.binaryMessenger)
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
  override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    pushNotifications?.registered(deviceToken)
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    let info = notification.request.content.userInfo
    guard let push = pushNotifications, push.isFirebase(info) else {
      super.userNotificationCenter(center, willPresent: notification, withCompletionHandler: completionHandler)
      return
    }
    completionHandler(push.receive(info, opened: false) ? [.banner, .sound] : [])
  }

  override func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
    let info = response.notification.request.content.userInfo
    guard let push = pushNotifications, push.isFirebase(info) else {
      super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
      return
    }
    _ = push.receive(info, opened: true)
    completionHandler()
  }

}
