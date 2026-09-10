import AppIntents
import DayVaultCore
import SwiftUI
import WidgetKit

@main
struct DayVaultWidgetBundle: WidgetBundle {
    var body: some Widget { TodayScheduleWidget() }
}

struct ScheduleTimelineEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct ScheduleTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> ScheduleTimelineEntry {
        ScheduleTimelineEntry(date: Date(), snapshot: WidgetSnapshot(items: [
            WidgetScheduleItem(id: "preview", title: "Deep work", start: Date(), end: Date().addingTimeInterval(3600), isCompleted: false),
        ]))
    }

    func getSnapshot(in context: Context, completion: @escaping (ScheduleTimelineEntry) -> Void) {
        completion(ScheduleTimelineEntry(date: Date(), snapshot: WidgetSnapshotStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ScheduleTimelineEntry>) -> Void) {
        let entry = ScheduleTimelineEntry(date: Date(), snapshot: WidgetSnapshotStore.load())
        let refresh = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }
}

struct TodayScheduleWidget: Widget {
    let kind = "DayVault.Today"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ScheduleTimelineProvider()) { entry in
            TodayWidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetBackground() }
        }
        .configurationDisplayName("widget.today.title")
        .description("widget.today.description")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

private struct TodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @AppStorage("widgetAppearance", store: UserDefaults(suiteName: WidgetSnapshotStore.suiteName))
    private var appearanceRaw = "midnight"
    let entry: ScheduleTimelineEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("DayVault", systemImage: "lock.shield.fill").font(.caption.bold()).foregroundStyle(accentColor)
                Spacer()
                Text(Date(), format: .dateTime.weekday(.abbreviated)).font(.caption2).foregroundStyle(.secondary)
            }
            if let next = entry.snapshot.items.first(where: { !$0.isCompleted }) {
                Text(next.title).font(.headline).lineLimit(family == .systemMedium ? 2 : 1)
                if let time = next.displayStart {
                    Text(time, style: .time).font(.caption).foregroundStyle(.secondary)
                } else {
                    Text(next.timePrecision == .inbox ? "待安排" : "只定日期")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if family != .accessoryRectangular {
                    Button(intent: CompleteOccurrenceIntent(occurrenceID: next.id)) {
                        Label("widget.complete", systemImage: "checkmark.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.20, green: 0.78, blue: 0.48))
                }
            } else {
                Text("widget.clear").font(.headline)
                Text("widget.clear.subtitle").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var accentColor: Color {
        switch appearanceRaw { case "light": .indigo; case "violet": Color(red: 0.76, green: 0.56, blue: 1); default: Color(red: 0.29, green: 0.82, blue: 0.96) }
    }
}

private struct WidgetBackground: View {
    @AppStorage("widgetAppearance", store: UserDefaults(suiteName: WidgetSnapshotStore.suiteName))
    private var appearanceRaw = "midnight"

    var body: some View {
        switch appearanceRaw {
        case "light": Color(red: 0.96, green: 0.97, blue: 0.99)
        case "violet": Color(red: 0.10, green: 0.05, blue: 0.20)
        default: Color(red: 0.043, green: 0.063, blue: 0.125)
        }
    }
}

struct CompleteOccurrenceIntent: AppIntent {
    static let title: LocalizedStringResource = "Complete schedule item"
    static let description = IntentDescription("Marks a DayVault schedule item complete.")
    static let openAppWhenRun = true

    @Parameter(title: "Occurrence") var occurrenceID: String

    init() {}
    init(occurrenceID: String) { self.occurrenceID = occurrenceID }

    func perform() async throws -> some IntentResult {
        UserDefaults(suiteName: WidgetSnapshotStore.suiteName)?.set(occurrenceID, forKey: "widget.pendingCompletion")
        return .result()
    }
}
