import Foundation
import SwiftData
import XCTest
@testable import DayVaultCore

final class JourneyMigrationTests: XCTestCase {
    @MainActor
    func testFrozenV1DiskStoreMigratesAllSixEntitiesAndDefaultsSafely() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("DayVault.store")
        let start = Date(timeIntervalSince1970: 1_750_000_000)
        let itemID = UUID()
        let inboxID = UUID()
        let categoryID = UUID()
        let key = OccurrenceKey.make(itemID: itemID, originalStart: start, timeZoneID: "Asia/Shanghai")
        try autoreleasepool {
            let schema = Schema(versionedSchema: DayVaultSchemaV1.self)
            let container = try ModelContainer(for: schema, configurations: [
                ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none),
            ])
            let item = DayVaultSchemaV1.ScheduleItem(id: itemID, title: "旧记录", notes: "旧备注", categoryID: categoryID,
                                                   plannedStart: start, plannedDurationMinutes: 42,
                                                   timeZoneID: "Asia/Shanghai", priority: .high,
                                                   recurrenceRule: RecurrenceRule(kind: .weekdays))
            let inbox = DayVaultSchemaV1.ScheduleItem(id: inboxID, title: "旧收件箱", plannedStart: start, isUnscheduled: true)
            let log = DayVaultSchemaV1.OccurrenceLog(scheduleItemID: itemID, originalStart: start, timeZoneID: item.timeZoneID)
            log.status = .completed
            log.completedAt = start.addingTimeInterval(42 * 60)
            log.actualStart = start
            log.actualEnd = log.completedAt
            let state = DayVaultSchemaV1.AchievementState(definitionID: "first_check")
            state.unlockedAt = log.completedAt
            state.progress = 1
            container.mainContext.insert(item)
            container.mainContext.insert(inbox)
            container.mainContext.insert(log)
            container.mainContext.insert(state)
            container.mainContext.insert(DayVaultSchemaV1.ScheduleCategory(id: categoryID, name: "运动", colorHex: "#123456", symbolName: "circle", balanceGroup: .care))
            container.mainContext.insert(DayVaultSchemaV1.QuickTemplate(title: "旧模板", durationMinutes: 42))
            container.mainContext.insert(DayVaultSchemaV1.DayReview(day: start, timeZoneID: "Asia/Shanghai"))
            try container.mainContext.save()
        }
        let container = try migratedContainer(at: url)
        let items = try container.mainContext.fetch(FetchDescriptor<ScheduleItem>())
        let item = try XCTUnwrap(items.first { $0.id == itemID })
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(item.title, "旧记录")
        XCTAssertEqual(item.notes, "旧备注")
        XCTAssertEqual(item.categoryID, categoryID)
        XCTAssertEqual(item.plannedStart, start)
        XCTAssertEqual(item.plannedDurationMinutes, 42)
        XCTAssertEqual(item.priority, .high)
        XCTAssertEqual(item.recurrenceRule.kind, .weekdays)
        XCTAssertNil(item.goalID)
        XCTAssertEqual(item.timePrecision, .timed)
        XCTAssertEqual(items.first { $0.id == inboxID }?.timePrecision, .inbox)
        let log = try XCTUnwrap(container.mainContext.fetch(FetchDescriptor<OccurrenceLog>()).first)
        XCTAssertEqual(log.occurrenceKey, key)
        XCTAssertEqual(log.status, .completed)
        XCTAssertEqual(log.actualEnd, start.addingTimeInterval(42 * 60))
        XCTAssertEqual(log.timePrecision, .timed)
        XCTAssertNil(log.goalID)
        XCTAssertFalse(log.recordedDuringCompanionship)
        XCTAssertNil(log.companionSessionID)
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<AchievementState>()).first?.unlockedAt, log.completedAt)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<ScheduleCategory>()), 1)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<QuickTemplate>()), 1)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<DayReview>()), 1)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<PersonalGoal>()), 0)
    }

    /// The optional local fixture was written by the original V1 code before freezing these models.
    @MainActor
    func testOriginalPrechangeV1DatabaseIsCompatibleWithFrozenSchema() throws {
        let source = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("DayVaultOriginalV1-27E6F2CA", isDirectory: true)
        guard FileManager.default.fileExists(atPath: source.appendingPathComponent("DayVault.store").path) else {
            throw XCTSkip("Original-build fixture is local to the development host; frozen V1 disk migration always runs.")
        }
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let copied = directory.appendingPathComponent("original", isDirectory: true)
        try FileManager.default.copyItem(at: source, to: copied)
        let container = try migratedContainer(at: copied.appendingPathComponent("DayVault.store"))
        let item = try XCTUnwrap(container.mainContext.fetch(FetchDescriptor<ScheduleItem>()).first)
        XCTAssertEqual(item.title, "V1 原始记录")
        XCTAssertEqual(item.notes, "保留的备注")
        XCTAssertEqual(item.plannedDurationMinutes, 42)
        XCTAssertNil(item.goalID)
        XCTAssertEqual(item.timePrecision, .timed)
        let log = try XCTUnwrap(container.mainContext.fetch(FetchDescriptor<OccurrenceLog>()).first)
        XCTAssertEqual(log.occurrenceKey, OccurrenceKey.make(itemID: item.id, originalStart: item.plannedStart, timeZoneID: item.timeZoneID))
        XCTAssertFalse(log.recordedDuringCompanionship)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<AchievementState>()), 1)
    }

    @MainActor
    func testNewJourneyModelsPersistTogetherWithoutRequiredRelationships() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("DayVault.store")
        let goalID = UUID()
        let start = Date(timeIntervalSince1970: 1_750_000_000)
        try autoreleasepool {
            let container = try migratedContainer(at: url)
            let goal = PersonalGoal(id: goalID, title: "练习吉他", timeZoneID: "Asia/Shanghai", aiEnabledAt: start)
            goal.restWeekdaysCSV = "1,7"
            goal.companionRecordedDayKeysJSON = "[\"2025-06-15\"]"
            let rule = PersonalAchievementRule(kind: .activeDays, target: 3, startsAt: start, timeZoneID: goal.timeZoneID)
            let definition = PersonalAchievementDefinition(goalID: goalID, batchID: UUID(), title: "三次和弦", rule: rule, confirmedAt: start)
            let evidence = PersonalAchievementEvidence(definitionKey: definition.definitionKey, goalID: goalID,
                                                       unlockedAt: start, occurrenceKeys: ["one", "one", "two"],
                                                       ruleJSON: definition.ruleJSON, metricValue: 3)
            let message = CompanionMessage(goalID: goalID, text: "已记下", sourceOccurrenceKeys: ["one"])
            message.sourceVersionsJSON = "{\"one\":\"v1\"}"
            message.triggerKey = "daily:2025-06-15"
            let memory = CompanionMemory(goalID: goalID, text: "练习目标", sourceOccurrenceKeys: ["one"])
            memory.isConfirmed = false
            container.mainContext.insert(goal)
            container.mainContext.insert(definition)
            container.mainContext.insert(evidence)
            container.mainContext.insert(message)
            container.mainContext.insert(memory)
            container.mainContext.insert(PlanAdjustmentRecord(goalID: goalID, reason: "时间变化", beforeJSON: "[]", afterJSON: "[]"))
            try container.mainContext.save()
        }
        let container = try migratedContainer(at: url)
        let goal = try XCTUnwrap(container.mainContext.fetch(FetchDescriptor<PersonalGoal>()).first)
        XCTAssertEqual(goal.id, goalID)
        XCTAssertEqual(goal.restWeekdaysCSV, "1,7")
        XCTAssertEqual(goal.aiEnabledAt, start)
        let definition = try XCTUnwrap(container.mainContext.fetch(FetchDescriptor<PersonalAchievementDefinition>()).first)
        XCTAssertEqual(definition.rule?.target, 3)
        XCTAssertEqual(definition.rule?.startsAt, start)
        XCTAssertEqual(definition.confirmedAt, start)
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<PersonalAchievementEvidence>()).first?.occurrenceKeys, ["one", "two"])
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<CompanionMessage>()).first?.triggerKey, "daily:2025-06-15")
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<CompanionMemory>()).first?.isConfirmed, false)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<PlanAdjustmentRecord>()), 1)
    }

    private func temporaryDirectory() throws -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("DayVaultMigrationTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    @MainActor
    private func migratedContainer(at url: URL) throws -> ModelContainer {
        let schema = Schema(versionedSchema: DayVaultSchemaV2.self)
        return try ModelContainer(for: schema, migrationPlan: DayVaultMigrationPlan.self, configurations: [
            ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none),
        ])
    }
}
