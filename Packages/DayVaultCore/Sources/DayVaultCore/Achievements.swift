import Foundation

public enum HiddenSignal: String, Codable, CaseIterable, Sendable {
    case dormant, faint, resonant

    public static func from(progress: Double) -> HiddenSignal {
        if progress >= 0.8 { return .resonant }
        if progress >= 0.4 { return .faint }
        return .dormant
    }
}

public enum AchievementCategory: String, Codable, CaseIterable, Sendable {
    case beginnings, consistency, reflection, mastery, balance, discovery
}

public struct AchievementDefinition: Identifiable, Equatable, Sendable {
    public let id: String
    public let titleKey: String
    public let descriptionKey: String
    public let clueKey: String?
    public let symbolName: String
    public let category: AchievementCategory
    public let isHidden: Bool
    public let target: Double
    public let version: Int

    public init(
        id: String,
        titleKey: String,
        descriptionKey: String,
        clueKey: String? = nil,
        symbolName: String,
        category: AchievementCategory,
        isHidden: Bool = false,
        target: Double = 1,
        version: Int = 1
    ) {
        self.id = id
        self.titleKey = titleKey
        self.descriptionKey = descriptionKey
        self.clueKey = clueKey
        self.symbolName = symbolName
        self.category = category
        self.isHidden = isHidden
        self.target = target
        self.version = version
    }
}

public enum AchievementCatalog {
    public static let all: [AchievementDefinition] = [
        visible("first_block", "square.grid.2x2.fill", .beginnings, 1),
        visible("first_check", "checkmark.seal.fill", .beginnings, 1),
        visible("timekeeper_1", "hourglass.bottomhalf.filled", .mastery, 10),
        visible("timekeeper_2", "hourglass.circle.fill", .mastery, 50),
        visible("timekeeper_3", "clock.badge.checkmark.fill", .mastery, 200),
        visible("steady_start", "flame.fill", .consistency, 3),
        visible("in_rhythm", "waveform.path.ecg", .consistency, 7),
        visible("month_in_motion", "calendar.badge.checkmark", .consistency, 20),
        visible("reflective_1", "book.closed.fill", .reflection, 5),
        visible("reflective_2", "books.vertical.fill", .reflection, 20),
        visible("template_maker", "square.on.square.badge.person.crop.fill", .discovery, 3),
        visible("familiar_route", "arrow.trianglehead.2.clockwise.rotate.90", .mastery, 10),
        visible("honest_clock", "timer", .reflection, 10),
        visible("on_time", "clock.badge.checkmark", .mastery, 10),
        visible("flexible_planner", "arrowshape.turn.up.right.fill", .mastery, 5),
        visible("balanced_week", "circle.hexagongrid.fill", .balance, 1),
        hidden("second_wind", "wind", .consistency),
        hidden("balanced_orbit", "circle.grid.cross.fill", .balance),
        hidden("found_time", "sparkles.rectangle.stack.fill", .discovery),
        hidden("calendar_tetris", "square.grid.3x3.fill", .mastery),
        hidden("human_factor", "heart.text.square.fill", .balance),
        hidden("just_enough", "scalemass.fill", .reflection),
        hidden("clean_slate", "wand.and.sparkles", .reflection),
        hidden("vault_keeper", "lock.open.fill", .discovery),
    ]

    private static func visible(_ id: String, _ symbol: String, _ category: AchievementCategory, _ target: Double) -> AchievementDefinition {
        AchievementDefinition(
            id: id,
            titleKey: "achievement.\(id).title",
            descriptionKey: "achievement.\(id).description",
            symbolName: symbol,
            category: category,
            target: target
        )
    }

    private static func hidden(_ id: String, _ symbol: String, _ category: AchievementCategory) -> AchievementDefinition {
        AchievementDefinition(
            id: id,
            titleKey: "achievement.\(id).title",
            descriptionKey: "achievement.\(id).description",
            clueKey: "achievement.\(id).clue",
            symbolName: symbol,
            category: category,
            isHidden: true
        )
    }
}

public struct AchievementSnapshot: Sendable {
    public var createdItemCount = 0
    public var completionCount = 0
    public var longestScheduledDayStreak = 0
    public var activeDaysInRolling30 = 0
    public var reviewCount = 0
    public var createdAndUsedTemplateCount = 0
    public var maxTemplateCompletionCount = 0
    public var actualTimeCount = 0
    public var onTimeCount = 0
    public var rescheduledAndCompletedCount = 0
    public var balancedWeek = false
    public var secondWindProgress = 0.0
    public var balancedOrbitProgress = 0.0
    public var foundTimeProgress = 0.0
    public var calendarTetrisProgress = 0.0
    public var humanFactorProgress = 0.0
    public var justEnoughProgress = 0.0
    public var cleanSlateProgress = 0.0
    public var unlockedVisibleCategories = 0

    public init() {}
}

public struct AchievementEvaluation: Equatable, Sendable {
    public let definitionID: String
    public let progress: Double
    public let signal: HiddenSignal
    public let shouldUnlock: Bool
}

public enum AchievementEngine {
    public static func evaluate(snapshot: AchievementSnapshot) -> [AchievementEvaluation] {
        AchievementCatalog.all.map { definition in
            let raw = value(for: definition.id, snapshot: snapshot)
            let normalized = min(1, max(0, raw / max(1, definition.target)))
            return AchievementEvaluation(
                definitionID: definition.id,
                progress: normalized,
                signal: HiddenSignal.from(progress: normalized),
                shouldUnlock: normalized >= 1
            )
        }
    }

    private static func value(for id: String, snapshot: AchievementSnapshot) -> Double {
        switch id {
        case "first_block": Double(snapshot.createdItemCount)
        case "first_check", "timekeeper_1", "timekeeper_2", "timekeeper_3": Double(snapshot.completionCount)
        case "steady_start", "in_rhythm": Double(snapshot.longestScheduledDayStreak)
        case "month_in_motion": Double(snapshot.activeDaysInRolling30)
        case "reflective_1", "reflective_2": Double(snapshot.reviewCount)
        case "template_maker": Double(snapshot.createdAndUsedTemplateCount)
        case "familiar_route": Double(snapshot.maxTemplateCompletionCount)
        case "honest_clock": Double(snapshot.actualTimeCount)
        case "on_time": Double(snapshot.onTimeCount)
        case "flexible_planner": Double(snapshot.rescheduledAndCompletedCount)
        case "balanced_week": snapshot.balancedWeek ? 1 : 0
        case "second_wind": snapshot.secondWindProgress
        case "balanced_orbit": snapshot.balancedOrbitProgress
        case "found_time": snapshot.foundTimeProgress
        case "calendar_tetris": snapshot.calendarTetrisProgress
        case "human_factor": snapshot.humanFactorProgress
        case "just_enough": snapshot.justEnoughProgress
        case "clean_slate": snapshot.cleanSlateProgress
        case "vault_keeper": min(1, Double(snapshot.unlockedVisibleCategories) / Double(AchievementCategory.allCases.count))
        default: 0
        }
    }
}

