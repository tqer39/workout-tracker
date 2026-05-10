import XCTest
import SwiftData
@testable import WorkoutTracker

#if DEBUG
@MainActor
final class FixturesTests: XCTestCase {
    func test_Steps_representativeIs1234() {
        XCTAssertEqual(Fixtures.Steps.representative, 1234)
    }

    func test_stepRecord_buildsRecordWithCount() {
        let record = Fixtures.stepRecord(1234, daysAgo: 0)
        XCTAssertEqual(record.steps, 1234)
    }

    func test_stepRecord_daysAgoSetsDate() {
        let todayStart = Calendar.current.startOfDay(for: Date())
        let record = Fixtures.stepRecord(500, daysAgo: 3)
        let diff = todayStart.timeIntervalSince(record.dayStart)
        XCTAssertEqual(diff, 86_400 * 3, accuracy: 1.0)
    }

    func test_achievement_setsCheckpointId() {
        let ach = Fixtures.achievement("tokyo", daysAgo: 1)
        XCTAssertEqual(ach.checkpointId, "tokyo")
        XCTAssertFalse(ach.celebrated)
    }

    func test_bodyMetric_defaultWeight() {
        let metric = Fixtures.bodyMetric()
        XCTAssertEqual(metric.weightKg ?? 0.0, 72.4, accuracy: 0.01)
    }

    func test_varietyWeek_hasSevenDistinctValues() {
        XCTAssertEqual(Fixtures.varietyWeek.count, 7)
        XCTAssertEqual(Set(Fixtures.varietyWeek).count, 7)
    }

    func test_streak4Days_allAboveTypicalGoal() {
        XCTAssertEqual(Fixtures.streak4Days.count, 4)
        XCTAssertTrue(Fixtures.streak4Days.allSatisfy { $0 >= 8000 })
    }

    func test_midJourneyAchievements_returnsFourCheckpoints() {
        let achievements = Fixtures.midJourneyAchievements()
        XCTAssertEqual(achievements.count, 4)
        XCTAssertEqual(achievements.map(\.checkpointId),
                       ["tokyo", "yokohama", "atami", "shizuoka"])
    }

    func test_seededContainer_holdsInsertedRecords() throws {
        let container = try InMemoryContainer.seeded { ctx in
            for (i, n) in Fixtures.varietyWeek.enumerated() {
                ctx.insert(Fixtures.stepRecord(n, daysAgo: i))
            }
        }
        let descriptor = FetchDescriptor<StepDailyRecord>()
        let records = try container.mainContext.fetch(descriptor)
        XCTAssertEqual(records.count, 7)
    }
}
#endif
