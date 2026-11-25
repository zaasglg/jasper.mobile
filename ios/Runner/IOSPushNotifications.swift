import FirebaseCore
import FirebaseMessaging
import Flutter
import UIKit
import UserNotifications

/// Native Firebase bridge; Flutter owns authenticated navigation after a tap.
final class IOSPushNotifications: NSObject, MessagingDelegate {
    private let channel: FlutterMethodChannel
    private var pending: [String: String]?
    private let accountKey = "jospar.push.account"
    private var configured: Bool { FirebaseApp.app() != nil }

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: "jospar/push_notifications", binaryMessenger: messenger)
        super.init()
        if Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil {
            FirebaseApp.configure()
            Messaging.messaging().delegate = self
            Messaging.messaging().isAutoInitEnabled = false
        }
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self = self else { result(nil); return }
            switch call.method {
            case "status":
                UNUserNotificationCenter.current().getNotificationSettings { settings in
                    DispatchQueue.main.async {
                        let allowed = [.authorized, .provisional, .ephemeral].contains(settings.authorizationStatus)
                        if allowed && self.configured { self.register() }
                        result(["authorized": allowed, "channelEnabled": allowed, "configured": self.configured])
                    }
                }
            case "requestPermission":
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { allowed, error in
                    DispatchQueue.main.async {
                        if let _ = error { result(FlutterError(code: "push_permission", message: "Не удалось запросить разрешение на уведомления.", details: nil)); return }
                        if allowed && self.configured { self.register() }
                        result(allowed)
                    }
                }
            case "token":
                guard self.configured, Messaging.messaging().apnsToken != nil else { result(nil); return }
                Messaging.messaging().token { token, error in
                    DispatchQueue.main.async {
                        if error != nil { result(FlutterError(code: "push_token", message: "Не удалось получить токен уведомлений Apple.", details: nil)) }
                        else { result(token) }
                    }
                }
            case "initialMessage": result(self.pending); self.pending = nil
            case "bindAccount":
                guard let args = call.arguments as? [String: Any], let id = args["userId"] as? String, !id.isEmpty else {
                    result(FlutterError(code: "invalid_account", message: "Не выбран аккаунт.", details: nil)); return
                }
                UserDefaults.standard.set(id, forKey: self.accountKey)
                result(nil)
            case "setPreferences":
                guard let args = call.arguments as? [String: Any], let owner = args["userId"] as? String,
                      let preferences = args["preferences"] as? [String: Any], !owner.isEmpty else {
                    result(FlutterError(code: "invalid_preferences", message: "Invalid preferences", details: nil)); return
                }
                UserDefaults.standard.set(preferences, forKey: "jospar.push.preferences.\(owner)")
                result(["timeZone": TimeZone.current.identifier])
            case "clearAccount":
                UserDefaults.standard.removeObject(forKey: self.accountKey)
                self.pending = nil
                UNUserNotificationCenter.current().removeAllDeliveredNotifications()
                result(nil)
            case "deleteToken":
                guard self.configured else { result(nil); return }
                Messaging.messaging().isAutoInitEnabled = false
                UIApplication.shared.unregisterForRemoteNotifications()
                Messaging.messaging().deleteToken { error in
                    DispatchQueue.main.async {
                        result(error == nil ? nil : FlutterError(code: "push_delete", message: "Не удалось сбросить токен уведомлений.", details: nil))
                    }
                }
            case "settings":
                guard let url = URL(string: UIApplication.openSettingsURLString) else { result(false); return }
                UIApplication.shared.open(url) { opened in result(opened) }
            default: result(FlutterMethodNotImplemented)
            }
        }
    }
    private func register() {
        Messaging.messaging().isAutoInitEnabled = true
        UIApplication.shared.registerForRemoteNotifications()
    }
    func registered(_ token: Data) {
        guard configured else { return }
        Messaging.messaging().apnsToken = token
        Messaging.messaging().token { [weak self] token, _ in
            guard let token = token else { return }
            DispatchQueue.main.async { self?.channel.invokeMethod("tokenChanged", arguments: token) }
        }
    }
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        DispatchQueue.main.async { [weak self] in self?.channel.invokeMethod("tokenChanged", arguments: token) }
    }
    func isFirebase(_ info: [AnyHashable: Any]) -> Bool {
        info["gcm.message_id"] != nil || info["eventId"] != nil
    }
    func receive(_ info: [AnyHashable: Any], opened: Bool) -> Bool {
        let values = info.reduce(into: [String: String]()) { result, entry in
            if let key = entry.key as? String, let value = entry.value as? String { result[key] = value }
        }
        if let recipient = values["recipientId"], recipient != UserDefaults.standard.string(forKey: accountKey) { return false }
        var data = values
        data["messageId"] = values["eventId"] ?? values["gcm.message_id"] ?? values["messageId"]
        if opened { pending = data }
        channel.invokeMethod(opened ? "opened" : "message", arguments: data)
        return opened || allows(values["type"] ?? "")
    }
    private func allows(_ type: String) -> Bool {
        if type == "call" { return true }
        guard let owner = UserDefaults.standard.string(forKey: accountKey) else { return false }
        guard let preferences = UserDefaults.standard.dictionary(forKey: "jospar.push.preferences.\(owner)") else { return true }
        let components = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let minute = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        let start = preferences["quietStart"] as? Int ?? 1320
        let end = preferences["quietEnd"] as? Int ?? 480
        if preferences["quietEnabled"] as? Bool == true {
            let quiet = start == end || (start < end ? minute >= start && minute < end : minute >= start || minute < end)
            if quiet { return false }
        }
        switch type {
        case "message": return preferences["messages"] as? Bool ?? true
        case "mention": return preferences["mentions"] as? Bool ?? true
        case "deadline", "reminder", "planner": return preferences["deadlines"] as? Bool ?? true
        default: return true
        }
    }
}
