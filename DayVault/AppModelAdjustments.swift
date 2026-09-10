import DayVaultCore
import Foundation
import SwiftData

struct AdjustmentLogSnapshot: Codable {
    let occurrenceID: String
    let hadLog: Bool
    let overrideStart: Date?
    let overrideDuration: Int?
    let wasRescheduled: Bool
    let originalRevision: String
}

struct AdjustmentEnvelope: Codable {
    let request: JourneyAIRequest
    let suggestion: JourneyAdjustmentSuggestion
    var appliedRevisions: [String: String] = [:]
}

extension AppModel {
    func journeyOccurrences(in interval: DateInterval) -> [ScheduleOccurrence] {
        items.flatMap { RecurrenceResolver.occurrences(for: $0, in: interval, logs: logs) }
    }

    func occurrenceRevision(_ occurrence: ScheduleOccurrence) -> String {
        let item = items.first { $0.id == occurrence.itemID }
        let log = logs.first { $0.occurrenceKey == occurrence.id }
        return "\(item?.updatedAt.timeIntervalSince1970 ?? 0):\(log?.updatedAt.timeIntervalSince1970 ?? 0):\(occurrence.status.rawValue):\(occurrence.timePrecision.rawValue):\(occurrence.goalID?.uuidString ?? "")"
    }

    private func adjustmentAuthorizationEpoch(goalID: UUID) throws -> Date {
        guard let epoch = goals.first(where: { $0.id == goalID })?.aiEnabledAt else { throw JourneyActionError.unavailableGoal }
        return epoch
    }

    private func requireAdjustmentAuthorization(goalID: UUID, epoch: Date) throws {
        guard try adjustmentAuthorizationEpoch(goalID: goalID) == epoch else { throw JourneyActionError.unavailableGoal }
    }

    func adjustmentRequest(goalID: UUID, message: String, now: Date? = nil) async throws -> JourneyAIRequest {
        let epoch = try adjustmentAuthorizationEpoch(goalID: goalID)
        guard let initialGoal = goals.first(where: { $0.id == goalID }) else { throw JourneyActionError.unavailableGoal }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: initialGoal.timeZoneID) ?? .current
        let timeZoneID = initialGoal.timeZoneID
        let queryDate = now ?? Date()
        // Fetch a complete calendar envelope first. No local schedule snapshot survives this await.
        let queryStart = calendar.startOfDay(for: queryDate)
        let queryEnd = calendar.date(byAdding: .day, value: 8, to: queryStart)!
        let calendarWasEnabled = calendarEnabled
        let calendarIDs = selectedCalendarIDs
        let events: [ExternalCalendarEvent]
        if calendarWasEnabled {
            events = try await calendarService.events(in: DateInterval(start: queryStart, end: queryEnd), calendarIDs: calendarIDs)
        } else {
            events = []
        }
        refresh()
        try requireAdjustmentAuthorization(goalID: goalID, epoch: epoch)
        guard let goal = goals.first(where: { $0.id == goalID }), goal.timeZoneID == timeZoneID,
              calendarEnabled == calendarWasEnabled, selectedCalendarIDs == calendarIDs else { throw JourneyActionError.stale }
        let now = now ?? Date()
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 7, to: now)!
        guard start >= queryStart, end <= queryEnd else { throw JourneyActionError.stale }
        let dayEnd = calendar.date(byAdding: .day, value: 7, to: start)!
        let range = DateInterval(start: start, end: end)
        let occurrences = journeyOccurrences(in: range)
        let candidates = occurrences.filter {
            guard $0.goalID == goalID, $0.status == .planned, $0.actualStart == nil, $0.timePrecision != .inbox else { return false }
            if $0.timePrecision == .dateOnly { return $0.start >= start && $0.start < dayEnd }
            return $0.start >= now && $0.end <= end
        }
        let IDs = Set(candidates.map(\.id))
        var busy = occurrences.filter { !IDs.contains($0.id) && $0.timePrecision == .timed && [.planned, .active].contains($0.status) }
            .map { PlannerBusyWindow(start: $0.start, end: $0.end) }
        busy += events.map { PlannerBusyWindow(start: $0.start, end: $0.end) }
        let restDays = Set(goal.restWeekdaysCSV.split(separator: ",").compactMap { Int($0) })
        var rest: [PlannerBusyWindow] = []
        for offset in 0...7 {
            let day = calendar.date(byAdding: .day, value: offset, to: start)!
            if restDays.contains(calendar.component(.weekday, from: day)) {
                rest.append(PlannerBusyWindow(start: day, end: calendar.date(byAdding: .day, value: 1, to: day)!))
            }
        }
        let base = journeyRequest(for: goal, operation: .suggestAdjustment, message: message)
        return JourneyAIRequest(operation: .suggestAdjustment, goalID: goal.id, goalTitle: goal.title,
            currentDate: now, timeZoneID: goal.timeZoneID, message: message, facts: base.facts,
            confirmedMemories: base.confirmedMemories,
            allowedOccurrences: candidates.map { JourneyAIOccurrence(id: $0.id, goalID: goalID, start: $0.start,
                durationMinutes: $0.durationMinutes, isTimed: $0.timePrecision == .timed, revision: occurrenceRevision($0)) },
            busyWindows: busy, restWindows: rest)
    }

    func proposeAdjustment(goalID: UUID, message: String) async throws -> UUID {
        guard !journeyBusy else { throw JourneyActionError.stale }
        let epoch = try adjustmentAuthorizationEpoch(goalID: goalID)
        journeyBusy = true
        defer { journeyBusy = false }
        let request = try await adjustmentRequest(goalID: goalID, message: message)
        try requireAdjustmentAuthorization(goalID: goalID, epoch: epoch)
        guard !request.allowedOccurrences.isEmpty else { throw JourneyActionError.noChanges }
        let sourceVersions = currentSourceVersions(for: goalID)
        let suggestion = try await journeyAI.suggestAdjustment(request)
        try requireAdjustmentAuthorization(goalID: goalID, epoch: epoch)
        try JourneyAIValidator.validate(suggestion, for: request)
        guard !suggestion.changes.isEmpty else { throw JourneyActionError.noChanges }
        let current = try await adjustmentRequest(goalID: goalID, message: message)
        try requireAdjustmentAuthorization(goalID: goalID, epoch: epoch)
        let currentVersions = currentSourceVersions(for: goalID)
        guard suggestion.sourceIDs.allSatisfy({ id in
            id == "message" || (sourceVersions[id] != nil && sourceVersions[id] == currentVersions[id])
        }) else { throw JourneyActionError.stale }
        try validateAdjustmentRevisions(suggestion.changes, current: current, original: request)
        try JourneyAIValidator.validate(suggestion, for: current)
        try validateAdjustmentGoalLimits(suggestion, request: current)
        let record = PlanAdjustmentRecord(goalID: goalID, reason: suggestion.summary, beforeJSON: "",
            afterJSON: encodeJourney(AdjustmentEnvelope(request: current, suggestion: suggestion)))
        context.insert(record)
        try saveJourney()
        return record.id
    }

    func applyAdjustment(_ record: PlanAdjustmentRecord) async throws {
        guard record.appliedAt == nil else { return }
        let goalID = record.goalID
        let epoch = try adjustmentAuthorizationEpoch(goalID: goalID)
        guard var envelope = JourneyJSON.decode(AdjustmentEnvelope.self, from: record.afterJSON) else { throw JourneyActionError.invalid }
        let originalEnvelope = record.afterJSON
        let current = try await adjustmentRequest(goalID: goalID, message: envelope.request.message)
        try requireAdjustmentAuthorization(goalID: goalID, epoch: epoch)
        guard !record.isDeleted, record.goalID == goalID, record.appliedAt == nil,
              record.afterJSON == originalEnvelope else { throw JourneyActionError.stale }
        // From the refreshed snapshot through the single save below, stay on MainActor without awaiting.
        try validateAdjustmentRevisions(envelope.suggestion.changes, current: current, original: envelope.request)
        try JourneyAIValidator.validate(envelope.suggestion, for: current)
        try validateAdjustmentGoalLimits(envelope.suggestion, request: current)
        let interval = adjustmentInterval(for: current)
        let byID = Dictionary(uniqueKeysWithValues: journeyOccurrences(in: interval).map { ($0.id, $0) })
        guard envelope.suggestion.changes.allSatisfy({ byID[$0.occurrenceID] != nil }) else { throw JourneyActionError.stale }
        var before: [AdjustmentLogSnapshot] = []
        let appliedAt = Date()
        for change in envelope.suggestion.changes {
            let occurrence = byID[change.occurrenceID]!
            let old = logs.first { $0.occurrenceKey == occurrence.id }
            before.append(AdjustmentLogSnapshot(occurrenceID: occurrence.id, hadLog: old != nil,
                overrideStart: old?.overrideStart, overrideDuration: old?.overrideDurationMinutes,
                wasRescheduled: old?.wasRescheduled ?? false, originalRevision: occurrenceRevision(occurrence)))
            let log = mutableLog(for: occurrence)
            log.overrideStart = change.newStart
            log.wasRescheduled = true
            log.updatedAt = appliedAt
        }
        record.beforeJSON = encodeJourney(before)
        record.appliedAt = appliedAt
        // Compute revisions against the in-context mutations without a partial save.
        for change in envelope.suggestion.changes {
            if let occurrence = byID[change.occurrenceID] { envelope.appliedRevisions[change.occurrenceID] = occurrenceRevision(occurrence) }
        }
        record.afterJSON = encodeJourney(envelope)
        try saveJourney()
        await refreshAfterAdjustment(envelope.suggestion.changes.map(\.occurrenceID))
    }

    func undoAdjustment(_ record: PlanAdjustmentRecord) async throws {
        guard record.appliedAt != nil, record.revertedAt == nil,
              let envelope = JourneyJSON.decode(AdjustmentEnvelope.self, from: record.afterJSON),
              let before = JourneyJSON.decode([AdjustmentLogSnapshot].self, from: record.beforeJSON) else { throw JourneyActionError.invalid }
        let goalID = record.goalID
        let epoch = try adjustmentAuthorizationEpoch(goalID: goalID)
        let originalEnvelope = record.afterJSON
        let originalBefore = record.beforeJSON
        let originalAppliedAt = record.appliedAt
        let current = try await adjustmentRequest(goalID: goalID, message: "撤销上次调整")
        try requireAdjustmentAuthorization(goalID: goalID, epoch: epoch)
        guard !record.isDeleted, record.goalID == goalID, record.appliedAt == originalAppliedAt, record.revertedAt == nil,
              record.afterJSON == originalEnvelope, record.beforeJSON == originalBefore else { throw JourneyActionError.stale }
        let currentByID = Dictionary(uniqueKeysWithValues: current.allowedOccurrences.map { ($0.id, $0) })
        guard before.allSatisfy({ currentByID[$0.occurrenceID]?.revision == envelope.appliedRevisions[$0.occurrenceID] && currentByID[$0.occurrenceID] != nil }) else { throw JourneyActionError.stale }
        let originalByID = Dictionary(uniqueKeysWithValues: envelope.request.allowedOccurrences.map { ($0.id, $0) })
        let reverse = JourneyAdjustmentSuggestion(goalID: goalID, summary: "恢复调整前的安排",
            changes: before.compactMap { snapshot in originalByID[snapshot.occurrenceID].map {
                JourneyAdjustmentChange(occurrenceID: snapshot.occurrenceID, newStart: $0.start)
            } }, sourceIDs: ["goal"])
        try JourneyAIValidator.validate(reverse, for: current)
        try validateAdjustmentGoalLimits(reverse, request: current)
        guard before.allSatisfy({ snapshot in logs.contains { $0.occurrenceKey == snapshot.occurrenceID } }) else { throw JourneyActionError.stale }
        for snapshot in before {
            let log = logs.first { $0.occurrenceKey == snapshot.occurrenceID }!
            // Keep a newer override rather than deleting the log; stale CloudKit copies cannot resurrect it.
            log.overrideStart = snapshot.overrideStart ?? originalByID[snapshot.occurrenceID]?.start
            log.overrideDurationMinutes = snapshot.overrideDuration
            log.wasRescheduled = snapshot.wasRescheduled
            log.updatedAt = Date()
        }
        record.revertedAt = Date()
        try saveJourney()
        await refreshAfterAdjustment(before.map(\.occurrenceID))
    }

    private func adjustmentInterval(for request: JourneyAIRequest) -> DateInterval {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: request.timeZoneID) ?? .current
        return DateInterval(start: calendar.startOfDay(for: request.currentDate),
            end: calendar.date(byAdding: .day, value: 7, to: request.currentDate)!)
    }

    private func validateAdjustmentRevisions(_ changes: [JourneyAdjustmentChange], current: JourneyAIRequest,
                                             original: JourneyAIRequest) throws {
        let currentByID = Dictionary(uniqueKeysWithValues: current.allowedOccurrences.map { ($0.id, $0) })
        let oldByID = Dictionary(uniqueKeysWithValues: original.allowedOccurrences.map { ($0.id, $0) })
        guard changes.allSatisfy({ change in
            guard let fresh = currentByID[change.occurrenceID], let old = oldByID[change.occurrenceID] else { return false }
            return fresh.revision == old.revision
        }) else { throw JourneyActionError.stale }
    }

    func validateAdjustmentGoalLimits(_ suggestion: JourneyAdjustmentSuggestion, request: JourneyAIRequest) throws {
        guard let goal = goals.first(where: { $0.id == request.goalID }) else { throw JourneyActionError.invalid }
        let byID = Dictionary(uniqueKeysWithValues: request.allowedOccurrences.map { ($0.id, $0) })
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: goal.timeZoneID) ?? .current
        let anchor = calendar.startOfDay(for: goal.createdAt)
        func cycleIndex(for date: Date) -> Int {
            let days = calendar.dateComponents([.day], from: anchor, to: calendar.startOfDay(for: date)).day ?? 0
            return Int(floor(Double(days) / 7))
        }
        var affectedCycles: Set<Int> = []
        for change in suggestion.changes {
            guard let old = byID[change.occurrenceID] else { throw JourneyActionError.invalid }
            let end = old.isTimed ? change.newStart.addingTimeInterval(TimeInterval(old.durationMinutes * 60)) : change.newStart
            if let deadline = goal.deadline, end > deadline { throw JourneyActionError.invalid }
            if goal.weeklyTargetDays != nil {
                let cycle = cycleIndex(for: old.start)
                guard cycle == cycleIndex(for: change.newStart) else { throw JourneyActionError.invalid }
                affectedCycles.insert(cycle)
            }
        }
        guard goal.weeklyTargetDays != nil, !affectedCycles.isEmpty else { return }
        let changes = Dictionary(uniqueKeysWithValues: suggestion.changes.map { ($0.occurrenceID, $0.newStart) })
        for cycle in affectedCycles {
            let cycleStart = calendar.date(byAdding: .day, value: cycle * 7, to: anchor)!
            let cycleEnd = calendar.date(byAdding: .day, value: 7, to: cycleStart)!
            let interval = DateInterval(start: cycleStart, end: cycleEnd)
            // Include the entire cycle, not just the AI's seven-day editable window.
            let cycleOccurrences = journeyOccurrences(in: interval).filter {
                $0.goalID == goal.id && $0.timePrecision != .inbox && [.planned, .active].contains($0.status)
            }
            var oldDays: Set<Date> = []
            var newDays: Set<Date> = []
            for occurrence in cycleOccurrences {
                let original = occurrence.actualStart ?? occurrence.start
                let proposed = changes[occurrence.id] ?? original
                if cycleIndex(for: original) == cycle { oldDays.insert(calendar.startOfDay(for: original)) }
                if cycleIndex(for: proposed) == cycle { newDays.insert(calendar.startOfDay(for: proposed)) }
            }
            // Actual activity remains fixed even when the item was archived or its planned date differs.
            for log in logs where log.goalID == goal.id && [.active, .completed].contains(log.status) {
                let activityAt = log.status == .completed ? log.completedAt : log.actualStart
                guard let activityAt, activityAt <= request.currentDate, cycleIndex(for: activityAt) == cycle else { continue }
                let day = calendar.startOfDay(for: activityAt)
                oldDays.insert(day)
                newDays.insert(day)
            }
            // Preserve an existing over-target cycle too; AI is not allowed to change its frequency.
            guard newDays.count == oldDays.count else { throw JourneyActionError.invalid }
        }
    }

    private func refreshAfterAdjustment(_ IDs: [String]) async {
        refresh()
        let interval = DateInterval(start: Date().addingTimeInterval(-86_400), end: Date().addingTimeInterval(8 * 86_400))
        for occurrence in journeyOccurrences(in: interval) where IDs.contains(occurrence.id) { await rescheduleNotification(for: occurrence) }
        reconcilePersonalAchievements()
        writeWidgetSnapshot()
    }
}
