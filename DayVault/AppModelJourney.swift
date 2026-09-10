import CryptoKit
import DayVaultCore
import Foundation
import SwiftData

enum JourneyActionError: LocalizedError {
    case unavailableGoal, stale, invalid, noChanges, saveFailed
    var errorDescription: String? {
        switch self {
        case .unavailableGoal: "请先选择目标并开启 AI 陪伴。"
        case .stale: "记录已经变化，请重新查看建议。"
        case .invalid: "这份建议未通过检查，没有修改你的记录。"
        case .noChanges: "目前没有可调整的事项。"
        case .saveFailed: "没有保存成功，请重试。"
        }
    }
}

extension AppModel {
    var selectedGoal: PersonalGoal? { goals.first { $0.id == selectedGoalID } }
    var selectedGoalTitle: String? { selectedGoal?.title }
    var activePersonalDefinitionKeys: Set<String> {
        var keys: Set<String> = []
        for batch in Dictionary(grouping: personalAchievements, by: \.batchID).values {
            let generations = Dictionary(grouping: batch, by: \.batchGenerationID).values.filter { members in
                guard let first = members.first, (1...3).contains(first.batchExpectedCount) else { return false }
                return members.count == first.batchExpectedCount && members.allSatisfy {
                    $0.batchExpectedCount == first.batchExpectedCount && $0.goalID == first.goalID
                }
            }.sorted { lhs, rhs in
                let a = lhs.map(\.batchCreatedAt).min()!
                let b = rhs.map(\.batchCreatedAt).min()!
                return a == b ? lhs[0].batchGenerationID.uuidString < rhs[0].batchGenerationID.uuidString : a < b
            }
            if let canonical = generations.first { keys.formUnion(canonical.map(\.definitionKey)) }
        }
        return keys
    }
    var visiblePersonalAchievements: [PersonalAchievementDefinition] {
        let keys = activePersonalDefinitionKeys
        return personalAchievements.filter { keys.contains($0.definitionKey) || personalState($0)?.unlockedAt != nil }
    }
    var latestCompanionText: String? {
        companionMessages.last { $0.goalID == selectedGoalID && $0.role == "assistant" && !$0.text.isEmpty }?.text
    }

    func encodeJourney<T: Encodable>(_ value: T) -> String { JourneyJSON.encode(value) ?? "" }

    func refreshJourney() {
        let fetched = (try? context.fetch(FetchDescriptor<PersonalGoal>())) ?? []
        goals = Array(Dictionary(fetched.map { ($0.id, $0) }, uniquingKeysWith: { lhs, rhs in
            let newest = lhs.updatedAt >= rhs.updatedAt ? lhs : rhs
            let days = Set((JourneyJSON.decode([String].self, from: lhs.companionRecordedDayKeysJSON) ?? []) +
                (JourneyJSON.decode([String].self, from: rhs.companionRecordedDayKeysJSON) ?? []))
            newest.companionRecordedDayKeysJSON = JourneyJSON.encode(days.sorted()) ?? "[]"
            return newest
        }).values).sorted { $0.createdAt < $1.createdAt }
        // Recover unioned shared days from independently synced logs, never from imported history.
        for goal in goals {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: goal.timeZoneID) ?? .current
            var days = Set(JourneyJSON.decode([String].self, from: goal.companionRecordedDayKeysJSON) ?? [])
            for log in logs where log.goalID == goal.id && log.recordedDuringCompanionship && log.companionSessionID != nil {
                if let date = log.completedAt, date <= Date() {
                    days.insert(String(calendar.startOfDay(for: date).timeIntervalSince1970))
                }
            }
            let merged = encodeJourney(days.sorted())
            if goal.companionRecordedDayKeysJSON != merged { goal.companionRecordedDayKeysJSON = merged }
        }
        let definitions = (try? context.fetch(FetchDescriptor<PersonalAchievementDefinition>())) ?? []
        personalAchievements = Array(Dictionary(definitions.map { ($0.definitionKey, $0) }, uniquingKeysWith: {
            $0.createdAt <= $1.createdAt ? $0 : $1
        }).values).sorted { $0.createdAt < $1.createdAt }
        personalEvidence = (try? context.fetch(FetchDescriptor<PersonalAchievementEvidence>())) ?? []
        companionMessages = (try? context.fetch(FetchDescriptor<CompanionMessage>())) ?? []
        companionMessages.sort { $0.createdAt < $1.createdAt }
        companionMemories = (try? context.fetch(FetchDescriptor<CompanionMemory>())) ?? []
        adjustmentRecords = (try? context.fetch(FetchDescriptor<PlanAdjustmentRecord>())) ?? []
        if !goals.contains(where: { $0.id == selectedGoalID }) { selectedGoalID = goals.first?.id }
        invalidateJourneyReferences()
    }

    @discardableResult
    func createGoal(title: String, weeklyTargetDays: Int? = nil, restWeekdays: Set<Int> = []) throws -> UUID {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, title.count <= 500,
              weeklyTargetDays.map({ (1...7).contains($0) }) ?? true,
              restWeekdays.allSatisfy({ (1...7).contains($0) }) else { throw JourneyActionError.invalid }
        let goal = PersonalGoal(title: title, weeklyTargetDays: weeklyTargetDays)
        goal.restWeekdaysCSV = restWeekdays.sorted().map(String.init).joined(separator: ",")
        context.insert(goal)
        try saveJourney()
        selectedGoalID = goal.id
        return goal.id
    }

    func saveJourney() throws {
        do {
#if DEBUG
            if failNextJourneySaveForTesting {
                failNextJourneySaveForTesting = false
                throw JourneyActionError.saveFailed
            }
#endif
            try context.save()
        }
        catch { context.rollback(); refresh(); throw JourneyActionError.saveFailed }
        refresh()
    }

    /// This is an explicit user action. Old records are never inferred from titles.
    func associateHistory(itemIDs: Set<UUID>, with goalID: UUID) throws {
        guard goals.contains(where: { $0.id == goalID }) else { throw JourneyActionError.invalid }
        for item in items where itemIDs.contains(item.id) {
            item.goalID = goalID
            item.updatedAt = Date()
            for log in logs where log.scheduleItemID == item.id && log.goalID == nil {
                log.goalID = goalID
                // Do not change companionship/session flags when importing history.
                log.updatedAt = Date()
            }
        }
        try saveJourney()
        reconcilePersonalAchievements(presentNewUnlocks: false)
    }

    func companionDayCount(for goalID: UUID?) -> Int {
        guard let goal = goals.first(where: { $0.id == goalID }) else { return 0 }
        return (JourneyJSON.decode([String].self, from: goal.companionRecordedDayKeysJSON) ?? []).count
    }

    func recordCompanionDay(goalID: UUID?, at date: Date) {
        guard let goal = goals.first(where: { $0.id == goalID }), let enabled = goal.aiEnabledAt,
              date >= enabled, date <= Date().addingTimeInterval(1) else { return }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: goal.timeZoneID) ?? .current
        let day = String(calendar.startOfDay(for: date).timeIntervalSince1970)
        var days = Set(JourneyJSON.decode([String].self, from: goal.companionRecordedDayKeysJSON) ?? [])
        days.insert(day)
        goal.companionRecordedDayKeysJSON = encodeJourney(days.sorted())
        goal.updatedAt = Date()
    }

    func personalState(_ definition: PersonalAchievementDefinition) -> AchievementState? {
        achievementStates.first { $0.definitionID == definition.definitionKey }
    }

    func reconcilePersonalAchievements(presentNewUnlocks: Bool = true) {
        var unlockedGoals: Set<UUID> = []
        var newKeys: [String] = []
        let activeKeys = activePersonalDefinitionKeys
        for definition in personalAchievements where activeKeys.contains(definition.definitionKey) {
            let result = PersonalAchievementEngine.evaluate(definition, logs: logs)
            guard result.isValid else { continue }
            let state = personalState(definition) ?? AchievementState(definitionID: definition.definitionKey, definitionVersion: definition.ruleVersion)
            if state.modelContext == nil { context.insert(state) }
            state.progress = result.progress
            state.signal = result.signal
            if state.unlockedAt == nil, result.shouldUnlock, let unlockedAt = result.unlockedAt {
                state.unlockedAt = unlockedAt
                let evidence = PersonalAchievementEvidence(
                    definitionKey: definition.definitionKey, goalID: definition.goalID,
                    unlockedAt: unlockedAt, occurrenceKeys: result.sourceOccurrenceKeys,
                    ruleJSON: definition.ruleJSON, metricValue: result.metricValue
                )
                evidence.sourceVersionsJSON = encodeJourney(currentSourceVersions().filter { result.sourceOccurrenceKeys.contains($0.key) })
                context.insert(evidence)
                if presentNewUnlocks {
                    unlockedGoals.insert(definition.goalID)
                }
                newKeys.append(definition.definitionKey)
            }
            state.updatedAt = Date()
        }
        do { try context.save() }
        catch {
            context.rollback()
            journeyError = JourneyActionError.saveFailed.localizedDescription
            refresh()
            return
        }
        if presentNewUnlocks { personalUnlockIDs.append(contentsOf: newKeys) }
        else { historicalUnlockCount += newKeys.count }
        refresh()
        for goalID in unlockedGoals { scheduleDailyCompanionReply(goalID: goalID, milestone: true) }
    }

    func archivePersonalAchievement(_ definition: PersonalAchievementDefinition) throws {
        guard personalState(definition)?.unlockedAt == nil else { return }
        definition.archivedAt = Date()
        definition.updatedAt = Date()
        try saveJourney()
    }

    func enableGoalAI(_ goalID: UUID) async throws {
        guard let goal = goals.first(where: { $0.id == goalID }) else { throw JourneyActionError.invalid }
        if goal.aiEnabledAt == nil { goal.aiEnabledAt = Date() }
        if goal.achievementBatchID == nil { goal.achievementBatchID = stableJourneyID("\(goal.id.uuidString):personal:v1") }
        goal.updatedAt = Date()
        try saveJourney()
        try await generatePersonalAchievements(goalID)
    }

    func disableGoalAI(_ goalID: UUID) throws {
        guard let goal = goals.first(where: { $0.id == goalID }) else { return }
        goal.aiEnabledAt = nil
        goal.updatedAt = Date()
        try saveJourney()
    }

    func generatePersonalAchievements(_ goalID: UUID) async throws {
        guard !journeyBusy, let goal = goals.first(where: { $0.id == goalID }), goal.aiEnabledAt != nil else { throw JourneyActionError.unavailableGoal }
        guard goal.achievementGenerationState != "complete" else { return }
        journeyBusy = true
        defer { journeyBusy = false }
        let batchID = goal.achievementBatchID ?? UUID()
        goal.achievementBatchID = batchID
        let request = journeyRequest(for: goal, operation: .designAchievements)
        let consentEpoch = goal.aiEnabledAt
        let scopeVersion = currentSourceVersions(for: goalID)
        goal.achievementGenerationState = "generating"
        try saveJourney()
        do {
            let response = try await journeyAI.designAchievements(request)
            try JourneyAIValidator.validate(response, for: request)
            refresh()
            guard goals.first(where: { $0.id == goalID })?.aiEnabledAt == consentEpoch else { throw JourneyActionError.unavailableGoal }
            let currentVersions = currentSourceVersions(for: goalID)
            guard ["goal", "goal-cadence"].allSatisfy({ scopeVersion[$0] == currentVersions[$0] }) else { throw JourneyActionError.stale }
            let canonicalKeys = activePersonalDefinitionKeys
            if personalAchievements.contains(where: { $0.batchID == batchID && canonicalKeys.contains($0.definitionKey) }) {
                goal.achievementGenerationState = "complete"
                try saveJourney()
                return
            }
            let earliest = logs.filter { $0.goalID == goalID && $0.status == .completed }.compactMap(\.completedAt).min()
            let anchor = min(earliest ?? goal.createdAt, goal.createdAt)
            let rules = try response.achievements.map { draft in
                guard let kind = PersonalAchievementRuleKind(rawValue: draft.ruleType.rawValue) else { throw JourneyActionError.invalid }
                // Eligibility is all explicitly associated history; the cycle boundary remains frozen.
                return PersonalAchievementRule(kind: kind, target: draft.target, startsAt: .distantPast,
                    timeZoneID: goal.timeZoneID, requiredDaysPerCycle: goal.weeklyTargetDays ?? 5, cycleAnchor: anchor)
            }
            let generationID = stableJourneyID("\(batchID.uuidString):\(encodeJourney(response)):\(encodeJourney(rules))")
            for (index, draft) in response.achievements.enumerated() {
                let rule = rules[index]
                let definition = PersonalAchievementDefinition(
                    id: stableJourneyID("\(generationID.uuidString):\(encodeJourney(rule)):\(index)"), goalID: goal.id, batchID: batchID,
                    title: draft.name, detail: draft.detail, clue: draft.clue,
                    badgeStyleID: draft.badgeStyleKey, isHidden: draft.isHidden, rule: rule, confirmedAt: Date(),
                    batchGenerationID: generationID, batchCreatedAt: request.currentDate, batchExpectedCount: response.achievements.count)
                context.insert(definition)
            }
            goal.achievementGenerationState = "complete"
            goal.updatedAt = Date()
            try saveJourney()
            reconcilePersonalAchievements(presentNewUnlocks: false)
        } catch {
            context.rollback()
            goal.achievementGenerationState = "retry"
            try? context.save()
            refresh()
            throw error
        }
    }

    func journeyRequest(for goal: PersonalGoal, operation: JourneyAIOperation, message: String = "") -> JourneyAIRequest {
        let completed = eligibleGoalLogs(goal.id)
            .sorted { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) }
        var facts = completed.suffix(35).map { log in
            let title = items.first(where: { $0.id == log.scheduleItemID })?.title ?? "已记录事项"
            let date = (log.completedAt ?? log.originalStart).formatted(.dateTime.year().month().day().locale(Locale(identifier: "zh_CN")))
            let provenance = log.recordedDuringCompanionship ? "开启陪伴后记录" : "历史记录，并非共同经历"
            return JourneyAIFact(id: log.occurrenceKey, text: "\(date)：\(title)。\(provenance)。")
        }
        facts.append(JourneyAIFact(id: "goal-count", text: "该目标已记录完成 \(completed.count) 次。"))
        if let target = goal.weeklyTargetDays {
            facts.append(JourneyAIFact(id: "goal-cadence", text: "用户确认的节奏：每七天 \(target) 个行动日，不得增加频率。"))
        }
        if operation == .companionReply {
            let recentMessages = companionMessages.filter { $0.goalID == goal.id && $0.role == "user" }
            for previous in recentMessages.suffix(3) {
                facts.append(JourneyAIFact(id: "message:\(previous.id.uuidString)", text: "此前用户主动说：\(String(previous.text.prefix(900)))"))
            }
        }
        let memories = companionMemories.filter { $0.goalID == goal.id && $0.isConfirmed }
            .suffix(10).map { JourneyAIFact(id: "memory:\($0.id.uuidString)", text: $0.text) }
        return JourneyAIRequest(operation: operation, goalID: goal.id, goalTitle: goal.title,
            timeZoneID: goal.timeZoneID, message: message, facts: facts, confirmedMemories: memories,
            achievementConsent: goal.aiEnabledAt != nil, cycleIsConfigured: goal.weeklyTargetDays != nil,
            requestID: operation == .designAchievements ? goal.achievementBatchID ?? UUID() : UUID())
    }

    func sendCompanionMessage(goalID: UUID, text: String, triggerKey: String? = nil) async throws {
        guard !journeyBusy, let goal = goals.first(where: { $0.id == goalID }), goal.aiEnabledAt != nil else { throw JourneyActionError.unavailableGoal }
        journeyBusy = true
        defer { journeyBusy = false }
        let request = journeyRequest(for: goal, operation: .companionReply, message: text)
        let consentEpoch = goal.aiEnabledAt
        var userMessageID: UUID?
        if triggerKey == nil {
            let message = CompanionMessage(goalID: goalID, role: "user", text: text)
            context.insert(message)
            userMessageID = message.id
            try saveJourney()
        }
        let sourceMessageID = userMessageID ?? companionMessages.first(where: { $0.triggerKey == triggerKey && $0.role == "event" })?.id
        var versions = currentSourceVersions(for: goalID)
        if let sourceMessageID { versions["message"] = versions["message:\(sourceMessageID.uuidString)"] }
        let reply = try await journeyAI.companionReply(request)
        try JourneyAIValidator.validate(reply, for: request)
        refresh()
        guard goals.first(where: { $0.id == goalID })?.aiEnabledAt == consentEpoch else { throw JourneyActionError.unavailableGoal }
        var nowVersions = currentSourceVersions(for: goalID)
        if let sourceMessageID { nowVersions["message"] = nowVersions["message:\(sourceMessageID.uuidString)"] }
        let contextIDs = Set(request.facts.map(\.id) + request.confirmedMemories.map(\.id) + ["goal", "message"])
        guard contextIDs.allSatisfy({ versions[$0] != nil && versions[$0] == nowVersions[$0] }) else { throw JourneyActionError.stale }
        let sourceIDs = reply.sourceIDs.compactMap { id -> String? in
            if id == "message" { return sourceMessageID.map { "message:\($0.uuidString)" } }
            if ["goal", "goal-count", "goal-cadence"].contains(id) { return "\(id):\(goalID.uuidString)" }
            return versions[id] == nil ? nil : id
        }
        let response = CompanionMessage(goalID: goalID, text: reply.text, sourceOccurrenceKeys: sourceIDs)
        response.sourceVersionsJSON = encodeJourney(currentSourceVersions().filter { sourceIDs.contains($0.key) })
        response.generationVersion = reply.skillVersion
        response.triggerKey = triggerKey
        context.insert(response)
        if let candidate = reply.memoryCandidate, !candidate.isEmpty {
            let memory = CompanionMemory(goalID: goalID, text: candidate, sourceOccurrenceKeys: sourceIDs)
            memory.sourceVersionsJSON = response.sourceVersionsJSON
            memory.isConfirmed = false
            context.insert(memory)
        }
        try saveJourney()
    }

    func scheduleDailyCompanionReply(goalID: UUID?, milestone: Bool = false) {
        guard AIPlannerServiceFactory.isRemoteConfigured, !journeyBusy,
              let goal = goals.first(where: { $0.id == goalID }), goal.aiEnabledAt != nil else { return }
        let day = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
        let key = milestone ? "milestone:\(personalUnlockIDs.sorted().joined(separator: ","))" : "daily:\(day)"
        guard !companionMessages.contains(where: { $0.triggerKey == key }) else { return }
        let reservation = CompanionMessage(goalID: goal.id, role: "event", text: "")
        reservation.triggerKey = key
        context.insert(reservation)
        guard (try? saveJourney()) != nil else { return }
        Task {
            do {
                try await sendCompanionMessage(goalID: goal.id,
                    text: milestone ? "我刚获得一项个人成就，请结合提供的记录简短回应，不猜测隐藏条件。" : "回应今天留下的行动，用一句话就好。", triggerKey: key)
            } catch { /* Automatic replies never interrupt recording. Manual chat exposes errors. */ }
        }
    }

    func confirmMemory(_ memory: CompanionMemory, text: String) throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 200 else { throw JourneyActionError.invalid }
        memory.text = trimmed
        memory.isConfirmed = true
        memory.updatedAt = Date()
        try saveJourney()
    }

    func deleteMemory(_ memory: CompanionMemory) throws { context.delete(memory); try saveJourney() }
    func clearConversation(goalID: UUID) throws {
        for message in companionMessages where message.goalID == goalID && message.role != "event" { context.delete(message) }
        // Keep the daily display reservation but invalidate an in-flight automatic reply.
        for message in companionMessages where message.goalID == goalID && message.role == "event" { message.text = UUID().uuidString }
        try saveJourney()
    }

    func currentSourceVersions(for goalID: UUID? = nil) -> [String: String] {
        var result: [String: String] = [:]
        for goal in goals {
            let id = goal.id.uuidString
            result["goal:\(id)"] = "\(goal.title):\(goal.deadline?.timeIntervalSince1970 ?? 0):\(goal.acceptedPlanJSON)"
            result["goal-count:\(id)"] = eligibleGoalLogs(goal.id)
                .map { "\($0.occurrenceKey):\($0.updatedAt.timeIntervalSince1970)" }.sorted().joined(separator: ";")
            result["goal-cadence:\(id)"] = "\(goal.weeklyTargetDays ?? 0):\(goal.restWeekdaysCSV)"
        }
        if let goalID {
            for key in ["goal", "goal-count", "goal-cadence"] { result[key] = result["\(key):\(goalID.uuidString)"] }
        }
        for log in logs where log.status == .completed {
            let item = items.first { $0.id == log.scheduleItemID }
            result[log.occurrenceKey] = "\(log.updatedAt.timeIntervalSince1970):\(item?.updatedAt.timeIntervalSince1970 ?? 0):\(log.goalID?.uuidString ?? "")"
        }
        for memory in companionMemories { result["memory:\(memory.id.uuidString)"] = "\(memory.updatedAt.timeIntervalSince1970):\(memory.text)" }
        for message in companionMessages where message.role == "user" || message.role == "event" { result["message:\(message.id.uuidString)"] = message.text }
        return result
    }

    func journeySourceDescription(_ key: String) -> String {
        if let log = logs.first(where: { $0.occurrenceKey == key }) {
            let title = items.first { $0.id == log.scheduleItemID }?.title ?? "已记录事项"
            return "\((log.completedAt ?? log.originalStart).formatted(date: .abbreviated, time: .omitted)) · \(title)"
        }
        if let memory = companionMemories.first(where: { "memory:\($0.id.uuidString)" == key }) { return memory.text }
        if let message = companionMessages.first(where: { "message:\($0.id.uuidString)" == key }) {
            return message.role == "event" ? "本次记录后的自动回应" : message.text
        }
        for goal in goals {
            switch key {
            case "goal:\(goal.id.uuidString)": return "目标：\(goal.title)"
            case "goal-count:\(goal.id.uuidString)":
                return "已关联的有效完成记录：\(eligibleGoalLogs(goal.id).count) 次"
            case "goal-cadence:\(goal.id.uuidString)":
                return "已确认节奏：每七天 \(goal.weeklyTargetDays ?? 0) 个行动日"
            default: continue
            }
        }
        return "来源已更新"
    }

    private func eligibleGoalLogs(_ goalID: UUID) -> [OccurrenceLog] {
        let now = Date()
        return logs.filter {
            $0.goalID == goalID && $0.status == .completed &&
            ($0.completedAt ?? .distantFuture) <= now && ($0.overrideStart ?? $0.originalStart) <= now
        }
    }

    private func invalidateJourneyReferences() {
        var versions = currentSourceVersions()
        func invalid(_ json: String) -> Bool {
            let saved = JourneyJSON.decode([String: String].self, from: json) ?? [:]
            return saved.contains { versions[$0.key] != $0.value }
        }
        var changed = false
        // A memory may cite another memory. Remove dependencies to a fixed point before replies.
        while let index = companionMemories.firstIndex(where: { invalid($0.sourceVersionsJSON) }) {
            let memory = companionMemories.remove(at: index)
            versions.removeValue(forKey: "memory:\(memory.id.uuidString)")
            context.delete(memory)
            changed = true
        }
        for message in companionMessages where message.role == "assistant" && !message.text.isEmpty && invalid(message.sourceVersionsJSON) {
            message.text = ""
            changed = true
        }
        if changed { try? context.save() }
    }

    func stableJourneyID(_ text: String) -> UUID {
        let digest = Array(SHA256.hash(data: Data(text.utf8)).prefix(16))
        return UUID(uuid: (digest[0], digest[1], digest[2], digest[3], digest[4], digest[5], digest[6], digest[7],
            digest[8], digest[9], digest[10], digest[11], digest[12], digest[13], digest[14], digest[15]))
    }
}
