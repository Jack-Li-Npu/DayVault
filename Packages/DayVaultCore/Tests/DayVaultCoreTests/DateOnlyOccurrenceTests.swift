import Foundation
import XCTest
@testable import DayVaultCore

final class DateOnlyOccurrenceTests: XCTestCase {
    func testDateOnlyPreservesIdentityAndEstimateWithoutPublishingClockTimes() throws {
        let start = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-09-10T11:00:00Z"))
        let item = ScheduleItem(title: "阅读", plannedStart: start, plannedDurationMinutes: 45, timeZoneID: "UTC", timePrecision: .dateOnly)
        let interval = DateInterval(start: start.addingTimeInterval(-3_600), end: start.addingTimeInterval(3_600))
        let occurrence = try XCTUnwrap(RecurrenceResolver.occurrences(for: item, in: interval).first)
        XCTAssertEqual(occurrence.id, OccurrenceKey.make(itemID: item.id, originalStart: start, timeZoneID: "UTC"))
        XCTAssertNil(occurrence.displayStart)
        XCTAssertNil(occurrence.displayEnd)
        XCTAssertEqual(occurrence.durationMinutes, 45)
        XCTAssertNil(item.displayStart)
        item.timePrecision = .timed
        let timed = try XCTUnwrap(RecurrenceResolver.occurrences(for: item, in: interval).first)
        XCTAssertEqual(timed.id, occurrence.id)
        XCTAssertEqual(timed.displayStart, start)
    }

    func testDateOnlyDoesNotAppearOnThePreviousDayAtMidnightBoundary() throws {
        let start = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-09-10T00:00:00Z"))
        let item = ScheduleItem(title: "今天的事", plannedStart: start, timeZoneID: "UTC", timePrecision: .dateOnly)
        let prior = DateInterval(start: start.addingTimeInterval(-86_400), end: start)
        XCTAssertTrue(RecurrenceResolver.occurrences(for: item, in: prior).isEmpty)
        let next = DateInterval(start: start.addingTimeInterval(86_400), end: start.addingTimeInterval(2 * 86_400))
        XCTAssertTrue(RecurrenceResolver.occurrences(for: item, in: next).isEmpty)
    }

    func testDateOnlyDSTDaysRemainOneOccurrenceAndKeepOriginalZone() throws {
        let start = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-07T05:00:00Z"))
        let end = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-10T04:00:00Z"))
        let item = ScheduleItem(title: "日记录", plannedStart: start, timeZoneID: "America/New_York",
                                recurrenceRule: RecurrenceRule(kind: .daily), timePrecision: .dateOnly)
        let result = RecurrenceResolver.occurrences(for: item, in: DateInterval(start: start, end: end))
        XCTAssertEqual(result.count, 3)
        XCTAssertTrue(result.allSatisfy { $0.displayStart == nil && $0.timeZoneID == "America/New_York" })
        XCTAssertEqual(result[2].start.timeIntervalSince(result[1].start), 23 * 3_600)
    }

    func testLegacyInboxAndRecordedGoalOwnershipRemainDistinct() throws {
        let start = Date(timeIntervalSince1970: 1_750_000_000)
        let firstGoal = UUID()
        let newGoal = UUID()
        let item = ScheduleItem(title: "历史记录", plannedStart: start, isUnscheduled: true, timeZoneID: "UTC", goalID: newGoal)
        let log = OccurrenceLog(scheduleItemID: item.id, originalStart: start, timeZoneID: item.timeZoneID, goalID: firstGoal)
        log.status = .completed
        let result = try XCTUnwrap(RecurrenceResolver.occurrences(for: item, in: DateInterval(start: start, duration: 86_400), logs: [log]).first)
        XCTAssertEqual(result.goalID, firstGoal)
        XCTAssertEqual(result.timePrecision, .inbox)
        XCTAssertNil(result.displayStart)
        log.goalID = nil
        XCTAssertNil(RecurrenceResolver.occurrences(for: item, in: DateInterval(start: start, duration: 86_400), logs: [log]).first?.goalID)
    }

    func testDateOnlyWidgetRoundTripAndLegacySnapshotDecode() throws {
        let date = Date(timeIntervalSinceReferenceDate: 0)
        let item = WidgetScheduleItem(id: "one", title: "日记录", start: date, end: date, isCompleted: false, timePrecision: .dateOnly)
        let decoded = try JSONDecoder().decode(WidgetScheduleItem.self, from: JSONEncoder().encode(item))
        XCTAssertEqual(decoded, item)
        XCTAssertNil(decoded.displayStart)
        let legacy = Data(#"{"id":"old","title":"旧记录","start":0,"end":60,"isCompleted":true}"#.utf8)
        let old = try JSONDecoder().decode(WidgetScheduleItem.self, from: legacy)
        XCTAssertEqual(old.timePrecision, .timed)
        XCTAssertEqual(old.displayStart, date)
    }
}
