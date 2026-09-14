import Foundation
import XCTest
@testable import DayVaultCore

final class MCPExchangeTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_789_387_200) // 2026-09-14 12:00 UTC

    private func proposal(zone: String = "Asia/Shanghai") -> MCPScheduleProposal {
        MCPScheduleProposal(snapshotID: UUID(), goalID: UUID(), goalTitle: "阅读", timeZoneID: zone,
                            createdAt: ISO8601DateFormatter().string(from: now), summary: "安排一次阅读。",
                            items: [.init(title: "阅读下一章", date: MCPExchange.dateString(now, timeZoneID: zone))])
    }

    private func snapshot() -> MCPSnapshot {
        MCPSnapshot(exportedAt: ISO8601DateFormatter().string(from: now),
                    goal: .init(id: UUID(), title: "阅读", timeZoneID: "Asia/Shanghai", restWeekdays: [1, 7]),
                    window: .init(startDate: "2026-08-15", endDate: "2026-09-28"),
                    records: [.init(id: "reading:one", itemID: UUID(), title: "阅读一章", date: "2026-09-14",
                                    status: "completed", timePrecision: "dateOnly")])
    }

    func testProposalRoundTripKeepsStableIDsAndDateOnlyFields() throws {
        let value = proposal()
        let data = try MCPExchange.encode(value)
        XCTAssertEqual(try MCPExchange.decodeProposal(data), value)
        XCTAssertNoThrow(try MCPExchange.validateProposal(value, now: now))
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(text.contains("duration"))
        XCTAssertFalse(text.contains("completedAt"))
        XCTAssertFalse(text.contains("unlock"))
    }

    func testRejectsUnknownTopLevelAndItemActions() throws {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: MCPExchange.encode(proposal())) as? [String: Any])
        object["unlockAchievement"] = "all"
        XCTAssertThrowsError(try MCPExchange.decodeProposal(JSONSerialization.data(withJSONObject: object)))
        object.removeValue(forKey: "unlockAchievement")
        var items = try XCTUnwrap(object["items"] as? [[String: Any]])
        items[0]["status"] = "completed"
        object["items"] = items
        XCTAssertThrowsError(try MCPExchange.decodeProposal(JSONSerialization.data(withJSONObject: object)))
    }

    func testInvalidJSONUUIDMissingFieldsAndNullsFailClosed() throws {
        for bytes in [Data("[]".utf8), Data("{".utf8), Data("null".utf8)] {
            XCTAssertThrowsError(try MCPExchange.decodeProposal(bytes))
        }
        XCTAssertThrowsError(try MCPExchange.decodeProposal(Data([0xff, 0xfe, 0xff])))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: MCPExchange.encode(proposal())) as? [String: Any])
        object["goalID"] = "wrong"
        XCTAssertThrowsError(try MCPExchange.decodeProposal(JSONSerialization.data(withJSONObject: object)))
        object["goalID"] = NSNull()
        XCTAssertThrowsError(try MCPExchange.decodeProposal(JSONSerialization.data(withJSONObject: object)))
        object.removeValue(forKey: "goalID")
        XCTAssertThrowsError(try MCPExchange.decodeProposal(JSONSerialization.data(withJSONObject: object)))
    }

    func testVersionKindSizesAndCountsAreBounded() throws {
        var value = proposal()
        value.schemaVersion = 2
        XCTAssertThrowsError(try MCPExchange.validateProposal(value, now: now))
        value.schemaVersion = 1
        value.kind = "dayvault.snapshot"
        XCTAssertThrowsError(try MCPExchange.validateProposal(value, now: now))
        value = proposal()
        value.items = []
        XCTAssertThrowsError(try MCPExchange.validateProposal(value, now: now))
        value.items = (1...21).map { .init(title: "阅读\($0)", date: "2026-09-14") }
        XCTAssertThrowsError(try MCPExchange.validateProposal(value, now: now))
        XCTAssertThrowsError(try MCPExchange.decodeProposal(Data(repeating: 32, count: MCPExchange.maxProposalBytes + 1)))
        XCTAssertThrowsError(try MCPExchange.decodeSnapshot(Data(repeating: 32, count: MCPExchange.maxSnapshotBytes + 1)))
    }

    func testTextRejectsWhitespaceControlsAndUsesUnicodeScalars() throws {
        for title in ["", " 阅读", "阅读\n下一章", "阅读\u{202E}abc", String(repeating: "书", count: 121)] {
            var value = proposal()
            value.items[0].title = title
            XCTAssertThrowsError(try MCPExchange.validateProposal(value, now: now), title)
        }
        var value = proposal()
        value.items[0].title = String(repeating: "书", count: 120)
        XCTAssertNoThrow(try MCPExchange.validateProposal(value, now: now))
        value.summary = String(repeating: "a", count: 501)
        XCTAssertThrowsError(try MCPExchange.validateProposal(value, now: now))
    }

    func testDuplicateIDsAndCaseInsensitiveTitleDatePairsFail() {
        var value = proposal()
        value.items.append(value.items[0])
        XCTAssertThrowsError(try MCPExchange.validateProposal(value, now: now))
        value = proposal()
        value.items[0].title = "Read"
        value.items.append(.init(title: "read", date: value.items[0].date))
        XCTAssertThrowsError(try MCPExchange.validateProposal(value, now: now))
        value.items[0].title = "Café"
        value.items[1].title = "Cafe\u{0301}"
        XCTAssertThrowsError(try MCPExchange.validateProposal(value, now: now))
    }

    func testFourteenDayHorizonUsesGoalZoneNotDeviceZone() throws {
        let instant = try XCTUnwrap(MCPExchange.timestamp("2026-09-14T12:00:00Z"))
        var value = proposal(zone: "Pacific/Kiritimati")
        value.createdAt = "2026-09-14T12:00:00Z"
        value.items[0].date = "2026-09-15"
        XCTAssertNoThrow(try MCPExchange.validateProposal(value, now: instant))
        value.items[0].date = "2026-09-29"
        XCTAssertNoThrow(try MCPExchange.validateProposal(value, now: instant))
        value.items[0].date = "2026-09-30"
        XCTAssertThrowsError(try MCPExchange.validateProposal(value, now: instant))
        value.items[0].date = "2026-09-14"
        XCTAssertThrowsError(try MCPExchange.validateProposal(value, now: instant))
    }

    func testExpiryAndClockSkewAreCheckedAgainAtAcceptance() {
        let value = proposal()
        XCTAssertNoThrow(try MCPExchange.validateProposal(value, now: now.addingTimeInterval(-300)))
        XCTAssertThrowsError(try MCPExchange.validateProposal(value, now: now.addingTimeInterval(-301)))
        var old = value
        old.createdAt = ISO8601DateFormatter().string(from: now.addingTimeInterval(-7 * 86_400 - 1))
        XCTAssertThrowsError(try MCPExchange.validateProposal(old, now: now))
    }

    func testCalendarDateValidationAcrossLeapDaysAndDST() throws {
        XCTAssertNil(MCPExchange.date("2026-02-29", timeZoneID: "UTC"))
        XCTAssertNotNil(MCPExchange.date("2028-02-29", timeZoneID: "UTC"))
        for invalid in ["2026-04-31", "2026-13-01", "2026-00-01", "2026-9-14", "2026-09-14T00:00:00Z"] {
            XCTAssertNil(MCPExchange.date(invalid, timeZoneID: "UTC"))
        }
        XCTAssertNil(MCPExchange.date("2026-09-14", timeZoneID: "Invalid/Zone"))
        XCTAssertNil(MCPExchange.date("2011-12-30", timeZoneID: "Pacific/Apia"))
        let first = try XCTUnwrap(MCPExchange.date("2026-03-08", timeZoneID: "America/New_York"))
        let second = try XCTUnwrap(MCPExchange.date("2026-03-09", timeZoneID: "America/New_York"))
        XCTAssertEqual(second.timeIntervalSince(first), 23 * 3_600)
    }

    func testTimestampsRequireAnOffsetAndRejectNormalizedInvalidTimes() {
        for invalid in ["2026-09-14", "2026-09-14T12:00:00", "2026-02-29T12:00:00Z",
                        "2026-09-14T24:00:00Z", "2026-09-14T23:60:00Z", "2026-09-14T23:59:60Z",
                        "2026-09-14T12:00:00+00:99", "2026-09-14T12:00:00+24:00"] {
            XCTAssertNil(MCPExchange.timestamp(invalid), invalid)
        }
        XCTAssertEqual(MCPExchange.timestamp("2026-09-14T20:00:00+08:00"), now)
        XCTAssertEqual(MCPExchange.timestamp("2026-09-14T12:00:00.000Z"), now)
    }

    func testSnapshotRoundTripDoesNotContainPrivateFields() throws {
        let value = snapshot()
        let data = try MCPExchange.encode(value)
        XCTAssertEqual(try MCPExchange.decodeSnapshot(data), value)
        let text = String(decoding: data, as: UTF8.self)
        for field in ["notes", "memories", "messages", "calendar", "achievement", "ruleJSON"] {
            XCTAssertFalse(text.contains("\"\(field)\""))
        }
    }

    func testSnapshotRejectsInjectedPrivateFieldsRatherThanForwardingThem() throws {
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: MCPExchange.encode(snapshot())) as? [String: Any])
        var goal = try XCTUnwrap(root["goal"] as? [String: Any])
        goal["notes"] = "private journal"
        root["goal"] = goal
        XCTAssertThrowsError(try MCPExchange.decodeSnapshot(JSONSerialization.data(withJSONObject: root)))
    }

    func testSnapshotWindowCountsStatusAndDuplicates() {
        var value = snapshot()
        value.records += value.records
        XCTAssertThrowsError(try MCPExchange.validateSnapshot(value))
        value = snapshot()
        value.records[0].status = "unlocked"
        XCTAssertThrowsError(try MCPExchange.validateSnapshot(value))
        value = snapshot()
        value.records[0].date = "2026-09-29"
        XCTAssertThrowsError(try MCPExchange.validateSnapshot(value))
        value = snapshot()
        value.window.endDate = "2027-09-14"
        XCTAssertThrowsError(try MCPExchange.validateSnapshot(value))
        value = snapshot()
        value.goal.restWeekdays = [1, 1]
        XCTAssertThrowsError(try MCPExchange.validateSnapshot(value))
    }

    func testSharedNodeFixturesDecodeWithIdenticalDatesAndIDs() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { root.deleteLastPathComponent() }
        let fixtures = root.appendingPathComponent("MCP/fixtures")
        let exported = try MCPExchange.decodeSnapshot(Data(contentsOf: fixtures.appendingPathComponent("snapshot.example.json")))
        let proposed = try MCPExchange.decodeProposal(Data(contentsOf: fixtures.appendingPathComponent("proposal.example.json")))
        let created = try XCTUnwrap(MCPExchange.timestamp(proposed.createdAt))
        try MCPExchange.validateProposal(proposed, now: created)
        XCTAssertEqual(proposed.snapshotID, exported.id)
        XCTAssertEqual(proposed.goalID, exported.goal.id)
        XCTAssertEqual(proposed.goalTitle, exported.goal.title)
        XCTAssertEqual(proposed.timeZoneID, exported.goal.timeZoneID)
        XCTAssertFalse(proposed.items.isEmpty)
    }
}
