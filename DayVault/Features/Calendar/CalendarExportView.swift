import DayVaultCore
import EventKit
import EventKitUI
import SwiftUI

struct CalendarExportView: View {
    let occurrence: ScheduleOccurrence
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if occurrence.isUnscheduled || occurrence.timePrecision == .inbox {
            VStack(alignment: .leading, spacing: 16) {
                Text("先选一个日期")
                    .font(.title2.weight(.bold))
                Text("这件事还在待安排中。设置日期后，就可以导出到日历。")
                    .foregroundStyle(EditorialPalette.muted)
                Button("返回安排日期") { dismiss() }
                    .buttonStyle(EditorialPrimaryButtonStyle(fill: EditorialPalette.acid, foreground: EditorialPalette.ink))
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(EditorialPalette.paper)
        } else {
            CalendarEventEditor(occurrence: occurrence)
        }
    }
}

private struct CalendarEventEditor: UIViewControllerRepresentable {
    let occurrence: ScheduleOccurrence
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: dismiss) }

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        event.title = occurrence.title
        event.notes = occurrence.notes
        if occurrence.timePrecision == .dateOnly {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: occurrence.timeZoneID) ?? .current
            let start = calendar.startOfDay(for: occurrence.start)
            event.isAllDay = true
            event.startDate = start
            event.endDate = calendar.date(byAdding: .day, value: 1, to: start)
        } else {
            event.isAllDay = false
            event.timeZone = TimeZone(identifier: occurrence.timeZoneID)
            event.startDate = occurrence.start
            event.endDate = occurrence.end
        }
        let controller = EKEventEditViewController()
        controller.eventStore = store
        controller.event = event
        controller.editViewDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: EKEventEditViewController, context: Context) {}

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        private let dismiss: DismissAction
        init(dismiss: DismissAction) { self.dismiss = dismiss }
        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            Task { @MainActor [dismiss] in dismiss() }
        }
    }
}

struct ExternalCalendarEventView: UIViewControllerRepresentable {
    let eventIdentifier: String

    func makeUIViewController(context: Context) -> UINavigationController {
        let store = EKEventStore()
        let controller = EKEventViewController()
        controller.event = store.event(withIdentifier: eventIdentifier)
        controller.allowsEditing = true
        controller.allowsCalendarPreview = true
        return UINavigationController(rootViewController: controller)
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
}
