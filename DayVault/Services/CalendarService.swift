import DayVaultCore
import EventKit
import Foundation

struct ExternalCalendarChoice: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let colorHex: String
}

enum CalendarAccessError: LocalizedError {
    case unavailable
    var errorDescription: String? {
        "无法读取已启用的日历。请检查日历权限后重试；这次不会调整安排。"
    }
}

actor SystemCalendarService: CalendarGateway {
    private let store = EKEventStore()

    func requestFullAccess() async throws -> Bool {
        try await store.requestFullAccessToEvents()
    }

    func events(in interval: DateInterval) async throws -> [ExternalCalendarEvent] {
        try events(in: interval, calendarIDs: Set(store.calendars(for: .event).map(\.calendarIdentifier)))
    }

    func calendars() -> [ExternalCalendarChoice] {
        store.calendars(for: .event).map {
            ExternalCalendarChoice(
                id: $0.calendarIdentifier,
                title: $0.title,
                colorHex: $0.cgColor.hexString
            )
        }
    }

    func events(in interval: DateInterval, calendarIDs: Set<String>) throws -> [ExternalCalendarEvent] {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { throw CalendarAccessError.unavailable }
        guard !calendarIDs.isEmpty else { return [] }
        let selected = store.calendars(for: .event).filter { calendarIDs.contains($0.calendarIdentifier) }
        let predicate = store.predicateForEvents(withStart: interval.start, end: interval.end, calendars: selected)
        return store.events(matching: predicate).map { event in
            ExternalCalendarEvent(
                id: event.eventIdentifier ?? UUID().uuidString,
                title: event.title ?? String(localized: "calendar.untitled"),
                start: event.startDate,
                end: event.endDate,
                colorHex: event.calendar.cgColor.hexString
            )
        }
    }
}

private extension CGColor {
    var hexString: String {
        guard let components, components.count >= 3 else { return "#49CFF5" }
        return String(format: "#%02X%02X%02X", Int(components[0] * 255), Int(components[1] * 255), Int(components[2] * 255))
    }
}
