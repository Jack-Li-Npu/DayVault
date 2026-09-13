import DayVaultCore
import Foundation
import SwiftData
import XCTest
@testable import DayVault

final class DayVaultTests: XCTestCase {
    @MainActor
    func testPersonalAchievementDisplayUsesFrozenRuleWithoutRewritingAIText() {
        let rule = PersonalAchievementRule(kind: .activeDays, target: 7, startsAt: .distantPast, timeZoneID: "Asia/Shanghai")
        let definition = PersonalAchievementDefinition(goalID: UUID(), batchID: UUID(), title: "半程灯", detail: "旧模型说明", rule: rule)
        let originalKey = definition.definitionKey
        let originalRule = definition.ruleJSON
        let originalUpdatedAt = definition.updatedAt
        let copy = PersonalAchievementCopy(definition: definition, isUnlocked: false)

        XCTAssertEqual(copy.title, "累计记录 7 天")
        XCTAssertTrue(copy.condition.contains("无需连续"))
        XCTAssertEqual(copy.progressLabel(value: 1), "1 / 7 天")
        XCTAssertEqual(definition.title, "半程灯")
        XCTAssertEqual(definition.detail, "旧模型说明")
        XCTAssertEqual(definition.definitionKey, originalKey)
        XCTAssertEqual(definition.ruleJSON, originalRule)
        XCTAssertEqual(definition.updatedAt, originalUpdatedAt)
    }

    @MainActor
    func testPersonalAchievementCopyDistinguishesCountsDaysAndCycles() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let cases: [(PersonalAchievementRuleKind, Int, String, String)] = [
            (.completionCount, 1, "首次完成", "1 / 1 次"),
            (.completionCount, 7, "完成 7 次", "1 / 7 次"),
            (.activeDays, 1, "首次完成", "1 / 1 天"),
            (.activeDays, 7, "累计记录 7 天", "1 / 7 天"),
            (.completedCycles, 4, "达标 4 个周期", "1 / 4 个周期"),
        ]
        for (kind, target, title, progress) in cases {
            let rule = PersonalAchievementRule(kind: kind, target: target, startsAt: start, timeZoneID: "UTC",
                                              cycleLengthDays: 14, requiredDaysPerCycle: 3, cycleAnchor: start)
            let definition = PersonalAchievementDefinition(goalID: UUID(), batchID: UUID(), title: "模型名称", rule: rule)
            let copy = PersonalAchievementCopy(definition: definition, isUnlocked: true)
            XCTAssertEqual(copy.title, title)
            XCTAssertEqual(copy.progressLabel(value: 1), progress)
            if kind == .completedCycles {
                XCTAssertTrue(copy.condition.contains("每 14 天"))
                XCTAssertTrue(copy.condition.contains("至少 3 天"))
            }
        }
    }

    @MainActor
    func testPersonalAchievementCopyConcealsTitleConditionAndNumericProgress() {
        let rule = PersonalAchievementRule(kind: .completionCount, target: 7, startsAt: .distantPast, timeZoneID: "UTC")
        let definition = PersonalAchievementDefinition(goalID: UUID(), batchID: UUID(), title: "隐藏答案", isHidden: true, rule: rule)
        let locked = PersonalAchievementCopy(definition: definition, isUnlocked: false)
        XCTAssertEqual(locked.title, "隐藏成就")
        XCTAssertEqual(locked.condition, "解锁后显示条件。")
        XCTAssertEqual(locked.progressLabel(value: 5), "")
        XCTAssertEqual(PersonalAchievementCopy(definition: definition, isUnlocked: true).title, "完成 7 次")
    }

    @MainActor
    func testInvalidPersonalRuleDoesNotPromiseSynchronizationOrShowProgress() {
        let rule = PersonalAchievementRule(kind: .completionCount, target: 0, startsAt: .distantPast, timeZoneID: "UTC")
        let definition = PersonalAchievementDefinition(goalID: UUID(), batchID: UUID(), title: "模型名称", rule: rule)
        let copy = PersonalAchievementCopy(definition: definition, isUnlocked: false)
        XCTAssertEqual(copy.title, "个人成就")
        XCTAssertEqual(copy.condition, "成就条件暂不可用。")
        XCTAssertEqual(copy.progressLabel(value: 1), "")
    }

    func testPublicAchievementCopyCoversTheUnchangedCatalog() throws {
        let path = try XCTUnwrap(Bundle.main.path(forResource: "zh-Hans", ofType: "lproj"))
        let strings = try XCTUnwrap(Bundle(path: path))
        XCTAssertEqual(AchievementCatalog.all.count, 24)
        XCTAssertEqual(AchievementCatalog.all.filter(\.isHidden).count, 8)
        var titles = Set<String>()
        for definition in AchievementCatalog.all {
            let title = strings.localizedString(forKey: definition.titleKey, value: nil, table: nil)
            XCTAssertTrue(titles.insert(title).inserted, "Duplicate achievement title: \(definition.id)")
            let keys = [definition.titleKey, definition.descriptionKey] + [definition.clueKey].compactMap { $0 }
            for key in keys {
                let value = strings.localizedString(forKey: key, value: nil, table: nil)
                XCTAssertNotEqual(value, key, "Missing catalog copy: \(key)")
                XCTAssertFalse(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            XCTAssertEqual(definition.version, 1, "A copy edit must not change an achievement rule version")
        }
    }

    func testChineseInterfaceUsesConsistentCategoryAndActionNames() throws {
        let path = try XCTUnwrap(Bundle.main.path(forResource: "zh-Hans", ofType: "lproj"))
        let strings = try XCTUnwrap(Bundle(path: path))
        let expected = [
            "category.focus": "专注", "category.study": "学习",
            "category.care": "健康", "category.rest": "休息",
            "category.personal": "个人事务", "balance.care": "健康",
            "editor.no_category": "未分类", "editor.new_item": "新增事项",
            "editor.what": "事项名称", "editor.when": "计划日期",
            "landing.kicker": "智能排程", "landing.send": "生成计划",
            "tab.insights": "统计", "insights.title": "统计",
        ]
        for (key, label) in expected {
            XCTAssertEqual(strings.localizedString(forKey: key, value: nil, table: nil), label, key)
        }
    }

    @MainActor
    func testInMemoryPersistenceIncludesEveryModel() throws {
        let container = PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        let item = ScheduleItem(title: "Test", plannedStart: Date())

        context.insert(item)
        try context.save()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ScheduleItem>()), 1)
    }

    @MainActor
    func testLocalPersistenceStartsWithoutCloudKit() throws {
        let container = PersistenceController.makeContainer(inMemory: false, cloudKitEnabled: false)
        let context = container.mainContext
        let marker = "local-smoke-\(UUID().uuidString)"
        let item = ScheduleItem(title: marker, plannedStart: Date())
        context.insert(item)

        try context.save()

        let titles = try context.fetch(FetchDescriptor<ScheduleItem>()).map(\.title)
        XCTAssertTrue(titles.contains(marker))
        context.delete(item)
        try context.save()
    }

    func testLocalPlannerAsksOnlyForTheMissingDeadline() async throws {
        let planner = LocalGoalPlanner()
        let request = PlannerRequest(
            goalText: "I want to learn pottery",
            currentDate: Date(timeIntervalSince1970: 1_800_000_000),
            timeZoneID: "UTC",
            locale: "en_US"
        )

        let turn = try await planner.generate(request)

        XCTAssertEqual(turn.kind, .clarification)
        XCTAssertEqual(turn.question, "When would you like to see the result?")
        XCTAssertNil(turn.plan)
    }

    func testLocalPlannerCreatesAValidScheduleFromABlurryGoal() async throws {
        let planner = LocalGoalPlanner()
        let request = PlannerRequest(
            goalText: "I want to read more in two weeks",
            currentDate: Date(timeIntervalSince1970: 1_800_000_000),
            timeZoneID: "UTC",
            locale: "en_US",
            activeChallengeIDs: StarterChallengeCatalog.all.map(\.id)
        )

        let turn = try await planner.generate(request)

        XCTAssertEqual(turn.kind, .plan)
        XCTAssertFalse(try XCTUnwrap(turn.plan).initialBlocks.isEmpty)
        XCTAssertEqual(turn.plan?.recommendedChallengeID, StarterChallengeCatalog.readingTrailID)
        XCTAssertNoThrow(try GeneratedPlanValidator.validate(turn, for: request))
    }

    func testLocalResultCannotClaimItUsedAIOrTheSkill() async throws {
        let service = HybridAIPlannerService(endpoint: nil, publishableKey: nil, accessToken: nil) { _ in
            XCTFail("A local preview must not make a network request")
            throw URLError(.badURL)
        }
        let result = try await service.generateResult(PlannerRequest(goalText: "6周后上台演讲"))
        XCTAssertEqual(result.source, .localDemo)
        XCTAssertEqual(result.turn.kind, .plan)
    }

    func testRemoteResultUsesServerMetadataNotModelAuthoredVersion() async throws {
        let endpoint = try XCTUnwrap(URL(string: "https://example.com/planner"))
        let service = HybridAIPlannerService(endpoint: endpoint, publishableKey: nil, accessToken: nil) { request in
            XCTAssertEqual(request.timeoutInterval, 150)
            let data = Data(#"{"kind":"clarification","question":"你想给谁演讲？","plan":null}"#.utf8)
            let response = HTTPURLResponse(url: endpoint, statusCode: 200, httpVersion: nil, headerFields: [
                "X-DayVault-Model": "example-model", "X-DayVault-Skill-Version": "1.1.0"
            ])!
            return (data, response)
        }
        let result = try await service.generateResult(PlannerRequest(goalText: "6周后上台演讲"))
        XCTAssertEqual(result.source, .remote(model: "example-model", skillVersion: "1.1.0"))
        XCTAssertEqual(result.turn.question, "你想给谁演讲？")
    }

    func testRemoteFailureNeverFallsBackToAFakeAIPlan() async throws {
        let endpoint = try XCTUnwrap(URL(string: "http://localhost:8000"))
        let service = HybridAIPlannerService(endpoint: endpoint, publishableKey: nil, accessToken: nil) { _ in
            throw URLError(.cannotConnectToHost)
        }
        do {
            _ = try await service.generateResult(PlannerRequest(goalText: "6周后上台演讲"))
            XCTFail("A configured but unavailable server must not produce a demo")
        } catch let error as AIPlannerServiceError {
            XCTAssertEqual(error, .connectionFailure(isLocal: true, code: URLError.cannotConnectToHost.rawValue))
        }
    }

    func testRemoteIncompleteResponseDoesNotBecomeADraft() async throws {
        let endpoint = try XCTUnwrap(URL(string: "https://example.com/planner"))
        let service = HybridAIPlannerService(endpoint: endpoint, publishableKey: nil, accessToken: nil) { _ in
            (Data(#"{"error":"incomplete_output"}"#.utf8), HTTPURLResponse(url: endpoint, statusCode: 502, httpVersion: nil, headerFields: nil)!)
        }
        do {
            _ = try await service.generateResult(PlannerRequest(goalText: "6周后上台演讲"))
            XCTFail("Incomplete output must be rejected")
        } catch AIPlannerServiceError.invalidResponse { }
    }

    func testLegacyLocalEndpointUsesIPv4WithoutChangingPathOrRemoteURLs() throws {
        for host in ["localhost", "LOCALHOST", "[::1]"] {
            let old = try XCTUnwrap(URL(string: "http://\(host):8000/generate-plan?test=1"))
            XCTAssertEqual(DayVaultAIEndpoint.normalized(old).absoluteString, "http://127.0.0.1:8000/generate-plan?test=1")
        }
        for address in ["https://example.com/planner", "https://localhost:8000/", "http://localhost:9000/"] {
            let url = try XCTUnwrap(URL(string: address))
            XCTAssertEqual(DayVaultAIEndpoint.normalized(url), url)
        }
    }

    func testActualRequestNormalizesOldSettingsAndSeparatesClientTimeout() async throws {
        let service = HybridAIPlannerService(endpoint: URL(string: "http://localhost:8000"), publishableKey: nil, accessToken: nil) { request in
            XCTAssertEqual(request.url?.host, "127.0.0.1")
            throw URLError(.timedOut)
        }
        do {
            _ = try await service.generateResult(PlannerRequest(goalText: "6天完成英语演讲准备"))
            XCTFail("Expected timeout, not a local demo")
        } catch let error as AIPlannerServiceError { XCTAssertEqual(error, .requestTimedOut) }
    }

    func testUpstreamFailuresKeepTheirLayerAndSafeStatusCode() async throws {
        let endpoint = try XCTUnwrap(URL(string: "http://127.0.0.1:8000"))
        let cases: [(String, AIPlannerServiceError)] = [
            (#"{"error":"provider_timeout","upstreamStatus":504}"#, .providerTimeout(status: 504)),
            (#"{"error":"provider_unavailable","upstreamStatus":503}"#, .providerUnavailable(status: 503)),
            (#"{"error":"provider_timeout"}"#, .providerTimeout(status: nil)),
        ]
        for (json, expected) in cases {
            let service = HybridAIPlannerService(endpoint: endpoint, publishableKey: nil, accessToken: nil) { _ in
                (Data(json.utf8), HTTPURLResponse(url: endpoint, statusCode: 502, httpVersion: nil, headerFields: nil)!)
            }
            do {
                _ = try await service.generateResult(PlannerRequest(goalText: "6天完成英语演讲准备"))
                XCTFail("Expected an upstream error, not a draft")
            } catch let error as AIPlannerServiceError { XCTAssertEqual(error, expected) }
        }
    }

    func testCancellationIsNotReportedAsAConnectionFailure() async throws {
        let service = HybridAIPlannerService(endpoint: URL(string: "http://localhost:8000"), publishableKey: nil, accessToken: nil) { _ in
            throw URLError(.cancelled)
        }
        do {
            _ = try await service.generateResult(PlannerRequest(goalText: "6天完成英语演讲准备"))
            XCTFail("Expected cancellation")
        } catch let error as URLError { XCTAssertEqual(error.code, .cancelled) }
    }

    func testRetryCanRecoverWithoutFallingBackToLocalTemplate() async throws {
        actor Attempts {
            var count = 0
            func next() -> Int { count += 1; return count }
        }
        let attempts = Attempts()
        let endpoint = try XCTUnwrap(URL(string: "http://localhost:8000"))
        let service = HybridAIPlannerService(endpoint: endpoint, publishableKey: nil, accessToken: nil) { request in
            XCTAssertEqual(request.url?.host, "127.0.0.1")
            if await attempts.next() == 1 { throw URLError(.cannotConnectToHost) }
            return (Data(#"{"kind":"clarification","question":"演讲需要多长时间？","plan":null}"#.utf8), HTTPURLResponse(url: endpoint, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        let request = PlannerRequest(goalText: "6天完成英语演讲准备")
        do { _ = try await service.generateResult(request); XCTFail("First attempt must fail") }
        catch is AIPlannerServiceError { }
        let retry = try await service.generateResult(request)
        XCTAssertEqual(retry.turn.question, "演讲需要多长时间？")
        XCTAssertEqual(retry.source, .remote(model: nil, skillVersion: nil))
    }
}
