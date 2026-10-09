import SwiftUI
import WidgetKit

private let appGroupId = "group.com.jospar.app"
private let widgetKind = "InboxHomeWidget"

private struct InboxEntry: TimelineEntry {
    let date: Date
    let count: Int
    let tasks: [String]
}

private struct InboxProvider: TimelineProvider {
    func placeholder(in context: Context) -> InboxEntry {
        InboxEntry(
            date: Date(),
            count: 3,
            tasks: ["Подготовить отчёт", "Проверить задачи", "Позвонить клиенту"]
        )
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (InboxEntry) -> Void
    ) {
        completion(loadEntry())
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<InboxEntry>) -> Void
    ) {
        let entry = loadEntry()
        let nextRefresh = Calendar.current.date(
            byAdding: .minute,
            value: 15,
            to: Date()
        ) ?? Date().addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func loadEntry() -> InboxEntry {
        let data = UserDefaults(suiteName: appGroupId)
        let tasks = (1...3)
            .compactMap { data?.string(forKey: "inbox_task_\($0)") }
            .filter { !$0.isEmpty }
        return InboxEntry(
            date: Date(),
            count: data?.integer(forKey: "inbox_count") ?? 0,
            tasks: tasks
        )
    }
}

private struct InboxWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: InboxEntry

    private var visibleTasks: [String] {
        Array(entry.tasks.prefix(family == .systemSmall ? 2 : 3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Image(systemName: "tray.full.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(red: 0.31, green: 0.27, blue: 0.90))
                Text("Инбокс")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.09, green: 0.09, blue: 0.13))
                Spacer(minLength: 8)
                Text("\(entry.count)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.31, green: 0.27, blue: 0.90))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(red: 0.93, green: 0.94, blue: 1.0))
                    .clipShape(Capsule())
            }

            Spacer(minLength: 10)

            if visibleTasks.isEmpty {
                Text("Быстрых задач пока нет")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                Spacer()
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(visibleTasks.enumerated()), id: \.offset) { _, task in
                        HStack(alignment: .firstTextBaseline, spacing: 7) {
                            Image(systemName: "circle")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(Color(red: 0.39, green: 0.40, blue: 0.95))
                            Text(task)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(red: 0.19, green: 0.20, blue: 0.24))
                                .lineLimit(1)
                        }
                    }
                }
                Spacer(minLength: 6)
            }

            Text("Открыть  →")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(red: 0.39, green: 0.40, blue: 0.95))
        }
        .widgetURL(URL(string: "jospar://inbox?homeWidget"))
        .widgetBackground(Color.white)
    }
}

private extension View {
    @ViewBuilder
    func widgetBackground(_ color: Color) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            containerBackground(for: .widget) { color }
        } else {
            padding(16)
                .background(color)
        }
    }
}

@main
struct InboxHomeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: widgetKind, provider: InboxProvider()) { entry in
            InboxWidgetView(entry: entry)
        }
        .configurationDisplayName("Инбокс Orbita")
        .description("Быстрые задачи, которые ждут распределения.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
