import DayVaultCore
import Foundation
import UserNotifications

enum NotificationActionIdentifier {
    static let category = "DAYVAULT_SCHEDULE"
    static let complete = "COMPLETE"
    static let snooze = "SNOOZE"
}

actor SystemNotificationService: NotificationScheduling {
    private let center = UNUserNotificationCenter.current()

    func configureCategories() async {
        let complete = UNNotificationAction(identifier: NotificationActionIdentifier.complete, title: String(localized: "action.complete"))
        let snooze = UNNotificationAction(identifier: NotificationActionIdentifier.snooze, title: String(localized: "action.snooze"))
        let category = UNNotificationCategory(
            identifier: NotificationActionIdentifier.category,
            actions: [complete, snooze],
            intentIdentifiers: []
        )
        center.setNotificationCategories([category])
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .badge, .sound])
    }

    func schedule(occurrence: ScheduleOccurrence, leadMinutes: Int) async throws {
        await cancel(occurrenceID: occurrence.id)
        guard occurrence.timePrecision == .timed, occurrence.status == .planned || occurrence.status == .active else { return }
        let fireDate = occurrence.start.addingTimeInterval(TimeInterval(-leadMinutes * 60))
        guard fireDate > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = occurrence.title
        content.body = String(localized: "notification.starting")
        content.categoryIdentifier = NotificationActionIdentifier.category
        content.userInfo = ["occurrenceID": occurrence.id]
        content.sound = .default
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let request = UNNotificationRequest(
            identifier: occurrence.id,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
        try await center.add(request)
    }

    func cancel(occurrenceID: String) async {
        center.removePendingNotificationRequests(withIdentifiers: [occurrenceID, "\(occurrenceID).snooze"])
    }

    func snooze(occurrenceID: String, title: String, body: String) async throws {
        let copy = UNMutableNotificationContent()
        copy.title = title
        copy.body = body
        copy.categoryIdentifier = NotificationActionIdentifier.category
        copy.userInfo = ["occurrenceID": occurrenceID]
        copy.sound = .default
        let request = UNNotificationRequest(
            identifier: "\(occurrenceID).snooze",
            content: copy,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 600, repeats: false)
        )
        try await center.add(request)
    }
}
