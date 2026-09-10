import DayVaultCore
import Foundation

enum AIPlannerServiceFactory {
    static var isRemoteConfigured: Bool {
        let environment = ProcessInfo.processInfo.environment
        let endpointText = environment["DAYVAULT_AI_ENDPOINT"] ?? UserDefaults.standard.string(forKey: "aiPlannerEndpoint")
        return endpointText.flatMap(URL.init(string:)) != nil
    }

    static func make() -> any AIPlanning {
        let environment = ProcessInfo.processInfo.environment
        let defaults = UserDefaults.standard
        let endpointText = environment["DAYVAULT_AI_ENDPOINT"] ?? defaults.string(forKey: "aiPlannerEndpoint")
        let publishableKey = environment["DAYVAULT_SUPABASE_KEY"] ?? defaults.string(forKey: "aiPlannerPublishableKey")
        let accessToken = environment["DAYVAULT_SUPABASE_ACCESS_TOKEN"] ?? defaults.string(forKey: "aiPlannerAccessToken")
        let endpoint = endpointText.flatMap(URL.init(string:))
        return HybridAIPlannerService(endpoint: endpoint, publishableKey: publishableKey, accessToken: accessToken)
    }
}

enum AIPlannerServiceError: LocalizedError {
    case invalidResponse
    case providerAuthenticationFailed
    case providerRateLimited
    case unsupportedModel
    case server(status: Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            String(localized: "ai.error.invalid_response")
        case .providerAuthenticationFailed:
            String(localized: "ai.error.provider_authentication")
        case .providerRateLimited:
            String(localized: "ai.error.provider_rate_limited")
        case .unsupportedModel:
            String(localized: "ai.error.model_unsupported")
        case let .server(status):
            String(format: String(localized: "ai.error.server"), status)
        }
    }
}

actor HybridAIPlannerService: AIPlanning {
    private let endpoint: URL?
    private let publishableKey: String?
    private let accessToken: String?
    private let localPlanner = LocalGoalPlanner()

    init(endpoint: URL?, publishableKey: String?, accessToken: String?) {
        self.endpoint = endpoint
        self.publishableKey = publishableKey
        self.accessToken = accessToken
    }

    func generate(_ request: PlannerRequest) async throws -> PlannerTurn {
        guard let endpoint else {
            try await Task.sleep(for: .milliseconds(850))
            return try await localPlanner.generate(request)
        }

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 60
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let publishableKey, !publishableKey.isEmpty {
            urlRequest.setValue(publishableKey, forHTTPHeaderField: "apikey")
        }
        if let accessToken, !accessToken.isEmpty {
            urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else { throw AIPlannerServiceError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            if let envelope = try? JSONDecoder().decode(AIPlannerErrorEnvelope.self, from: data) {
                switch envelope.error {
                case "provider_authentication_failed":
                    throw AIPlannerServiceError.providerAuthenticationFailed
                case "provider_rate_limited":
                    throw AIPlannerServiceError.providerRateLimited
                case "model_not_supported":
                    throw AIPlannerServiceError.unsupportedModel
                default:
                    break
                }
            }
            throw AIPlannerServiceError.server(status: http.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let turn = try decoder.decode(PlannerTurn.self, from: data)
        try GeneratedPlanValidator.validate(turn, for: request)
        return turn
    }
}

private struct AIPlannerErrorEnvelope: Decodable {
    let error: String
}

actor LocalGoalPlanner: AIPlanning {
    func generate(_ request: PlannerRequest) async throws -> PlannerTurn {
        let language = request.locale.lowercased().hasPrefix("zh") ? Language.chinese : .english
        let combined = [request.goalText, request.clarificationAnswer].compactMap { $0 }.joined(separator: " ")
        guard let inferred = Self.inferDeadline(from: combined, relativeTo: request.currentDate) else {
            return .clarification(language == .chinese ? "你希望什么时候看到成果？" : "When would you like to see the result?")
        }

        let calendar = Self.calendar(timeZoneID: request.timeZoneID)
        let deadline = max(inferred, request.currentDate.addingTimeInterval(3_600))
        let dayCount = max(1, min(180, calendar.dateComponents([.day], from: request.currentDate, to: deadline).day ?? 1))
        let title = Self.cleanTitle(request.goalText, language: language)
        let phases = Self.makePhases(title: title, start: request.currentDate, deadline: deadline, dayCount: dayCount, language: language, calendar: calendar)
        let milestones = phases.map { phase in
            PlanMilestone(
                title: language == .chinese ? "完成：\(phase.title)" : "Finish: \(phase.title)",
                due: phase.end,
                definitionOfDone: phase.summary
            )
        }
        let blocks = Self.makeBlocks(
            title: title,
            phases: phases,
            start: request.currentDate,
            deadline: deadline,
            dayCount: dayCount,
            busyWindows: request.busyWindows,
            existingLoads: request.existingDailyLoads,
            language: language,
            calendar: calendar
        )
        let challengeID = Self.challengeID(for: request.goalText, allowed: request.activeChallengeIDs)
        let patterns = dayCount > 14 ? [GeneratedPlanPattern(
            title: language == .chinese ? "继续推进 \(title)" : "Keep moving \(title) forward",
            weekdays: [2, 4, 6],
            startMinutesFromMidnight: 19 * 60,
            durationMinutes: 45,
            endDate: deadline,
            balanceGroup: .focus
        )] : []
        let plan = GeneratedProjectPlan(
            title: title,
            clarifiedGoal: language == .chinese ? "在 \(deadline.formatted(date: .abbreviated, time: .omitted)) 前完成：\(title)" : "Make meaningful progress on \(title) by \(deadline.formatted(date: .abbreviated, time: .omitted)).",
            deadline: deadline,
            phases: phases,
            milestones: milestones,
            initialBlocks: blocks,
            recurringPatterns: patterns,
            recommendedChallengeID: challengeID,
            assumptions: [
                language == .chinese ? "先按每天 09:00–21:00 的可用时间安排。" : "I used a conservative 9 AM–9 PM availability window.",
                language == .chinese ? "未来两周先安排具体行动，之后按节奏继续。" : "The next two weeks are concrete; later work follows a repeatable rhythm.",
            ],
            warnings: blocks.isEmpty ? [language == .chinese ? "目前没有找到可用时间，请调整期限或日历。" : "I couldn't find free time. Try a later deadline or a lighter calendar."] : []
        )
        let turn = PlannerTurn.plan(plan)
        try GeneratedPlanValidator.validate(turn, for: request)
        return turn
    }

    private enum Language { case english, chinese }

    private static func calendar(timeZoneID: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneID) ?? .current
        return calendar
    }

    private static func inferDeadline(from text: String, relativeTo now: Date) -> Date? {
        let normalized = text.lowercased()
        let calendar = Calendar.current
        if normalized.contains("today") || normalized.contains("今天") {
            return calendar.date(bySettingHour: 21, minute: 0, second: 0, of: now)
        }
        if normalized.contains("tomorrow") || normalized.contains("明天") || normalized.contains("明晚") {
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now.addingTimeInterval(86_400)
            return calendar.date(bySettingHour: 21, minute: 0, second: 0, of: tomorrow)
        }
        if normalized.contains("this week") || normalized.contains("这周") || normalized.contains("本周") {
            return calendar.date(byAdding: .day, value: 7, to: now)
        }
        if normalized.contains("next week") || normalized.contains("下周") {
            return calendar.date(byAdding: .day, value: 10, to: now)
        }
        if normalized.contains("next month") || normalized.contains("下个月") {
            return calendar.date(byAdding: .month, value: 1, to: now)
        }
        if normalized.contains("end of this month") || normalized.contains("月底") {
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: now) ?? now
            return calendar.date(byAdding: .day, value: -1, to: calendar.date(from: calendar.dateComponents([.year, .month], from: nextMonth)) ?? nextMonth)
        }
        if normalized.contains("christmas") || normalized.contains("圣诞") {
            let year = calendar.component(.year, from: now)
            let thisYear = calendar.date(from: DateComponents(year: year, month: 12, day: 25, hour: 21)) ?? now
            return thisYear > now ? thisYear : calendar.date(byAdding: .year, value: 1, to: thisYear)
        }
        if let amount = relativeAmount(in: normalized, units: ["day", "days", "天"]) {
            return calendar.date(byAdding: .day, value: amount, to: now)
        }
        if let amount = relativeAmount(in: normalized, units: ["week", "weeks", "weekend", "weekends", "周", "星期"]) {
            return calendar.date(byAdding: .day, value: amount * 7, to: now)
        }
        if let amount = relativeAmount(in: normalized, units: ["month", "months", "个月", "月"]) {
            return calendar.date(byAdding: .month, value: amount, to: now)
        }
        return parseNamedMonthDay(normalized, relativeTo: now) ?? parseNamedWeekday(normalized, relativeTo: now)
    }

    private static func relativeAmount(in text: String, units: [String]) -> Int? {
        let chineseNumbers = ["一": 1, "两": 2, "二": 2, "三": 3, "四": 4, "五": 5, "六": 6, "七": 7, "八": 8, "九": 9, "十": 10]
        for unit in units {
            let escaped = NSRegularExpression.escapedPattern(for: unit)
            let pattern = "(?:in\\s+)?(\\d+|one|two|three|four|five|six|一|两|二|三|四|五|六|七|八|九|十)[-\\s]*(?:个)?\(escaped)"
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                  let range = Range(match.range(at: 1), in: text) else { continue }
            let token = String(text[range])
            let english = ["one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6]
            return Int(token) ?? english[token] ?? chineseNumbers[token]
        }
        return nil
    }

    private static func parseNamedMonthDay(_ text: String, relativeTo now: Date) -> Date? {
        let calendar = Calendar.current
        let months = [
            "january": 1, "february": 2, "march": 3, "april": 4, "may": 5, "june": 6,
            "july": 7, "august": 8, "september": 9, "october": 10, "november": 11, "december": 12,
        ]
        for (name, month) in months where text.contains(name) {
            let pattern = "\(name)\\s+(\\d{1,2})"
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                  let range = Range(match.range(at: 1), in: text),
                  let day = Int(text[range]) else { continue }
            var year = calendar.component(.year, from: now)
            var result = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 21))
            if let value = result, value <= now {
                year += 1
                result = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 21))
            }
            return result
        }
        return nil
    }

    private static func parseNamedWeekday(_ text: String, relativeTo now: Date) -> Date? {
        let calendar = Calendar.current
        let names = ["sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4, "thursday": 5, "friday": 6, "saturday": 7]
        guard let weekday = names.first(where: { text.contains($0.key) })?.value else { return nil }
        return calendar.nextDate(
            after: now,
            matching: DateComponents(hour: 21, weekday: weekday),
            matchingPolicy: .nextTime
        )
    }

    private static func cleanTitle(_ goal: String, language: Language) -> String {
        let trimmed = goal.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 44 { return trimmed }
        let end = trimmed.index(trimmed.startIndex, offsetBy: 44)
        return String(trimmed[..<end]) + (language == .chinese ? "…" : "…")
    }

    private static func makePhases(title: String, start: Date, deadline: Date, dayCount: Int, language: Language, calendar: Calendar) -> [PlanPhase] {
        let count = dayCount <= 7 ? 2 : dayCount <= 30 ? 3 : 4
        let english = [("Find the shape", "Define what done looks like and gather what you need."), ("Build the core", "Complete the most important working pieces."), ("Practice and refine", "Test the work, repeat, and fix weak spots."), ("Finish calmly", "Review the result and leave time for final changes.")]
        let chinese = [("理清方向", "明确完成标准，准备需要的材料。"), ("完成核心", "先做最重要、最能推进结果的部分。"), ("练习与调整", "通过练习或测试找出薄弱点并修正。"), ("从容收尾", "检查成果，并为最后修改留出时间。")]
        let copy = language == .chinese ? chinese : english
        return (0..<count).map { index in
            let phaseStart = calendar.date(byAdding: .day, value: dayCount * index / count, to: start) ?? start
            let phaseEnd = index == count - 1 ? deadline : (calendar.date(byAdding: .day, value: dayCount * (index + 1) / count, to: start) ?? deadline)
            return PlanPhase(title: copy[index].0, summary: copy[index].1, start: phaseStart, end: phaseEnd)
        }
    }

    private static func makeBlocks(
        title: String,
        phases: [PlanPhase],
        start: Date,
        deadline: Date,
        dayCount: Int,
        busyWindows: [PlannerBusyWindow],
        existingLoads: [PlannerDailyLoad],
        language: Language,
        calendar: Calendar
    ) -> [GeneratedPlanBlock] {
        let loadedDays = Dictionary(uniqueKeysWithValues: existingLoads.map { (calendar.startOfDay(for: $0.day), $0.scheduledMinutes) })
        var blocks: [GeneratedPlanBlock] = []
        for offset in 0..<min(14, dayCount + 1) where offset % 2 == 0 || dayCount <= 4 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: start)),
                  (loadedDays[day] ?? 0) < 360 else { continue }
            let phase = phases.last(where: { $0.start <= day }) ?? phases[0]
            let action = language == .chinese ? "推进：\(phase.title)" : "Move forward: \(phase.title)"
            guard let blockStart = freeStart(on: day, after: start, deadline: deadline, duration: 45, busyWindows: busyWindows, calendar: calendar) else { continue }
            blocks.append(GeneratedPlanBlock(title: action, start: blockStart, durationMinutes: 45, notes: title, balanceGroup: .focus))
        }
        return blocks
    }

    private static func freeStart(on day: Date, after now: Date, deadline: Date, duration: Int, busyWindows: [PlannerBusyWindow], calendar: Calendar) -> Date? {
        for hour in [19, 9, 14, 16, 20] {
            guard let start = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) else { continue }
            let end = start.addingTimeInterval(TimeInterval(duration * 60))
            if start < now.addingTimeInterval(1_800) || end > deadline { continue }
            if busyWindows.contains(where: { $0.start < end && $0.end > start }) { continue }
            return start
        }
        return nil
    }

    private static func challengeID(for goal: String, allowed: [UUID]) -> UUID? {
        let normalized = goal.lowercased()
        let preferred: UUID
        if normalized.contains("read") || normalized.contains("book") || normalized.contains("读") || normalized.contains("书") {
            preferred = StarterChallengeCatalog.readingTrailID
        } else if normalized.contains("start") || normalized.contains("habit") || normalized.contains("开始") || normalized.contains("习惯") {
            preferred = StarterChallengeCatalog.smallWinsID
        } else {
            preferred = StarterChallengeCatalog.focusSprintID
        }
        return allowed.contains(preferred) ? preferred : allowed.first
    }
}
