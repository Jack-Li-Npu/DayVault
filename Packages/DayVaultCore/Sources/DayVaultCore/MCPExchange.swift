import Foundation

// These transfer objects deliberately have no notes, memories, unlocks or database relationships.
public struct MCPGoalSnapshot: Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var timeZoneID: String
    public var restWeekdays: [Int]
    public var weeklyTargetDays: Int?
    public var deadlineDate: String?

    public init(id: UUID, title: String, timeZoneID: String, restWeekdays: [Int] = [],
                weeklyTargetDays: Int? = nil, deadlineDate: String? = nil) {
        self.id = id
        self.title = title
        self.timeZoneID = timeZoneID
        self.restWeekdays = restWeekdays
        self.weeklyTargetDays = weeklyTargetDays
        self.deadlineDate = deadlineDate
    }
}

public struct MCPRecordSnapshot: Codable, Equatable, Sendable {
    public var id: String
    public var itemID: UUID
    public var title: String
    public var date: String
    public var status: String
    public var timePrecision: String

    public init(id: String, itemID: UUID, title: String, date: String, status: String, timePrecision: String) {
        self.id = id
        self.itemID = itemID
        self.title = title
        self.date = date
        self.status = status
        self.timePrecision = timePrecision
    }
}

public struct MCPDateWindow: Codable, Equatable, Sendable {
    public var startDate: String
    public var endDate: String

    public init(startDate: String, endDate: String) {
        self.startDate = startDate
        self.endDate = endDate
    }
}

public struct MCPSnapshot: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var kind: String
    public var id: UUID
    public var exportedAt: String
    public var goal: MCPGoalSnapshot
    public var window: MCPDateWindow
    public var records: [MCPRecordSnapshot]

    public init(schemaVersion: Int = 1, kind: String = "dayvault.snapshot", id: UUID = UUID(),
                exportedAt: String, goal: MCPGoalSnapshot, window: MCPDateWindow, records: [MCPRecordSnapshot]) {
        self.schemaVersion = schemaVersion
        self.kind = kind
        self.id = id
        self.exportedAt = exportedAt
        self.goal = goal
        self.window = window
        self.records = records
    }
}

public struct MCPProposedItem: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var title: String
    public var date: String

    public init(id: UUID = UUID(), title: String, date: String) {
        self.id = id
        self.title = title
        self.date = date
    }
}

public struct MCPScheduleProposal: Codable, Equatable, Sendable, Identifiable {
    public var schemaVersion: Int
    public var kind: String
    public var id: UUID
    public var snapshotID: UUID
    public var goalID: UUID
    public var goalTitle: String
    public var timeZoneID: String
    public var createdAt: String
    public var summary: String
    public var items: [MCPProposedItem]

    public init(schemaVersion: Int = 1, kind: String = "dayvault.proposal", id: UUID = UUID(),
                snapshotID: UUID, goalID: UUID, goalTitle: String, timeZoneID: String,
                createdAt: String, summary: String, items: [MCPProposedItem]) {
        self.schemaVersion = schemaVersion
        self.kind = kind
        self.id = id
        self.snapshotID = snapshotID
        self.goalID = goalID
        self.goalTitle = goalTitle
        self.timeZoneID = timeZoneID
        self.createdAt = createdAt
        self.summary = summary
        self.items = items
    }
}

public enum MCPExchangeError: LocalizedError, Equatable {
    case invalidFile, unsupportedVersion, tooLarge, invalidDate, invalidText, duplicateItems, expired

    public var errorDescription: String? {
        switch self {
        case .invalidFile: "文件格式不正确。请选择 DayVault 导出的快照或 MCP 生成的计划草案。"
        case .unsupportedVersion: "暂不支持此文件版本。请更新 DayVault 或重新生成草案。"
        case .tooLarge: "文件超出大小或数量限制。请减少事项后重试。"
        case .invalidDate: "日期或时区不正确。草案只能安排今天起 14 天内的事项。"
        case .invalidText: "部分文字为空、过长或含不可见控制字符。请修改后重试。"
        case .duplicateItems: "草案含重复事项。请移除重复内容后重试。"
        case .expired: "草案已过期或生成时间不正确。请重新导出目标并生成草案。"
        }
    }
}

public enum MCPExchange {
    public static let maxProposalBytes = 128 * 1_024
    public static let maxSnapshotBytes = 1_024 * 1_024

    public static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }

    /// Do not rely on Codable's normal unknown-key tolerance at an external trust boundary.
    public static func decodeProposal(_ data: Data) throws -> MCPScheduleProposal {
        guard data.count <= maxProposalBytes else { throw MCPExchangeError.tooLarge }
        let root = try object(data)
        try checkKeys(root, required: ["schemaVersion", "kind", "id", "snapshotID", "goalID",
                                      "goalTitle", "timeZoneID", "createdAt", "summary", "items"])
        guard let items = root["items"] as? [[String: Any]], (1...20).contains(items.count) else {
            throw MCPExchangeError.invalidFile
        }
        for item in items { try checkKeys(item, required: ["id", "title", "date"]) }
        do { return try JSONDecoder().decode(MCPScheduleProposal.self, from: data) }
        catch { throw MCPExchangeError.invalidFile }
    }

    public static func decodeSnapshot(_ data: Data) throws -> MCPSnapshot {
        guard data.count <= maxSnapshotBytes else { throw MCPExchangeError.tooLarge }
        let root = try object(data)
        try checkKeys(root, required: ["schemaVersion", "kind", "id", "exportedAt", "goal", "window", "records"])
        guard let goal = root["goal"] as? [String: Any], let window = root["window"] as? [String: Any],
              let records = root["records"] as? [[String: Any]], records.count <= 1_000 else {
            throw MCPExchangeError.invalidFile
        }
        try checkKeys(goal, required: ["id", "title", "timeZoneID", "restWeekdays"],
                      optional: ["weeklyTargetDays", "deadlineDate"])
        try checkKeys(window, required: ["startDate", "endDate"])
        for record in records {
            try checkKeys(record, required: ["id", "itemID", "title", "date", "status", "timePrecision"])
        }
        let snapshot: MCPSnapshot
        do { snapshot = try JSONDecoder().decode(MCPSnapshot.self, from: data) }
        catch { throw MCPExchangeError.invalidFile }
        try validateSnapshot(snapshot)
        return snapshot
    }

    public static func validateProposal(_ proposal: MCPScheduleProposal, now: Date = Date()) throws {
        guard proposal.schemaVersion == 1 else { throw MCPExchangeError.unsupportedVersion }
        guard proposal.kind == "dayvault.proposal" else { throw MCPExchangeError.invalidFile }
        guard (1...20).contains(proposal.items.count), try encode(proposal).count <= maxProposalBytes else {
            throw MCPExchangeError.tooLarge
        }
        try validateText(proposal.goalTitle, limit: 500)
        try validateText(proposal.summary, limit: 500)
        guard let calendar = calendar(proposal.timeZoneID), let created = timestamp(proposal.createdAt),
              now.timeIntervalSince1970.isFinite else { throw MCPExchangeError.invalidDate }
        guard created.timeIntervalSince(now) <= 300, now.timeIntervalSince(created) <= 7 * 86_400 else {
            throw MCPExchangeError.expired
        }
        let today = calendar.startOfDay(for: now)
        guard let end = calendar.date(byAdding: .day, value: 14, to: today) else { throw MCPExchangeError.invalidDate }
        var ids = Set<UUID>()
        var pairs = Set<String>()
        for item in proposal.items {
            try validateText(item.title, limit: 120)
            guard let day = date(item.date, timeZoneID: proposal.timeZoneID), day >= today, day <= end else {
                throw MCPExchangeError.invalidDate
            }
            guard ids.insert(item.id).inserted, pairs.insert(item.date + "\n" + item.title.lowercased()).inserted else {
                throw MCPExchangeError.duplicateItems
            }
        }
    }

    public static func validateSnapshot(_ snapshot: MCPSnapshot) throws {
        guard snapshot.schemaVersion == 1 else { throw MCPExchangeError.unsupportedVersion }
        guard snapshot.kind == "dayvault.snapshot" else { throw MCPExchangeError.invalidFile }
        guard snapshot.records.count <= 1_000, try encode(snapshot).count <= maxSnapshotBytes else {
            throw MCPExchangeError.tooLarge
        }
        let goal = snapshot.goal
        try validateText(goal.title, limit: 500)
        guard let calendar = calendar(goal.timeZoneID), timestamp(snapshot.exportedAt) != nil,
              Set(goal.restWeekdays).count == goal.restWeekdays.count,
              goal.restWeekdays.allSatisfy({ (1...7).contains($0) }),
              goal.weeklyTargetDays.map({ (1...7).contains($0) }) ?? true,
              let start = date(snapshot.window.startDate, timeZoneID: goal.timeZoneID),
              let end = date(snapshot.window.endDate, timeZoneID: goal.timeZoneID), end >= start,
              let span = calendar.dateComponents([.day], from: start, to: end).day, span <= 44 else {
            throw MCPExchangeError.invalidDate
        }
        if let deadline = goal.deadlineDate, date(deadline, timeZoneID: goal.timeZoneID) == nil {
            throw MCPExchangeError.invalidDate
        }
        var ids = Set<String>()
        for record in snapshot.records {
            try validateText(record.id, limit: 500)
            try validateText(record.title, limit: 120)
            guard let day = date(record.date, timeZoneID: goal.timeZoneID), day >= start, day <= end,
                  OccurrenceStatus(rawValue: record.status) != nil,
                  ScheduleTimePrecision(rawValue: record.timePrecision) != nil else { throw MCPExchangeError.invalidDate }
            guard ids.insert(record.id).inserted else { throw MCPExchangeError.duplicateItems }
        }
    }

    public static func dateString(_ value: Date, timeZoneID: String) -> String {
        guard let calendar = calendar(timeZoneID) else { return "" }
        let parts = calendar.dateComponents([.year, .month, .day], from: value)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// Round-trip components: Calendar.date alone accepts impossible dates by normalizing them.
    public static func date(_ value: String, timeZoneID: String) -> Date? {
        guard value.range(of: #"^[0-9]{4}-[0-9]{2}-[0-9]{2}$"#, options: .regularExpression) != nil,
              let calendar = calendar(timeZoneID) else { return nil }
        let parts = value.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, (1...9999).contains(parts[0]),
              let day = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])),
              dateString(day, timeZoneID: timeZoneID) == value else { return nil }
        return calendar.startOfDay(for: day)
    }

    public static func timestamp(_ value: String) -> Date? {
        guard value.range(of: #"^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]{1,9})?(Z|[+-][0-9]{2}:[0-9]{2})$"#,
                          options: .regularExpression) != nil,
              date(String(value.prefix(10)), timeZoneID: "UTC") != nil else { return nil }
        let characters = Array(value)
        guard let hour = Int(String(characters[11...12])), hour < 24,
              let minute = Int(String(characters[14...15])), minute < 60,
              let second = Int(String(characters[17...18])), second < 60 else { return nil }
        if !value.hasSuffix("Z") {
            let offset = value.suffix(5).split(separator: ":").compactMap { Int($0) }
            guard offset.count == 2, offset[0] < 24, offset[1] < 60 else { return nil }
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    private static func calendar(_ timeZoneID: String) -> Calendar? {
        guard let timeZone = TimeZone(identifier: timeZoneID) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    private static func validateText(_ value: String, limit: Int) throws {
        guard !value.isEmpty, value == value.trimmingCharacters(in: .whitespacesAndNewlines),
              value.unicodeScalars.count <= limit,
              !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
            throw MCPExchangeError.invalidText
        }
    }

    private static func object(_ data: Data) throws -> [String: Any] {
        guard String(data: data, encoding: .utf8) != nil else { throw MCPExchangeError.invalidFile }
        do {
            guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw MCPExchangeError.invalidFile
            }
            return object
        } catch { throw MCPExchangeError.invalidFile }
    }

    private static func checkKeys(_ object: [String: Any], required: Set<String>, optional: Set<String> = []) throws {
        let keys = Set(object.keys)
        guard required.isSubset(of: keys), keys.isSubset(of: required.union(optional)),
              !object.values.contains(where: { $0 is NSNull }) else { throw MCPExchangeError.invalidFile }
    }
}
