import Foundation

public struct PersonalAchievementEvaluation: Equatable, Sendable {
    public let definitionID: UUID
    public let definitionKey: String
    public let progress: Double
    public let signal: HiddenSignal
    public let shouldUnlock: Bool
    public let unlockedAt: Date?
    public let sourceOccurrenceKeys: [String]
    public let metricValue: Int
    public let isValid: Bool
}

public enum PersonalAchievementEngine {
    public static func evaluate(
        _ definition: PersonalAchievementDefinition,
        logs: [OccurrenceLog],
        now: Date = Date()
    ) -> PersonalAchievementEvaluation {
        guard let rule = definition.rule, rule.isValid, definition.ruleVersion > 0,
              let confirmedAt = definition.confirmedAt, confirmedAt <= now,
              definition.archivedAt == nil, now.timeIntervalSince1970.isFinite else {
            return result(for: definition, metric: 0, target: 1, sources: [], valid: false)
        }

        let latest = Dictionary(logs.map { ($0.occurrenceKey, $0) }, uniquingKeysWith: newest)
        let eligible = latest.values.filter { log in
            guard log.goalID == definition.goalID, log.status == .completed,
                  !log.occurrenceKey.isEmpty, let date = log.completedAt,
                  date.timeIntervalSince1970.isFinite, date >= rule.startsAt, date <= now,
                  rule.endsAt.map({ date <= $0 }) ?? true else { return false }
            // A future scheduled record cannot become a historical achievement by being checked early.
            return (log.overrideStart ?? log.originalStart) <= now
        }.sorted { lhs, rhs in
            if lhs.completedAt == rhs.completedAt { return lhs.occurrenceKey < rhs.occurrenceKey }
            return (lhs.completedAt ?? .distantFuture) < (rhs.completedAt ?? .distantFuture)
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: rule.timeZoneID)!
        switch rule.kind {
        case .completionCount:
            return result(for: definition, metric: eligible.count, target: rule.target,
                          sources: Array(eligible.prefix(rule.target)))
        case .activeDays:
            let daily = firstCompletionPerDay(eligible, calendar: calendar)
            return result(for: definition, metric: daily.count, target: rule.target,
                          sources: Array(daily.prefix(rule.target)))
        case .completedCycles:
            let anchor = calendar.startOfDay(for: rule.cycleAnchor ?? rule.startsAt)
            let daily = firstCompletionPerDay(eligible, calendar: calendar)
            let cycles = Dictionary(grouping: daily) { log in
                let day = calendar.startOfDay(for: log.completedAt!)
                let offset = calendar.dateComponents([.day], from: anchor, to: day).day ?? 0
                return Int(floor(Double(offset) / Double(rule.cycleLengthDays)))
            }
            let completed = cycles.keys.sorted().compactMap { cycle -> [OccurrenceLog]? in
                guard let days = cycles[cycle], days.count >= rule.requiredDaysPerCycle else { return nil }
                return Array(days.prefix(rule.requiredDaysPerCycle))
            }
            return result(for: definition, metric: completed.count, target: rule.target,
                          sources: Array(completed.prefix(rule.target)).flatMap { $0 })
        }
    }

    private static func firstCompletionPerDay(_ logs: [OccurrenceLog], calendar: Calendar) -> [OccurrenceLog] {
        var seen = Set<Date>()
        return logs.filter { log in
            guard let date = log.completedAt else { return false }
            return seen.insert(calendar.startOfDay(for: date)).inserted
        }
    }

    private static func newest(_ lhs: OccurrenceLog, _ rhs: OccurrenceLog) -> OccurrenceLog {
        if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt ? lhs : rhs }
        return lhs.id.uuidString < rhs.id.uuidString ? lhs : rhs
    }

    private static func result(
        for definition: PersonalAchievementDefinition, metric: Int, target: Int,
        sources: [OccurrenceLog], valid: Bool = true
    ) -> PersonalAchievementEvaluation {
        let progress = min(1, Double(metric) / Double(target))
        let unlocked = valid && metric >= target
        return PersonalAchievementEvaluation(
            definitionID: definition.id,
            definitionKey: definition.definitionKey,
            progress: progress,
            signal: HiddenSignal.from(progress: progress),
            shouldUnlock: unlocked,
            unlockedAt: unlocked ? sources.compactMap(\.completedAt).max() : nil,
            sourceOccurrenceKeys: sources.map(\.occurrenceKey),
            metricValue: metric,
            isValid: valid
        )
    }
}
