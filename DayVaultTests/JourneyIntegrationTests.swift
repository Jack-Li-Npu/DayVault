import DayVaultCore
import Foundation
import SwiftData
import XCTest
@testable import DayVault

final class JourneyIntegrationTests: XCTestCase {
    @MainActor
    func testExplicitHistoryAssociationIsGoalScopedAndDoesNotInventSharedDays() throws {
        let model = makeModel()
        let first = try insertGoal(in: model, title: "训练")
        let other = try insertGoal(in: model, title: "阅读")
        let start = Date().addingTimeInterval(-2 * 86_400)
        let history = try insertOccurrence(in: model, goalID: nil, start: start)
        let unrelated = try insertOccurrence(in: model, goalID: other.id, start: start)
        let oldLog = model.mutableLog(for: history)
        oldLog.status = .completed
        oldLog.completedAt = start.addingTimeInterval(60)
        let otherLog = model.mutableLog(for: unrelated)
        otherLog.status = .completed
        otherLog.completedAt = start.addingTimeInterval(60)
        try model.saveJourney()

        try model.associateHistory(itemIDs: [history.itemID], with: first.id)

        XCTAssertEqual(oldLog.goalID, first.id)
        XCTAssertEqual(otherLog.goalID, other.id)
        XCTAssertFalse(oldLog.recordedDuringCompanionship)
        XCTAssertNil(oldLog.companionSessionID)
        XCTAssertEqual(model.companionDayCount(for: first.id), 0)
        let request = model.journeyRequest(for: first, operation: .companionReply)
        XCTAssertTrue(request.facts.contains { $0.id == history.id && $0.text.contains("历史记录") })
        XCTAssertFalse(request.facts.contains { $0.id == unrelated.id })
        XCTAssertTrue(request.facts.contains { $0.id == "goal-count" && $0.text.contains("1 次") })
    }

    @MainActor
    func testThreePersonalRulesUnlockOnceWithoutChangingPublicCatalogAcrossRelaunch() throws {
        let model = makeModel()
        let goal = try insertGoal(in: model)
        let start = Calendar.current.startOfDay(for: Date()).addingTimeInterval(-86_400)
        let batchID = UUID()
        let kinds: [PersonalAchievementRuleKind] = [.completionCount, .activeDays, .completedCycles]
        let definitions = kinds.map { kind in
            PersonalAchievementDefinition(goalID: goal.id, batchID: batchID, title: kind.rawValue,
                isHidden: kind == .completedCycles,
                rule: PersonalAchievementRule(kind: kind, target: kind == .completionCount ? 2 : 1,
                    startsAt: start.addingTimeInterval(-86_400), timeZoneID: TimeZone.current.identifier,
                    requiredDaysPerCycle: 1), confirmedAt: start, createdAt: start, batchExpectedCount: 3)
        }
        definitions.forEach { model.context.insert($0) }
        try model.saveJourney()
        let first = try insertOccurrence(in: model, goalID: goal.id, start: start, precision: .dateOnly)
        let second = try insertOccurrence(in: model, goalID: goal.id, start: start, precision: .dateOnly)
        // Avoid automatic network-triggered replies; the injected service is still entirely local.
        model.journeyBusy = true
        model.complete(first, at: start.addingTimeInterval(3_600))
        model.complete(second, at: start.addingTimeInterval(7_200))
        model.journeyBusy = false
        let firstDates = Dictionary(uniqueKeysWithValues: definitions.map { ($0.definitionKey, model.personalState($0)?.unlockedAt) })
        let queue = model.personalUnlockIDs

        model.complete(first, at: Date())
        model.reconcilePersonalAchievements()

        XCTAssertEqual(model.personalEvidence.count, 3)
        XCTAssertEqual(Set(queue), Set(definitions.map(\.definitionKey)))
        XCTAssertEqual(model.personalUnlockIDs, queue)
        XCTAssertEqual(AchievementCatalog.all.count, 24)
        XCTAssertTrue(AchievementCatalog.all.allSatisfy { !$0.id.hasPrefix("personal:") })
        XCTAssertTrue(definitions.allSatisfy { model.personalState($0)?.unlockedAt != nil })
        XCTAssertTrue(definitions.allSatisfy { model.personalState($0)?.unlockedAt == firstDates[$0.definitionKey]! })
        let restored = makeModel(container: model.container)
        XCTAssertTrue(restored.personalUnlockIDs.isEmpty)
        XCTAssertEqual(restored.personalEvidence.count, 3)
        XCTAssertEqual(restored.achievementStates.filter { $0.definitionID.hasPrefix("personal:") && $0.unlockedAt != nil }.count, 3)
    }

    @MainActor
    func testDateOnlyCompletionPreservesIdentityAndNeverInventsActualTimes() throws {
        let model = makeModel()
        let goal = try insertGoal(in: model, enabled: true)
        let occurrence = try insertOccurrence(in: model, goalID: goal.id,
            start: Calendar.current.startOfDay(for: Date()), precision: .dateOnly)
        model.journeyBusy = true

        model.complete(occurrence)
        model.complete(occurrence)

        let log = try XCTUnwrap(model.logs.first { $0.occurrenceKey == occurrence.id })
        XCTAssertEqual(log.goalID, goal.id)
        XCTAssertEqual(log.timePrecision, .dateOnly)
        XCTAssertNil(log.actualStart)
        XCTAssertNil(log.actualEnd)
        XCTAssertTrue(log.recordedDuringCompanionship)
        XCTAssertEqual(model.companionDayCount(for: goal.id), 1)
        let resolved = try XCTUnwrap(model.occurrences().first { $0.id == occurrence.id })
        XCTAssertNil(resolved.displayStart)
        XCTAssertNil(resolved.displayEnd)
        XCTAssertEqual(resolved.durationMinutes, occurrence.durationMinutes)
        model.remove(resolved)
        XCTAssertEqual(model.companionDayCount(for: goal.id), 1, "Correcting a log cannot erase a day already shared.")
    }

    @MainActor
    func testNewDateOnlyDraftNormalizesItsDayAndClearsReminder() async throws {
        let model = makeModel()
        let goal = try insertGoal(in: model)
        var draft = ScheduleItemDraft()
        draft.title = "不需要具体钟点的行动"
        draft.plannedStart = Date()
        draft.goalID = goal.id
        draft.reminderLead = .ten

        let error = await model.addItem(draft, isPro: false)

        XCTAssertNil(error)
        let item = try XCTUnwrap(model.items.first)
        XCTAssertEqual(item.goalID, goal.id)
        XCTAssertEqual(item.timePrecision, .dateOnly)
        XCTAssertEqual(item.plannedStart, Calendar.current.startOfDay(for: draft.plannedStart))
        XCTAssertNil(item.reminderLeadMinutes)
        XCTAssertNil(item.displayStart)
    }

    @MainActor
    func testUnfinishedInboxRemainsVisibleAfterItsOriginalDay() throws {
        let model = makeModel()
        let old = try insertOccurrence(in: model, goalID: nil,
            start: Date().addingTimeInterval(-4 * 86_400), precision: .inbox)

        XCTAssertTrue(model.occurrences().contains { $0.id == old.id && $0.timePrecision == .inbox })
        model.complete(old)
        XCTAssertFalse(model.occurrences().contains { $0.id == old.id })
    }

    @MainActor
    func testGenerationFailureDoesNotCreateDefinitionsOrUnlocks() async throws {
        let fake = JourneyFakeAI(failDesign: true)
        let model = makeModel(ai: fake)
        let goal = try insertGoal(in: model)

        do {
            try await model.enableGoalAI(goal.id)
            XCTFail("Expected the injected failure")
        } catch {}

        XCTAssertTrue(model.personalAchievements.isEmpty)
        XCTAssertTrue(model.personalEvidence.isEmpty)
        XCTAssertTrue(model.personalUnlockIDs.isEmpty)
        XCTAssertEqual(goal.achievementGenerationState, "retry")
        XCTAssertFalse(model.journeyBusy)
    }

    @MainActor
    func testDisablingAIDuringGenerationRejectsTheDelayedResponse() async throws {
        let fake = JourneyFakeAI(pausedOperation: .designAchievements)
        let model = makeModel(ai: fake)
        let goal = try insertGoal(in: model)
        let pending = Task { try await model.enableGoalAI(goal.id) }
        await fake.waitUntilPaused()
        try model.disableGoalAI(goal.id)
        await fake.resume()

        do { try await pending.value; XCTFail("Disabled generation must be rejected") } catch {}

        XCTAssertNil(goal.aiEnabledAt)
        XCTAssertTrue(model.personalAchievements.isEmpty)
        XCTAssertTrue(model.personalEvidence.isEmpty)
        XCTAssertFalse(model.journeyBusy)
    }

    @MainActor
    func testRepeatedGenerationKeepsOneFrozenBatch() async throws {
        let fake = JourneyFakeAI()
        let model = makeModel(ai: fake)
        let goal = try insertGoal(in: model)

        try await model.enableGoalAI(goal.id)
        let ids = Set(model.personalAchievements.map(\.definitionKey))
        try await model.enableGoalAI(goal.id)

        XCTAssertEqual(ids.count, 3)
        XCTAssertEqual(Set(model.personalAchievements.map(\.definitionKey)), ids)
        let count = await fake.designRequestCount
        XCTAssertEqual(count, 1)
        XCTAssertTrue(model.personalAchievements.allSatisfy { $0.goalID == goal.id && $0.confirmedAt != nil })
        XCTAssertTrue(model.personalEvidence.isEmpty)
    }

    @MainActor
    func testPartialCloudGenerationCannotBecomeAnActiveBatchOrUnlock() throws {
        let model = makeModel()
        let goal = try insertGoal(in: model)
        let definitions = makeBatch(goalID: goal.id, batchID: UUID(), generationID: UUID(),
            createdAt: Date().addingTimeInterval(-60))
        model.context.insert(definitions[0])
        try model.saveJourney()
        model.reconcilePersonalAchievements(presentNewUnlocks: false)

        XCTAssertTrue(model.activePersonalDefinitionKeys.isEmpty)
        XCTAssertTrue(model.visiblePersonalAchievements.isEmpty)
        XCTAssertFalse(model.achievementStates.contains { $0.definitionID == definitions[0].definitionKey })

        model.context.insert(definitions[1])
        try model.saveJourney()

        XCTAssertEqual(model.activePersonalDefinitionKeys, Set(definitions.map(\.definitionKey)))
        XCTAssertEqual(model.visiblePersonalAchievements.count, 2)
        XCTAssertTrue(model.personalEvidence.isEmpty)
    }

    @MainActor
    func testWholeBatchReconciliationKeepsCanonicalGenerationAndEarnedLosingHistory() throws {
        let model = makeModel()
        let goal = try insertGoal(in: model)
        let batchID = UUID()
        let newer = makeBatch(goalID: goal.id, batchID: batchID, generationID: UUID(),
            createdAt: Date().addingTimeInterval(-60))
        let older = makeBatch(goalID: goal.id, batchID: batchID, generationID: UUID(),
            createdAt: Date().addingTimeInterval(-120))
        newer.forEach { model.context.insert($0) }
        let earned = AchievementState(definitionID: newer[0].definitionKey)
        earned.unlockedAt = Date().addingTimeInterval(-30)
        earned.progress = 1
        model.context.insert(earned)
        let receipt = PersonalAchievementEvidence(definitionKey: newer[0].definitionKey, goalID: goal.id,
            unlockedAt: earned.unlockedAt!, occurrenceKeys: ["retained-original-proof"],
            ruleJSON: newer[0].ruleJSON, metricValue: 1)
        model.context.insert(receipt)
        try model.saveJourney()
        XCTAssertEqual(model.activePersonalDefinitionKeys, Set(newer.map(\.definitionKey)))
        model.context.insert(older[0])
        try model.saveJourney()
        XCTAssertEqual(model.activePersonalDefinitionKeys, Set(newer.map(\.definitionKey)),
            "A partial older generation must not replace a complete generation.")

        model.context.insert(older[1])
        try model.saveJourney()
        model.reconcilePersonalAchievements(presentNewUnlocks: false)

        XCTAssertEqual(model.activePersonalDefinitionKeys, Set(older.map(\.definitionKey)))
        XCTAssertEqual(Set(model.visiblePersonalAchievements.map(\.definitionKey)),
            Set(older.map(\.definitionKey) + [newer[0].definitionKey]))
        XCTAssertEqual(model.personalEvidence.first?.ruleJSON, newer[0].ruleJSON)
        XCTAssertEqual(model.personalState(newer[0])?.unlockedAt, earned.unlockedAt)
        let restored = makeModel(container: model.container)
        XCTAssertEqual(restored.activePersonalDefinitionKeys, Set(older.map(\.definitionKey)))
        XCTAssertEqual(Set(restored.visiblePersonalAchievements.map(\.definitionKey)),
            Set(model.visiblePersonalAchievements.map(\.definitionKey)))
        XCTAssertTrue(restored.personalUnlockIDs.isEmpty)
    }

    @MainActor
    func testDisableThenReenableDoesNotAcceptThePreviousConsentSessionResponse() async throws {
        let fake = JourneyFakeAI(pausedOperation: .designAchievements)
        let model = makeModel(ai: fake)
        let goal = try insertGoal(in: model)
        let pending = Task { try await model.enableGoalAI(goal.id) }
        await fake.waitUntilPaused()
        try model.disableGoalAI(goal.id)
        // A second generation may be rejected while busy; it must not authorize the old request.
        try? await model.enableGoalAI(goal.id)
        await fake.resume()

        do { try await pending.value; XCTFail("The response belongs to revoked consent") } catch {}

        XCTAssertTrue(model.personalAchievements.isEmpty)
        XCTAssertTrue(model.personalEvidence.isEmpty)
    }

    @MainActor
    func testClearingConversationRejectsAnInFlightReplyAndItsMemoryCandidate() async throws {
        let fake = JourneyFakeAI(pausedOperation: .companionReply, replySources: ["message"], memoryCandidate: "周末休息")
        let model = makeModel(ai: fake)
        let goal = try insertGoal(in: model, enabled: true)
        let pending = Task { try await model.sendCompanionMessage(goalID: goal.id, text: "请记住周末休息") }
        await fake.waitUntilPaused()
        try model.clearConversation(goalID: goal.id)
        await fake.resume()

        do { try await pending.value; XCTFail("Cleared conversation must not be recreated by an old response") } catch {}

        XCTAssertTrue(model.companionMessages.filter { $0.role != "event" }.isEmpty)
        XCTAssertTrue(model.companionMemories.isEmpty)
    }

    @MainActor
    func testCorrectingACompletionWithdrawsAggregateCitedReply() async throws {
        let model = makeModel(ai: JourneyFakeAI(replySources: ["goal-count"]))
        let goal = try insertGoal(in: model, enabled: true)
        let occurrence = try insertOccurrence(in: model, goalID: goal.id, start: Date().addingTimeInterval(-3_600))
        model.journeyBusy = true
        model.complete(occurrence)
        model.journeyBusy = false
        try await model.sendCompanionMessage(goalID: goal.id, text: "今天做到了")
        let reply = try XCTUnwrap(model.companionMessages.last { $0.role == "assistant" })
        XCTAssertFalse(reply.text.isEmpty)
        XCTAssertFalse((JourneyJSON.decode([String: String].self, from: reply.sourceVersionsJSON) ?? [:]).isEmpty)

        model.remove(occurrence)

        XCTAssertTrue(reply.text.isEmpty, "A reply citing the previous completion total must be withdrawn.")
        XCTAssertEqual(model.companionMessages.filter { $0.role == "user" }.count, 1)
    }

    @MainActor
    func testMemoryCandidateRequiresConfirmationAndDeletionWithdrawsItsReply() async throws {
        let fake = JourneyFakeAI(replySources: ["message"], memoryCandidate: "周末留给休息")
        let model = makeModel(ai: fake)
        let goal = try insertGoal(in: model, enabled: true)
        try await model.sendCompanionMessage(goalID: goal.id, text: "请记住我周末休息")
        let memory = try XCTUnwrap(model.companionMemories.first)
        XCTAssertFalse(memory.isConfirmed)
        XCTAssertTrue(model.journeyRequest(for: goal, operation: .companionReply).confirmedMemories.isEmpty)
        try model.confirmMemory(memory, text: memory.text)
        let source = "memory:\(memory.id.uuidString)"
        XCTAssertEqual(model.journeyRequest(for: goal, operation: .companionReply).confirmedMemories.map(\.id), [source])
        await fake.setReplySources([source])
        try await model.sendCompanionMessage(goalID: goal.id, text: "我的偏好是什么")
        let reply = try XCTUnwrap(model.companionMessages.last { $0.role == "assistant" })

        try model.deleteMemory(memory)

        XCTAssertTrue(reply.text.isEmpty)
    }

    @MainActor
    func testDisablingAIDuringAdjustmentDoesNotPersistDraftOrMutateSchedule() async throws {
        let fake = JourneyFakeAI(pausedOperation: .suggestAdjustment)
        let model = makeModel(ai: fake)
        let goal = try insertGoal(in: model, enabled: true)
        let occurrence = try insertOccurrence(in: model, goalID: goal.id, start: futureStart())
        let pending = Task { try await model.proposeAdjustment(goalID: goal.id, message: "晚一点做") }
        await fake.waitUntilPaused()
        try model.disableGoalAI(goal.id)
        await fake.resume()

        do { _ = try await pending.value; XCTFail("Disabled adjustment must be rejected") } catch {}

        XCTAssertTrue(model.adjustmentRecords.isEmpty)
        XCTAssertFalse(model.logs.contains { $0.occurrenceKey == occurrence.id })
    }

    @MainActor
    func testDisableThenReenableCannotAuthorizeAnOlderAdjustmentResponse() async throws {
        let fake = JourneyFakeAI(pausedOperation: .suggestAdjustment)
        let model = makeModel(ai: fake)
        let goal = try insertGoal(in: model, enabled: true)
        _ = try insertOccurrence(in: model, goalID: goal.id, start: futureStart())
        let pending = Task { try await model.proposeAdjustment(goalID: goal.id, message: "晚一点做") }
        await fake.waitUntilPaused()
        try model.disableGoalAI(goal.id)
        try? await model.enableGoalAI(goal.id)
        await fake.resume()

        do { _ = try await pending.value; XCTFail("Old consent cannot authorize a new draft") } catch {}

        XCTAssertTrue(model.adjustmentRecords.isEmpty)
        XCTAssertTrue(model.logs.isEmpty)
    }

    @MainActor
    func testAdjustmentCannotSplitSameDayActionsToIncreaseTrainingFrequency() async throws {
        let model = makeModel()
        let goal = try insertGoal(in: model, enabled: true)
        goal.createdAt = Calendar.current.startOfDay(for: Date()).addingTimeInterval(-4 * 86_400)
        goal.weeklyTargetDays = 2
        try model.saveJourney()
        let first = try insertOccurrence(in: model, goalID: goal.id, start: futureStart())
        let second = try insertOccurrence(in: model, goalID: goal.id, start: first.start.addingTimeInterval(2 * 3_600))
        let request = try await model.adjustmentRequest(goalID: goal.id, message: "挪一下")
        let suggestion = JourneyAdjustmentSuggestion(goalID: goal.id, summary: "分到第二天",
            changes: [JourneyAdjustmentChange(occurrenceID: second.id, newStart: second.start.addingTimeInterval(86_400))], sourceIDs: ["goal"])
        try JourneyAIValidator.validate(suggestion, for: request)

        XCTAssertThrowsError(try model.validateAdjustmentGoalLimits(suggestion, request: request))
        XCTAssertTrue(model.logs.isEmpty)
    }

    @MainActor
    func testAdjustmentCannotTradeActionDaysBetweenTwoFrozenCycles() async throws {
        let model = makeModel()
        let goal = try insertGoal(in: model, enabled: true)
        goal.createdAt = Calendar.current.startOfDay(for: Date()).addingTimeInterval(-4 * 86_400)
        goal.weeklyTargetDays = 2
        try model.saveJourney()
        let first = try insertOccurrence(in: model, goalID: goal.id, start: futureStart())
        let second = try insertOccurrence(in: model, goalID: goal.id, start: first.start.addingTimeInterval(86_400))
        let nextCycle = try insertOccurrence(in: model, goalID: goal.id, start: first.start.addingTimeInterval(2 * 86_400))
        let sameDay = try insertOccurrence(in: model, goalID: goal.id, start: nextCycle.start.addingTimeInterval(2 * 3_600))
        let request = try await model.adjustmentRequest(goalID: goal.id, message: "调整这周")
        let suggestion = JourneyAdjustmentSuggestion(goalID: goal.id, summary: "总行动日不变但交换周期频率", changes: [
            JourneyAdjustmentChange(occurrenceID: second.id, newStart: first.start.addingTimeInterval(4 * 3_600)),
            JourneyAdjustmentChange(occurrenceID: sameDay.id, newStart: sameDay.start.addingTimeInterval(86_400)),
        ], sourceIDs: ["goal"])
        try JourneyAIValidator.validate(suggestion, for: request)

        XCTAssertThrowsError(try model.validateAdjustmentGoalLimits(suggestion, request: request),
            "Keeping the seven-day total cannot conceal shrinking one cycle and expanding another.")
        XCTAssertTrue(model.logs.isEmpty)
    }

    @MainActor
    func testExistingAboveTargetCadenceStillAllowsSameDayTimeAdjustment() async throws {
        let model = makeModel()
        let goal = try insertGoal(in: model, enabled: true)
        goal.createdAt = Calendar.current.startOfDay(for: Date()).addingTimeInterval(-4 * 86_400)
        goal.weeklyTargetDays = 1
        try model.saveJourney()
        let first = try insertOccurrence(in: model, goalID: goal.id, start: futureStart())
        _ = try insertOccurrence(in: model, goalID: goal.id, start: first.start.addingTimeInterval(86_400))
        let historical = try insertOccurrence(in: model, goalID: goal.id, start: first.start.addingTimeInterval(-2 * 86_400))
        let log = model.mutableLog(for: historical)
        log.status = .completed
        log.completedAt = historical.end
        try model.saveJourney()
        let request = try await model.adjustmentRequest(goalID: goal.id, message: "只改钟点")
        XCTAssertFalse(request.allowedOccurrences.contains { $0.id == historical.id })
        let suggestion = JourneyAdjustmentSuggestion(goalID: goal.id, summary: "原有行动日不变",
            changes: [JourneyAdjustmentChange(occurrenceID: first.id, newStart: first.start.addingTimeInterval(3_600))], sourceIDs: ["goal"])
        try JourneyAIValidator.validate(suggestion, for: request)

        XCTAssertNoThrow(try model.validateAdjustmentGoalLimits(suggestion, request: request))
    }

    @MainActor
    func testAdjustmentAppliesAndUndoesAsOccurrenceOverridesWithStableIdentity() async throws {
        let model = makeModel()
        let goal = try insertGoal(in: model, enabled: true)
        let occurrence = try insertOccurrence(in: model, goalID: goal.id, start: futureStart())
        let target = occurrence.start.addingTimeInterval(3_600)
        let record = try await insertAdjustment(in: model, goalID: goal.id,
            changes: [JourneyAdjustmentChange(occurrenceID: occurrence.id, newStart: target)])
        XCTAssertTrue(model.logs.isEmpty)

        try await model.applyAdjustment(record)

        let applied = try XCTUnwrap(model.logs.first { $0.occurrenceKey == occurrence.id })
        XCTAssertEqual(applied.overrideStart, target)
        XCTAssertTrue(applied.wasRescheduled)
        XCTAssertNotNil(record.appliedAt)
        XCTAssertEqual(model.items.first { $0.id == occurrence.itemID }?.plannedStart, occurrence.originalStart)
        XCTAssertNil(applied.actualStart)
        XCTAssertNil(applied.actualEnd)
        let firstAppliedAt = record.appliedAt
        try await model.applyAdjustment(record)
        XCTAssertEqual(record.appliedAt, firstAppliedAt)

        try await model.undoAdjustment(record)

        XCTAssertNotNil(record.revertedAt)
        XCTAssertEqual(applied.overrideStart, occurrence.start)
        XCTAssertFalse(applied.wasRescheduled)
        XCTAssertEqual(model.logs.filter { $0.occurrenceKey == occurrence.id }.count, 1)
        XCTAssertEqual(model.occurrences(for: occurrence.start).first { $0.id == occurrence.id }?.durationMinutes, occurrence.durationMinutes)
    }

    @MainActor
    func testAdjustmentSaveFailureRollsBackTheEntireBatchAndCanBeRetried() async throws {
        let model = makeModel()
        let goal = try insertGoal(in: model, enabled: true)
        let first = try insertOccurrence(in: model, goalID: goal.id, start: futureStart())
        let second = try insertOccurrence(in: model, goalID: goal.id, start: first.start.addingTimeInterval(3 * 3_600))
        let record = try await insertAdjustment(in: model, goalID: goal.id, changes: [
            JourneyAdjustmentChange(occurrenceID: first.id, newStart: first.start.addingTimeInterval(3_600)),
            JourneyAdjustmentChange(occurrenceID: second.id, newStart: second.start.addingTimeInterval(3_600)),
        ])
        let originalEnvelope = record.afterJSON
        model.failNextJourneySaveForTesting = true

        do { try await model.applyAdjustment(record); XCTFail("Expected injected save failure") } catch {}

        XCTAssertTrue(model.logs.isEmpty)
        XCTAssertNil(record.appliedAt)
        XCTAssertEqual(record.afterJSON, originalEnvelope)
        XCTAssertTrue(model.personalUnlockIDs.isEmpty)
        try await model.applyAdjustment(record)
        XCTAssertEqual(model.logs.count, 2)
        XCTAssertNotNil(record.appliedAt)
    }

    @MainActor
    func testUndoSaveFailureRetainsTheAppliedSchedule() async throws {
        let model = makeModel()
        let goal = try insertGoal(in: model, enabled: true)
        let occurrence = try insertOccurrence(in: model, goalID: goal.id, start: futureStart())
        let target = occurrence.start.addingTimeInterval(3_600)
        let record = try await insertAdjustment(in: model, goalID: goal.id,
            changes: [JourneyAdjustmentChange(occurrenceID: occurrence.id, newStart: target)])
        try await model.applyAdjustment(record)
        model.failNextJourneySaveForTesting = true

        do { try await model.undoAdjustment(record); XCTFail("Expected injected save failure") } catch {}

        XCTAssertNil(record.revertedAt)
        XCTAssertEqual(model.logs.first { $0.occurrenceKey == occurrence.id }?.overrideStart, target)
        try await model.undoAdjustment(record)
        XCTAssertNotNil(record.revertedAt)
    }

    @MainActor
    func testAStaleSecondChangeRejectsTheEntireAdjustmentBeforeAnyMutation() async throws {
        let model = makeModel()
        let goal = try insertGoal(in: model, enabled: true)
        let first = try insertOccurrence(in: model, goalID: goal.id, start: futureStart())
        let second = try insertOccurrence(in: model, goalID: goal.id, start: first.start.addingTimeInterval(3 * 3_600))
        let record = try await insertAdjustment(in: model, goalID: goal.id, changes: [
            JourneyAdjustmentChange(occurrenceID: first.id, newStart: first.start.addingTimeInterval(3_600)),
            JourneyAdjustmentChange(occurrenceID: second.id, newStart: second.start.addingTimeInterval(3_600)),
        ])
        let changedItem = try XCTUnwrap(model.items.first { $0.id == second.itemID })
        changedItem.updatedAt = changedItem.updatedAt.addingTimeInterval(1)
        try model.saveJourney()

        do { try await model.applyAdjustment(record); XCTFail("Expected stale preview rejection") } catch {}

        XCTAssertNil(record.appliedAt)
        XCTAssertTrue(record.beforeJSON.isEmpty)
        XCTAssertTrue(model.logs.isEmpty, "Neither of the proposed occurrence overrides may leak through.")
    }

    @MainActor
    func testExpiredAdjustmentCannotMoveAnItemIntoThePast() async throws {
        let model = makeModel()
        let goal = try insertGoal(in: model, enabled: true)
        let occurrence = try insertOccurrence(in: model, goalID: goal.id, start: futureStart())
        let earlier = Date().addingTimeInterval(-3_600)
        let oldRequest = try await model.adjustmentRequest(goalID: goal.id, message: "调整", now: earlier)
        let suggestion = JourneyAdjustmentSuggestion(goalID: goal.id, summary: "之前生成的建议",
            changes: [JourneyAdjustmentChange(occurrenceID: occurrence.id, newStart: earlier.addingTimeInterval(600))], sourceIDs: ["goal"])
        try JourneyAIValidator.validate(suggestion, for: oldRequest)
        let record = PlanAdjustmentRecord(goalID: goal.id, reason: suggestion.summary, beforeJSON: "",
            afterJSON: model.encodeJourney(AdjustmentEnvelope(request: oldRequest, suggestion: suggestion)))
        model.context.insert(record)
        try model.saveJourney()

        do { try await model.applyAdjustment(record); XCTFail("Expired target must be rejected") } catch {}

        XCTAssertNil(record.appliedAt)
        XCTAssertTrue(model.logs.isEmpty)
    }

    @MainActor
    func testLaterUserEditPreventsUndoFromOverwritingIt() async throws {
        let model = makeModel()
        let goal = try insertGoal(in: model, enabled: true)
        let occurrence = try insertOccurrence(in: model, goalID: goal.id, start: futureStart())
        let record = try await insertAdjustment(in: model, goalID: goal.id, changes: [
            JourneyAdjustmentChange(occurrenceID: occurrence.id, newStart: occurrence.start.addingTimeInterval(3_600)),
        ])
        try await model.applyAdjustment(record)
        let log = try XCTUnwrap(model.logs.first { $0.occurrenceKey == occurrence.id })
        let edited = occurrence.start.addingTimeInterval(2 * 3_600)
        log.overrideStart = edited
        log.updatedAt = log.updatedAt.addingTimeInterval(1)
        try model.saveJourney()

        do { try await model.undoAdjustment(record); XCTFail("A later edit must survive undo") } catch {}

        XCTAssertNil(record.revertedAt)
        XCTAssertEqual(log.overrideStart, edited)
    }

    @MainActor
    private func makeModel(container: ModelContainer? = nil, ai: any JourneyAI = JourneyFakeAI()) -> AppModel {
        let model = AppModel(container: container ?? PersistenceController.makeContainer(inMemory: true),
            persistAvatarPreferences: false, journeyAI: ai)
        model.calendarEnabled = false
        return model
    }

    @MainActor
    private func insertGoal(in model: AppModel, title: String = "保持行动", enabled: Bool = false) throws -> PersonalGoal {
        let goal = PersonalGoal(title: title, timeZoneID: TimeZone.current.identifier,
            aiEnabledAt: enabled ? Date().addingTimeInterval(-60) : nil,
            createdAt: Date().addingTimeInterval(-30 * 86_400))
        model.context.insert(goal)
        try model.saveJourney()
        return goal
    }

    @MainActor
    private func insertOccurrence(in model: AppModel, goalID: UUID?, start: Date,
                                  precision: ScheduleTimePrecision = .timed) throws -> ScheduleOccurrence {
        let item = ScheduleItem(title: "测试行动", plannedStart: start, plannedDurationMinutes: 30,
            goalID: goalID, timePrecision: precision)
        model.context.insert(item)
        try model.saveJourney()
        return try XCTUnwrap(RecurrenceResolver.occurrences(for: item,
            in: DateInterval(start: start.addingTimeInterval(-86_400), end: start.addingTimeInterval(86_400)), logs: model.logs).first)
    }

    @MainActor
    private func insertAdjustment(in model: AppModel, goalID: UUID,
                                  changes: [JourneyAdjustmentChange]) async throws -> PlanAdjustmentRecord {
        let request = try await model.adjustmentRequest(goalID: goalID, message: "晚一点做")
        let suggestion = JourneyAdjustmentSuggestion(goalID: goalID, summary: "同一天稍晚一点",
            changes: changes, sourceIDs: ["goal"])
        try JourneyAIValidator.validate(suggestion, for: request)
        let record = PlanAdjustmentRecord(goalID: goalID, reason: suggestion.summary, beforeJSON: "",
            afterJSON: model.encodeJourney(AdjustmentEnvelope(request: request, suggestion: suggestion)))
        model.context.insert(record)
        try model.saveJourney()
        return record
    }

    private func futureStart() -> Date {
        Calendar.current.startOfDay(for: Date()).addingTimeInterval(86_400 + 10 * 3_600)
    }

    private func makeBatch(goalID: UUID, batchID: UUID, generationID: UUID,
                           createdAt: Date) -> [PersonalAchievementDefinition] {
        (0..<2).map { index in
            PersonalAchievementDefinition(goalID: goalID, batchID: batchID, title: "批次事项 \(index)",
                rule: PersonalAchievementRule(kind: .completionCount, target: index + 1,
                    startsAt: .distantPast, timeZoneID: TimeZone.current.identifier),
                confirmedAt: createdAt, createdAt: createdAt,
                batchGenerationID: generationID, batchCreatedAt: createdAt, batchExpectedCount: 2)
        }
    }
}

/// No network, credentials, timers or paid services are used by these tests.
private actor JourneyFakeAI: JourneyAI {
    enum Failure: Error { case requested }
    let failDesign: Bool
    let pausedOperation: JourneyAIOperation?
    var replySources: [String]
    let memoryCandidate: String?
    private(set) var designRequestCount = 0
    private var reachedPause = false
    private var pauseWaiter: CheckedContinuation<Void, Never>?
    private var responseWaiter: CheckedContinuation<Void, Never>?

    init(failDesign: Bool = false, pausedOperation: JourneyAIOperation? = nil,
         replySources: [String] = ["goal"], memoryCandidate: String? = nil) {
        self.failDesign = failDesign
        self.pausedOperation = pausedOperation
        self.replySources = replySources
        self.memoryCandidate = memoryCandidate
    }

    func waitUntilPaused() async {
        if reachedPause { return }
        await withCheckedContinuation { pauseWaiter = $0 }
    }

    func resume() { responseWaiter?.resume(); responseWaiter = nil }
    func setReplySources(_ sources: [String]) { replySources = sources }

    private func pauseIfNeeded(_ operation: JourneyAIOperation) async {
        guard pausedOperation == operation else { return }
        await withCheckedContinuation { continuation in
            responseWaiter = continuation
            reachedPause = true
            pauseWaiter?.resume()
            pauseWaiter = nil
        }
    }

    func designAchievements(_ request: JourneyAIRequest) async throws -> JourneyAchievementDesign {
        designRequestCount += 1
        await pauseIfNeeded(.designAchievements)
        if failDesign { throw Failure.requested }
        return JourneyAchievementDesign(goalID: request.goalID, achievements: [
            JourneyAchievementDraft(id: "first", name: "先行一步", detail: "完成一次行动", ruleType: .completionCount,
                target: 1, isHidden: false, clue: "", badgeStyleKey: "crest", sourceIDs: ["goal"]),
            JourneyAchievementDraft(id: "days", name: "留下日子", detail: "留下两个行动日", ruleType: .activeDays,
                target: 2, isHidden: false, clue: "", badgeStyleKey: "steps", sourceIDs: ["goal"]),
            JourneyAchievementDraft(id: "secret", name: "未完待续", detail: "完成三次行动", ruleType: .completionCount,
                target: 3, isHidden: true, clue: "故事还在继续", badgeStyleKey: "orbit", sourceIDs: ["goal"]),
        ])
    }

    func companionReply(_ request: JourneyAIRequest) async throws -> JourneyCompanionReply {
        await pauseIfNeeded(.companionReply)
        return JourneyCompanionReply(goalID: request.goalID, text: "你留下了自己的记录。",
            sourceIDs: replySources, memoryCandidate: memoryCandidate)
    }

    func suggestAdjustment(_ request: JourneyAIRequest) async throws -> JourneyAdjustmentSuggestion {
        await pauseIfNeeded(.suggestAdjustment)
        return JourneyAdjustmentSuggestion(goalID: request.goalID, summary: "同一天晚一点做",
            changes: request.allowedOccurrences.prefix(1).map {
                JourneyAdjustmentChange(occurrenceID: $0.id, newStart: $0.start.addingTimeInterval(3_600))
            }, sourceIDs: ["goal"])
    }
}
