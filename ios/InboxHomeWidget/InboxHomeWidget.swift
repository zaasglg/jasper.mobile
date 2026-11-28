import SwiftUI
import WidgetKit

private let appGroupId = "group.com.josparbee.app"
private let widgetKind = "InboxHomeWidget"

private struct InboxEntry: TimelineEntry {
    let date: Date
    let count: Int
    let tasks: [String]
    var taskIds: [String] = []
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
            tasks: tasks,
            taskIds: (1...3).map { data?.string(forKey: "inbox_task_id_\($0)") ?? "" }
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
                    ForEach(Array(visibleTasks.enumerated()), id: \.offset) { index, task in
                        HStack(alignment: .center, spacing: 4) {
                            if #available(iOSApplicationExtension 17.0, *), index < entry.taskIds.count, !entry.taskIds[index].isEmpty {
                                Button(intent: CompleteInboxIntent(taskId: entry.taskIds[index])) {
                                    Image(systemName: "circle")
                                        .font(.system(size: 22, weight: .regular))
                                        .frame(width: 36, height: 36)
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(Color(red: 0.39, green: 0.40, blue: 0.95))
                                .accessibilityLabel("Завершить: \(task)")
                            } else {
                                Image(systemName: "circle")
                                    .font(.system(size: 22))
                                    .foregroundColor(Color(red: 0.39, green: 0.40, blue: 0.95))
                            }
                            Text(task)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(red: 0.19, green: 0.20, blue: 0.24))
                                .lineLimit(1)
                        }
                    }
                }
                Spacer(minLength: 6)
            }

            Link(destination: URL(string: "jospar://inbox?homeWidget&action=add")!) {
                Text("＋ Добавить задачу")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(red: 0.39, green: 0.40, blue: 0.95))
            }
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


private struct AssistantEntry: TimelineEntry {
    let date: Date
}

private struct AssistantProvider: TimelineProvider {
    func placeholder(in context: Context) -> AssistantEntry { AssistantEntry(date: Date()) }
    func getSnapshot(in context: Context, completion: @escaping (AssistantEntry) -> Void) {
        completion(AssistantEntry(date: Date()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<AssistantEntry>) -> Void) {
        completion(Timeline(entries: [AssistantEntry(date: Date())], policy: .never))
    }
}

private struct AssistantWidgetView: View {
    @Environment(\.colorScheme) private var colorScheme
    private var accent: Color {
        colorScheme == .dark
            ? Color(red: 0.70, green: 0.65, blue: 1)
            : Color(red: 0.43, green: 0.37, blue: 0.88)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Jospar AI").font(.system(size: 18, weight: .semibold))
                Spacer(minLength: 4)
                Image(systemName: "bubble.left").foregroundColor(accent)
            }
            Spacer(minLength: 0)
            Text("Чем помочь?")
                .font(.system(size: 14)).foregroundColor(.secondary)
            HStack(spacing: 6) {
                Text("Написать запрос")
                Image(systemName: "arrow.up.right")
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(accent)
        }
        .foregroundColor(.primary)
        .widgetURL(URL(string: "jospar://assistant?homeWidget&keyboard=true"))
        .widgetBackground(colorScheme == .dark
            ? Color(red: 0.094, green: 0.098, blue: 0.122) : .white)
    }
}

struct AssistantHomeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AssistantHomeWidget", provider: AssistantProvider()) { _ in
            AssistantWidgetView()
        }
        .configurationDisplayName("Jospar AI")
        .description("Откройте помощника и сразу напишите запрос.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct JosparWidgetBundle: WidgetBundle {
    var body: some Widget {
        InboxHomeWidget()
        AssistantHomeWidget()
    }
}
