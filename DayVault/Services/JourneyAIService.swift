import DayVaultCore
import Foundation

enum JourneyAIServiceFactory {
    static var isConfigured: Bool { false }

    static func make() -> any JourneyAI {
        DisabledJourneyAIService()
    }
}

enum JourneyAIServiceError: LocalizedError, Equatable {
    case disabled

    var errorDescription: String? {
        "此版本不提供 AI 功能。已有记录和成就不受影响。"
    }
}

/// No endpoint, credentials or network session are retained by the shipped app.
struct DisabledJourneyAIService: JourneyAI {
    func designAchievements(_ request: JourneyAIRequest) async throws -> JourneyAchievementDesign {
        throw JourneyAIServiceError.disabled
    }

    func companionReply(_ request: JourneyAIRequest) async throws -> JourneyCompanionReply {
        throw JourneyAIServiceError.disabled
    }

    func suggestAdjustment(_ request: JourneyAIRequest) async throws -> JourneyAdjustmentSuggestion {
        throw JourneyAIServiceError.disabled
    }
}
