#if DEBUG
import DayVaultCore
import Foundation

extension AppModel {
    /// Historical fixtures are only available in disposable UI-test stores.
    func seedArchivedJourneyPreviewIfRequested() {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("-ui-testing"), arguments.contains("-inMemoryStore"),
              arguments.contains("-preview-journey"), goals.isEmpty else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let firstDay = calendar.date(byAdding: .day, value: -7, to: today)!
        let goal = PersonalGoal(title: "阅读记录", weeklyTargetDays: 5,
                                aiEnabledAt: firstDay, createdAt: firstDay)
        let batchID = UUID()
        goal.achievementBatchID = batchID
        goal.achievementGenerationState = "complete"
        context.insert(goal)

        var dayKeys: [String] = []
        var sourceKeys: [String] = []
        for offset in 0..<7 {
            let day = calendar.date(byAdding: .day, value: offset, to: firstDay)!
            let item = ScheduleItem(title: "阅读一章", plannedStart: day, plannedDurationMinutes: 0)
            item.goalID = goal.id
            item.timePrecision = .dateOnly
            let log = OccurrenceLog(scheduleItemID: item.id, originalStart: day, timeZoneID: goal.timeZoneID)
            log.goalID = goal.id
            log.timePrecision = .dateOnly
            log.status = .completed
            log.completedAt = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day)
            log.recordedDuringCompanionship = true
            log.companionSessionID = batchID
            context.insert(item)
            context.insert(log)
            dayKeys.append(String(day.timeIntervalSince1970))
            sourceKeys.append(log.occurrenceKey)
        }
        goal.companionRecordedDayKeysJSON = encodeJourney(dayKeys)
        context.insert(PersonalAchievementDefinition(
            goalID: goal.id, batchID: batchID, title: "阅读七日", badgeStyleID: "crest",
            rule: PersonalAchievementRule(kind: .activeDays, target: 7, startsAt: firstDay,
                                          timeZoneID: goal.timeZoneID),
            confirmedAt: firstDay, createdAt: firstDay
        ))
        try? context.save()
        refresh()

        let sourceVersions = encodeJourney(currentSourceVersions().filter { sourceKeys.contains($0.key) })
        let messageDate = today.addingTimeInterval(-60)
        context.insert(CompanionMessage(goalID: goal.id, role: "user", text: "睡前读一章比较适合我。", createdAt: messageDate))
        let reply = CompanionMessage(goalID: goal.id, text: "你已在七个不同日期留下阅读记录。",
                                     sourceOccurrenceKeys: sourceKeys, createdAt: messageDate.addingTimeInterval(1))
        reply.sourceVersionsJSON = sourceVersions
        context.insert(reply)
        let memory = CompanionMemory(goalID: goal.id, text: "睡前读一章比较适合我。",
                                     sourceOccurrenceKeys: sourceKeys, createdAt: messageDate)
        memory.sourceVersionsJSON = sourceVersions
        context.insert(memory)
        try? context.save()
        selectedGoalID = goal.id
    }
}
#endif
