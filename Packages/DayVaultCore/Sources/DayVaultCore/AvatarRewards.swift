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
            name: "启程护腕", detail: "第一件装备，留给真正开始行动的你。"
        ),
        AvatarReward(
            id: "rhythm_cap", slot: .head, achievementID: "steady_start",
            name: "节奏棒球帽", detail: "帽檐压低一点，按自己的节奏来。"
        ),
        AvatarReward(
            id: "ten_jacket", slot: .outerwear, achievementID: "timekeeper_1",
            name: "十次行动夹克", detail: "把一次次完成，穿在身上。"
        ),
        AvatarReward(
            id: "rhythm_varsity", slot: .outerwear, achievementID: "in_rhythm",
            name: "VII 棒球外套", detail: "袖口的 VII，是你留下的印记。"
        ),
        AvatarReward(
            id: "month_satchel", slot: .accessory, achievementID: "month_in_motion",
            name: "月行斜挎包", detail: "装上这段时间积累的小事，继续走。"
        ),
        AvatarReward(
            id: "comeback_bandana", slot: .head, achievementID: "second_wind",
            name: "回归头巾", detail: "这件装备，藏着一段只有你知道的故事。"
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
