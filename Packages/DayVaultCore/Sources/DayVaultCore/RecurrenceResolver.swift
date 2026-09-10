import Foundation

public enum RecurrenceResolver {
    public static func occurrences(
        for item: ScheduleItem,
        in interval: DateInterval,
        logs: [OccurrenceLog] = []
    ) -> [ScheduleOccurrence] {
        guard !item.isArchived else { return [] }
        let timeZone = TimeZone(identifier: item.timeZoneID) ?? .current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let rule = item.recurrenceRule
        let logByKey = Dictionary(
            logs.lazy
                .filter { $0.scheduleItemID == item.id }
                .map { ($0.occurrenceKey, $0) },
            uniquingKeysWith: newest
        )
        var dates: [Date] = []

        if rule.kind == .none {
            if intersects(start: item.plannedStart, duration: item.plannedDurationMinutes,
                          precision: item.timePrecision, interval: interval, calendar: calendar) {
                dates = [item.plannedStart]
            }
        } else {
            var cursor = calendar.startOfDay(for: max(item.plannedStart, interval.start))
            let finalDate = min(item.recurrenceEnd ?? interval.end, interval.end)
            let anchorDay = calendar.startOfDay(for: item.plannedStart)
            let time = calendar.dateComponents([.hour, .minute, .second], from: item.plannedStart)

            while cursor < finalDate {
                if matches(cursor, anchorDay: anchorDay, rule: rule, calendar: calendar),
                   let date = calendar.date(bySettingHour: time.hour ?? 0, minute: time.minute ?? 0, second: time.second ?? 0, of: cursor),
                   date >= item.plannedStart,
                   date < interval.end {
                    dates.append(date)
                }
                guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
                cursor = next
            }
        }

        var candidatesByKey = Dictionary(
            dates.map {
                (
                    OccurrenceKey.make(itemID: item.id, originalStart: $0, timeZoneID: item.timeZoneID),
                    $0
                )
            },
            uniquingKeysWith: { newest, _ in newest }
        )

        // An override can move an occurrence completely outside the range where
        // its original recurrence date would be generated. Include those logs as
        // candidates when their effective interval intersects the requested range.
        for (key, log) in logByKey {
            guard let overrideStart = log.overrideStart else { continue }
            let duration = log.overrideDurationMinutes ?? item.plannedDurationMinutes
            guard intersects(start: overrideStart, duration: duration, precision: log.timePrecision,
                             interval: interval, calendar: calendar) else { continue }
            candidatesByKey[key] = log.originalStart
        }

        return candidatesByKey.compactMap { key, originalStart in
            let log = logByKey[key]
            guard log?.status != .removed else { return nil }
            let precision: ScheduleTimePrecision = item.isUnscheduled ? .inbox : (log?.timePrecision ?? item.timePrecision)
            let effectiveStart = log?.overrideStart ?? originalStart
            let start = precision == .dateOnly ? calendar.startOfDay(for: effectiveStart) : effectiveStart
            return ScheduleOccurrence(
                id: key,
                itemID: item.id,
                title: item.title,
                notes: item.notes,
                categoryID: item.categoryID,
                originalStart: originalStart,
                start: start,
                durationMinutes: log?.overrideDurationMinutes ?? item.plannedDurationMinutes,
                isUnscheduled: precision == .inbox,
                status: log?.status ?? .planned,
                actualStart: log?.actualStart,
                actualEnd: log?.actualEnd,
                priority: item.priority,
                timeZoneID: item.timeZoneID,
                templateID: item.templateID,
                goalID: log == nil ? item.goalID : log?.goalID,
                timePrecision: precision
            )
        }
        .filter {
            intersects(start: $0.start, duration: $0.durationMinutes, precision: $0.timePrecision,
                       interval: interval, calendar: calendar)
        }
        .sorted { lhs, rhs in
            lhs.start == rhs.start ? lhs.id < rhs.id : lhs.start < rhs.start
        }
    }

    private static func intersects(start: Date, duration: Int, precision: ScheduleTimePrecision,
                                   interval: DateInterval, calendar: Calendar) -> Bool {
        if precision == .dateOnly || precision == .inbox {
            let day = calendar.startOfDay(for: start)
            guard let end = calendar.date(byAdding: .day, value: 1, to: day) else { return false }
            return end > interval.start && day < interval.end
        }
        let end = start.addingTimeInterval(TimeInterval(duration * 60))
        return end > interval.start && start < interval.end
    }

    private static func newest(_ lhs: OccurrenceLog, _ rhs: OccurrenceLog) -> OccurrenceLog {
        lhs.updatedAt >= rhs.updatedAt ? lhs : rhs
    }

    private static func matches(_ day: Date, anchorDay: Date, rule: RecurrenceRule, calendar: Calendar) -> Bool {
        let dayDistance = calendar.dateComponents([.day], from: anchorDay, to: day).day ?? 0
        guard dayDistance >= 0 else { return false }
        let weekday = calendar.component(.weekday, from: day)
        switch rule.kind {
        case .none:
            return dayDistance == 0
        case .daily:
            return dayDistance % rule.interval == 0
        case .weekdays:
            return (2...6).contains(weekday)
        case .selectedWeekdays:
            return rule.weekdays.contains(weekday)
        case .weekly:
            return weekday == calendar.component(.weekday, from: anchorDay) && (dayDistance / 7) % rule.interval == 0
        case .monthly:
            let anchorComponents = calendar.dateComponents([.day], from: anchorDay)
            let currentComponents = calendar.dateComponents([.day], from: day)
            let months = calendar.dateComponents([.month], from: anchorDay, to: day).month ?? 0
            return anchorComponents.day == currentComponents.day && months % rule.interval == 0
        }
    }
}
