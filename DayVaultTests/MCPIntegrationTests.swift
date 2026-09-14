import DayVaultCore
import Darwin
import Foundation
import SwiftData
import XCTest
@testable import DayVault

final class MCPIntegrationTests: XCTestCase {
    private let now = ISO8601DateFormatter().date(from: "2026-09-14T12:00:00Z")!
    private let zone = "Asia/Shanghai"

    @MainActor
    func testSnapshotExportsOnlySelectedGoalAndMinimalFieldsWithoutSaving() throws {
        let model = makeModel()
        let goal = try insertGoal(model)
        let other = try insertGoal(model, title: "工作")
        let item = ScheduleItem(title: "阅读一章", notes: "不应导出的私人备注", plannedStart: day("2026-09-14"),
            timeZoneID: zone, goalID: goal.id, timePrecision: .dateOnly)
        let unrelated = ScheduleItem(title: "其他目标的秘密", plannedStart: day("2026-09-14"),
            timeZoneID: zone, goalID: other.id, timePrecision: .dateOnly)
        let inbox = ScheduleItem(title: "待安排的秘密", plannedStart: day("2026-09-14"),
            timeZoneID: zone, goalID: goal.id, timePrecision: .inbox)
        [item, unrelated, inbox].forEach { model.context.insert($0) }
        model.context.insert(CompanionMessage(goalID: goal.id, role: "user", text: "不应导出的对话"))
        try model.saveJourney()
        let itemCount = model.items.count

        let snapshot = try model.makeMCPSnapshot(goalID: goal.id, now: now)
        let data = try MCPExchange.encode(snapshot)
        let text = String(decoding: data, as: UTF8.self)

        XCTAssertEqual(snapshot.records.map(\.title), ["阅读一章"])
        XCTAssertEqual(snapshot.window.startDate, "2026-08-15")
        XCTAssertEqual(snapshot.window.endDate, "2026-09-28")
        XCTAssertEqual(snapshot.goal.id, goal.id)
        for excluded in ["notes", "memories", "不应导出的", "其他目标的秘密", "待安排的秘密", "achievements"] {
            XCTAssertFalse(text.contains(excluded))
        }
        XCTAssertEqual(model.items.count, itemCount)
        XCTAssertFalse(model.context.hasChanges)
    }

    @MainActor
    func testSnapshotResolvesRecurringItemsAndHonorsHistoricalOccurrenceGoal() throws {
        let model = makeModel()
        let goal = try insertGoal(model)
        let other = try insertGoal(model, title: "其他目标")
        let recurring = ScheduleItem(title: "每日阅读", plannedStart: day("2026-08-01"), timeZoneID: zone,
            recurrenceRule: .init(kind: .daily), goalID: goal.id, timePrecision: .dateOnly)
        let reassigned = ScheduleItem(title: "历史归属", plannedStart: day("2026-09-13"), timeZoneID: zone,
            goalID: other.id, timePrecision: .dateOnly)
        [recurring, reassigned].forEach { model.context.insert($0) }
        let log = OccurrenceLog(scheduleItemID: reassigned.id,
            originalStart: reassigned.plannedStart, timeZoneID: zone)
        log.goalID = goal.id
        log.timePrecision = .dateOnly
        log.status = .completed
        log.completedAt = reassigned.plannedStart
        model.context.insert(log)
        try model.saveJourney()

        let snapshot = try model.makeMCPSnapshot(goalID: goal.id, now: now)

        XCTAssertEqual(snapshot.records.filter { $0.itemID == recurring.id }.count, 45)
        XCTAssertEqual(snapshot.records.first { $0.itemID == reassigned.id }?.status, "completed")
        XCTAssertFalse(try model.makeMCPSnapshot(goalID: other.id, now: now).records.contains { $0.itemID == reassigned.id })
    }

    @MainActor
    func testExportRejectsFutureCompletionsInsteadOfReportingFalseProgress() throws {
        let model = makeModel()
        let goal = try insertGoal(model)
        let item = ScheduleItem(title: "阅读一章", plannedStart: day("2026-09-15"),
            timeZoneID: zone, goalID: goal.id, timePrecision: .dateOnly)
        model.context.insert(item)
        let log = OccurrenceLog(scheduleItemID: item.id, originalStart: item.plannedStart, timeZoneID: zone)
        log.goalID = goal.id
        log.timePrecision = .dateOnly
        log.status = .completed
        log.completedAt = item.plannedStart
        model.context.insert(log)
        try model.saveJourney()
        XCTAssertThrowsError(try model.makeMCPSnapshot(goalID: goal.id, now: now)) {
            XCTAssertEqual($0 as? MCPImportError, .inconsistentHistory)
        }
        XCTAssertEqual(model.logs.first?.status, .completed, "Export must not repair or mutate the user's history")
    }

    @MainActor
    func testOversizedSnapshotFailsWithoutTruncating() throws {
        let model = makeModel()
        let goal = try insertGoal(model)
        for index in 0..<23 {
            model.context.insert(ScheduleItem(title: "事项 \(index)", plannedStart: day("2026-08-01"),
                timeZoneID: zone, recurrenceRule: .init(kind: .daily), goalID: goal.id, timePrecision: .dateOnly))
        }
        try model.saveJourney()
        XCTAssertThrowsError(try model.makeMCPSnapshot(goalID: goal.id, now: now)) {
            XCTAssertEqual($0 as? MCPExchangeError, .tooLarge)
        }
        XCTAssertEqual(model.items.count, 23)
    }

    @MainActor
    func testPreviewNeverWritesAndConfirmationCreatesOnlyDateOnlyItems() throws {
        let model = makeModel()
        let goal = try insertGoal(model)
        let proposal = makeProposal(goal: goal, dates: ["2026-09-15", "2026-09-16"])
        let preview = try model.previewMCPProposal(MCPExchange.encode(proposal), now: now)

        XCTAssertTrue(model.items.isEmpty)
        XCTAssertTrue(model.logs.isEmpty)
        XCTAssertFalse(model.context.hasChanges)
        XCTAssertTrue(model.companionMessages.isEmpty)

        try model.confirmMCPProposal(preview, now: now)

        XCTAssertEqual(Set(model.items.map(\.id)), Set(proposal.items.map(\.id)))
        XCTAssertTrue(model.items.allSatisfy {
            $0.goalID == goal.id && $0.timePrecision == .dateOnly && $0.timeZoneID == zone &&
            $0.recurrenceRule.kind == .none && $0.reminderLeadMinutes == nil && $0.notes.isEmpty &&
            $0.displayStart == nil && $0.displayEnd == nil
        })
        XCTAssertEqual(model.items.map { MCPExchange.dateString($0.plannedStart, timeZoneID: zone) }, ["2026-09-15", "2026-09-16"])
        XCTAssertTrue(model.logs.isEmpty)
        XCTAssertNil(goal.aiEnabledAt)
        XCTAssertTrue(model.companionMessages.isEmpty)
        XCTAssertTrue(model.unlockedAchievementIDs.contains("first_block"))
    }

    @MainActor
    func testSamePreviewAndFileCannotReplayAcrossRelaunch() throws {
        let model = makeModel()
        let goal = try insertGoal(model)
        let data = try MCPExchange.encode(makeProposal(goal: goal))
        let preview = try model.previewMCPProposal(data, now: now)
        try model.confirmMCPProposal(preview, now: now)

        XCTAssertThrowsError(try model.confirmMCPProposal(preview, now: now)) {
            XCTAssertEqual($0 as? MCPImportError, .duplicate)
        }
        let restored = makeModel(container: model.container)
        XCTAssertThrowsError(try restored.previewMCPProposal(data, now: now)) {
            XCTAssertEqual($0 as? MCPImportError, .duplicate)
        }
        XCTAssertEqual(restored.items.count, 1)
    }

    @MainActor
    func testFailedSaveRollsBackWholeBatchAndCanBeRetried() throws {
        let model = makeModel()
        let goal = try insertGoal(model)
        let data = try MCPExchange.encode(makeProposal(goal: goal, dates: ["2026-09-15", "2026-09-16"]))
        let preview = try model.previewMCPProposal(data, now: now)
        model.failNextJourneySaveForTesting = true

        XCTAssertThrowsError(try model.confirmMCPProposal(preview, now: now))
        XCTAssertTrue(model.items.isEmpty)
        XCTAssertTrue(try model.context.fetch(FetchDescriptor<ScheduleItem>()).isEmpty)
        XCTAssertTrue(model.context.autosaveEnabled)
        XCTAssertTrue(model.logs.isEmpty)
        XCTAssertFalse(model.unlockedAchievementIDs.contains("first_block"))

        try model.confirmMCPProposal(preview, now: now)
        XCTAssertEqual(model.items.count, 2)
    }

    @MainActor
    func testChangedGoalInvalidatesPreviewWithoutPartialImport() throws {
        let model = makeModel()
        let goal = try insertGoal(model)
        let preview = try model.previewMCPProposal(MCPExchange.encode(makeProposal(goal: goal)), now: now)
        goal.weeklyTargetDays = 4
        try model.saveJourney()

        XCTAssertThrowsError(try model.confirmMCPProposal(preview, now: now)) {
            XCTAssertEqual($0 as? MCPImportError, .goalChanged)
        }
        XCTAssertTrue(model.items.isEmpty)
    }

    @MainActor
    func testWrongGoalIdentityTitleOrTimezoneCannotBeImported() throws {
        let model = makeModel()
        let goal = try insertGoal(model)
        var proposal = makeProposal(goal: goal)
        proposal.goalID = UUID()
        XCTAssertThrowsError(try model.previewMCPProposal(MCPExchange.encode(proposal), now: now))
        proposal.goalID = goal.id
        proposal.goalTitle = "同名不代表同一目标"
        XCTAssertThrowsError(try model.previewMCPProposal(MCPExchange.encode(proposal), now: now))
        proposal.goalTitle = goal.title
        proposal.timeZoneID = "UTC"
        XCTAssertThrowsError(try model.previewMCPProposal(MCPExchange.encode(proposal), now: now))
        XCTAssertTrue(model.items.isEmpty)
    }

    @MainActor
    func testRestDayAndDeadlineAreCheckedAgainstCurrentGoal() throws {
        let model = makeModel()
        let goal = try insertGoal(model)
        goal.restWeekdaysCSV = "3" // Tuesday, September 15.
        try model.saveJourney()
        XCTAssertThrowsError(try model.previewMCPProposal(MCPExchange.encode(makeProposal(goal: goal)), now: now)) {
            XCTAssertEqual($0 as? MCPImportError, .restDay)
        }
        goal.restWeekdaysCSV = ""
        goal.deadline = day("2026-09-14")
        try model.saveJourney()
        XCTAssertThrowsError(try model.previewMCPProposal(MCPExchange.encode(makeProposal(goal: goal)), now: now)) {
            XCTAssertEqual($0 as? MCPImportError, .deadline)
        }
        XCTAssertTrue(model.items.isEmpty)
    }

    @MainActor
    func testNewConflictingRecordAfterPreviewBlocksEntireBatch() throws {
        let model = makeModel()
        let goal = try insertGoal(model)
        let proposal = makeProposal(goal: goal, dates: ["2026-09-15", "2026-09-16"])
        let preview = try model.previewMCPProposal(MCPExchange.encode(proposal), now: now)
        let added = ScheduleItem(title: proposal.items[1].title, plannedStart: day("2026-09-16"),
            timeZoneID: zone, goalID: goal.id, timePrecision: .dateOnly)
        model.context.insert(added)
        try model.saveJourney()

        XCTAssertThrowsError(try model.confirmMCPProposal(preview, now: now)) {
            XCTAssertEqual($0 as? MCPImportError, .duplicate)
        }
        XCTAssertEqual(model.items.map(\.id), [added.id])
    }

    @MainActor
    func testRecurringDuplicateAndArchivedIDsAreRejected() throws {
        let model = makeModel()
        let goal = try insertGoal(model)
        let proposal = makeProposal(goal: goal)
        let recurring = ScheduleItem(title: proposal.items[0].title, plannedStart: day("2026-09-01"),
            timeZoneID: zone, recurrenceRule: .init(kind: .daily), goalID: goal.id, timePrecision: .dateOnly)
        model.context.insert(recurring)
        try model.saveJourney()
        XCTAssertThrowsError(try model.previewMCPProposal(MCPExchange.encode(proposal), now: now)) {
            XCTAssertEqual($0 as? MCPImportError, .duplicate)
        }
        var changed = proposal
        changed.items[0].title = "无重复标题"
        let archived = ScheduleItem(id: changed.items[0].id, title: "旧记录", plannedStart: day("2026-07-01"), timeZoneID: zone)
        archived.isArchived = true
        model.context.insert(archived)
        try model.saveJourney()
        XCTAssertThrowsError(try model.previewMCPProposal(MCPExchange.encode(changed), now: now)) {
            XCTAssertEqual($0 as? MCPImportError, .duplicate)
        }
    }

    @MainActor
    func testGoalDeletedAfterPreviewIsRejected() throws {
        let model = makeModel()
        let goal = try insertGoal(model)
        let preview = try model.previewMCPProposal(MCPExchange.encode(makeProposal(goal: goal)), now: now)
        model.context.delete(goal)
        try model.saveJourney()
        XCTAssertThrowsError(try model.confirmMCPProposal(preview, now: now)) {
            XCTAssertEqual($0 as? MCPImportError, .goalMissing)
        }
        XCTAssertTrue(model.items.isEmpty)
    }

    @MainActor
    func testDatesAreRecheckedOnConfirmationAfterMidnight() throws {
        let model = makeModel()
        let goal = try insertGoal(model)
        let proposal = makeProposal(goal: goal, dates: ["2026-09-14"])
        let preview = try model.previewMCPProposal(MCPExchange.encode(proposal), now: now)
        XCTAssertThrowsError(try model.confirmMCPProposal(preview, now: now.addingTimeInterval(86_400))) {
            XCTAssertEqual($0 as? MCPExchangeError, .invalidDate)
        }
        XCTAssertTrue(model.items.isEmpty)
    }

    @MainActor
    func testDayOnlyImportKeepsGoalTimezoneAcrossDST() throws {
        let model = makeModel()
        let zone = "America/Los_Angeles"
        let goal = PersonalGoal(title: "阅读", timeZoneID: zone)
        model.context.insert(goal)
        try model.saveJourney()
        let date = ISO8601DateFormatter().date(from: "2026-10-31T18:00:00Z")!
        let proposal = MCPScheduleProposal(snapshotID: UUID(), goalID: goal.id, goalTitle: goal.title,
            timeZoneID: zone, createdAt: date.ISO8601Format(), summary: "安排两次阅读。", items: [
                MCPProposedItem(title: "第一章", date: "2026-11-01"), MCPProposedItem(title: "第二章", date: "2026-11-02")
            ])
        let preview = try model.previewMCPProposal(MCPExchange.encode(proposal), now: date)
        try model.confirmMCPProposal(preview, now: date)
        XCTAssertEqual(model.items.map { MCPExchange.dateString($0.plannedStart, timeZoneID: zone) }, ["2026-11-01", "2026-11-02"])
        XCTAssertEqual(model.items[1].plannedStart.timeIntervalSince(model.items[0].plannedStart), 25 * 3_600)
    }

    func testBoundedFileReaderRejectsOversizedFilesAndSymlinks() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("proposal.json")
        try Data(repeating: 32, count: MCPExchange.maxProposalBytes + 1).write(to: file)
        XCTAssertThrowsError(try MCPProposalFile.read(file)) {
            XCTAssertEqual($0 as? MCPExchangeError, .tooLarge)
        }
        let link = directory.appendingPathComponent("link.json")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)
        XCTAssertThrowsError(try MCPProposalFile.read(link))
        XCTAssertThrowsError(try MCPProposalFile.read(directory)) {
            XCTAssertEqual($0 as? MCPImportError, .unreadableFile)
        }
        let pipe = directory.appendingPathComponent("pipe.json")
        let created = pipe.withUnsafeFileSystemRepresentation { path -> Int32 in
            guard let path else { return -1 }
            return mkfifo(path, S_IRUSR | S_IWUSR)
        }
        XCTAssertEqual(created, 0)
        XCTAssertThrowsError(try MCPProposalFile.read(pipe)) {
            XCTAssertEqual($0 as? MCPImportError, .unreadableFile)
        }
        try Data("{}".utf8).write(to: file)
        XCTAssertEqual(try MCPProposalFile.read(file), Data("{}".utf8))
    }

    @MainActor
    private func makeModel(container: ModelContainer? = nil) -> AppModel {
        let model = AppModel(container: container ?? PersistenceController.makeContainer(inMemory: true),
            persistAvatarPreferences: false)
        model.calendarEnabled = false
        return model
    }

    @MainActor
    private func insertGoal(_ model: AppModel, title: String = "阅读") throws -> PersonalGoal {
        let goal = PersonalGoal(title: title, timeZoneID: zone)
        model.context.insert(goal)
        try model.saveJourney()
        return goal
    }

    private func day(_ value: String) -> Date { MCPExchange.date(value, timeZoneID: zone)! }

    private func makeProposal(goal: PersonalGoal, dates: [String] = ["2026-09-15"]) -> MCPScheduleProposal {
        MCPScheduleProposal(snapshotID: UUID(), goalID: goal.id, goalTitle: goal.title, timeZoneID: goal.timeZoneID,
            createdAt: now.ISO8601Format(), summary: "按目标安排阅读。", items: dates.enumerated().map { index, date in
                MCPProposedItem(title: "阅读第 \(index + 1) 章", date: date)
            })
    }
}
