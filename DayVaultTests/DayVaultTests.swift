import DayVaultCore
import Foundation
import SwiftData
import XCTest
@testable import DayVault

final class DayVaultTests: XCTestCase {
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
}
