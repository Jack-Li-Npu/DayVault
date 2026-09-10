import DayVaultCore
import Foundation

enum JourneyAIServiceFactory {
    static var isConfigured: Bool { endpoint != nil }

    static func make() -> any JourneyAI {
        let environment = ProcessInfo.processInfo.environment
        let defaults = UserDefaults.standard
        return RemoteJourneyAIService(
            endpoint: endpoint,
            publishableKey: environment["DAYVAULT_SUPABASE_KEY"] ?? defaults.string(forKey: "aiPlannerPublishableKey"),
            accessToken: environment["DAYVAULT_SUPABASE_ACCESS_TOKEN"] ?? defaults.string(forKey: "aiPlannerAccessToken")
        )
    }

    private static var endpoint: URL? {
        let value = ProcessInfo.processInfo.environment["DAYVAULT_AI_ENDPOINT"] ?? UserDefaults.standard.string(forKey: "aiPlannerEndpoint")
        guard let value, let url = URL(string: value), url.user == nil, url.password == nil else { return nil }
        if url.scheme == "https", url.host != nil { return url }
#if DEBUG
        if url.scheme == "http", ["localhost", "127.0.0.1", "[::1]"].contains(url.host ?? "") { return url }
#endif
        return nil
    }
}

enum JourneyAIServiceError: LocalizedError {
    case unavailable, invalidResponse, authentication, rateLimited, unsupportedModel, server
    var errorDescription: String? {
        switch self {
        case .unavailable: "AI 还没有连接。连接测试服务后，可以再试一次。"
        case .invalidResponse: "这次回复不符合要求，没有保存任何修改。可以重试。"
        case .authentication: "AI 服务验证失败。请检查连接设置后重试。"
        case .rateLimited: "AI 服务暂时繁忙。请稍后再试。"
        case .unsupportedModel: "当前服务暂不支持已选择的模型。请检查服务配置。"
        case .server: "暂时没有收到 AI 回复。你的记录没有改变，可以稍后再试。"
        }
    }
}

actor RemoteJourneyAIService: JourneyAI {
    private let endpoint: URL?
    private let publishableKey: String?
    private let accessToken: String?
    private let session: URLSession

    init(endpoint: URL?, publishableKey: String? = nil, accessToken: String? = nil, session: URLSession = .shared) {
        self.endpoint = endpoint; self.publishableKey = publishableKey; self.accessToken = accessToken; self.session = session
    }

    func designAchievements(_ request: JourneyAIRequest) async throws -> JourneyAchievementDesign {
        try JourneyAIValidator.validateRequest(request, operation: .designAchievements)
        let result: JourneyAchievementDesign = try await send(request)
        try JourneyAIValidator.validate(result, for: request)
        return result
    }

    func companionReply(_ request: JourneyAIRequest) async throws -> JourneyCompanionReply {
        try JourneyAIValidator.validateRequest(request, operation: .companionReply)
        let result: JourneyCompanionReply = try await send(request)
        try JourneyAIValidator.validate(result, for: request)
        return result
    }

    func suggestAdjustment(_ request: JourneyAIRequest) async throws -> JourneyAdjustmentSuggestion {
        try JourneyAIValidator.validateRequest(request, operation: .suggestAdjustment)
        let result: JourneyAdjustmentSuggestion = try await send(request)
        try JourneyAIValidator.validate(result, for: request)
        return result
    }

    private func send<Result: Decodable>(_ request: JourneyAIRequest) async throws -> Result {
        guard let endpoint else { throw JourneyAIServiceError.unavailable }
        var outbound = URLRequest(url: endpoint)
        outbound.httpMethod = "POST"
        outbound.timeoutInterval = 60
        outbound.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let publishableKey, !publishableKey.isEmpty { outbound.setValue(publishableKey, forHTTPHeaderField: "apikey") }
        if let accessToken, !accessToken.isEmpty { outbound.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization") }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        outbound.httpBody = try encoder.encode(request)
        let (data, response) = try await session.data(for: outbound)
        guard let http = response as? HTTPURLResponse else { throw JourneyAIServiceError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let code = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            switch code {
            case "authentication_required", "provider_authentication_failed": throw JourneyAIServiceError.authentication
            case "provider_rate_limited": throw JourneyAIServiceError.rateLimited
            case "model_not_supported": throw JourneyAIServiceError.unsupportedModel
            default: throw JourneyAIServiceError.server
            }
        }
        guard data.count <= 128_000 else { throw JourneyAIServiceError.invalidResponse }
        try validateResponseKeys(data, operation: request.operation)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer().decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: value) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: value) else { throw JourneyAIServiceError.invalidResponse }
            return date
        }
        do { return try decoder.decode(Result.self, from: data) }
        catch { throw JourneyAIServiceError.invalidResponse }
    }

    private func validateResponseKeys(_ data: Data, operation: JourneyAIOperation) throws {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw JourneyAIServiceError.invalidResponse }
        let keys: Set<String>
        switch operation {
        case .designAchievements:
            keys = ["skillVersion", "goalID", "achievements"]
            guard let items = object["achievements"] as? [[String: Any]], items.allSatisfy({ Set($0.keys) == ["id", "name", "detail", "ruleType", "target", "isHidden", "clue", "badgeStyleKey", "sourceIDs"] }) else { throw JourneyAIServiceError.invalidResponse }
        case .companionReply: keys = ["skillVersion", "goalID", "text", "sourceIDs", "memoryCandidate"]
        case .suggestAdjustment:
            keys = ["skillVersion", "goalID", "summary", "changes", "sourceIDs"]
            guard let changes = object["changes"] as? [[String: Any]], changes.allSatisfy({ Set($0.keys) == ["occurrenceID", "newStart"] }) else { throw JourneyAIServiceError.invalidResponse }
        }
        guard Set(object.keys) == keys else { throw JourneyAIServiceError.invalidResponse }
    }
}
