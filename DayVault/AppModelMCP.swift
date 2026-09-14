import DayVaultCore
import Darwin
import Foundation
import SwiftData

enum MCPImportError: LocalizedError, Equatable {
    case goalMissing, goalChanged, duplicate, restDay, deadline, unreadableFile, inconsistentHistory

    var errorDescription: String? {
        switch self {
        case .goalMissing: "找不到草案对应的目标。请为现有目标重新导出快照。"
        case .goalChanged: "目标设置已变化。请重新导出快照并生成草案。"
        case .duplicate: "部分事项已经存在，没有导入。请移除重复事项后重试。"
        case .restDay: "草案中有事项安排在休息日。请调整日期后重新导入。"
        case .deadline: "草案中有事项超出目标期限。请调整日期后重新导入。"
        case .unreadableFile: "无法读取此文件。请将 JSON 文件保存到“文件”后重试。"
        case .inconsistentHistory: "部分完成记录的日期不正确。请修正未来日期的完成记录后重新导出。"
        }
    }
}

struct MCPProposalPreview: Identifiable {
    let proposal: MCPScheduleProposal
    fileprivate let goalRevision: MCPGoalRevision
    var id: UUID { proposal.id }
}

fileprivate struct MCPGoalRevision: Equatable {
    let goal: MCPGoalSnapshot
    let updatedAt: Date
    let deadline: Date?
}

extension AppModel {
    /// A selected-goal transfer, not a backup. Creating the preview never writes a file or saves records.
    func makeMCPSnapshot(goalID: UUID, now: Date = Date()) throws -> MCPSnapshot {
        let goal = try currentMCPGoal(goalID)
        let scope = try mcpGoalSnapshot(goal)
        var calendar = Calendar(identifier: .gregorian)
        guard let zone = TimeZone(identifier: goal.timeZoneID) else { throw MCPExchangeError.invalidDate }
        calendar.timeZone = zone
        let today = calendar.startOfDay(for: now)
        guard let start = calendar.date(byAdding: .day, value: -30, to: today),
              let endDay = calendar.date(byAdding: .day, value: 14, to: today),
              let end = calendar.date(byAdding: .day, value: 1, to: endDay) else { throw MCPExchangeError.invalidDate }
        let window = MCPDateWindow(startDate: MCPExchange.dateString(start, timeZoneID: goal.timeZoneID),
                                   endDate: MCPExchange.dateString(endDay, timeZoneID: goal.timeZoneID))
        let occurrences = try currentMCPOccurrences(in: DateInterval(start: start, end: end))
        let allLogs = try context.fetch(FetchDescriptor<OccurrenceLog>())
        let completionLogs = Dictionary(allLogs.map { ($0.occurrenceKey, $0) }, uniquingKeysWith: {
            $0.updatedAt >= $1.updatedAt ? $0 : $1
        })
        let todayKey = MCPExchange.dateString(today, timeZoneID: goal.timeZoneID)
        for occurrence in occurrences where occurrence.goalID == goalID && occurrence.status == .completed {
            guard MCPExchange.dateString(occurrence.start, timeZoneID: goal.timeZoneID) <= todayKey,
                  let completedAt = completionLogs[occurrence.id]?.completedAt, completedAt <= now else {
                throw MCPImportError.inconsistentHistory
            }
        }
        let records = occurrences.compactMap { occurrence -> MCPRecordSnapshot? in
            guard occurrence.goalID == goalID, occurrence.timePrecision != .inbox,
                  occurrence.status != .removed else { return nil }
            let date = MCPExchange.dateString(occurrence.start, timeZoneID: goal.timeZoneID)
            guard date >= window.startDate, date <= window.endDate else { return nil }
            return MCPRecordSnapshot(id: occurrence.id, itemID: occurrence.itemID, title: occurrence.title,
                date: date, status: occurrence.status.rawValue, timePrecision: occurrence.timePrecision.rawValue)
        }.sorted { lhs, rhs in lhs.date == rhs.date ? lhs.id < rhs.id : lhs.date < rhs.date }
        let snapshot = MCPSnapshot(exportedAt: now.ISO8601Format(), goal: scope, window: window, records: records)
        try MCPExchange.validateSnapshot(snapshot)
        return snapshot
    }

    func previewMCPProposal(_ data: Data, now: Date = Date()) throws -> MCPProposalPreview {
        let proposal = try MCPExchange.decodeProposal(data)
        try MCPExchange.validateProposal(proposal, now: now)
        let goal = try currentMCPGoal(proposal.goalID)
        try validateMCPProposalAgainstCurrentRecords(proposal, goal: goal, now: now)
        return MCPProposalPreview(proposal: proposal, goalRevision: try mcpGoalRevision(goal))
    }

    /// Stay on MainActor, with no await between validation and the single batch save.
    func confirmMCPProposal(_ preview: MCPProposalPreview, now: Date = Date()) throws {
        let proposal = preview.proposal
        try MCPExchange.validateProposal(proposal, now: now)
        let goal = try currentMCPGoal(proposal.goalID)
        guard try mcpGoalRevision(goal) == preview.goalRevision else { throw MCPImportError.goalChanged }
        try validateMCPProposalAgainstCurrentRecords(proposal, goal: goal, now: now)
        let newItems = try proposal.items.map { proposed -> ScheduleItem in
            guard let date = MCPExchange.date(proposed.date, timeZoneID: goal.timeZoneID) else {
                throw MCPExchangeError.invalidDate
            }
            return ScheduleItem(id: proposed.id, title: proposed.title, plannedStart: date,
                plannedDurationMinutes: 1, timeZoneID: goal.timeZoneID, goalID: goal.id, timePrecision: .dateOnly)
        }
        let autosave = context.autosaveEnabled
        context.autosaveEnabled = false
        defer { context.autosaveEnabled = autosave }
        newItems.forEach { context.insert($0) }
        try saveJourney()
        // These are new plans, not imported completions. No reminder or occurrence log is created.
        reconcileAchievements()
        reconcilePersonalAchievements(presentNewUnlocks: false)
        writeWidgetSnapshot()
    }

    private func currentMCPGoal(_ id: UUID) throws -> PersonalGoal {
        guard let goal = try context.fetch(FetchDescriptor<PersonalGoal>()).filter({ $0.id == id })
            .max(by: { $0.updatedAt < $1.updatedAt }) else { throw MCPImportError.goalMissing }
        return goal
    }

    private func mcpGoalSnapshot(_ goal: PersonalGoal) throws -> MCPGoalSnapshot {
        let components = goal.restWeekdaysCSV.split(separator: ",", omittingEmptySubsequences: false)
        let restDays = goal.restWeekdaysCSV.isEmpty ? [] : components.compactMap { Int($0) }
        guard goal.restWeekdaysCSV.isEmpty || restDays.count == components.count,
              Set(restDays).count == restDays.count, restDays.allSatisfy({ (1...7).contains($0) }),
              TimeZone(identifier: goal.timeZoneID) != nil else { throw MCPExchangeError.invalidDate }
        return MCPGoalSnapshot(id: goal.id, title: goal.title, timeZoneID: goal.timeZoneID,
            restWeekdays: restDays.sorted(), weeklyTargetDays: goal.weeklyTargetDays,
            deadlineDate: goal.deadline.map { MCPExchange.dateString($0, timeZoneID: goal.timeZoneID) })
    }

    private func mcpGoalRevision(_ goal: PersonalGoal) throws -> MCPGoalRevision {
        MCPGoalRevision(goal: try mcpGoalSnapshot(goal), updatedAt: goal.updatedAt, deadline: goal.deadline)
    }

    private func currentMCPOccurrences(in interval: DateInterval) throws -> [ScheduleOccurrence] {
        let allItems = try context.fetch(FetchDescriptor<ScheduleItem>())
        let allLogs = try context.fetch(FetchDescriptor<OccurrenceLog>())
        let canonical = Dictionary(allItems.map { ($0.id, $0) }, uniquingKeysWith: {
            $0.updatedAt >= $1.updatedAt ? $0 : $1
        })
        return canonical.values.flatMap { RecurrenceResolver.occurrences(for: $0, in: interval, logs: allLogs) }
    }

    private func validateMCPProposalAgainstCurrentRecords(_ proposal: MCPScheduleProposal,
                                                         goal: PersonalGoal, now: Date) throws {
        let scope = try mcpGoalSnapshot(goal)
        guard proposal.goalTitle == scope.title, proposal.timeZoneID == scope.timeZoneID else {
            throw MCPImportError.goalChanged
        }
        // Inspect every persisted ID, including archived items and logs awaiting a synced parent item.
        let allItems = try context.fetch(FetchDescriptor<ScheduleItem>())
        let allLogs = try context.fetch(FetchDescriptor<OccurrenceLog>())
        let existingIDs = Set(allItems.map(\.id)).union(allLogs.map(\.scheduleItemID))
        guard proposal.items.allSatisfy({ !existingIDs.contains($0.id) }) else { throw MCPImportError.duplicate }
        var calendar = Calendar(identifier: .gregorian)
        guard let zone = TimeZone(identifier: goal.timeZoneID) else { throw MCPExchangeError.invalidDate }
        calendar.timeZone = zone
        let start = calendar.startOfDay(for: now)
        guard let end = calendar.date(byAdding: .day, value: 15, to: start) else { throw MCPExchangeError.invalidDate }
        let current = try currentMCPOccurrences(in: DateInterval(start: start, end: end))
            .filter { $0.goalID == goal.id && $0.timePrecision != .inbox }
        let pairs = Set(current.map {
            MCPExchange.dateString($0.start, timeZoneID: goal.timeZoneID) + "\n" + $0.title.lowercased()
        })
        for item in proposal.items {
            guard let day = MCPExchange.date(item.date, timeZoneID: goal.timeZoneID) else { throw MCPExchangeError.invalidDate }
            guard !scope.restWeekdays.contains(calendar.component(.weekday, from: day)) else { throw MCPImportError.restDay }
            if let deadline = scope.deadlineDate, item.date > deadline { throw MCPImportError.deadline }
            guard !pairs.contains(item.date + "\n" + item.title.lowercased()) else { throw MCPImportError.duplicate }
        }
    }
}

enum MCPProposalFile {
    static func read(_ url: URL) throws -> Data {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            // Check the opened descriptor, not a path that could change between inspection and open.
            // Nonblocking mode also prevents a selected FIFO from hanging the app before fstat.
            let descriptor = url.withUnsafeFileSystemRepresentation { path -> Int32 in
                guard let path else { return -1 }
                return Darwin.open(path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
            }
            guard descriptor >= 0 else { throw MCPImportError.unreadableFile }
            let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
            defer { try? handle.close() }
            var status = stat()
            guard fstat(descriptor, &status) == 0, status.st_mode & S_IFMT == S_IFREG else {
                throw MCPImportError.unreadableFile
            }
            guard status.st_size >= 0, status.st_size <= MCPExchange.maxProposalBytes else { throw MCPExchangeError.tooLarge }
            let data = try handle.read(upToCount: MCPExchange.maxProposalBytes + 1) ?? Data()
            guard data.count <= MCPExchange.maxProposalBytes else { throw MCPExchangeError.tooLarge }
            guard data.count == status.st_size else { throw MCPImportError.unreadableFile }
            return data
        } catch let error as MCPExchangeError { throw error }
        catch { throw MCPImportError.unreadableFile }
    }
}
