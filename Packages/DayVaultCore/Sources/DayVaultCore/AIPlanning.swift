import Foundation

public struct PlannerBusyWindow: Codable, Equatable, Sendable {
    public let start: Date
    public let end: Date

    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }

    public var interval: DateInterval { DateInterval(start: start, end: end) }
}

public struct PlannerDailyLoad: Codable, Equatable, Sendable {
    public let day: Date
    public let scheduledMinutes: Int

    public init(day: Date, scheduledMinutes: Int) {
        self.day = day
        self.scheduledMinutes = max(0, scheduledMinutes)
    }
}

public struct PlannerRequest: Codable, Equatable, Sendable {
    public let goalText: String
    public let clarificationAnswer: String?
    public let currentDate: Date
    public let timeZoneID: String
    public let locale: String
    public let busyWindows: [PlannerBusyWindow]
    public let existingDailyLoads: [PlannerDailyLoad]
    public let activeChallengeIDs: [UUID]

    public init(
        goalText: String,
        clarificationAnswer: String? = nil,
        currentDate: Date = Date(),
        timeZoneID: String = TimeZone.current.identifier,
        locale: String = Locale.current.identifier,
        busyWindows: [PlannerBusyWindow] = [],
        existingDailyLoads: [PlannerDailyLoad] = [],
        activeChallengeIDs: [UUID] = []
    ) {
        self.goalText = goalText
        self.clarificationAnswer = clarificationAnswer
        self.currentDate = currentDate
        self.timeZoneID = timeZoneID
        self.locale = locale
        self.busyWindows = busyWindows
        self.existingDailyLoads = existingDailyLoads
        self.activeChallengeIDs = activeChallengeIDs
    }
}

public enum PlannerTurnKind: String, Codable, Sendable {
    case clarification
    case plan
}

public struct PlannerClarification: Codable, Equatable, Sendable {
    public let question: String

    public init(question: String) {
        self.question = question
    }
}

public struct PlanPhase: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let summary: String
    public let start: Date
    public let end: Date

    public init(id: UUID = UUID(), title: String, summary: String, start: Date, end: Date) {
        self.id = id
        self.title = title
        self.summary = summary
        self.start = start
        self.end = end
    }
}

public struct PlanMilestone: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let due: Date
    public let definitionOfDone: String

    public init(id: UUID = UUID(), title: String, due: Date, definitionOfDone: String) {
        self.id = id
        self.title = title
        self.due = due
        self.definitionOfDone = definitionOfDone
    }
}

public struct GeneratedPlanBlock: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let start: Date
    public let durationMinutes: Int
    public let notes: String
    public let balanceGroup: BalanceGroup

    public init(
        id: UUID = UUID(),
        title: String,
        start: Date,
        durationMinutes: Int,
        notes: String = "",
        balanceGroup: BalanceGroup = .focus
    ) {
        self.id = id
        self.title = title
        self.start = start
        self.durationMinutes = durationMinutes
        self.notes = notes
        self.balanceGroup = balanceGroup
    }

    public var end: Date {
        start.addingTimeInterval(TimeInterval(durationMinutes * 60))
    }
}

public struct GeneratedPlanPattern: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let weekdays: Set<Int>
    public let startMinutesFromMidnight: Int
    public let durationMinutes: Int
    public let endDate: Date
    public let balanceGroup: BalanceGroup

    public init(
        id: UUID = UUID(),
        title: String,
        weekdays: Set<Int>,
        startMinutesFromMidnight: Int,
        durationMinutes: Int,
        endDate: Date,
        balanceGroup: BalanceGroup = .focus
    ) {
        self.id = id
        self.title = title
        self.weekdays = weekdays
        self.startMinutesFromMidnight = startMinutesFromMidnight
        self.durationMinutes = durationMinutes
        self.endDate = endDate
        self.balanceGroup = balanceGroup
    }
}

public struct GeneratedProjectPlan: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let skillVersion: String
    public let title: String
    public let clarifiedGoal: String
    public let deadline: Date
    public let phases: [PlanPhase]
    public let milestones: [PlanMilestone]
    public let initialBlocks: [GeneratedPlanBlock]
    public let recurringPatterns: [GeneratedPlanPattern]
    public let recommendedChallengeID: UUID?
    public let assumptions: [String]
    public let warnings: [String]

    public init(
        id: UUID = UUID(),
        skillVersion: String = "1.0.0",
        title: String,
        clarifiedGoal: String,
        deadline: Date,
        phases: [PlanPhase],
        milestones: [PlanMilestone],
        initialBlocks: [GeneratedPlanBlock],
        recurringPatterns: [GeneratedPlanPattern] = [],
        recommendedChallengeID: UUID? = nil,
        assumptions: [String] = [],
        warnings: [String] = []
    ) {
        self.id = id
        self.skillVersion = skillVersion
        self.title = title
        self.clarifiedGoal = clarifiedGoal
        self.deadline = deadline
        self.phases = phases
        self.milestones = milestones
        self.initialBlocks = initialBlocks
        self.recurringPatterns = recurringPatterns
        self.recommendedChallengeID = recommendedChallengeID
        self.assumptions = assumptions
        self.warnings = warnings
    }
}

public struct PlannerTurn: Codable, Equatable, Sendable {
    public let kind: PlannerTurnKind
    public let question: String?
    public let plan: GeneratedProjectPlan?

    public init(kind: PlannerTurnKind, question: String? = nil, plan: GeneratedProjectPlan? = nil) {
        self.kind = kind
        self.question = question
        self.plan = plan
    }

    public static func clarification(_ question: String) -> PlannerTurn {
        PlannerTurn(kind: .clarification, question: question)
    }

    public static func plan(_ plan: GeneratedProjectPlan) -> PlannerTurn {
        PlannerTurn(kind: .plan, plan: plan)
    }
}

public protocol AIPlanning: Sendable {
    func generate(_ request: PlannerRequest) async throws -> PlannerTurn
}

public enum PlanValidationError: Error, Equatable, Sendable {
    case missingPlan
    case invalidDeadline
    case invalidPhaseCount
    case tooManyBlocks
    case duplicateBlockID
    case invalidDuration
    case blockAfterDeadline
    case blockBeforeRequest
    case busyWindowConflict
    case tooManyDemandingBlocks
    case unknownChallenge
}

public enum GeneratedPlanValidator {
    public static func validate(_ turn: PlannerTurn, for request: PlannerRequest) throws {
        if turn.kind == .clarification {
            guard let question = turn.question, !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw PlanValidationError.missingPlan
            }
            return
        }

        guard let plan = turn.plan else { throw PlanValidationError.missingPlan }
        guard plan.deadline > request.currentDate else { throw PlanValidationError.invalidDeadline }
        guard (2...5).contains(plan.phases.count) else { throw PlanValidationError.invalidPhaseCount }
        guard plan.initialBlocks.count <= 100 else { throw PlanValidationError.tooManyBlocks }
        guard Set(plan.initialBlocks.map(\.id)).count == plan.initialBlocks.count else { throw PlanValidationError.duplicateBlockID }

        var demandingByDay: [Date: Int] = [:]
        let calendar = Calendar(identifier: .gregorian)
        for block in plan.initialBlocks {
            guard (15...180).contains(block.durationMinutes) else { throw PlanValidationError.invalidDuration }
            guard block.start >= request.currentDate.addingTimeInterval(-60) else { throw PlanValidationError.blockBeforeRequest }
            guard block.end <= plan.deadline.addingTimeInterval(60) else { throw PlanValidationError.blockAfterDeadline }
            if request.busyWindows.contains(where: { $0.start < block.end && $0.end > block.start }) {
                throw PlanValidationError.busyWindowConflict
            }
            if block.balanceGroup == .focus {
                let day = calendar.startOfDay(for: block.start)
                demandingByDay[day, default: 0] += 1
                if demandingByDay[day, default: 0] > 2 { throw PlanValidationError.tooManyDemandingBlocks }
            }
        }

        if let challengeID = plan.recommendedChallengeID,
           !request.activeChallengeIDs.contains(challengeID) {
            throw PlanValidationError.unknownChallenge
        }
    }
}

public struct CommunityChallengeDefinition: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let titleKey: String
    public let subtitleKey: String
    public let promptKey: String
    public let symbolName: String
    public let durationDays: Int
    public let participantCount: Int?
    public let isTrending: Bool

    public init(
        id: UUID,
        titleKey: String,
        subtitleKey: String,
        promptKey: String,
        symbolName: String,
        durationDays: Int,
        participantCount: Int? = nil,
        isTrending: Bool = false
    ) {
        self.id = id
        self.titleKey = titleKey
        self.subtitleKey = subtitleKey
        self.promptKey = promptKey
        self.symbolName = symbolName
        self.durationDays = durationDays
        self.participantCount = participantCount
        self.isTrending = isTrending && (participantCount ?? 0) >= 100
    }
}

public enum StarterChallengeCatalog {
    public static let focusSprintID = UUID(uuidString: "81AD0D9D-9500-4F15-8D47-9AC7AE75E5A1")!
    public static let readingTrailID = UUID(uuidString: "D9C25FB6-814E-4B82-A890-B86048804B8C")!
    public static let smallWinsID = UUID(uuidString: "4DA13BE0-52CE-49DB-B9DA-F5D68AF3EF35")!

    public static let all: [CommunityChallengeDefinition] = [
        CommunityChallengeDefinition(
            id: focusSprintID,
            titleKey: "challenge.focus.title",
            subtitleKey: "challenge.focus.subtitle",
            promptKey: "challenge.focus.prompt",
            symbolName: "scope",
            durationDays: 7
        ),
        CommunityChallengeDefinition(
            id: readingTrailID,
            titleKey: "challenge.read.title",
            subtitleKey: "challenge.read.subtitle",
            promptKey: "challenge.read.prompt",
            symbolName: "book.pages.fill",
            durationDays: 14
        ),
        CommunityChallengeDefinition(
            id: smallWinsID,
            titleKey: "challenge.small.title",
            subtitleKey: "challenge.small.subtitle",
            promptKey: "challenge.small.prompt",
            symbolName: "sparkles",
            durationDays: 7
        ),
    ]
}
