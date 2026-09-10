import Foundation
import XCTest
@testable import DayVaultCore

final class JourneyAIValidationTests: XCTestCase {
    private let goalID = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
    private let now = ISO8601DateFormatter().date(from: "2026-09-10T08:00:00Z")!

    func testCompanionRejectsUnknownSourcesAndAnotherGoal() throws {
        let request = makeRequest(.companionReply)
        XCTAssertNoThrow(try JourneyAIValidator.validate(JourneyCompanionReply(goalID: goalID, text: "这一回记下了。", sourceIDs: ["completed:1"]), for: request))
        XCTAssertThrowsError(try JourneyAIValidator.validate(JourneyCompanionReply(goalID: goalID, text: "超过所有人了。", sourceIDs: ["invented-ranking"]), for: request))
        XCTAssertThrowsError(try JourneyAIValidator.validate(JourneyCompanionReply(goalID: UUID(), text: "记下了。", sourceIDs: ["goal"]), for: request))
    }

    func testAnEventWithoutUserMessageCannotCiteMessageOrProposeMemory() {
        let request = makeRequest(.companionReply, message: "")
        XCTAssertThrowsError(try JourneyAIValidator.validate(JourneyCompanionReply(goalID: goalID, text: "记下了。", sourceIDs: ["message"]), for: request))
        XCTAssertThrowsError(try JourneyAIValidator.validate(JourneyCompanionReply(goalID: goalID, text: "记下了。", sourceIDs: ["goal"], memoryCandidate: "喜欢每天早上运动"), for: request))
    }

    func testAchievementDesignRequiresConsentAndConfiguredCycles() {
        let design = JourneyAchievementDesign(goalID: goalID, achievements: [achievement()])
        XCTAssertThrowsError(try JourneyAIValidator.validate(design, for: makeRequest(.designAchievements, consent: false)))
        XCTAssertNoThrow(try JourneyAIValidator.validate(design, for: makeRequest(.designAchievements, consent: true)))
        let cycles = JourneyAchievementDesign(goalID: goalID, achievements: [achievement(rule: .completedCycles)])
        XCTAssertThrowsError(try JourneyAIValidator.validate(cycles, for: makeRequest(.designAchievements, consent: true)))
    }

    func testDesignerCannotExceedTwoVisibleMilestonesOrUseUnlistedArt() {
        let request = makeRequest(.designAchievements, consent: true)
        XCTAssertThrowsError(try JourneyAIValidator.validate(JourneyAchievementDesign(goalID: goalID, achievements: [achievement(id: "a"), achievement(id: "b"), achievement(id: "c")]), for: request))
        XCTAssertThrowsError(try JourneyAIValidator.validate(JourneyAchievementDesign(goalID: goalID, achievements: [achievement(style: "borrowed_game_badge")]), for: request))
    }

    func testAdjustmentOnlyMovesSuppliedSameGoalOccurrences() {
        let occurrence = candidate(start: now.addingTimeInterval(86_400))
        let request = makeRequest(.suggestAdjustment, occurrences: [occurrence])
        XCTAssertNoThrow(try JourneyAIValidator.validate(adjustment(start: now.addingTimeInterval(2 * 86_400)), for: request))
        let unknown = JourneyAdjustmentSuggestion(goalID: goalID, summary: "移动这一项", changes: [.init(occurrenceID: "unknown", newStart: now)], sourceIDs: ["goal"])
        XCTAssertThrowsError(try JourneyAIValidator.validate(unknown, for: request))
        let wrongGoal = JourneyAIOccurrence(id: "occ-1", goalID: UUID(), start: occurrence.start, durationMinutes: 30, isTimed: true, revision: "r1")
        XCTAssertThrowsError(try JourneyAIValidator.validateRequest(makeRequest(.suggestAdjustment, occurrences: [wrongGoal]), operation: .suggestAdjustment))
    }

    func testTimedAdjustmentsRejectPastAndSevenDayBoundary() {
        let request = makeRequest(.suggestAdjustment, occurrences: [candidate(start: now.addingTimeInterval(86_400))])
        XCTAssertThrowsError(try JourneyAIValidator.validate(adjustment(start: now.addingTimeInterval(-60)), for: request))
        XCTAssertThrowsError(try JourneyAIValidator.validate(adjustment(start: now.addingTimeInterval(7 * 86_400)), for: request))
    }

    func testDateOnlyTodayIsAllowedButCannotGainAClockTime() {
        let today = now.addingTimeInterval(-16 * 3_600)
        let request = makeRequest(.suggestAdjustment, occurrences: [candidate(start: today, timed: false)])
        XCTAssertNoThrow(try JourneyAIValidator.validate(adjustment(start: today), for: request))
        XCTAssertNoThrow(try JourneyAIValidator.validate(adjustment(start: today.addingTimeInterval(86_400)), for: request))
        XCTAssertThrowsError(try JourneyAIValidator.validate(adjustment(start: today.addingTimeInterval(86_400 + 3_600)), for: request))
    }

    func testDateOnlyRestWindowBlocksTheWholeTargetCivilDay() {
        let today = now.addingTimeInterval(-16 * 3_600)
        let rest = PlannerBusyWindow(start: now.addingTimeInterval(86_400), end: now.addingTimeInterval(86_400 + 3_600))
        let request = makeRequest(.suggestAdjustment, occurrences: [candidate(start: today, timed: false)], rest: [rest])
        XCTAssertThrowsError(try JourneyAIValidator.validate(adjustment(start: today.addingTimeInterval(86_400)), for: request))
        XCTAssertNoThrow(try JourneyAIValidator.validate(adjustment(start: today.addingTimeInterval(2 * 86_400)), for: request))
    }

    func testCompanionRequestHasNoHiddenDefinitionOrUnconfirmedMemoryField() throws {
        let data = try JSONEncoder().encode(makeRequest(.companionReply))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNil(object["hiddenRules"])
        XCTAssertNil(object["achievementDefinitions"])
        XCTAssertNil(object["inferredMemories"])
        XCTAssertNotNil(object["requestID"])
    }

    private func makeRequest(_ operation: JourneyAIOperation, message: String = "请挪一下安排", consent: Bool = false, occurrences: [JourneyAIOccurrence] = [], rest: [PlannerBusyWindow] = []) -> JourneyAIRequest {
        JourneyAIRequest(operation: operation, goalID: goalID, goalTitle: "阅读", currentDate: now, timeZoneID: "Asia/Shanghai", message: message, facts: [.init(id: "completed:1", text: "本目标完成了一次")], allowedOccurrences: occurrences, restWindows: rest, achievementConsent: consent)
    }

    private func achievement(id: String = "a", rule: JourneyAchievementRuleType = .completionCount, style: String = "steps") -> JourneyAchievementDraft {
        JourneyAchievementDraft(id: id, name: "走出三步", detail: "完成本目标三次行动", ruleType: rule, target: 3, isHidden: false, clue: "", badgeStyleKey: style, sourceIDs: ["goal"])
    }

    private func candidate(start: Date, timed: Bool = true) -> JourneyAIOccurrence {
        JourneyAIOccurrence(id: "occ-1", goalID: goalID, start: start, durationMinutes: 30, isTimed: timed, revision: "r1")
    }

    private func adjustment(start: Date) -> JourneyAdjustmentSuggestion {
        JourneyAdjustmentSuggestion(goalID: goalID, summary: "提议移动这一次", changes: [.init(occurrenceID: "occ-1", newStart: start)], sourceIDs: ["message"])
    }
}
