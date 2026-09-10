import Foundation
import SwiftData

public enum ScheduleTimePrecision: String, Codable, CaseIterable, Sendable {
    case dateOnly, timed, inbox
}

@Model
public final class PersonalGoal {
    public var id: UUID = UUID()
    public var title: String = ""
    public var deadline: Date?
    public var createdAt: Date = Date()
    public var timeZoneID: String = TimeZone.current.identifier
    public var acceptedPlanJSON: String = ""
    public var weeklyTargetDays: Int?
    public var aiEnabledAt: Date?
    public var achievementBatchID: UUID?
    public var achievementGenerationState: String = "idle"
    public var restWeekdaysCSV: String = ""
    public var companionRecordedDayKeysJSON: String = "[]"
    public var updatedAt: Date = Date()

    public init(id: UUID = UUID(), title: String, deadline: Date? = nil,
                timeZoneID: String = TimeZone.current.identifier,
                acceptedPlanJSON: String = "", weeklyTargetDays: Int? = nil,
                aiEnabledAt: Date? = nil, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.deadline = deadline
        self.timeZoneID = timeZoneID
        self.acceptedPlanJSON = acceptedPlanJSON
        self.weeklyTargetDays = weeklyTargetDays
        self.aiEnabledAt = aiEnabledAt
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }
}

public enum PersonalAchievementRuleKind: String, Codable, CaseIterable, Sendable {
    case completionCount, activeDays, completedCycles
}

/// The host freezes this rule on acceptance. AI prose never decides eligibility.
public struct PersonalAchievementRule: Codable, Equatable, Sendable {
    public let kind: PersonalAchievementRuleKind
    public let target: Int
    public let startsAt: Date
    public let endsAt: Date?
    public let timeZoneID: String
    public let cycleLengthDays: Int
    public let requiredDaysPerCycle: Int
    public let cycleAnchor: Date?

    public init(kind: PersonalAchievementRuleKind, target: Int, startsAt: Date,
                endsAt: Date? = nil, timeZoneID: String,
                cycleLengthDays: Int = 7, requiredDaysPerCycle: Int = 5, cycleAnchor: Date? = nil) {
        self.kind = kind
        self.target = target
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.timeZoneID = timeZoneID
        self.cycleLengthDays = cycleLengthDays
        self.requiredDaysPerCycle = requiredDaysPerCycle
        self.cycleAnchor = cycleAnchor
    }

    public var isValid: Bool {
        guard target > 0, target <= 10_000, startsAt.timeIntervalSince1970.isFinite,
              TimeZone(identifier: timeZoneID) != nil,
              (1...31).contains(cycleLengthDays),
              (1...cycleLengthDays).contains(requiredDaysPerCycle) else { return false }
        if let cycleAnchor, !cycleAnchor.timeIntervalSince1970.isFinite { return false }
        if let endsAt { return endsAt.timeIntervalSince1970.isFinite && endsAt > startsAt }
        return true
    }
}

@Model
public final class PersonalAchievementDefinition {
    public var id: UUID = UUID()
    public private(set) var goalID: UUID = UUID()
    public private(set) var batchID: UUID = UUID()
    /// One immutable response generation. The whole batch is reconciled together.
    public var batchGenerationID: UUID = UUID()
    public var batchCreatedAt: Date = Date()
    public var batchExpectedCount: Int = 1
    public var title: String = ""
    public var detail: String = ""
    public var clue: String = ""
    public var badgeStyleID: String = "patch"
    public var isHidden: Bool = false
    public private(set) var ruleJSON: String = ""
    public private(set) var ruleVersion: Int = 1
    public var confirmedAt: Date?
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    public var archivedAt: Date?

    public var definitionKey: String { "personal:\(id.uuidString.lowercased()):v\(ruleVersion)" }
    public var rule: PersonalAchievementRule? { JourneyJSON.decode(PersonalAchievementRule.self, from: ruleJSON) }

    public init(id: UUID = UUID(), goalID: UUID, batchID: UUID, title: String, detail: String = "",
                clue: String = "", badgeStyleID: String = "patch", isHidden: Bool = false,
                rule: PersonalAchievementRule, ruleVersion: Int = 1,
                confirmedAt: Date? = nil, createdAt: Date = Date(),
                batchGenerationID: UUID? = nil, batchCreatedAt: Date? = nil,
                batchExpectedCount: Int = 1) {
        self.id = id
        self.goalID = goalID
        self.batchID = batchID
        self.batchGenerationID = batchGenerationID ?? batchID
        self.batchCreatedAt = batchCreatedAt ?? createdAt
        self.batchExpectedCount = batchExpectedCount
        self.title = title
        self.detail = detail
        self.clue = clue
        self.badgeStyleID = badgeStyleID
        self.isHidden = isHidden
        self.ruleJSON = JourneyJSON.encode(rule) ?? ""
        self.ruleVersion = ruleVersion
        self.confirmedAt = confirmedAt
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }
}

/// An immutable receipt for an unlock, distinct from its current recomputed progress.
@Model
public final class PersonalAchievementEvidence {
    public var id: UUID = UUID()
    public var definitionKey: String = ""
    public var goalID: UUID = UUID()
    public var unlockedAt: Date = Date()
    public var occurrenceKeysJSON: String = "[]"
    public var sourceVersionsJSON: String = "{}"
    public var ruleJSON: String = ""
    public var metricValue: Int = 0
    public var createdAt: Date = Date()

    public var occurrenceKeys: [String] {
        JourneyJSON.decode([String].self, from: occurrenceKeysJSON) ?? []
    }

    public init(id: UUID = UUID(), definitionKey: String, goalID: UUID,
                unlockedAt: Date, occurrenceKeys: [String], ruleJSON: String, metricValue: Int) {
        self.id = id
        self.definitionKey = definitionKey
        self.goalID = goalID
        self.unlockedAt = unlockedAt
        self.occurrenceKeysJSON = JourneyJSON.encode(Array(Set(occurrenceKeys)).sorted()) ?? "[]"
        self.ruleJSON = ruleJSON
        self.metricValue = metricValue
        self.createdAt = Date()
    }
}

@Model
public final class CompanionMessage {
    public var id: UUID = UUID()
    public var goalID: UUID?
    public var role: String = "assistant"
    public var text: String = ""
    public var sourceOccurrenceKeysJSON: String = "[]"
    public var createdAt: Date = Date()
    public var isLocalFallback: Bool = false
    public var sourceVersionsJSON: String = "{}"
    public var generationVersion: String = "1.0.0"
    public var triggerKey: String?

    public var sourceOccurrenceKeys: [String] {
        JourneyJSON.decode([String].self, from: sourceOccurrenceKeysJSON) ?? []
    }

    public init(id: UUID = UUID(), goalID: UUID? = nil, role: String = "assistant", text: String,
                sourceOccurrenceKeys: [String] = [], createdAt: Date = Date(), isLocalFallback: Bool = false) {
        self.id = id
        self.goalID = goalID
        self.role = role
        self.text = text
        self.sourceOccurrenceKeysJSON = JourneyJSON.encode(sourceOccurrenceKeys) ?? "[]"
        self.createdAt = createdAt
        self.isLocalFallback = isLocalFallback
    }
}

@Model
public final class CompanionMemory {
    public var id: UUID = UUID()
    public var goalID: UUID?
    public var text: String = ""
    public var sourceOccurrenceKeysJSON: String = "[]"
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    public var sourceVersionsJSON: String = "{}"
    public var isConfirmed: Bool = true

    public var sourceOccurrenceKeys: [String] {
        JourneyJSON.decode([String].self, from: sourceOccurrenceKeysJSON) ?? []
    }

    public init(id: UUID = UUID(), goalID: UUID? = nil, text: String,
                sourceOccurrenceKeys: [String] = [], createdAt: Date = Date()) {
        self.id = id
        self.goalID = goalID
        self.text = text
        self.sourceOccurrenceKeysJSON = JourneyJSON.encode(sourceOccurrenceKeys) ?? "[]"
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }
}

@Model
public final class PlanAdjustmentRecord {
    public var id: UUID = UUID()
    public var goalID: UUID = UUID()
    public var reason: String = ""
    public var beforeJSON: String = ""
    public var afterJSON: String = ""
    public var sourceOccurrenceKeysJSON: String = "[]"
    public var createdAt: Date = Date()
    public var appliedAt: Date?
    public var revertedAt: Date?

    public init(id: UUID = UUID(), goalID: UUID, reason: String, beforeJSON: String,
                afterJSON: String, sourceOccurrenceKeys: [String] = [], createdAt: Date = Date(), appliedAt: Date? = nil) {
        self.id = id
        self.goalID = goalID
        self.reason = reason
        self.beforeJSON = beforeJSON
        self.afterJSON = afterJSON
        self.sourceOccurrenceKeysJSON = JourneyJSON.encode(sourceOccurrenceKeys) ?? "[]"
        self.createdAt = createdAt
        self.appliedAt = appliedAt
    }
}

public enum JourneyJSON {
    public static func encode<T: Encodable>(_ value: T) -> String? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public static func decode<T: Decodable>(_ type: T.Type, from string: String) -> T? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(type, from: Data(string.utf8))
    }
}
