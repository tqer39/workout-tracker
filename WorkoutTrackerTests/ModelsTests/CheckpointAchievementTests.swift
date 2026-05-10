import XCTest
import SwiftData
@testable import WorkoutTracker

final class CheckpointAchievementTests: XCTestCase {
    @MainActor
    func test_insert_and_celebration_flag_default() throws {
        let container = try InMemoryContainer.make()
        let ctx = container.mainContext

        ctx.insert(CheckpointAchievement(
            checkpointId: "yokohama",
            achievedAt: Date(),
            totalStepsAtAchievement: 30_000
        ))
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<CheckpointAchievement>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.checkpointId, "yokohama")
        XCTAssertEqual(fetched.first?.celebrated, false)
    }

    @MainActor
    func test_checkpointId_unique() throws {
        let container = try InMemoryContainer.make()
        let ctx = container.mainContext

        ctx.insert(CheckpointAchievement(
            checkpointId: "tokyo", achievedAt: Date(), totalStepsAtAchievement: 0
        ))
        try ctx.save()
        ctx.insert(CheckpointAchievement(
            checkpointId: "tokyo", achievedAt: Date(), totalStepsAtAchievement: 100
        ))
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<CheckpointAchievement>())
        XCTAssertEqual(fetched.count, 1)
    }

    @MainActor
    func test_midJourneyAchievements_persistsInOrder() throws {
        let container = try InMemoryContainer.seeded { ctx in
            Fixtures.midJourneyAchievements().forEach { ctx.insert($0) }
        }
        let descriptor = FetchDescriptor<CheckpointAchievement>(
            sortBy: [SortDescriptor(\.achievedAt, order: .forward)]
        )
        let achievements = try container.mainContext.fetch(descriptor)
        XCTAssertEqual(achievements.count, 4)
        XCTAssertEqual(achievements.first?.checkpointId, "tokyo")
        XCTAssertEqual(achievements.last?.checkpointId, "shizuoka")
    }
}
