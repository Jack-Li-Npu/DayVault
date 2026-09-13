import Foundation

public enum AvatarSlot: String, Codable, CaseIterable, Sendable {
    case head, outerwear, accessory
}

public struct AvatarReward: Identifiable, Equatable, Sendable {
    public let id: String
    public let slot: AvatarSlot
    public let achievementID: String
    public let name: String
    public let detail: String

    public init(id: String, slot: AvatarSlot, achievementID: String, name: String, detail: String) {
        self.id = id
        self.slot = slot
        self.achievementID = achievementID
        self.name = name
        self.detail = detail
    }
}

public enum AvatarRewardCatalog {
    public static let all: [AvatarReward] = [
        AvatarReward(
            id: "starter_band", slot: .accessory, achievementID: "first_check",
            name: "启程护腕", detail: "首次完成事项时获得。"
        ),
        AvatarReward(
            id: "rhythm_cap", slot: .head, achievementID: "steady_start",
            name: "节奏棒球帽", detail: "连续三个有安排的日子完成事项时获得。"
        ),
        AvatarReward(
            id: "ten_jacket", slot: .outerwear, achievementID: "timekeeper_1",
            name: "十次行动夹克", detail: "累计完成十个事项时获得。"
        ),
        AvatarReward(
            id: "rhythm_varsity", slot: .outerwear, achievementID: "in_rhythm",
            name: "VII 棒球外套", detail: "连续七个有安排的日子完成事项时获得。"
        ),
        AvatarReward(
            id: "month_satchel", slot: .accessory, achievementID: "month_in_motion",
            name: "月行斜挎包", detail: "最近三十天中，二十个日程日期留有完成记录时获得。"
        ),
        AvatarReward(
            id: "comeback_bandana", slot: .head, achievementID: "second_wind",
            name: "回归头巾", detail: "隐藏成就奖励，解锁后可装备。"
        ),
    ]

    public static func reward(for achievementID: String) -> AvatarReward? {
        all.first { $0.achievementID == achievementID }
    }
}

/// Stores appearance only. Ownership comes from permanently unlocked achievements.
public struct AvatarOutfit: Codable, Equatable, Sendable {
    public var head: String?
    public var outerwear: String?
    public var accessory: String?

    public init(head: String? = nil, outerwear: String? = nil, accessory: String? = nil) {
        self.head = head
        self.outerwear = outerwear
        self.accessory = accessory
    }

    public var equippedIDs: Set<String> {
        Set([head, outerwear, accessory].compactMap { $0 })
    }

    public func equipping(_ reward: AvatarReward, unlockedAchievementIDs: Set<String>) -> Self {
        guard AvatarRewardCatalog.all.contains(reward),
              unlockedAchievementIDs.contains(reward.achievementID) else {
            return self
        }
        var outfit = self
        outfit[reward.slot] = reward.id
        return outfit
    }

    public func removing(_ slot: AvatarSlot) -> Self {
        var outfit = self
        outfit[slot] = nil
        return outfit
    }

    /// Use after loading a saved outfit, before presenting or persisting it again.
    public func validated(unlockedAchievementIDs: Set<String>) -> Self {
        var outfit = self
        for slot in AvatarSlot.allCases {
            guard let id = outfit[slot] else { continue }
            let canWear = AvatarRewardCatalog.all.contains {
                $0.id == id && $0.slot == slot && unlockedAchievementIDs.contains($0.achievementID)
            }
            if !canWear { outfit[slot] = nil }
        }
        return outfit
    }

    private subscript(slot: AvatarSlot) -> String? {
        get {
            switch slot {
            case .head: head
            case .outerwear: outerwear
            case .accessory: accessory
            }
        }
        set {
            switch slot {
            case .head: head = newValue
            case .outerwear: outerwear = newValue
            case .accessory: accessory = newValue
            }
        }
    }
}
