import DayVaultCore
import Foundation
import SwiftData
import XCTest
@testable import DayVault

final class AvatarIntegrationTests: XCTestCase {
    @MainActor
    func testLockedAndUnknownRewardsCannotBeEquipped() throws {
        try withIsolatedModel { _, defaults, model in
            XCTAssertFalse(model.equipAvatarReward("ten_jacket"))
            XCTAssertFalse(model.equipAvatarReward("unknown_reward"))
            XCTAssertTrue(model.earnedAvatarRewards.isEmpty)
            XCTAssertEqual(model.avatarOutfit, AvatarOutfit())
            XCTAssertNil(defaults.data(forKey: "avatar.outfit.v1"))
        }
    }

    @MainActor
    func testFirstActualCompletionEarnsAndEquipsTheStarterBand() throws {
        try withIsolatedModel { _, defaults, model in
            let occurrence = try insertOccurrence(in: model)
            XCTAssertFalse(model.unlockedAchievementIDs.contains("first_check"))

            model.complete(occurrence, at: occurrence.end)

            XCTAssertTrue(model.unlockedAchievementIDs.contains("first_check"))
            XCTAssertEqual(model.earnedAvatarRewards.map(\.id), ["starter_band"])
            XCTAssertTrue(model.equipAvatarReward("starter_band"))
            XCTAssertEqual(model.avatarOutfit.accessory, "starter_band")
            let savedData = try XCTUnwrap(defaults.data(forKey: "avatar.outfit.v1"))
            XCTAssertEqual(try JSONDecoder().decode(AvatarOutfit.self, from: savedData), model.avatarOutfit)
        }
    }

    @MainActor
    func testRepeatedCompletionDoesNotDuplicateRewardsOrUnlockCeremonies() throws {
        try withIsolatedModel { _, _, model in
            let occurrence = try insertOccurrence(in: model)
            model.complete(occurrence, at: occurrence.end)
            let firstQueue = model.unlockQueue
            let firstUnlockDate = try XCTUnwrap(model.achievementStates.first { $0.definitionID == "first_check" }?.unlockedAt)

            model.complete(occurrence, at: occurrence.end.addingTimeInterval(60))

            XCTAssertEqual(model.logs.filter { $0.occurrenceKey == occurrence.id }.count, 1)
            XCTAssertEqual(model.earnedAvatarRewards.filter { $0.id == "starter_band" }.count, 1)
            XCTAssertEqual(model.unlockQueue, firstQueue)
            XCTAssertEqual(model.unlockQueue.filter { $0.definition.id == "first_check" }.count, 1)
            XCTAssertEqual(model.achievementStates.first { $0.definitionID == "first_check" }?.unlockedAt, firstUnlockDate)
        }
    }

    @MainActor
    func testAStaleCeremonyCallbackCannotConsumeTheNextUnlock() throws {
        try withIsolatedModel { _, _, model in
            let occurrence = try insertOccurrence(in: model)
            model.complete(occurrence, at: occurrence.end)
            let first = try XCTUnwrap(model.unlockQueue.first)
            XCTAssertGreaterThanOrEqual(model.unlockQueue.count, 2)
            model.consumeUnlock(id: first.id)
            let remaining = model.unlockQueue

            model.consumeUnlock(id: first.id)
            model.consumeUnlock(id: UUID())

            XCTAssertEqual(model.unlockQueue, remaining)
            let next = try XCTUnwrap(model.unlockQueue.first)
            model.consumeUnlock(id: next.id)
            XCTAssertEqual(model.unlockQueue, Array(remaining.dropFirst()))
        }
    }

    @MainActor
    func testEarnedOutfitRestoresAcrossAppModelLaunchesWithoutReplayingUnlocks() throws {
        try withIsolatedModel { container, defaults, model in
            let occurrence = try insertOccurrence(in: model)
            model.complete(occurrence, at: occurrence.end)
            XCTAssertTrue(model.equipAvatarReward("starter_band"))

            let restored = AppModel(container: container, avatarDefaults: defaults)

            XCTAssertEqual(restored.avatarOutfit, model.avatarOutfit)
            XCTAssertEqual(restored.earnedAvatarRewards.map(\.id), ["starter_band"])
            XCTAssertTrue(restored.unlockQueue.isEmpty)
        }
    }

    @MainActor
    func testRemovingAnItemSavesTheEmptySlotWithoutRemovingOwnership() throws {
        try withIsolatedModel { container, defaults, model in
            let occurrence = try insertOccurrence(in: model)
            model.complete(occurrence, at: occurrence.end)
            XCTAssertTrue(model.equipAvatarReward("starter_band"))

            model.removeAvatarReward(in: .accessory)

            XCTAssertNil(model.avatarOutfit.accessory)
            XCTAssertEqual(model.earnedAvatarRewards.map(\.id), ["starter_band"])
            let restored = AppModel(container: container, avatarDefaults: defaults)
            XCTAssertNil(restored.avatarOutfit.accessory)
            XCTAssertTrue(restored.equipAvatarReward("starter_band"))
        }
    }

    @MainActor
    func testCloudArrivalMakesHistoricalRewardWearableWithoutCeremony() throws {
        try withIsolatedModel { _, _, model in
            let arrival = AchievementState(definitionID: "first_check")
            arrival.progress = 1
            arrival.unlockedAt = Date(timeIntervalSince1970: 1_750_000_000)
            model.context.insert(arrival)
            try model.context.save()

            model.syncFromPersistence()

            XCTAssertEqual(model.earnedAvatarRewards.map(\.id), ["starter_band"])
            XCTAssertEqual(model.historicalUnlockCount, 1)
            XCTAssertTrue(model.unlockQueue.isEmpty)
            XCTAssertTrue(model.equipAvatarReward("starter_band"))
            XCTAssertEqual(model.avatarOutfit.accessory, "starter_band")
        }
    }

    @MainActor
    func testEquippingOneSlotPreservesAnotherSlotWhileItsUnlockIsStillSyncing() throws {
        try withIsolatedModel { container, defaults, _ in
            let savedOutfit = AvatarOutfit(head: "rhythm_cap")
            defaults.set(try JSONEncoder().encode(savedOutfit), forKey: "avatar.outfit.v1")
            let unlockDate = Date(timeIntervalSince1970: 1_750_000_000)
            let firstArrival = AchievementState(definitionID: "first_check")
            firstArrival.unlockedAt = unlockDate
            container.mainContext.insert(firstArrival)
            try container.mainContext.save()
            let model = AppModel(container: container, avatarDefaults: defaults)

            XCTAssertNil(model.avatarOutfit.head)
            XCTAssertTrue(model.equipAvatarReward("starter_band"))
            XCTAssertEqual(model.avatarOutfit.accessory, "starter_band")
            let savedData = try XCTUnwrap(defaults.data(forKey: "avatar.outfit.v1"))
            let pendingOutfit = try JSONDecoder().decode(AvatarOutfit.self, from: savedData)
            XCTAssertEqual(pendingOutfit.head, "rhythm_cap")
            XCTAssertEqual(pendingOutfit.accessory, "starter_band")

            let delayedArrival = AchievementState(definitionID: "steady_start")
            delayedArrival.unlockedAt = unlockDate
            model.context.insert(delayedArrival)
            try model.context.save()
            model.syncFromPersistence()

            XCTAssertEqual(model.avatarOutfit.head, "rhythm_cap")
            XCTAssertEqual(model.avatarOutfit.accessory, "starter_band")
            XCTAssertTrue(model.unlockQueue.isEmpty)
            let restored = AppModel(container: container, avatarDefaults: defaults)
            XCTAssertEqual(restored.avatarOutfit, model.avatarOutfit)
        }
    }

    @MainActor
    func testCloudDuplicatesKeepEarliestUnlockAndAnAlreadyEquippedReward() throws {
        try withIsolatedModel { _, _, model in
            let laterDate = Date(timeIntervalSince1970: 1_750_000_000)
            let earlierDate = laterDate.addingTimeInterval(-86_400)
            let firstArrival = AchievementState(definitionID: "first_check")
            firstArrival.unlockedAt = laterDate
            model.context.insert(firstArrival)
            try model.context.save()
            model.syncFromPersistence()
            XCTAssertTrue(model.equipAvatarReward("starter_band"))

            let duplicate = AchievementState(definitionID: "first_check")
            duplicate.unlockedAt = earlierDate
            duplicate.progress = 1
            model.context.insert(duplicate)
            try model.context.save()
            model.syncFromPersistence()

            let merged = model.achievementStates.filter { $0.definitionID == "first_check" }
            XCTAssertEqual(merged.count, 1)
            XCTAssertEqual(merged.first?.unlockedAt, earlierDate)
            XCTAssertEqual(model.avatarOutfit.accessory, "starter_band")
            XCTAssertEqual(model.earnedAvatarRewards.map(\.id), ["starter_band"])
            XCTAssertEqual(model.historicalUnlockCount, 1)
            XCTAssertTrue(model.unlockQueue.isEmpty)
        }
    }

    @MainActor
    func testEditingRecordedHistoryDoesNotRevokeEarnedEquipment() throws {
        try withIsolatedModel { _, _, model in
            let occurrence = try insertOccurrence(in: model)
            model.complete(occurrence, at: occurrence.end)
            XCTAssertTrue(model.equipAvatarReward("starter_band"))

            model.remove(occurrence)
            model.syncFromPersistence()

            XCTAssertEqual(model.logs.filter { $0.status == .completed }.count, 0)
            XCTAssertTrue(model.unlockedAchievementIDs.contains("first_check"))
            XCTAssertEqual(model.earnedAvatarRewards.map(\.id), ["starter_band"])
            XCTAssertEqual(model.avatarOutfit.accessory, "starter_band")
        }
    }

    @MainActor
    func testSavedAppearanceCannotGrantOwnershipOfLockedEquipment() throws {
        try withIsolatedModel { container, defaults, _ in
            let unearned = AvatarOutfit(head: "rhythm_cap", outerwear: "ten_jacket", accessory: "starter_band")
            defaults.set(try JSONEncoder().encode(unearned), forKey: "avatar.outfit.v1")

            let restored = AppModel(container: container, avatarDefaults: defaults)

            XCTAssertEqual(restored.avatarOutfit, AvatarOutfit())
            XCTAssertTrue(restored.earnedAvatarRewards.isEmpty)
            XCTAssertFalse(restored.equipAvatarReward("ten_jacket"))
        }
    }

    @MainActor
    private func insertOccurrence(in model: AppModel) throws -> ScheduleOccurrence {
        let start = Calendar.current.startOfDay(for: Date()).addingTimeInterval(10 * 3_600)
        let item = ScheduleItem(title: "角色奖励测试", plannedStart: start)
        model.context.insert(item)
        try model.context.save()
        model.refresh()
        return try XCTUnwrap(model.occurrences(for: start).first { $0.itemID == item.id })
    }

    @MainActor
    private func withIsolatedModel(_ body: (ModelContainer, UserDefaults, AppModel) throws -> Void) throws {
        let suiteName = "DayVault.AvatarIntegrationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let container = PersistenceController.makeContainer(inMemory: true)
        let model = AppModel(container: container, avatarDefaults: defaults)
        try body(container, defaults, model)
    }
}
