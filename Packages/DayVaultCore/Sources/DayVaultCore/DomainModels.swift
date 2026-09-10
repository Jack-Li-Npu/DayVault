import Foundation
import SwiftData

public enum RecurrenceKind: String, Codable, CaseIterable, Sendable {
    case none, daily, weekdays, selectedWeekdays, weekly, monthly
}

public struct RecurrenceRule: Codable, Equatable, Sendable {
    public var kind: RecurrenceKind
    public var weekdays: Set<Int>
    public var interval: Int

    public init(kind: RecurrenceKind = .none, weekdays: Set<Int> = [], interval: Int = 1) {
        self.kind = kind
        self.weekdays = weekdays
        self.interval = max(1, interval)
    }
}

public enum ItemPriority: String, Codable, CaseIterable, Sendable {
    case low, normal, high
}

public enum OccurrenceStatus: String, Codable, CaseIterable, Sendable {
    case planned, active, completed, skipped, removed
}

public enum SkipReason: String, Codable, CaseIterable, Sendable {
    case rest, conflict, noLongerNeeded, other
}

public enum BalanceGroup: String, Codable, CaseIterable, Sendable {
    case focus, care, rest, other
}

public enum ReminderLead: Int, Codable, CaseIterable, Sendable {
    case atStart = 0
    case five = 5
    case ten = 10
    case fifteen = 15
    case thirty = 30
    case sixty = 60
}

@Model
public final class ScheduleCategory {
    public var id: UUID = UUID()
    public var name: String = ""
    public var colorHex: String = "#49CFF5"
    public var symbolName: String = "circle.fill"
    public var balanceGroupRaw: String = BalanceGroup.other.rawValue
    public var sortOrder: Int = 0

    public var balanceGroup: BalanceGroup {
        get { BalanceGroup(rawValue: balanceGroupRaw) ?? .other }
        set { balanceGroupRaw = newValue.rawValue }
    }

    public init(
        id: UUID = UUID(),
        name: String,
        colorHex: String,
        symbolName: String,
        balanceGroup: BalanceGroup,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.symbolName = symbolName
        self.balanceGroupRaw = balanceGroup.rawValue
        self.sortOrder = sortOrder
    }
}

@Model
public final class ScheduleItem {
    public var id: UUID = UUID()
    public var title: String = ""
    public var notes: String = ""
    public var categoryID: UUID?
    public var plannedStart: Date = Date()
    public var plannedDurationMinutes: Int = 30
    public var isUnscheduled: Bool = false
    public var timeZoneID: String = TimeZone.current.identifier
    public var priorityRaw: String = ItemPriority.normal.rawValue
    public var recurrenceKindRaw: String = RecurrenceKind.none.rawValue
    public var recurrenceWeekdaysCSV: String = ""
    public var recurrenceInterval: Int = 1
    public var recurrenceEnd: Date?
    public var reminderLeadMinutes: Int?
    public var templateID: UUID?
    public var isArchived: Bool = false
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    public var goalID: UUID?
    public var timePrecisionRaw: String = "timed"

    public var timePrecision: ScheduleTimePrecision {
        get { isUnscheduled ? .inbox : (ScheduleTimePrecision(rawValue: timePrecisionRaw) ?? .timed) }
        set {
            timePrecisionRaw = newValue.rawValue
            isUnscheduled = newValue == .inbox
        }
    }

    public var displayStart: Date? { timePrecision == .timed ? plannedStart : nil }
    public var displayEnd: Date? { timePrecision == .timed ? plannedEnd : nil }

    public var priority: ItemPriority {
        get { ItemPriority(rawValue: priorityRaw) ?? .normal }
        set { priorityRaw = newValue.rawValue }
    }

    public var recurrenceRule: RecurrenceRule {
        get {
            RecurrenceRule(
                kind: RecurrenceKind(rawValue: recurrenceKindRaw) ?? .none,
                weekdays: Set(recurrenceWeekdaysCSV.split(separator: ",").compactMap { Int($0) }),
                interval: recurrenceInterval
            )
        }
        set {
            recurrenceKindRaw = newValue.kind.rawValue
            recurrenceWeekdaysCSV = newValue.weekdays.sorted().map(String.init).joined(separator: ",")
            recurrenceInterval = newValue.interval
        }
    }

    public var plannedEnd: Date {
        plannedStart.addingTimeInterval(TimeInterval(plannedDurationMinutes * 60))
    }

    public init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        categoryID: UUID? = nil,
        plannedStart: Date,
        plannedDurationMinutes: Int = 30,
        isUnscheduled: Bool = false,
        timeZoneID: String = TimeZone.current.identifier,
        priority: ItemPriority = .normal,
        recurrenceRule: RecurrenceRule = .init(),
        recurrenceEnd: Date? = nil,
        reminderLead: ReminderLead? = nil,
        templateID: UUID? = nil,
        goalID: UUID? = nil,
        timePrecision: ScheduleTimePrecision = .timed
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.categoryID = categoryID
        self.plannedStart = plannedStart
        self.plannedDurationMinutes = max(1, plannedDurationMinutes)
        self.isUnscheduled = isUnscheduled
        self.timeZoneID = timeZoneID
        self.priorityRaw = priority.rawValue
        self.recurrenceKindRaw = recurrenceRule.kind.rawValue
        self.recurrenceWeekdaysCSV = recurrenceRule.weekdays.sorted().map(String.init).joined(separator: ",")
        self.recurrenceInterval = recurrenceRule.interval
        self.recurrenceEnd = recurrenceEnd
        self.reminderLeadMinutes = reminderLead?.rawValue
        self.templateID = templateID
        self.goalID = goalID
        self.timePrecisionRaw = timePrecision.rawValue
        if timePrecision == .inbox { self.isUnscheduled = true }
    }
}

@Model
public final class OccurrenceLog {
    public var id: UUID = UUID()
    public var occurrenceKey: String = ""
    public var scheduleItemID: UUID = UUID()
    public var originalStart: Date = Date()
    public var overrideStart: Date?
    public var overrideDurationMinutes: Int?
    public var statusRaw: String = OccurrenceStatus.planned.rawValue
    public var actualStart: Date?
    public var actualEnd: Date?
    public var skipReasonRaw: String?
    public var completedAt: Date?
    public var wasRescheduled: Bool = false
    public var fitBetweenCalendarEvents: Bool = false
    public var conflictsResolved: Int = 0
    public var timeZoneID: String = TimeZone.current.identifier
    public var updatedAt: Date = Date()
    public var goalID: UUID?
    public var timePrecisionRaw: String = "timed"
    public var recordedDuringCompanionship: Bool = false
    public var companionSessionID: UUID?

    public var timePrecision: ScheduleTimePrecision {
        get { ScheduleTimePrecision(rawValue: timePrecisionRaw) ?? .timed }
        set { timePrecisionRaw = newValue.rawValue }
    }

    public var status: OccurrenceStatus {
        get { OccurrenceStatus(rawValue: statusRaw) ?? .planned }
        set { statusRaw = newValue.rawValue }
    }

    public var skipReason: SkipReason? {
        get { skipReasonRaw.flatMap(SkipReason.init(rawValue:)) }
        set { skipReasonRaw = newValue?.rawValue }
    }

    public init(scheduleItemID: UUID, originalStart: Date, timeZoneID: String,
                goalID: UUID? = nil, timePrecision: ScheduleTimePrecision = .timed,
                recordedDuringCompanionship: Bool = false, companionSessionID: UUID? = nil) {
        self.scheduleItemID = scheduleItemID
        self.originalStart = originalStart
        self.timeZoneID = timeZoneID
        self.goalID = goalID
        self.timePrecisionRaw = timePrecision.rawValue
        self.recordedDuringCompanionship = recordedDuringCompanionship
        self.companionSessionID = companionSessionID
        self.occurrenceKey = OccurrenceKey.make(itemID: scheduleItemID, originalStart: originalStart, timeZoneID: timeZoneID)
    }
}

@Model
public final class QuickTemplate {
    public var id: UUID = UUID()
    public var title: String = ""
    public var notes: String = ""
    public var categoryID: UUID?
    public var durationMinutes: Int = 30
    public var priorityRaw: String = ItemPriority.normal.rawValue
    public var useCount: Int = 0
    public var createdAt: Date = Date()

    public var priority: ItemPriority {
        get { ItemPriority(rawValue: priorityRaw) ?? .normal }
        set { priorityRaw = newValue.rawValue }
    }

    public init(title: String, notes: String = "", categoryID: UUID? = nil, durationMinutes: Int = 30, priority: ItemPriority = .normal) {
        self.title = title
        self.notes = notes
        self.categoryID = categoryID
        self.durationMinutes = max(1, durationMinutes)
        self.priorityRaw = priority.rawValue
    }
}

@Model
public final class DayReview {
    public var id: UUID = UUID()
    public var day: Date = Date()
    public var timeZoneID: String = TimeZone.current.identifier
    public var completedAt: Date = Date()

    public init(day: Date, timeZoneID: String = TimeZone.current.identifier) {
        self.day = day
        self.timeZoneID = timeZoneID
    }
}

@Model
public final class AchievementState {
    public var id: UUID = UUID()
    public var definitionID: String = ""
    public var progress: Double = 0
    public var signalRaw: String = HiddenSignal.dormant.rawValue
    public var unlockedAt: Date?
    public var definitionVersion: Int = 1
    public var updatedAt: Date = Date()

    public var signal: HiddenSignal {
        get { HiddenSignal(rawValue: signalRaw) ?? .dormant }
        set { signalRaw = newValue.rawValue }
    }

    public init(definitionID: String, definitionVersion: Int = 1) {
        self.definitionID = definitionID
        self.definitionVersion = definitionVersion
    }
}

public struct ScheduleOccurrence: Identifiable, Equatable, Sendable {
    public let id: String
    public let itemID: UUID
    public let title: String
    public let notes: String
    public let categoryID: UUID?
    public let originalStart: Date
    public var start: Date
    public var durationMinutes: Int
    public let isUnscheduled: Bool
    public var status: OccurrenceStatus
    public var actualStart: Date?
    public var actualEnd: Date?
    public let priority: ItemPriority
    public let timeZoneID: String
    public let templateID: UUID?
    public var goalID: UUID? = nil
    public var timePrecision: ScheduleTimePrecision = .timed

    public var end: Date { start.addingTimeInterval(TimeInterval(durationMinutes * 60)) }
    public var displayStart: Date? { !isUnscheduled && timePrecision == .timed ? start : nil }
    public var displayEnd: Date? { !isUnscheduled && timePrecision == .timed ? end : nil }
}

public enum OccurrenceKey {
    public static func make(itemID: UUID, originalStart: Date, timeZoneID: String) -> String {
        "\(itemID.uuidString)|\(Int64(originalStart.timeIntervalSince1970))|\(timeZoneID)"
    }
}
