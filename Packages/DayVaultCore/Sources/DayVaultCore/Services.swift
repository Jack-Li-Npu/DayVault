import Foundation

public protocol ScheduleRepository: Sendable {
    func occurrences(in interval: DateInterval) async throws -> [ScheduleOccurrence]
    func complete(_ occurrence: ScheduleOccurrence, at date: Date) async throws
    func reschedule(_ occurrence: ScheduleOccurrence, to start: Date, durationMinutes: Int) async throws
}

public protocol ActualTimeTracking: Sendable {
    var activeOccurrenceID: String? { get async }
    func start(_ occurrence: ScheduleOccurrence, at date: Date) async throws
    func stop(at date: Date) async throws
}

public struct ExternalCalendarEvent: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let start: Date
    public let end: Date
    public let colorHex: String

    public init(id: String, title: String, start: Date, end: Date, colorHex: String) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.colorHex = colorHex
    }
}

public protocol CalendarGateway: Sendable {
    func requestFullAccess() async throws -> Bool
    func events(in interval: DateInterval) async throws -> [ExternalCalendarEvent]
}

public protocol NotificationScheduling: Sendable {
    func requestAuthorization() async throws -> Bool
    func schedule(occurrence: ScheduleOccurrence, leadMinutes: Int) async throws
    func cancel(occurrenceID: String) async
}

public protocol EntitlementProviding: Sendable {
    var hasLifetimePro: Bool { get async }
    func refresh() async
    func purchaseLifetime() async throws
    func restore() async throws
}
