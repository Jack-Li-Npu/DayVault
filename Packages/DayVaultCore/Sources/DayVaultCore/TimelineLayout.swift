import Foundation

public struct TimelinePlacement: Identifiable, Equatable, Sendable {
    public let id: String
    public let column: Int
    public let columnCount: Int

    public init(id: String, column: Int, columnCount: Int) {
        self.id = id
        self.column = column
        self.columnCount = columnCount
    }
}

public enum TimelineLayout {
    public static func placements(for occurrences: [ScheduleOccurrence]) -> [String: TimelinePlacement] {
        let sorted = occurrences.sorted { lhs, rhs in
            lhs.start == rhs.start ? lhs.end < rhs.end : lhs.start < rhs.start
        }
        var result: [String: TimelinePlacement] = [:]
        var groups: [[ScheduleOccurrence]] = []
        var activeGroup: [ScheduleOccurrence] = []
        var groupEnd = Date.distantPast

        for occurrence in sorted {
            if activeGroup.isEmpty || occurrence.start < groupEnd {
                activeGroup.append(occurrence)
                groupEnd = max(groupEnd, occurrence.end)
            } else {
                groups.append(activeGroup)
                activeGroup = [occurrence]
                groupEnd = occurrence.end
            }
        }
        if !activeGroup.isEmpty { groups.append(activeGroup) }

        for group in groups {
            var columnEnds: [Date] = []
            var assigned: [(ScheduleOccurrence, Int)] = []
            for occurrence in group {
                let available = columnEnds.firstIndex { $0 <= occurrence.start }
                let column = available ?? columnEnds.count
                if column == columnEnds.count { columnEnds.append(occurrence.end) }
                else { columnEnds[column] = occurrence.end }
                assigned.append((occurrence, column))
            }
            let count = max(1, columnEnds.count)
            for (occurrence, column) in assigned {
                result[occurrence.id] = TimelinePlacement(id: occurrence.id, column: column, columnCount: count)
            }
        }
        return result
    }
}
