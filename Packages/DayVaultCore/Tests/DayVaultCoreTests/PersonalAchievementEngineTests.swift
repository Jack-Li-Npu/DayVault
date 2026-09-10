import Foundation
import XCTest
@testable import DayVaultCore

final class PersonalAchievementEngineTests: XCTestCase {
    private let start = ISO8601DateFormatter().date(from: "2026-01-05T00:00:00Z")!

    func testCompletionThresholdIsDeterministicAndSourcesAreUnique() {
        let definition = definition(kind: .completionCount, target: 3)
        let logs = (0..<4).map { completion(goalID: definition.goalID, day: $0) }
        let below = evaluate(definition, logs: Array(logs.prefix(2)))
        XCTAssertEqual(below.progress, 2.0 / 3.0, accuracy: 0.0001)
        XCTAssertFalse(below.shouldUnlock)
        let exact = evaluate(definition, logs: Array(logs.prefix(3)))
        XCTAssertTrue(exact.shouldUnlock)
        XCTAssertEqual(exact.unlockedAt, logs[2].completedAt)
        XCTAssertEqual(exact.sourceOccurrenceKeys, Array(logs.prefix(3)).map(\.occurrenceKey))
        let repeated = evaluate(definition, logs: logs + logs)
        XCTAssertEqual(repeated.metricValue, 4)
        XCTAssertEqual(repeated.sourceOccurrenceKeys, exact.sourceOccurrenceKeys)
        XCTAssertEqual(repeated.unlockedAt, exact.unlockedAt)
        XCTAssertEqual(repeated, evaluate(definition, logs: (logs + logs).reversed()))
    }

    func testScopeAndDateWindowRejectUnrelatedOrFutureRecords() {
        let definition = definition(kind: .completionCount, target: 1)
        let wrongGoal = completion(goalID: UUID(), day: 0)
        let before = completion(goalID: definition.goalID, day: -1)
        let future = completion(goalID: definition.goalID, day: 31)
        let futurePlan = completion(goalID: definition.goalID, day: 32)
        futurePlan.completedAt = start.addingTimeInterval(100)
        let logs = [wrongGoal, before, future, futurePlan]
        XCTAssertEqual(evaluate(definition, logs: logs).metricValue, 0)
        let ended = definitionWithRule(goalID: definition.goalID, rule: PersonalAchievementRule(
            kind: .completionCount, target: 1, startsAt: start, endsAt: start.addingTimeInterval(86_400), timeZoneID: "UTC"
        ))
        XCTAssertFalse(evaluate(ended, logs: [completion(goalID: ended.goalID, day: 2)]).shouldUnlock)
    }

    func testLatestVersionOfOccurrenceControlsProgressAfterEditing() {
        let definition = definition(kind: .completionCount, target: 1)
        let first = completion(goalID: definition.goalID, day: 0)
        let edited = OccurrenceLog(scheduleItemID: first.scheduleItemID, originalStart: first.originalStart,
                                   timeZoneID: first.timeZoneID, goalID: definition.goalID)
        edited.status = .removed
        edited.updatedAt = first.updatedAt.addingTimeInterval(1)
        XCTAssertTrue(evaluate(definition, logs: [first]).shouldUnlock)
        XCTAssertFalse(evaluate(definition, logs: [first, edited]).shouldUnlock)
        XCTAssertFalse(evaluate(definition, logs: [edited, first]).shouldUnlock)
    }

    func testActiveDaysCountOnePerDayInFrozenTimezone() {
        let definition = definitionWithRule(rule: PersonalAchievementRule(
            kind: .activeDays, target: 2, startsAt: start, timeZoneID: "Asia/Shanghai"
        ))
        let first = completion(goalID: definition.goalID, day: 0)
        first.completedAt = start.addingTimeInterval(15 * 3_600 + 30 * 60)
        let sameDay = completion(goalID: definition.goalID, day: 0)
        sameDay.completedAt = start.addingTimeInterval(15 * 3_600 + 40 * 60)
        let nextDay = completion(goalID: definition.goalID, day: 0)
        nextDay.completedAt = start.addingTimeInterval(16 * 3_600 + 30 * 60)
        XCTAssertEqual(evaluate(definition, logs: [first, sameDay]).metricValue, 1)
        let result = evaluate(definition, logs: [first, sameDay, nextDay])
        XCTAssertTrue(result.shouldUnlock)
        XCTAssertEqual(result.sourceOccurrenceKeys, [first.occurrenceKey, nextDay.occurrenceKey])
    }

    func testCompletedCyclesUseFixedBoundariesAndAllowRestAndMissingCycles() {
        let definition = definition(kind: .completedCycles, target: 2)
        let firstWeek = (0..<5).map { completion(goalID: definition.goalID, day: $0) }
        let thirdWeek = (14..<19).map { completion(goalID: definition.goalID, day: $0) }
        XCTAssertEqual(evaluate(definition, logs: firstWeek).metricValue, 1)
        let almost = evaluate(definition, logs: firstWeek + thirdWeek.prefix(4))
        XCTAssertEqual(almost.metricValue, 1)
        let result = evaluate(definition, logs: firstWeek + thirdWeek)
        XCTAssertEqual(result.metricValue, 2)
        XCTAssertTrue(result.shouldUnlock)
        XCTAssertEqual(result.unlockedAt, thirdWeek.last?.completedAt)
        XCTAssertEqual(result.sourceOccurrenceKeys.count, 10)
        XCTAssertEqual(evaluate(definition, logs: firstWeek + firstWeek).metricValue, 1)
    }

    func testUnconfirmedArchivedAndMalformedRulesDoNotUnlock() {
        let definition = definition(kind: .completionCount, target: 1)
        let log = completion(goalID: definition.goalID, day: 0)
        definition.confirmedAt = nil
        XCTAssertFalse(evaluate(definition, logs: [log]).isValid)
        definition.confirmedAt = start
        definition.archivedAt = start
        XCTAssertFalse(evaluate(definition, logs: [log]).isValid)
        let invalid = definitionWithRule(rule: PersonalAchievementRule(kind: .completionCount, target: 0, startsAt: start, timeZoneID: "UTC"))
        XCTAssertFalse(evaluate(invalid, logs: [log]).isValid)
        let invalidZone = PersonalAchievementRule(kind: .activeDays, target: 2, startsAt: start, timeZoneID: "not-a-zone")
        XCTAssertFalse(invalidZone.isValid)
        let impossibleCycle = PersonalAchievementRule(kind: .completedCycles, target: 2, startsAt: start, timeZoneID: "UTC", cycleLengthDays: 7, requiredDaysPerCycle: 8)
        XCTAssertFalse(impossibleCycle.isValid)
    }

    func testHiddenSignalStagesAndPersonalNamespaceStaySeparateFromPublicCatalog() {
        let definition = definition(kind: .completionCount, target: 5)
        definition.isHidden = true
        let logs = (0..<5).map { completion(goalID: definition.goalID, day: $0) }
        XCTAssertEqual(evaluate(definition, logs: []).signal, .dormant)
        XCTAssertEqual(evaluate(definition, logs: Array(logs.prefix(2))).signal, .faint)
        XCTAssertEqual(evaluate(definition, logs: Array(logs.prefix(4))).signal, .resonant)
        XCTAssertTrue(definition.definitionKey.hasPrefix("personal:"))
        XCTAssertFalse(AchievementCatalog.all.contains { $0.id == definition.definitionKey })
        XCTAssertEqual(AchievementCatalog.all.count, 24)
        XCTAssertNil(AvatarRewardCatalog.reward(for: definition.definitionKey))
    }

    func testLinkingHistoryDoesNotInventCompanionParticipation() {
        let log = completion(goalID: UUID(), day: 0)
        XCTAssertFalse(log.recordedDuringCompanionship)
        XCTAssertNil(log.companionSessionID)
        log.goalID = UUID()
        XCTAssertFalse(log.recordedDuringCompanionship)
        XCTAssertNil(log.companionSessionID)
    }

    func testFrozenRuleJSONAndEvidenceRoundTripWithoutChangingSourceIDs() throws {
        let definition = definition(kind: .activeDays, target: 3)
        let rule = try XCTUnwrap(definition.rule)
        XCTAssertEqual(JourneyJSON.decode(PersonalAchievementRule.self, from: try XCTUnwrap(JourneyJSON.encode(rule))), rule)
        let keys = ["a", "b", "a"]
        let evidence = PersonalAchievementEvidence(definitionKey: definition.definitionKey, goalID: definition.goalID,
                                                   unlockedAt: start, occurrenceKeys: keys, ruleJSON: definition.ruleJSON, metricValue: 3)
        XCTAssertEqual(evidence.occurrenceKeys, ["a", "b"])
        XCTAssertEqual(evidence.ruleJSON, definition.ruleJSON)
    }

    func testLegacyRuleWithoutCycleAnchorStillDecodesAndUsesStartBoundary() throws {
        let legacy = """
        {"kind":"completedCycles","target":1,"startsAt":"2026-01-05T00:00:00Z","timeZoneID":"UTC","cycleLengthDays":7,"requiredDaysPerCycle":2}
        """
        let rule = try XCTUnwrap(JourneyJSON.decode(PersonalAchievementRule.self, from: legacy))
        XCTAssertNil(rule.cycleAnchor)
        XCTAssertEqual(rule.startsAt, start)
        XCTAssertTrue(rule.isValid)
        let definition = definitionWithRule(rule: rule)
        let logs = [completion(goalID: definition.goalID, day: 0), completion(goalID: definition.goalID, day: 1)]
        XCTAssertEqual(evaluate(definition, logs: logs).metricValue, 1)
    }

    func testAllHistoryRulesAcceptExplicitlyLinkedOlderRecordsWithoutRewritingRule() throws {
        for kind: PersonalAchievementRuleKind in [.completionCount, .activeDays] {
            let rule = PersonalAchievementRule(kind: kind, target: 1, startsAt: .distantPast,
                timeZoneID: "UTC", cycleAnchor: start)
            let definition = definitionWithRule(rule: rule)
            let frozenJSON = definition.ruleJSON
            let old = completion(goalID: UUID(), day: -50)
            old.goalID = nil
            XCTAssertEqual(evaluate(definition, logs: [old]).metricValue, 0)

            old.goalID = definition.goalID

            XCTAssertTrue(evaluate(definition, logs: [old]).shouldUnlock)
            XCTAssertEqual(definition.ruleJSON, frozenJSON)
            XCTAssertEqual(try XCTUnwrap(definition.rule).cycleAnchor, start)
            XCTAssertFalse(old.recordedDuringCompanionship)
            XCTAssertNil(old.companionSessionID)
        }
    }

    func testLinkedHistoryAddsEarlierCompletedCyclesWithoutMovingFrozenAnchor() throws {
        let rule = PersonalAchievementRule(kind: .completedCycles, target: 2, startsAt: .distantPast,
            timeZoneID: "UTC", requiredDaysPerCycle: 2, cycleAnchor: start)
        let definition = definitionWithRule(rule: rule)
        let current = [0, 1].map { completion(goalID: definition.goalID, day: $0) }
        let prior = [-7, -6].map { completion(goalID: UUID(), day: $0) }
        XCTAssertEqual(evaluate(definition, logs: current + prior).metricValue, 1)
        let frozenJSON = definition.ruleJSON

        prior.forEach { $0.goalID = definition.goalID }

        let result = evaluate(definition, logs: current + prior)
        XCTAssertEqual(result.metricValue, 2)
        XCTAssertTrue(result.shouldUnlock)
        XCTAssertEqual(result.sourceOccurrenceKeys.count, 4)
        XCTAssertEqual(try XCTUnwrap(definition.rule).cycleAnchor, start)
        XCTAssertEqual(definition.ruleJSON, frozenJSON)
        let acrossBoundary = [-1, 0].map { completion(goalID: definition.goalID, day: $0) }
        XCTAssertEqual(evaluate(definition, logs: acrossBoundary).metricValue, 0,
            "The day before the anchor belongs to the previous cycle, not cycle zero.")
    }

    private func definition(kind: PersonalAchievementRuleKind, target: Int) -> PersonalAchievementDefinition {
        definitionWithRule(rule: PersonalAchievementRule(kind: kind, target: target, startsAt: start, timeZoneID: "UTC"))
    }

    private func definitionWithRule(goalID: UUID = UUID(), rule: PersonalAchievementRule) -> PersonalAchievementDefinition {
        PersonalAchievementDefinition(goalID: goalID, batchID: UUID(), title: "个人里程碑", rule: rule, confirmedAt: start)
    }

    private func completion(goalID: UUID, day: Int) -> OccurrenceLog {
        let date = start.addingTimeInterval(Double(day * 86_400 + 3_600))
        let log = OccurrenceLog(scheduleItemID: UUID(), originalStart: date, timeZoneID: "UTC", goalID: goalID)
        log.status = .completed
        log.completedAt = date.addingTimeInterval(1_800)
        log.updatedAt = log.completedAt!
        return log
    }

    private func evaluate(_ definition: PersonalAchievementDefinition, logs: [OccurrenceLog]) -> PersonalAchievementEvaluation {
        PersonalAchievementEngine.evaluate(definition, logs: logs, now: start.addingTimeInterval(30 * 86_400))
    }
}
