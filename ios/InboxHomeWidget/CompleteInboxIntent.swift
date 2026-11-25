import AppIntents
import home_widget

@available(iOS 17, *)
struct CompleteInboxIntent: AppIntent {
    static var title: LocalizedStringResource = "Завершить задачу"
    @Parameter(title: "Задача") var taskId: String
    init() {}
    init(taskId: String) { self.taskId = taskId }
    func perform() async throws -> some IntentResult {
        var components = URLComponents()
        components.scheme = "jospar"
        components.host = "complete"
        components.queryItems = [URLQueryItem(name: "id", value: taskId)]
        await HomeWidgetBackgroundWorker.run(url: components.url, appGroup: "group.com.jospar.app")
        return .result()
    }
}

@available(iOS 17, *)
@available(iOSApplicationExtension, unavailable)
extension CompleteInboxIntent: ForegroundContinuableIntent {}
