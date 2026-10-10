import AppIntents
import Foundation

// The flag survives a cold launch and login. Flutter consumes it when its
// authenticated router is ready; a notification also covers a running app.
enum AssistantLaunchBridge {
    static let pendingKey = "jospar.pendingAssistantLaunch"
    static let notification = Notification.Name("jospar.openAssistant")

    @MainActor static func requestLaunch() {
        UserDefaults.standard.set(true, forKey: pendingKey)
        NotificationCenter.default.post(name: notification, object: nil)
    }
}

@available(iOS 16.0, *)
struct TalkToJosparIntent: AppIntent {
    static var title: LocalizedStringResource = "Говорить с Jospar"
    static var description = IntentDescription("Открыть ИИ-помощника Jospar и задать вопрос голосом.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        await AssistantLaunchBridge.requestLaunch()
        return .result()
    }
}

@available(iOS 16.0, *)
struct JosparAssistantShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TalkToJosparIntent(),
            phrases: [
                "Открыть помощника \(.applicationName)",
                "Говорить с \(.applicationName)",
                "Talk to \(.applicationName)",
                "Open assistant in \(.applicationName)",
                "Ok \(.applicationName)"
            ],
            shortTitle: "Говорить с Jospar",
            systemImageName: "mic.fill"
        )
    }
}
