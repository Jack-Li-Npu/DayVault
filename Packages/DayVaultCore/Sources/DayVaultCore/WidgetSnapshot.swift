import Foundation

public struct WidgetScheduleItem: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let start: Date
    public let end: Date
    public let isCompleted: Bool
    public let timePrecision: ScheduleTimePrecision

    public var displayStart: Date? { timePrecision == .timed ? start : nil }
    public var displayEnd: Date? { timePrecision == .timed ? end : nil }

    public init(id: String, title: String, start: Date, end: Date, isCompleted: Bool,
                timePrecision: ScheduleTimePrecision = .timed) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.isCompleted = isCompleted
        self.timePrecision = timePrecision
    }

    private enum CodingKeys: String, CodingKey { case id, title, start, end, isCompleted, timePrecision }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        title = try values.decode(String.self, forKey: .title)
        start = try values.decode(Date.self, forKey: .start)
        end = try values.decode(Date.self, forKey: .end)
        isCompleted = try values.decode(Bool.self, forKey: .isCompleted)
        timePrecision = try values.decodeIfPresent(ScheduleTimePrecision.self, forKey: .timePrecision) ?? .timed
    }
}

public struct WidgetSnapshot: Codable, Equatable, Sendable {
    public let generatedAt: Date
    public let items: [WidgetScheduleItem]

    public init(generatedAt: Date = Date(), items: [WidgetScheduleItem]) {
        self.generatedAt = generatedAt
        self.items = items
    }
}

public enum WidgetSnapshotStore {
    public static let suiteName = "group.com.dayvault.shared"
    private static let key = "widget.snapshot"

    public static func save(_ snapshot: WidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults(suiteName: suiteName)?.set(data, forKey: key)
    }

    public static func load() -> WidgetSnapshot {
        guard let data = UserDefaults(suiteName: suiteName)?.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
        else { return WidgetSnapshot(items: []) }
        return snapshot
    }
}
