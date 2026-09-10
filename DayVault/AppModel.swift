import DayVaultCore
import Foundation
import Observation
import SwiftData
import WidgetKit

struct UnlockPresentation: Identifiable, Equatable {
    let id = UUID()
    let definition: AchievementDefinition
}

@MainActor
@Observable
final class AppModel {
    let container: ModelContainer
    let context: ModelContext
    let calendarService = SystemCalendarService()
    let notificationService = SystemNotificationService()
    let aiPlanner = AIPlannerServiceFactory.make()
    let journeyAI: any JourneyAI

    var goals: [PersonalGoal] = []
    var personalAchievements: [PersonalAchievementDefinition] = []
    var personalEvidence: [PersonalAchievementEvidence] = []
    var companionMessages: [CompanionMessage] = []
    var companionMemories: [CompanionMemory] = []
    var adjustmentRecords: [PlanAdjustmentRecord] = []
    var selectedGoalID: UUID?
    var lastCompletionFeedbackID: UUID?
    var journeyError: String?
    var journeyBusy = false
    var personalUnlockIDs: [String] = []
#if DEBUG
    // Fault injection for verifying the same rollback path used by disk-save errors.
    var failNextJourneySaveForTesting = false
#endif

    var selectedDate = Date()
    var items: [ScheduleItem] = []
    var logs: [OccurrenceLog] = []
    var categories: [ScheduleCategory] = []
    var templates: [QuickTemplate] = []
    var reviews: [DayReview] = []
    var achievementStates: [AchievementState] = []
    var externalEvents: [ExternalCalendarEvent] = []
    var vaultSelection: AchievementDefinition?
    var historicalUnlockCount = 0
    var availableCalendars: [ExternalCalendarChoice] = []
    var selectedCalendarIDs = Set(UserDefaults.standard.stringArray(forKey: "selectedCalendarIDs") ?? [])
    var unlockQueue: [UnlockPresentation] = []
    var unlockBlockingSheets: Set<String> = []
    var isPresentingEditor = false
    var editorDate = Date()
    var calendarEnabled = UserDefaults.standard.bool(forKey: "calendarEnabled")
    var calendarError: String?
    var lastAppliedPlanTitle: String?
    var canUndoAIPlan: Bool { !lastAppliedAIItemIDs.isEmpty }
    private var savedAvatarOutfit = AvatarOutfit()
    private let avatarDefaults: UserDefaults
    private let persistAvatarPreferences: Bool

    var unlockedAchievementIDs: Set<String> {
        Set(achievementStates.compactMap { $0.unlockedAt == nil ? nil : $0.definitionID })
    }

    var earnedAvatarRewards: [AvatarReward] {
        AvatarRewardCatalog.all.filter { unlockedAchievementIDs.contains($0.achievementID) }
    }

    var avatarOutfit: AvatarOutfit {
        savedAvatarOutfit.validated(unlockedAchievementIDs: unlockedAchievementIDs)
    }

    private var lastAppliedAIItemIDs: Set<UUID> = Set(
        UserDefaults.standard.stringArray(forKey: "lastAppliedAIItemIDs")?.compactMap(UUID.init(uuidString:)) ?? []
    )

    init(container: ModelContainer, avatarDefaults: UserDefaults = .standard, persistAvatarPreferences: Bool = true, journeyAI: (any JourneyAI)? = nil) {
        self.container = container
        self.context = container.mainContext
        self.journeyAI = journeyAI ?? JourneyAIServiceFactory.make()
        self.avatarDefaults = avatarDefaults
        self.persistAvatarPreferences = persistAvatarPreferences
        if persistAvatarPreferences,
           let data = avatarDefaults.data(forKey: "avatar.outfit.v1"),
           let outfit = try? JSONDecoder().decode(AvatarOutfit.self, from: data) {
            savedAvatarOutfit = outfit
        }
        context.autosaveEnabled = true
        refresh()
        mergeDuplicateAchievementStates()
        seedIfNeeded()
        refresh()
#if DEBUG
        seedPreviewDataIfRequested()
        refresh()
#endif
        reconcileAchievements(presentNewUnlocks: false)
        reconcilePersonalAchievements(presentNewUnlocks: false)
        Task { await refreshExternalEvents() }
    }

    func refresh() {
        let fetchedItems = (try? context.fetch(FetchDescriptor<ScheduleItem>())) ?? []
        items = Array(Dictionary(fetchedItems.map { ($0.id, $0) }, uniquingKeysWith: { lhs, rhs in
            lhs.updatedAt >= rhs.updatedAt ? lhs : rhs
        }).values).sorted { $0.plannedStart < $1.plannedStart }
        let fetchedLogs = (try? context.fetch(FetchDescriptor<OccurrenceLog>())) ?? []
        logs = Array(Dictionary(fetchedLogs.map { ($0.occurrenceKey, $0) }, uniquingKeysWith: { lhs, rhs in
            lhs.updatedAt >= rhs.updatedAt ? lhs : rhs
        }).values)
        categories = (try? context.fetch(FetchDescriptor<ScheduleCategory>(sortBy: [SortDescriptor(\.sortOrder)]))) ?? []
        templates = (try? context.fetch(FetchDescriptor<QuickTemplate>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
        reviews = (try? context.fetch(FetchDescriptor<DayReview>())) ?? []
        achievementStates = (try? context.fetch(FetchDescriptor<AchievementState>())) ?? []
        refreshJourney()
    }

    func dayInterval(for date: Date? = nil) -> DateInterval {
        let value = date ?? selectedDate
        let start = Calendar.current.startOfDay(for: value)
        return DateInterval(start: start, end: Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400))
    }

    func occurrences(for date: Date? = nil) -> [ScheduleOccurrence] {
        let interval = dayInterval(for: date)
        return items.flatMap { item in
            let query = item.isUnscheduled ? dayInterval(for: item.plannedStart) : interval
            return RecurrenceResolver.occurrences(for: item, in: query, logs: logs.filter { $0.scheduleItemID == item.id })
                .filter { !item.isUnscheduled || [.planned, .active].contains($0.status) }
        }.sorted { $0.start < $1.start }
    }

    func category(for id: UUID?) -> ScheduleCategory? {
        guard let id else { return nil }
        return categories.first { $0.id == id }
    }

    func showEditor(at date: Date = Date()) {
        editorDate = date
        isPresentingEditor = true
    }

    @discardableResult
    func equipAvatarReward(_ rewardID: String) -> Bool {
        guard let reward = AvatarRewardCatalog.all.first(where: { $0.id == rewardID }),
              unlockedAchievementIDs.contains(reward.achievementID) else { return false }
        // Keep other saved slots intact while their historical unlocks are still syncing.
        savedAvatarOutfit = savedAvatarOutfit.equipping(reward, unlockedAchievementIDs: unlockedAchievementIDs)
        saveAvatarOutfit()
        return true
    }

    func removeAvatarReward(in slot: AvatarSlot) {
        savedAvatarOutfit = savedAvatarOutfit.removing(slot)
        saveAvatarOutfit()
    }

    private func saveAvatarOutfit() {
        guard persistAvatarPreferences, let data = try? JSONEncoder().encode(savedAvatarOutfit) else { return }
        avatarDefaults.set(data, forKey: "avatar.outfit.v1")
    }

    func addItem(_ draft: ScheduleItemDraft, isPro: Bool) async -> String? {
        if draft.saveAsTemplate && !isPro && templates.count >= 3 { return "editor.template_limit" }
        let item = ScheduleItem(
            title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: draft.notes,
            categoryID: draft.categoryID,
            plannedStart: draft.plannedStart,
            plannedDurationMinutes: draft.durationMinutes,
            isUnscheduled: draft.isUnscheduled,
            priority: draft.priority,
            recurrenceRule: draft.recurrenceRule,
            reminderLead: draft.reminderLead,
            templateID: draft.templateID
        )
        item.timePrecision = draft.isUnscheduled ? .inbox : draft.timePrecision
        if item.timePrecision == .dateOnly { item.plannedStart = Calendar.current.startOfDay(for: draft.plannedStart) }
        item.goalID = draft.goalID
        if item.timePrecision != .timed { item.reminderLeadMinutes = nil }
        context.insert(item)
        if draft.saveAsTemplate {
            context.insert(QuickTemplate(
                title: item.title,
                notes: item.notes,
                categoryID: item.categoryID,
                durationMinutes: item.plannedDurationMinutes,
                priority: item.priority
            ))
        }
        if let templateID = draft.templateID, let template = templates.first(where: { $0.id == templateID }) {
            template.useCount += 1
            template.updatedAtCompat()
        }
        do { try context.save() }
        catch {
            context.rollback()
            refresh()
            return "保存失败，请重试。"
        }
        refresh()
        if let lead = item.reminderLeadMinutes {
            _ = try? await notificationService.requestAuthorization()
            let end = Calendar.current.date(byAdding: .day, value: 60, to: Date()) ?? Date().addingTimeInterval(60 * 86_400)
            let upcoming = RecurrenceResolver.occurrences(
                for: item,
                in: DateInterval(start: Date(), end: end),
                logs: logs.filter { $0.scheduleItemID == item.id }
            )
            for occurrence in upcoming.prefix(20) {
                try? await notificationService.schedule(occurrence: occurrence, leadMinutes: lead)
            }
        }
        reconcileAchievements()
        writeWidgetSnapshot()
        return nil
    }

    func plannerRequest(goal: String, clarificationAnswer: String? = nil) -> PlannerRequest {
        let calendar = Calendar.current
        let loads = (0..<14).compactMap { offset -> PlannerDailyLoad? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: Date())) else { return nil }
            let minutes = occurrences(for: day).filter { $0.timePrecision == .timed && $0.status != .removed }.reduce(0) { $0 + $1.durationMinutes }
            return PlannerDailyLoad(day: day, scheduledMinutes: minutes)
        }
        return PlannerRequest(
            goalText: goal,
            clarificationAnswer: clarificationAnswer,
            currentDate: Date(),
            timeZoneID: TimeZone.current.identifier,
            locale: Locale.current.identifier,
            busyWindows: externalEvents.map { PlannerBusyWindow(start: $0.start, end: $0.end) },
            existingDailyLoads: loads,
            activeChallengeIDs: StarterChallengeCatalog.all.map(\.id)
        )
    }

    func applyGeneratedPlan(_ plan: GeneratedProjectPlan) -> String? {
        var appliedIDs = Set(UserDefaults.standard.stringArray(forKey: "appliedAIPlanIDs") ?? [])
        guard !appliedIDs.contains(plan.id.uuidString), !goals.contains(where: { $0.id == plan.id }) else { return "ai.error.already_applied" }
        let childIDs = plan.initialBlocks.map(\.id) + plan.recurringPatterns.map(\.id)
        guard Set(childIDs).count == childIDs.count, Set(childIDs).isDisjoint(with: Set(items.map(\.id))) else {
            return "ai.error.apply_failed"
        }

        let goal = PersonalGoal(id: plan.id, title: plan.title)
        goal.deadline = plan.deadline
        goal.acceptedPlanJSON = encodeJourney(plan)
        context.insert(goal)

        var inserted: [ScheduleItem] = []
        for block in plan.initialBlocks {
            let item = ScheduleItem(
                id: block.id,
                title: block.title,
                notes: block.notes,
                categoryID: categories.first(where: { $0.balanceGroup == block.balanceGroup })?.id,
                plannedStart: block.start,
                plannedDurationMinutes: block.durationMinutes
            )
            item.goalID = goal.id
            context.insert(item)
            inserted.append(item)
        }
        for pattern in plan.recurringPatterns {
            guard let firstStart = firstStart(for: pattern) else { continue }
            let item = ScheduleItem(
                id: pattern.id,
                title: pattern.title,
                categoryID: categories.first(where: { $0.balanceGroup == pattern.balanceGroup })?.id,
                plannedStart: firstStart,
                plannedDurationMinutes: pattern.durationMinutes,
                recurrenceRule: RecurrenceRule(kind: .selectedWeekdays, weekdays: pattern.weekdays),
                recurrenceEnd: pattern.endDate
            )
            item.goalID = goal.id
            context.insert(item)
            inserted.append(item)
        }

        do {
            try context.save()
        } catch {
            context.rollback()
            return "ai.error.apply_failed"
        }

        lastAppliedAIItemIDs = Set(inserted.map(\.id))
        lastAppliedPlanTitle = plan.title
        UserDefaults.standard.set(lastAppliedAIItemIDs.map(\.uuidString), forKey: "lastAppliedAIItemIDs")
        appliedIDs.insert(plan.id.uuidString)
        UserDefaults.standard.set(Array(appliedIDs), forKey: "appliedAIPlanIDs")
        refresh()
        selectedGoalID = goal.id
        reconcileAchievements()
        writeWidgetSnapshot()
        return nil
    }

    func undoLastAIPlan() {
        guard !lastAppliedAIItemIDs.isEmpty else { return }
        for item in items where lastAppliedAIItemIDs.contains(item.id) {
            // Preserve any series that already contains actual activity.
            guard !logs.contains(where: { $0.scheduleItemID == item.id && ($0.status == .completed || $0.status == .active) }) else { continue }
            item.isArchived = true
            item.updatedAt = Date()
        }
        try? context.save()
        lastAppliedAIItemIDs = []
        lastAppliedPlanTitle = nil
        UserDefaults.standard.removeObject(forKey: "lastAppliedAIItemIDs")
        refresh()
        reconcileAchievements(presentNewUnlocks: false)
        writeWidgetSnapshot()
    }

    func complete(_ occurrence: ScheduleOccurrence, at date: Date = Date()) {
        let log = mutableLog(for: occurrence)
        guard log.status != .completed else { return }
        log.status = .completed
        log.completedAt = date
        log.goalID = occurrence.goalID
        log.timePrecision = occurrence.timePrecision
        if let goal = goals.first(where: { $0.id == occurrence.goalID }), let enabled = goal.aiEnabledAt, date >= enabled {
            log.recordedDuringCompanionship = true
            log.companionSessionID = goal.id
            recordCompanionDay(goalID: goal.id, at: date)
        }
        if occurrence.timePrecision == .timed && occurrence.durationMinutes <= 15 {
            log.fitBetweenCalendarEvents = isBetweenCalendarEvents(occurrence)
        }
        if log.actualStart != nil && log.actualEnd == nil { log.actualEnd = date }
        log.updatedAt = date
        do { try context.save() }
        catch {
            context.rollback()
            journeyError = "这次记录没有保存，请重试。"
            refresh()
            return
        }
        lastCompletionFeedbackID = UUID()
        Task { await notificationService.cancel(occurrenceID: occurrence.id) }
        refresh()
        reconcileAchievements()
        reconcilePersonalAchievements()
        scheduleDailyCompanionReply(goalID: occurrence.goalID)
        writeWidgetSnapshot()
    }

    func start(_ occurrence: ScheduleOccurrence, at date: Date = Date()) {
        for active in logs where active.status == .active && active.occurrenceKey != occurrence.id {
            active.status = .planned
            active.actualStart = nil
        }
        let log = mutableLog(for: occurrence)
        log.status = .active
        log.actualStart = date
        log.actualEnd = nil
        log.updatedAt = date
        try? context.save()
        refresh()
        writeWidgetSnapshot()
    }

    func reschedule(_ occurrence: ScheduleOccurrence, to start: Date, durationMinutes: Int) {
        let before = overlapCount(for: occurrence, among: occurrences(for: occurrence.start))
        let log = mutableLog(for: occurrence)
        log.overrideStart = occurrence.timePrecision == .timed ? snap(start) : Calendar.current.startOfDay(for: start)
        log.overrideDurationMinutes = max(1, durationMinutes)
        log.wasRescheduled = true
        log.updatedAt = Date()
        try? context.save()
        refresh()
        if let updated = occurrences(for: start).first(where: { $0.id == occurrence.id }) {
            let after = overlapCount(for: updated, among: occurrences(for: start))
            log.conflictsResolved += max(0, before - after)
            try? context.save()
            Task { await rescheduleNotification(for: updated) }
        }
        refresh()
        reconcileAchievements()
        reconcilePersonalAchievements()
        writeWidgetSnapshot()
    }

    func resize(_ occurrence: ScheduleOccurrence, durationMinutes: Int) {
        reschedule(occurrence, to: occurrence.start, durationMinutes: max(15, durationMinutes))
    }

    func skip(_ occurrence: ScheduleOccurrence, reason: SkipReason) {
        let log = mutableLog(for: occurrence)
        log.status = .skipped
        log.skipReason = reason
        log.updatedAt = Date()
        try? context.save()
        Task { await notificationService.cancel(occurrenceID: occurrence.id) }
        refresh()
        reconcileAchievements()
        reconcilePersonalAchievements()
        writeWidgetSnapshot()
    }

    func remove(_ occurrence: ScheduleOccurrence) {
        let log = mutableLog(for: occurrence)
        log.status = .removed
        log.updatedAt = Date()
        try? context.save()
        Task { await notificationService.cancel(occurrenceID: occurrence.id) }
        refresh()
        reconcileAchievements()
        reconcilePersonalAchievements()
        writeWidgetSnapshot()
    }

    func finishDayReview() {
        let day = Calendar.current.startOfDay(for: selectedDate)
        guard !reviews.contains(where: { Calendar.current.isDate($0.day, inSameDayAs: day) }) else { return }
        context.insert(DayReview(day: day))
        try? context.save()
        refresh()
        reconcileAchievements()
    }

    func enableCalendar() async {
        do {
            calendarEnabled = try await calendarService.requestFullAccess()
            UserDefaults.standard.set(calendarEnabled, forKey: "calendarEnabled")
            await refreshCalendarChoices()
            await refreshExternalEvents()
        } catch {
            calendarError = error.localizedDescription
        }
    }

    func refreshExternalEvents() async {
        guard calendarEnabled else {
            externalEvents = []
            return
        }
        do {
            if availableCalendars.isEmpty { await refreshCalendarChoices() }
            externalEvents = try await calendarService.events(in: dayInterval(), calendarIDs: selectedCalendarIDs)
            calendarError = nil
        } catch {
            externalEvents = []
            calendarError = error.localizedDescription
        }
    }

    func setCalendar(_ id: String, selected: Bool) {
        if selected { selectedCalendarIDs.insert(id) }
        else { selectedCalendarIDs.remove(id) }
        UserDefaults.standard.set(Array(selectedCalendarIDs), forKey: "selectedCalendarIDs")
        UserDefaults.standard.set(true, forKey: "calendarSelectionInitialized")
        Task { await refreshExternalEvents() }
    }

    private func refreshCalendarChoices() async {
        availableCalendars = await calendarService.calendars()
        if !UserDefaults.standard.bool(forKey: "calendarSelectionInitialized"), selectedCalendarIDs.isEmpty && !availableCalendars.isEmpty {
            selectedCalendarIDs = Set(availableCalendars.map(\.id))
            UserDefaults.standard.set(Array(selectedCalendarIDs), forKey: "selectedCalendarIDs")
            UserDefaults.standard.set(true, forKey: "calendarSelectionInitialized")
        }
    }

    func achievementState(for definition: AchievementDefinition) -> AchievementState? {
        achievementStates.first { $0.definitionID == definition.id }
    }

    func consumeUnlock(id: UUID? = nil) {
        guard let first = unlockQueue.first, id == nil || first.id == id else { return }
        unlockQueue.removeFirst()
    }

    func handleNotificationCompletion(_ occurrenceID: String) {
        let nearby = items.flatMap { item in
            let start = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            let end = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
            return RecurrenceResolver.occurrences(for: item, in: DateInterval(start: start, end: end), logs: logs.filter { $0.scheduleItemID == item.id })
        }
        guard let occurrence = nearby.first(where: { $0.id == occurrenceID }) else { return }
        complete(occurrence)
    }

    func processPendingWidgetCompletion() {
        let defaults = UserDefaults(suiteName: WidgetSnapshotStore.suiteName)
        guard let id = defaults?.string(forKey: "widget.pendingCompletion") else { return }
        defaults?.removeObject(forKey: "widget.pendingCompletion")
        handleNotificationCompletion(id)
    }

    func syncFromPersistence() {
        let priorHistoricalCount = historicalUnlockCount
        let previouslyUnlocked = Set(achievementStates.compactMap { $0.unlockedAt == nil ? nil : $0.definitionID })
        refresh()
        mergeDuplicateAchievementStates()
        refresh()
        reconcileAchievements(presentNewUnlocks: false)
        reconcilePersonalAchievements(presentNewUnlocks: false)
        let currentlyUnlocked = Set(achievementStates.compactMap { $0.unlockedAt == nil ? nil : $0.definitionID })
        historicalUnlockCount = priorHistoricalCount + currentlyUnlocked.subtracting(previouslyUnlocked).count
        writeWidgetSnapshot()
    }

    func currentScheduledDayStreak() -> Int {
        let calendar = Calendar.current
        let history = occurrences(inPastDays: 400).filter { !$0.isUnscheduled }
        let scheduledDays = Set(history.map { calendar.startOfDay(for: $0.start) })
        let completedDays = Set(history.filter { $0.status == .completed }.map { calendar.startOfDay(for: $0.start) })
        var streak = 0
        for day in scheduledDays.sorted(by: >) {
            if completedDays.contains(day) { streak += 1 }
            else { break }
        }
        return streak
    }

    private func seedIfNeeded() {
        if categories.isEmpty {
            let seeds: [(String, String, String, BalanceGroup)] = [
                ("category.focus", "#49CFF5", "brain.head.profile", .focus),
                ("category.study", "#8467F2", "book.fill", .focus),
                ("category.care", "#34C77B", "heart.fill", .care),
                ("category.rest", "#F4C15D", "moon.stars.fill", .rest),
                ("category.personal", "#E7A93B", "person.fill", .other),
            ]
            for (index, seed) in seeds.enumerated() {
                context.insert(ScheduleCategory(name: seed.0, colorHex: seed.1, symbolName: seed.2, balanceGroup: seed.3, sortOrder: index))
            }
        }
        let existing = Set(achievementStates.map(\.definitionID))
        for definition in AchievementCatalog.all where !existing.contains(definition.id) {
            context.insert(AchievementState(definitionID: definition.id, definitionVersion: definition.version))
        }
        try? context.save()
    }

#if DEBUG
    private func seedPreviewDataIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-preview-sample-data"), items.isEmpty else { return }
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: Date())
        let samples: [(String, Int, Int, BalanceGroup, OccurrenceStatus)] = [
            ("列出三件关键事", 8, 30, .focus, .completed),
            ("整理作品集方向", 10, 45, .focus, .planned),
            ("出去走一小圈", 14, 20, .rest, .planned),
            ("给家里打个电话", 19, 30, .care, .planned),
        ]

        for (title, hour, duration, group, status) in samples {
            guard let start = calendar.date(bySettingHour: hour, minute: hour == 10 ? 15 : 0, second: 0, of: day) else { continue }
            let item = ScheduleItem(
                title: title,
                categoryID: categories.first(where: { $0.balanceGroup == group })?.id,
                plannedStart: start,
                plannedDurationMinutes: duration
            )
            context.insert(item)
            if status == .completed {
                let log = OccurrenceLog(scheduleItemID: item.id, originalStart: start, timeZoneID: item.timeZoneID)
                log.status = .completed
                log.completedAt = start.addingTimeInterval(TimeInterval(duration * 60))
                context.insert(log)
            }
        }
        try? context.save()
    }
#endif

    private func mergeDuplicateAchievementStates() {
        let fetched = (try? context.fetch(FetchDescriptor<AchievementState>())) ?? []
        for group in Dictionary(grouping: fetched, by: \.definitionID).values where group.count > 1 {
            guard let canonical = group.first else { continue }
            canonical.progress = group.map(\.progress).max() ?? canonical.progress
            canonical.unlockedAt = group.compactMap(\.unlockedAt).min()
            canonical.definitionVersion = group.map(\.definitionVersion).max() ?? canonical.definitionVersion
            canonical.updatedAt = group.map(\.updatedAt).max() ?? canonical.updatedAt
            canonical.signal = group.map(\.signal).max(by: { signalRank($0) < signalRank($1) }) ?? canonical.signal
            for duplicate in group.dropFirst() { context.delete(duplicate) }
        }
        try? context.save()
    }

    private func signalRank(_ signal: HiddenSignal) -> Int {
        switch signal { case .dormant: 0; case .faint: 1; case .resonant: 2 }
    }

    func mutableLog(for occurrence: ScheduleOccurrence) -> OccurrenceLog {
        if let existing = logs.filter({ $0.occurrenceKey == occurrence.id }).max(by: { $0.updatedAt < $1.updatedAt }) {
            return existing
        }
        let log = OccurrenceLog(scheduleItemID: occurrence.itemID, originalStart: occurrence.originalStart, timeZoneID: occurrence.timeZoneID)
        log.goalID = occurrence.goalID
        log.timePrecision = occurrence.timePrecision
        context.insert(log)
        logs.append(log)
        return log
    }

    private func overlapCount(for occurrence: ScheduleOccurrence, among all: [ScheduleOccurrence]) -> Int {
        guard occurrence.timePrecision == .timed else { return 0 }
        return all.filter { $0.timePrecision == .timed && $0.id != occurrence.id && $0.start < occurrence.end && $0.end > occurrence.start }.count
    }

    private func snap(_ date: Date) -> Date {
        let interval: TimeInterval = 15 * 60
        return Date(timeIntervalSince1970: (date.timeIntervalSince1970 / interval).rounded() * interval)
    }

    private func firstStart(for pattern: GeneratedPlanPattern) -> Date? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        for offset in 0...7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  pattern.weekdays.contains(calendar.component(.weekday, from: day)) else { continue }
            let hour = pattern.startMinutesFromMidnight / 60
            let minute = pattern.startMinutesFromMidnight % 60
            guard let candidate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
                  candidate > Date(), candidate <= pattern.endDate else { continue }
            return candidate
        }
        return nil
    }

    private func reconcileAchievements(presentNewUnlocks: Bool = true) {
        refresh()
        var snapshot = buildAchievementSnapshot()
        var evaluations = AchievementEngine.evaluate(snapshot: snapshot)
        apply(evaluations, presentNewUnlocks: presentNewUnlocks)
        refresh()
        let unlockedCategories: Set<AchievementCategory> = Set(
            AchievementCatalog.all.compactMap { definition in
                guard !definition.isHidden,
                      achievementState(for: definition)?.unlockedAt != nil else { return nil }
                return definition.category
            }
        )
        snapshot.unlockedVisibleCategories = unlockedCategories.count
        evaluations = AchievementEngine.evaluate(snapshot: snapshot)
        apply(evaluations, presentNewUnlocks: presentNewUnlocks)
        try? context.save()
        refresh()
    }

    private func apply(_ evaluations: [AchievementEvaluation], presentNewUnlocks: Bool) {
        for evaluation in evaluations {
            guard let state = achievementStates.first(where: { $0.definitionID == evaluation.definitionID }),
                  let definition = AchievementCatalog.all.first(where: { $0.id == evaluation.definitionID }) else { continue }
            state.progress = max(state.progress, evaluation.progress)
            state.signal = evaluation.signal
            state.updatedAt = Date()
            if evaluation.shouldUnlock && state.unlockedAt == nil {
                state.unlockedAt = Date()
                if presentNewUnlocks { unlockQueue.append(UnlockPresentation(definition: definition)) }
            }
        }
    }

    private func buildAchievementSnapshot() -> AchievementSnapshot {
        var snapshot = AchievementSnapshot()
        let completed = logs.filter { $0.status == .completed && ($0.completedAt ?? .distantFuture) <= Date() }
        snapshot.createdItemCount = items.count
        snapshot.completionCount = completed.count
        snapshot.reviewCount = reviews.count
        snapshot.createdAndUsedTemplateCount = templates.filter { $0.useCount > 0 }.count
        snapshot.actualTimeCount = completed.filter { $0.actualStart != nil && $0.actualEnd != nil }.count
        snapshot.rescheduledAndCompletedCount = completed.filter(\.wasRescheduled).count
        snapshot.foundTimeProgress = completed.contains(where: \.fitBetweenCalendarEvents) ? 1 : 0
        snapshot.calendarTetrisProgress = min(1, Double(completed.reduce(0) { $0 + $1.conflictsResolved }) / 3)

        let itemByID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        snapshot.onTimeCount = completed.filter { log in
            guard log.timePrecision == .timed, let actual = log.actualStart else { return false }
            let planned = log.overrideStart ?? log.originalStart
            return abs(actual.timeIntervalSince(planned)) <= 600
        }.count
        var templateCounts: [UUID: Int] = [:]
        for log in completed {
            if let templateID = itemByID[log.scheduleItemID]?.templateID { templateCounts[templateID, default: 0] += 1 }
        }
        snapshot.maxTemplateCompletionCount = templateCounts.values.max() ?? 0

        let calendar = Calendar.current
        let completedDays = Set(completed.map { calendar.startOfDay(for: $0.overrideStart ?? $0.originalStart) })
        snapshot.activeDaysInRolling30 = completedDays.filter { $0 <= calendar.startOfDay(for: Date()) && $0 >= calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: Date()))! }.count
        let occurrenceHistory = occurrences(inPastDays: 400).filter { !$0.isUnscheduled }
        let scheduledDays = Set(occurrenceHistory.map { calendar.startOfDay(for: $0.start) })
        snapshot.longestScheduledDayStreak = longestScheduledStreak(
            scheduledDays: scheduledDays,
            completedDays: completedDays
        )

        let recentStart = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: Date()))!
        let recent = completed.filter { ($0.completedAt ?? .distantPast) >= recentStart }
        var minutesByGroup: [BalanceGroup: Int] = [:]
        for log in recent {
            guard log.timePrecision == .timed, let item = itemByID[log.scheduleItemID], let category = category(for: item.categoryID) else { continue }
            minutesByGroup[category.balanceGroup, default: 0] += log.overrideDurationMinutes ?? item.plannedDurationMinutes
        }
        let total = minutesByGroup.values.reduce(0, +)
        snapshot.balancedWeek = minutesByGroup.filter { $0.key != .other && $0.value > 0 }.count >= 3 && total > 0 && (minutesByGroup.values.max() ?? total) * 100 <= total * 70

        var groupsByDay: [Date: Set<BalanceGroup>] = [:]
        for log in completed {
            guard let completedAt = log.completedAt, let item = itemByID[log.scheduleItemID], let category = category(for: item.categoryID) else { continue }
            groupsByDay[calendar.startOfDay(for: completedAt), default: []].insert(category.balanceGroup)
        }
        let desired: Set<BalanceGroup> = [.focus, .care, .rest]
        snapshot.balancedOrbitProgress = groupsByDay.values.map { Double($0.intersection(desired).count) / 3 }.max() ?? 0

        let completedByDay = Dictionary(grouping: completed) { calendar.startOfDay(for: $0.completedAt ?? $0.originalStart) }
        let skippedRestDays = Set(logs.filter { $0.status == .skipped && $0.skipReason == .rest }.map { calendar.startOfDay(for: $0.originalStart) })
        snapshot.humanFactorProgress = skippedRestDays.contains { !(completedByDay[$0] ?? []).isEmpty } ? 1 : 0

        let dayCounts = Dictionary(grouping: occurrences(inPastDays: 60)) { calendar.startOfDay(for: $0.start) }
        let sortedDays = dayCounts.keys.sorted()
        for (index, day) in sortedDays.enumerated() {
            let planned = dayCounts[day]?.count ?? 0
            let done = completedByDay[day]?.count ?? 0
            if planned > 0 && done == 0, index + 1 < sortedDays.count {
                let next = calendar.date(byAdding: .day, value: 1, to: day)!
                if !(completedByDay[next] ?? []).isEmpty { snapshot.secondWindProgress = 1 }
            }
            if planned >= 6 && Double(done) / Double(planned) < 0.5 {
                if sortedDays.dropFirst(index + 1).contains(where: { later in
                    let laterPlanned = dayCounts[later]?.count ?? 0
                    return laterPlanned > 0 && laterPlanned <= 3 && (completedByDay[later]?.count ?? 0) == laterPlanned
                }) { snapshot.justEnoughProgress = 1 }
            }
        }
        let overdue = occurrences(inPastDays: 90).filter { $0.end < Date() && $0.status == .planned }
        let hasResolvedPast = logs.contains { [.completed, .skipped, .removed].contains($0.status) || $0.wasRescheduled }
        snapshot.cleanSlateProgress = hasResolvedPast && overdue.isEmpty ? 1 : 0
        return snapshot
    }

    private func occurrences(inPastDays days: Int) -> [ScheduleOccurrence] {
        let end = Calendar.current.startOfDay(for: Date()).addingTimeInterval(86_400)
        let start = Calendar.current.date(byAdding: .day, value: -days, to: end) ?? end.addingTimeInterval(TimeInterval(-days * 86_400))
        let interval = DateInterval(start: start, end: end)
        return items.flatMap { item in RecurrenceResolver.occurrences(for: item, in: interval, logs: logs.filter { $0.scheduleItemID == item.id }) }
    }

    private func longestScheduledStreak(scheduledDays: Set<Date>, completedDays: Set<Date>) -> Int {
        let sorted = scheduledDays.sorted()
        var best = 0
        var current = 0
        for day in sorted {
            current = completedDays.contains(day) ? current + 1 : 0
            best = max(best, current)
        }
        return best
    }

    private func isBetweenCalendarEvents(_ occurrence: ScheduleOccurrence) -> Bool {
        let before = externalEvents.contains { $0.end <= occurrence.start }
        let after = externalEvents.contains { $0.start >= occurrence.end }
        return before && after
    }

    func rescheduleNotification(for occurrence: ScheduleOccurrence) async {
        guard occurrence.timePrecision == .timed, let item = items.first(where: { $0.id == occurrence.itemID }),
              let lead = item.reminderLeadMinutes else {
            await notificationService.cancel(occurrenceID: occurrence.id)
            return
        }
        try? await notificationService.schedule(occurrence: occurrence, leadMinutes: lead)
    }

    func writeWidgetSnapshot() {
        let snapshot = WidgetSnapshot(items: occurrences().prefix(6).map {
            WidgetScheduleItem(id: $0.id, title: $0.title, start: $0.start, end: $0.end, isCompleted: $0.status == .completed, timePrecision: $0.timePrecision)
        })
        WidgetSnapshotStore.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

struct ScheduleItemDraft {
    var title = ""
    var notes = ""
    var categoryID: UUID?
    var plannedStart = Date()
    var durationMinutes = 30
    var isUnscheduled = false
    var timePrecision: ScheduleTimePrecision = .dateOnly
    var goalID: UUID?
    var priority = ItemPriority.normal
    var recurrenceRule = RecurrenceRule()
    var reminderLead: ReminderLead?
    var saveAsTemplate = false
    var templateID: UUID?
}

private extension QuickTemplate {
    func updatedAtCompat() {
        // SwiftData tracks the mutation to useCount; this method keeps call sites explicit.
    }
}
