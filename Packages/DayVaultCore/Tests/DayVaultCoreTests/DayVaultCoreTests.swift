import Foundation
import XCTest
@testable import DayVaultCore

final class RecurrenceResolverTests: XCTestCase {
    func testWeekdayRuleSkipsWeekendAcrossMonthBoundary() throws {
        let calendar = calendar(timeZoneID: "America/New_York")
        let start = try date(2026, 1, 30, 9, 0, calendar: calendar) // Friday
        let item = ScheduleItem(
            title: "Study",
            plannedStart: start,
            timeZoneID: calendar.timeZone.identifier,
            recurrenceRule: RecurrenceRule(kind: .weekdays)
        )
        let range = DateInterval(
            start: try date(2026, 1, 30, 0, 0, calendar: calendar),
            end: try date(2026, 2, 4, 0, 0, calendar: calendar)
        )

        let occurrences = RecurrenceResolver.occurrences(for: item, in: range)
        let days = occurrences.map { calendar.component(.day, from: $0.start) }

        XCTAssertEqual(days, [30, 2, 3])
    }

    func testDailyRulePreservesWallClockTimeAcrossDST() throws {
        let calendar = calendar(timeZoneID: "America/Los_Angeles")
        let start = try date(2026, 3, 6, 9, 15, calendar: calendar)
        let item = ScheduleItem(
            title: "Morning block",
            plannedStart: start,
            timeZoneID: calendar.timeZone.identifier,
            recurrenceRule: RecurrenceRule(kind: .daily)
        )
        let range = DateInterval(
            start: try date(2026, 3, 6, 0, 0, calendar: calendar),
            end: try date(2026, 3, 11, 0, 0, calendar: calendar)
        )

        let occurrences = RecurrenceResolver.occurrences(for: item, in: range)

        XCTAssertEqual(occurrences.count, 5)
        XCTAssertTrue(occurrences.allSatisfy {
            calendar.component(.hour, from: $0.start) == 9 &&
            calendar.component(.minute, from: $0.start) == 15
        })
    }

    func testLeapDayMonthlyRuleDoesNotInventInvalidDates() throws {
        let calendar = calendar(timeZoneID: "UTC")
        let start = try date(2024, 2, 29, 10, 0, calendar: calendar)
        let item = ScheduleItem(
            title: "Leap review",
            plannedStart: start,
            timeZoneID: "UTC",
            recurrenceRule: RecurrenceRule(kind: .monthly)
        )
        let range = DateInterval(
            start: start,
            end: try date(2024, 6, 1, 0, 0, calendar: calendar)
        )

        let occurrences = RecurrenceResolver.occurrences(for: item, in: range)
        let monthDays = occurrences.map {
            (calendar.component(.month, from: $0.start), calendar.component(.day, from: $0.start))
        }

        XCTAssertEqual(monthDays.map(\.0), [2, 3, 4, 5])
        XCTAssertTrue(monthDays.allSatisfy { $0.1 == 29 })
    }

    func testEditedOccurrenceUsesOverrideAndLatestDuplicateLog() throws {
        let calendar = calendar(timeZoneID: "UTC")
        let original = try date(2026, 9, 7, 9, 0, calendar: calendar)
        let item = ScheduleItem(title: "Focus", plannedStart: original, timeZoneID: "UTC")
        let oldLog = OccurrenceLog(scheduleItemID: item.id, originalStart: original, timeZoneID: "UTC")
        oldLog.overrideStart = try date(2026, 9, 7, 10, 0, calendar: calendar)
        oldLog.updatedAt = try date(2026, 9, 7, 10, 0, calendar: calendar)
        let newLog = OccurrenceLog(scheduleItemID: item.id, originalStart: original, timeZoneID: "UTC")
        newLog.overrideStart = try date(2026, 9, 7, 11, 15, calendar: calendar)
        newLog.overrideDurationMinutes = 45
        newLog.status = .completed
        newLog.updatedAt = try date(2026, 9, 7, 11, 30, calendar: calendar)
        let range = DateInterval(
            start: try date(2026, 9, 7, 0, 0, calendar: calendar),
            end: try date(2026, 9, 8, 0, 0, calendar: calendar)
        )

        let occurrence = try XCTUnwrap(
            RecurrenceResolver.occurrences(for: item, in: range, logs: [oldLog, newLog]).first
        )

        XCTAssertEqual(occurrence.start, newLog.overrideStart)
        XCTAssertEqual(occurrence.durationMinutes, 45)
        XCTAssertEqual(occurrence.status, .completed)
        XCTAssertEqual(occurrence.originalStart, original)
    }

    func testCrossDayOverrideAppearsOnlyInTargetRangeAndRemainsDeduplicated() throws {
        let calendar = calendar(timeZoneID: "UTC")
        let original = try date(2026, 9, 7, 9, 0, calendar: calendar)
        let item = ScheduleItem(
            title: "Move me",
            plannedStart: original,
            plannedDurationMinutes: 30,
            timeZoneID: "UTC"
        )
        let oldLog = OccurrenceLog(scheduleItemID: item.id, originalStart: original, timeZoneID: "UTC")
        oldLog.overrideStart = try date(2026, 9, 8, 10, 0, calendar: calendar)
        oldLog.updatedAt = try date(2026, 9, 7, 10, 0, calendar: calendar)
        let newLog = OccurrenceLog(scheduleItemID: item.id, originalStart: original, timeZoneID: "UTC")
        newLog.overrideStart = try date(2026, 9, 8, 11, 15, calendar: calendar)
        newLog.overrideDurationMinutes = 45
        newLog.updatedAt = try date(2026, 9, 7, 11, 0, calendar: calendar)
        let logs = [oldLog, newLog]
        let originalDay = DateInterval(
            start: try date(2026, 9, 7, 0, 0, calendar: calendar),
            end: try date(2026, 9, 8, 0, 0, calendar: calendar)
        )
        let targetDay = DateInterval(
            start: originalDay.end,
            end: try date(2026, 9, 9, 0, 0, calendar: calendar)
        )
        let combinedRange = DateInterval(start: originalDay.start, end: targetDay.end)

        let occurrencesOnOriginalDay = RecurrenceResolver.occurrences(for: item, in: originalDay, logs: logs)
        let occurrencesOnTargetDay = RecurrenceResolver.occurrences(for: item, in: targetDay, logs: logs)
        let occurrencesAcrossBothDays = RecurrenceResolver.occurrences(for: item, in: combinedRange, logs: logs)

        XCTAssertTrue(occurrencesOnOriginalDay.isEmpty)
        let moved = try XCTUnwrap(occurrencesOnTargetDay.first)
        XCTAssertEqual(occurrencesOnTargetDay.count, 1)
        XCTAssertEqual(moved.start, newLog.overrideStart)
        XCTAssertEqual(moved.durationMinutes, 45)
        XCTAssertEqual(moved.originalStart, original)
        XCTAssertEqual(occurrencesAcrossBothDays.count, 1)
        XCTAssertEqual(Set(occurrencesAcrossBothDays.map(\.id)).count, 1)
    }

    func testRecurringOverrideAppearsAlongsideNaturalTargetDayOccurrenceOnce() throws {
        let calendar = calendar(timeZoneID: "UTC")
        let original = try date(2026, 9, 7, 9, 0, calendar: calendar)
        let item = ScheduleItem(
            title: "Daily focus",
            plannedStart: original,
            timeZoneID: "UTC",
            recurrenceRule: RecurrenceRule(kind: .daily)
        )
        let log = OccurrenceLog(scheduleItemID: item.id, originalStart: original, timeZoneID: "UTC")
        log.overrideStart = try date(2026, 9, 8, 11, 0, calendar: calendar)
        let targetDay = DateInterval(
            start: try date(2026, 9, 8, 0, 0, calendar: calendar),
            end: try date(2026, 9, 9, 0, 0, calendar: calendar)
        )

        let occurrences = RecurrenceResolver.occurrences(for: item, in: targetDay, logs: [log, log])

        XCTAssertEqual(occurrences.map(\.start), [
            try date(2026, 9, 8, 9, 0, calendar: calendar),
            try date(2026, 9, 8, 11, 0, calendar: calendar),
        ])
        XCTAssertEqual(Set(occurrences.map(\.id)).count, 2)
        XCTAssertEqual(occurrences.filter { $0.originalStart == original }.count, 1)
    }

    private func calendar(timeZoneID: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(identifier: timeZoneID)!
        return calendar
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int,
        _ minute: Int,
        calendar: Calendar
    ) throws -> Date {
        try XCTUnwrap(calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )))
    }
}

final class TimelineLayoutTests: XCTestCase {
    func testOverlapsShareColumnsAndTouchingBlocksReuseAColumn() {
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let items = [
            occurrence(id: "a", start: base, minutes: 60),
            occurrence(id: "b", start: base.addingTimeInterval(15 * 60), minutes: 30),
            occurrence(id: "c", start: base.addingTimeInterval(45 * 60), minutes: 30),
        ]

        let placements = TimelineLayout.placements(for: items)

        XCTAssertEqual(placements["a"]?.columnCount, 2)
        XCTAssertEqual(placements["b"]?.columnCount, 2)
        XCTAssertEqual(placements["c"]?.columnCount, 2)
        XCTAssertEqual(placements["a"]?.column, 0)
        XCTAssertEqual(placements["b"]?.column, 1)
        XCTAssertEqual(placements["c"]?.column, 1)
    }

    func testFiftySimultaneousItemsReceiveFiftyColumns() {
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let occurrences = (0..<50).map { occurrence(id: "\($0)", start: base, minutes: 15) }

        let placements = TimelineLayout.placements(for: occurrences)

        XCTAssertEqual(Set(placements.values.map(\.column)).count, 50)
        XCTAssertTrue(placements.values.allSatisfy { $0.columnCount == 50 })
    }

    private func occurrence(id: String, start: Date, minutes: Int) -> ScheduleOccurrence {
        ScheduleOccurrence(
            id: id,
            itemID: UUID(),
            title: id,
            notes: "",
            categoryID: nil,
            originalStart: start,
            start: start,
            durationMinutes: minutes,
            isUnscheduled: false,
            status: .planned,
            actualStart: nil,
            actualEnd: nil,
            priority: .normal,
            timeZoneID: "UTC",
            templateID: nil
        )
    }
}

final class AchievementEngineTests: XCTestCase {
    func testCatalogContainsSixteenVisibleAndEightConcealedAchievements() {
        XCTAssertEqual(AchievementCatalog.all.count, 24)
        XCTAssertEqual(AchievementCatalog.all.filter { !$0.isHidden }.count, 16)
        XCTAssertEqual(AchievementCatalog.all.filter(\.isHidden).count, 8)
        XCTAssertEqual(Set(AchievementCatalog.all.map(\.id)).count, 24)
    }

    func testExactThresholdUnlocksWithoutOverrun() throws {
        var snapshot = AchievementSnapshot()
        snapshot.completionCount = 10

        let evaluations = AchievementEngine.evaluate(snapshot: snapshot)
        let firstTier = try XCTUnwrap(evaluations.first { $0.definitionID == "timekeeper_1" })
        let secondTier = try XCTUnwrap(evaluations.first { $0.definitionID == "timekeeper_2" })

        XCTAssertEqual(firstTier.progress, 1)
        XCTAssertTrue(firstTier.shouldUnlock)
        XCTAssertEqual(secondTier.progress, 0.2)
        XCTAssertFalse(secondTier.shouldUnlock)
    }

    func testConcealedSignalsAreNonnumericStages() throws {
        var snapshot = AchievementSnapshot()
        snapshot.secondWindProgress = 0.45
        snapshot.foundTimeProgress = 0.85

        let evaluations = AchievementEngine.evaluate(snapshot: snapshot)

        XCTAssertEqual(try evaluation("second_wind", in: evaluations).signal, .faint)
        XCTAssertEqual(try evaluation("found_time", in: evaluations).signal, .resonant)
        XCTAssertFalse(try evaluation("found_time", in: evaluations).shouldUnlock)
    }

    func testVaultKeeperRequiresEveryVisibleCategory() throws {
        var snapshot = AchievementSnapshot()
        snapshot.unlockedVisibleCategories = AchievementCategory.allCases.count - 1
        XCTAssertFalse(try evaluation("vault_keeper", in: AchievementEngine.evaluate(snapshot: snapshot)).shouldUnlock)

        snapshot.unlockedVisibleCategories = AchievementCategory.allCases.count
        XCTAssertTrue(try evaluation("vault_keeper", in: AchievementEngine.evaluate(snapshot: snapshot)).shouldUnlock)
    }

    private func evaluation(
        _ id: String,
        in evaluations: [AchievementEvaluation]
    ) throws -> AchievementEvaluation {
        try XCTUnwrap(evaluations.first { $0.definitionID == id })
    }
}

final class GeneratedPlanValidatorTests: XCTestCase {
    func testAcceptsAConservativePlan() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let request = PlannerRequest(
            goalText: "Prepare a portfolio in two weeks",
            currentDate: now,
            timeZoneID: "UTC"
        )
        let turn = makeTurn(now: now)

        XCTAssertNoThrow(try GeneratedPlanValidator.validate(turn, for: request))
    }

    func testRejectsABlockThatCollidesWithKnownBusyTime() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let blockStart = now.addingTimeInterval(3_600)
        let request = PlannerRequest(
            goalText: "Prepare a portfolio in two weeks",
            currentDate: now,
            timeZoneID: "UTC",
            busyWindows: [PlannerBusyWindow(
                start: blockStart.addingTimeInterval(-300),
                end: blockStart.addingTimeInterval(1_800)
            )]
        )

        XCTAssertThrowsError(try GeneratedPlanValidator.validate(makeTurn(now: now), for: request)) { error in
            XCTAssertEqual(error as? PlanValidationError, .busyWindowConflict)
        }
    }

    func testRejectsAnInventedCommunityChallenge() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let request = PlannerRequest(
            goalText: "Prepare a portfolio in two weeks",
            currentDate: now,
            timeZoneID: "UTC",
            activeChallengeIDs: StarterChallengeCatalog.all.map(\.id)
        )
        let turn = makeTurn(now: now, challengeID: UUID())

        XCTAssertThrowsError(try GeneratedPlanValidator.validate(turn, for: request)) { error in
            XCTAssertEqual(error as? PlanValidationError, .unknownChallenge)
        }
    }

    private func makeTurn(now: Date, challengeID: UUID? = nil) -> PlannerTurn {
        let deadline = now.addingTimeInterval(14 * 86_400)
        let midpoint = now.addingTimeInterval(7 * 86_400)
        let plan = GeneratedProjectPlan(
            title: "Portfolio",
            clarifiedGoal: "Prepare a portfolio in two weeks",
            deadline: deadline,
            phases: [
                PlanPhase(title: "Choose work", summary: "Select the strongest pieces.", start: now, end: midpoint),
                PlanPhase(title: "Polish", summary: "Finish and review the presentation.", start: midpoint, end: deadline),
            ],
            milestones: [],
            initialBlocks: [
                GeneratedPlanBlock(
                    title: "Select three pieces",
                    start: now.addingTimeInterval(3_600),
                    durationMinutes: 45
                ),
            ],
            recommendedChallengeID: challengeID
        )
        return .plan(plan)
    }
}
