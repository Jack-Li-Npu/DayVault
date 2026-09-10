import Foundation
import XCTest
@testable import DayVaultCore

final class AvatarRewardsTests: XCTestCase {
    private var allUnlocks: Set<String> {
        Set(AvatarRewardCatalog.all.map(\.achievementID))
    }

    func testCatalogContainsSixUniqueRewardsWithExistingAchievementSources() {
        let rewards = AvatarRewardCatalog.all
        let achievementIDs = Set(AchievementCatalog.all.map(\.id))

        XCTAssertEqual(rewards.count, 6)
        XCTAssertEqual(Set(rewards.map(\.id)).count, 6)
        XCTAssertEqual(Set(rewards.map(\.achievementID)).count, 6)
        XCTAssertEqual(Set(rewards.map(\.slot)), Set(AvatarSlot.allCases))
        XCTAssertTrue(rewards.allSatisfy { achievementIDs.contains($0.achievementID) })
        XCTAssertTrue(rewards.allSatisfy { !$0.name.isEmpty && !$0.detail.isEmpty })
    }

    func testCatalogMappingsStayStable() throws {
        let expected: [(String, AvatarSlot, String)] = [
            ("starter_band", .accessory, "first_check"),
            ("rhythm_cap", .head, "steady_start"),
            ("ten_jacket", .outerwear, "timekeeper_1"),
            ("rhythm_varsity", .outerwear, "in_rhythm"),
            ("month_satchel", .accessory, "month_in_motion"),
            ("comeback_bandana", .head, "second_wind"),
        ]
        for (id, slot, achievementID) in expected {
            let reward = try XCTUnwrap(AvatarRewardCatalog.reward(for: achievementID))
            XCTAssertEqual(reward.id, id)
            XCTAssertEqual(reward.slot, slot)
        }
        XCTAssertNil(AvatarRewardCatalog.reward(for: "unknown_achievement"))
    }

    func testLockedEquipmentCannotBeWorn() {
        let outfit = AvatarOutfit()
        for reward in AvatarRewardCatalog.all {
            XCTAssertEqual(outfit.equipping(reward, unlockedAchievementIDs: []), outfit)
        }
    }

    func testEachRewardCanBeWornWithItsExactAchievement() {
        for reward in AvatarRewardCatalog.all {
            let outfit = AvatarOutfit().equipping(reward, unlockedAchievementIDs: [reward.achievementID])
            XCTAssertEqual(outfit.equippedIDs, [reward.id])
            XCTAssertEqual(outfit.validated(unlockedAchievementIDs: [reward.achievementID]), outfit)
        }
    }

    func testAnotherUnlockedAchievementDoesNotGrantReward() throws {
        let reward = try XCTUnwrap(AvatarRewardCatalog.reward(for: "timekeeper_1"))
        XCTAssertEqual(
            AvatarOutfit().equipping(reward, unlockedAchievementIDs: ["first_check"]),
            AvatarOutfit()
        )
    }

    func testChangingEquipmentReplacesOnlyItsSlot() throws {
        let initial = AvatarOutfit(head: "rhythm_cap", outerwear: "ten_jacket", accessory: "starter_band")
        let replacements = ["second_wind", "in_rhythm", "month_in_motion"]
        let expected = [
            AvatarOutfit(head: "comeback_bandana", outerwear: "ten_jacket", accessory: "starter_band"),
            AvatarOutfit(head: "rhythm_cap", outerwear: "rhythm_varsity", accessory: "starter_band"),
            AvatarOutfit(head: "rhythm_cap", outerwear: "ten_jacket", accessory: "month_satchel"),
        ]

        for (index, achievementID) in replacements.enumerated() {
            let reward = try XCTUnwrap(AvatarRewardCatalog.reward(for: achievementID))
            XCTAssertEqual(initial.equipping(reward, unlockedAchievementIDs: allUnlocks), expected[index])
        }
    }

    func testRepeatedEquipAndValidationAreIdempotent() throws {
        let reward = try XCTUnwrap(AvatarRewardCatalog.reward(for: "first_check"))
        let outfit = AvatarOutfit().equipping(reward, unlockedAchievementIDs: allUnlocks)

        XCTAssertEqual(outfit.equipping(reward, unlockedAchievementIDs: allUnlocks), outfit)
        XCTAssertEqual(outfit.validated(unlockedAchievementIDs: allUnlocks), outfit)
        XCTAssertEqual(outfit.equippedIDs.count, 1)
    }

    func testRemovingSlotPreservesOtherEquipment() {
        let initial = AvatarOutfit(head: "rhythm_cap", outerwear: "ten_jacket", accessory: "starter_band")
        XCTAssertEqual(initial.removing(.head), AvatarOutfit(outerwear: "ten_jacket", accessory: "starter_band"))
        XCTAssertEqual(initial.removing(.outerwear), AvatarOutfit(head: "rhythm_cap", accessory: "starter_band"))
        XCTAssertEqual(initial.removing(.accessory), AvatarOutfit(head: "rhythm_cap", outerwear: "ten_jacket"))
        XCTAssertEqual(AvatarOutfit().removing(.head), AvatarOutfit())
    }

    func testOutfitRoundTripsAcrossLaunches() throws {
        let initial = AvatarOutfit(head: "rhythm_cap", outerwear: "ten_jacket", accessory: "starter_band")
        let saved = try JSONEncoder().encode(initial)
        let restored = try JSONDecoder().decode(AvatarOutfit.self, from: saved)

        XCTAssertEqual(restored, initial)
        XCTAssertEqual(restored.validated(unlockedAchievementIDs: allUnlocks), initial)
        XCTAssertEqual(try JSONDecoder().decode(AvatarOutfit.self, from: Data("{}".utf8)), AvatarOutfit())
    }

    func testValidationRejectsUnknownWrongSlotAndLockedIDs() throws {
        let corrupted = Data(#"{"head":"invented_hat","outerwear":"rhythm_cap","accessory":"month_satchel"}"#.utf8)
        let restored = try JSONDecoder().decode(AvatarOutfit.self, from: corrupted)

        XCTAssertEqual(restored.validated(unlockedAchievementIDs: ["steady_start"]), AvatarOutfit())
        let partial = AvatarOutfit(head: "rhythm_cap", outerwear: "invented_jacket", accessory: "starter_band")
        XCTAssertEqual(
            partial.validated(unlockedAchievementIDs: ["first_check", "steady_start"]),
            AvatarOutfit(head: "rhythm_cap", accessory: "starter_band")
        )
    }

    func testInvalidSerializedTypesFailToDecode() {
        let malformed = Data(#"{"head":42}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(AvatarOutfit.self, from: malformed))
    }

    func testForgedRewardsCannotBypassCatalogOrUnlockRequirements() throws {
        let real = try XCTUnwrap(AvatarRewardCatalog.reward(for: "timekeeper_1"))
        let forgeries = [
            AvatarReward(id: "invented", slot: .outerwear, achievementID: "first_check", name: "假装备", detail: ""),
            AvatarReward(id: real.id, slot: .head, achievementID: real.achievementID, name: real.name, detail: real.detail),
            AvatarReward(id: real.id, slot: real.slot, achievementID: "first_check", name: real.name, detail: real.detail),
        ]
        for reward in forgeries {
            XCTAssertEqual(AvatarOutfit().equipping(reward, unlockedAchievementIDs: allUnlocks), AvatarOutfit())
        }
    }

    func testBandanaIsTheOnlyHiddenRewardAndCopyKeepsItsRuleSecret() throws {
        let hiddenIDs = Set(AchievementCatalog.all.filter(\.isHidden).map(\.id))
        let hiddenRewards = AvatarRewardCatalog.all.filter { hiddenIDs.contains($0.achievementID) }
        let bandana = try XCTUnwrap(hiddenRewards.first)

        XCTAssertEqual(hiddenRewards.count, 1)
        XCTAssertEqual(bandana.id, "comeback_bandana")
        XCTAssertEqual(bandana.achievementID, "second_wind")
        XCTAssertFalse(bandana.detail.contains("第二天"))
        XCTAssertFalse(bandana.detail.contains("全部"))
        XCTAssertFalse(bandana.detail.contains("错过"))
        XCTAssertFalse(bandana.detail.contains("完成"))
    }
}
