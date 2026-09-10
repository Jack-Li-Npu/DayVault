import DayVaultCore
import SwiftData
import SwiftUI

@main
struct DayVaultApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @UIApplicationDelegateAdaptor(NotificationDelegate.self) private var notificationDelegate
    private let container: ModelContainer
    @State private var model: AppModel
    @State private var entitlements = EntitlementStore()

    init() {
        let process = ProcessInfo.processInfo
        let isTesting = process.arguments.contains("-inMemoryStore") ||
            process.environment["XCTestConfigurationFilePath"] != nil
        let container = PersistenceController.makeContainer(inMemory: isTesting)
        self.container = container
        _model = State(initialValue: AppModel(container: container, persistAvatarPreferences: !isTesting))
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(model)
                .environment(entitlements)
                .modelContainer(container)
#if DEBUG
                .environment(\.avatarReducedMotionPreview, ProcessInfo.processInfo.arguments.contains("-preview-accessibility"))
                .transformEnvironment(\.dynamicTypeSize) { value in
                    if ProcessInfo.processInfo.arguments.contains("-preview-accessibility") { value = .accessibility3 }
                }
#endif
                .task { await entitlements.start() }
                .onReceive(NotificationCenter.default.publisher(for: .completeOccurrenceFromNotification)) { note in
                    if let id = note.object as? String { model.handleNotificationCompletion(id) }
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        model.processPendingWidgetCompletion()
                        model.syncFromPersistence()
                    }
                }
        }
    }
}
