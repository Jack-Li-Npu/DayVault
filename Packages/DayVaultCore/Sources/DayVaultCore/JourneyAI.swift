import Foundation

public enum JourneyAIOperation: String, Codable, Sendable {
    case designAchievements, companionReply, suggestAdjustment
}

public struct JourneyAIFact: Codable, Equatable, Sendable {
    public let id: String
    public let text: String
    public init(id: String, text: String) { self.id = id; self.text = text }
}

/// A host-filtered snapshot, never a permission to mutate the matching record.
public struct JourneyAIOccurrence: Codable, Equatable, Sendable {
    public let id: String
    public let goalID: UUID
    public let start: Date
    public let durationMinutes: Int
    public let isTimed: Bool
    public let revision: String
    public init(id: String, goalID: UUID, start: Date, durationMinutes: Int, isTimed: Bool, revision: String) {
        self.id = id; self.goalID = goalID; self.start = start
        self.durationMinutes = durationMinutes; self.isTimed = isTimed; self.revision = revision
    }
}

/// Deliberately has no hidden achievement definition, rule, clue or progress fields.
public struct JourneyAIRequest: Codable, Equatable, Sendable {
    public let requestID: UUID
    public let operation: JourneyAIOperation
    public let goalID: UUID
    public let goalTitle: String
    public let currentDate: Date
    public let timeZoneID: String
    public let message: String
    public let facts: [JourneyAIFact]
    public let confirmedMemories: [JourneyAIFact]
    public let allowedOccurrences: [JourneyAIOccurrence]
    public let busyWindows: [PlannerBusyWindow]
    public let restWindows: [PlannerBusyWindow]
    public let achievementConsent: Bool
    public let cycleIsConfigured: Bool

    public init(operation: JourneyAIOperation, goalID: UUID, goalTitle: String, currentDate: Date = Date(), timeZoneID: String = TimeZone.current.identifier, message: String = "", facts: [JourneyAIFact] = [], confirmedMemories: [JourneyAIFact] = [], allowedOccurrences: [JourneyAIOccurrence] = [], busyWindows: [PlannerBusyWindow] = [], restWindows: [PlannerBusyWindow] = [], achievementConsent: Bool = false, cycleIsConfigured: Bool = false, requestID: UUID = UUID()) {
        self.requestID = requestID
        self.operation = operation; self.goalID = goalID; self.goalTitle = goalTitle
        self.currentDate = currentDate; self.timeZoneID = timeZoneID; self.message = message
        self.facts = facts; self.confirmedMemories = confirmedMemories; self.allowedOccurrences = allowedOccurrences
        self.busyWindows = busyWindows; self.restWindows = restWindows
        self.achievementConsent = achievementConsent; self.cycleIsConfigured = cycleIsConfigured
    }

    public var allowedSourceIDs: Set<String> {
        var ids = Set((facts + confirmedMemories).map(\.id)).union(["goal"])
        if !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { ids.insert("message") }
        return ids
    }
}

public enum JourneyAchievementRuleType: String, Codable, Sendable {
    case completionCount, activeDays, completedCycles
}

public struct JourneyAchievementDraft: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let detail: String
    public let ruleType: JourneyAchievementRuleType
    public let target: Int
    public let isHidden: Bool
    public let clue: String
    public let badgeStyleKey: String
    public let sourceIDs: [String]
    public init(id: String, name: String, detail: String, ruleType: JourneyAchievementRuleType, target: Int, isHidden: Bool, clue: String, badgeStyleKey: String, sourceIDs: [String]) {
        self.id = id; self.name = name; self.detail = detail; self.ruleType = ruleType; self.target = target
        self.isHidden = isHidden; self.clue = clue; self.badgeStyleKey = badgeStyleKey; self.sourceIDs = sourceIDs
    }
}

public struct JourneyAchievementDesign: Codable, Equatable, Sendable {
    public let skillVersion: String
    public let goalID: UUID
    public let achievements: [JourneyAchievementDraft]
    public init(skillVersion: String = "1.0.0", goalID: UUID, achievements: [JourneyAchievementDraft]) {
        self.skillVersion = skillVersion; self.goalID = goalID; self.achievements = achievements
    }
}

public struct JourneyCompanionReply: Codable, Equatable, Sendable {
    public let skillVersion: String
    public let goalID: UUID
    public let text: String
    public let sourceIDs: [String]
    public let memoryCandidate: String?
    public init(skillVersion: String = "1.0.0", goalID: UUID, text: String, sourceIDs: [String], memoryCandidate: String? = nil) {
        self.skillVersion = skillVersion; self.goalID = goalID; self.text = text
        self.sourceIDs = sourceIDs; self.memoryCandidate = memoryCandidate
    }
}

public struct JourneyAdjustmentChange: Codable, Equatable, Sendable {
    public let occurrenceID: String
    public let newStart: Date
    public init(occurrenceID: String, newStart: Date) { self.occurrenceID = occurrenceID; self.newStart = newStart }
}

public struct JourneyAdjustmentSuggestion: Codable, Equatable, Sendable {
    public let skillVersion: String
    public let goalID: UUID
    public let summary: String
    public let changes: [JourneyAdjustmentChange]
    public let sourceIDs: [String]
    public init(skillVersion: String = "1.0.0", goalID: UUID, summary: String, changes: [JourneyAdjustmentChange], sourceIDs: [String]) {
        self.skillVersion = skillVersion; self.goalID = goalID; self.summary = summary
        self.changes = changes; self.sourceIDs = sourceIDs
    }
}

public protocol JourneyAI: Sendable {
    func designAchievements(_ request: JourneyAIRequest) async throws -> JourneyAchievementDesign
    func companionReply(_ request: JourneyAIRequest) async throws -> JourneyCompanionReply
    func suggestAdjustment(_ request: JourneyAIRequest) async throws -> JourneyAdjustmentSuggestion
}

public enum JourneyAIValidationError: Error, Equatable, Sendable {
    case invalidRequest, wrongOperation, wrongGoal, unsupportedVersion, invalidAchievement, invalidSources, invalidReply, invalidAdjustment
}

public enum JourneyAIValidator {
    public static let badgeStyleKeys: Set<String> = ["crest", "orbit", "steps", "spark", "ribbon"]

    public static func validateRequest(_ request: JourneyAIRequest, operation: JourneyAIOperation) throws {
        guard request.operation == operation else { throw JourneyAIValidationError.wrongOperation }
        guard (1...500).contains(request.goalTitle.count), !request.goalTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, request.message.count <= 2_000,
              TimeZone(identifier: request.timeZoneID) != nil,
              request.currentDate.timeIntervalSince1970.isFinite,
              request.facts.count <= 40, request.confirmedMemories.count <= 10,
              request.allowedOccurrences.count <= 100,
              request.busyWindows.count + request.restWindows.count <= 200 else { throw JourneyAIValidationError.invalidRequest }
        let facts = request.facts + request.confirmedMemories
        guard Set(facts.map(\.id)).count == facts.count,
              facts.allSatisfy({ !$0.id.isEmpty && $0.id.count <= 200 && !["goal", "message"].contains($0.id) && !$0.text.isEmpty && $0.text.count <= 1_000 }),
              Set(request.allowedOccurrences.map(\.id)).count == request.allowedOccurrences.count else { throw JourneyAIValidationError.invalidRequest }
        guard (request.busyWindows + request.restWindows).allSatisfy({ $0.start < $0.end }) else { throw JourneyAIValidationError.invalidRequest }
        guard request.allowedOccurrences.allSatisfy({ $0.goalID == request.goalID && (1...200).contains($0.id.count) && (1...200).contains($0.revision.count) && $0.start.timeIntervalSince1970.isFinite && (1...720).contains($0.durationMinutes) }) else { throw JourneyAIValidationError.invalidRequest }
        if operation == .designAchievements && !request.achievementConsent { throw JourneyAIValidationError.invalidRequest }
    }

    public static func validate(_ response: JourneyAchievementDesign, for request: JourneyAIRequest) throws {
        try validateRequest(request, operation: .designAchievements)
        try validateHeader(response.skillVersion, goalID: response.goalID, request: request)
        guard (1...3).contains(response.achievements.count), response.achievements.filter({ !$0.isHidden }).count <= 2,
              response.achievements.filter(\.isHidden).count <= 1,
              Set(response.achievements.map(\.id)).count == response.achievements.count else { throw JourneyAIValidationError.invalidAchievement }
        for achievement in response.achievements {
            guard (1...64).contains(achievement.id.count), (1...40).contains(achievement.name.count),
                  (1...300).contains(achievement.detail.count), achievement.clue.count <= 120,
                  (1...1_000).contains(achievement.target), badgeStyleKeys.contains(achievement.badgeStyleKey),
                  achievement.ruleType != .completedCycles || request.cycleIsConfigured,
                  !achievement.isHidden || !achievement.clue.isEmpty else { throw JourneyAIValidationError.invalidAchievement }
            try validateSources(achievement.sourceIDs, request: request)
        }
    }

    public static func validate(_ response: JourneyCompanionReply, for request: JourneyAIRequest) throws {
        try validateRequest(request, operation: .companionReply)
        try validateHeader(response.skillVersion, goalID: response.goalID, request: request)
        guard (1...600).contains(response.text.count), !response.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              (response.memoryCandidate?.count ?? 0) <= 200 else { throw JourneyAIValidationError.invalidReply }
        if let memory = response.memoryCandidate {
            guard !memory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !request.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw JourneyAIValidationError.invalidReply }
        }
        try validateSources(response.sourceIDs, request: request)
    }

    public static func validate(_ response: JourneyAdjustmentSuggestion, for request: JourneyAIRequest) throws {
        try validateRequest(request, operation: .suggestAdjustment)
        try validateHeader(response.skillVersion, goalID: response.goalID, request: request)
        try validateSources(response.sourceIDs, request: request)
        guard (1...600).contains(response.summary.count), response.changes.count <= 100,
              Set(response.changes.map(\.occurrenceID)).count == response.changes.count else { throw JourneyAIValidationError.invalidAdjustment }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: request.timeZoneID)!
        guard let horizon = calendar.date(byAdding: .day, value: 7, to: request.currentDate) else { throw JourneyAIValidationError.invalidAdjustment }
        let byID = Dictionary(uniqueKeysWithValues: request.allowedOccurrences.map { ($0.id, $0) })
        let changes = Dictionary(uniqueKeysWithValues: response.changes.map { ($0.occurrenceID, $0.newStart) })
        for change in response.changes {
            guard let occurrence = byID[change.occurrenceID] else { throw JourneyAIValidationError.invalidAdjustment }
            if !occurrence.isTimed {
                let today = calendar.startOfDay(for: request.currentDate)
                guard let dayHorizon = calendar.date(byAdding: .day, value: 7, to: today),
                      occurrence.start >= today, occurrence.start < dayHorizon,
                      change.newStart >= today, change.newStart < dayHorizon,
                      let targetDayEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: change.newStart)) else { throw JourneyAIValidationError.invalidAdjustment }
                let targetDay = calendar.startOfDay(for: change.newStart)
                guard !request.restWindows.contains(where: { $0.start < targetDayEnd && $0.end > targetDay }) else { throw JourneyAIValidationError.invalidAdjustment }
                guard calendar.component(.hour, from: change.newStart) == calendar.component(.hour, from: occurrence.start),
                      calendar.component(.minute, from: change.newStart) == calendar.component(.minute, from: occurrence.start),
                      calendar.component(.second, from: change.newStart) == calendar.component(.second, from: occurrence.start) else { throw JourneyAIValidationError.invalidAdjustment }
                continue // Day-only plans do not invent an hourly blocking interval.
            }
            guard occurrence.start >= request.currentDate, occurrence.start < horizon,
                  change.newStart >= request.currentDate, change.newStart < horizon else { throw JourneyAIValidationError.invalidAdjustment }
            let end = change.newStart.addingTimeInterval(TimeInterval(occurrence.durationMinutes * 60))
            guard end <= horizon, !(request.busyWindows + request.restWindows).contains(where: { $0.start < end && $0.end > change.newStart }) else { throw JourneyAIValidationError.invalidAdjustment }
            guard !request.allowedOccurrences.contains(where: { other in
                guard other.id != occurrence.id, other.isTimed else { return false }
                let otherStart = changes[other.id] ?? other.start
                return otherStart < end && otherStart.addingTimeInterval(TimeInterval(other.durationMinutes * 60)) > change.newStart
            }) else { throw JourneyAIValidationError.invalidAdjustment }
        }
    }

    private static func validateHeader(_ version: String, goalID: UUID, request: JourneyAIRequest) throws {
        guard version == "1.0.0" else { throw JourneyAIValidationError.unsupportedVersion }
        guard goalID == request.goalID else { throw JourneyAIValidationError.wrongGoal }
    }

    private static func validateSources(_ ids: [String], request: JourneyAIRequest) throws {
        guard !ids.isEmpty, ids.count <= 20, Set(ids).count == ids.count,
              Set(ids).isSubset(of: request.allowedSourceIDs) else { throw JourneyAIValidationError.invalidSources }
    }
}
