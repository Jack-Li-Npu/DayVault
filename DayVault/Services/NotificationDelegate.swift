import UIKit
import UserNotifications

final class NotificationDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        Task { await SystemNotificationService().configureCategories() }
        return true
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let occurrenceID = response.notification.request.content.userInfo["occurrenceID"] as? String else { return }
        switch response.actionIdentifier {
        case NotificationActionIdentifier.complete:
            NotificationCenter.default.post(name: .completeOccurrenceFromNotification, object: occurrenceID)
        case NotificationActionIdentifier.snooze:
            let content = response.notification.request.content
            try? await SystemNotificationService().snooze(occurrenceID: occurrenceID, title: content.title, body: content.body)
        default:
            break
        }
    }
}

extension Notification.Name {
    static let completeOccurrenceFromNotification = Notification.Name("DayVault.completeOccurrenceFromNotification")
}
