import XCTest
@testable import WorkoutTracker

final class CompanionLineFilterTests: XCTestCase {
    func test_distanceBand_early() {
        XCTAssertEqual(DistanceBand.from(progress: 0.0), .early)
        XCTAssertEqual(DistanceBand.from(progress: 0.29), .early)
    }

    func test_distanceBand_mid() {
        XCTAssertEqual(DistanceBand.from(progress: 0.30), .mid)
        XCTAssertEqual(DistanceBand.from(progress: 0.69), .mid)
    }

    func test_distanceBand_late() {
        XCTAssertEqual(DistanceBand.from(progress: 0.70), .late)
        XCTAssertEqual(DistanceBand.from(progress: 1.0), .late)
    }

    func test_streakBand_firstDay() {
        XCTAssertEqual(StreakBand.from(streakDays: 0), .firstDay)
        XCTAssertEqual(StreakBand.from(streakDays: 1), .firstDay)
    }

    func test_streakBand_threeDay() {
        XCTAssertEqual(StreakBand.from(streakDays: 3), .threeDay)
        XCTAssertEqual(StreakBand.from(streakDays: 6), .threeDay)
    }

    func test_streakBand_oneWeek() {
        XCTAssertEqual(StreakBand.from(streakDays: 7), .oneWeek)
        XCTAssertEqual(StreakBand.from(streakDays: 29), .oneWeek)
    }

    func test_streakBand_oneMonthPlus() {
        XCTAssertEqual(StreakBand.from(streakDays: 30), .oneMonthPlus)
    }

    func test_filter_matchesWildcardOnNil() {
        let filter = CompanionLineFilter(
            progress: .achieved,
            timeOfDay: .morning,
            streak: .threeDay,
            distance: .mid
        )
        let line = CompanionLine(
            text: "test",
            progress: nil,
            timeOfDay: nil,
            streak: nil,
            distance: nil
        )
        XCTAssertTrue(filter.matches(line))
    }

    func test_filter_rejectsOnExplicitMismatch() {
        let filter = CompanionLineFilter(
            progress: .achieved,
            timeOfDay: .morning,
            streak: .threeDay,
            distance: .mid
        )
        let line = CompanionLine(
            text: "test",
            progress: [.unmet],
            timeOfDay: nil,
            streak: nil,
            distance: nil
        )
        XCTAssertFalse(filter.matches(line))
    }

    func test_filter_acceptsOnArrayContains() {
        let filter = CompanionLineFilter(
            progress: .achieved,
            timeOfDay: .morning,
            streak: .threeDay,
            distance: .mid
        )
        let line = CompanionLine(
            text: "test",
            progress: [.achieved, .completed],
            timeOfDay: [.morning, .day],
            streak: nil,
            distance: nil
        )
        XCTAssertTrue(filter.matches(line))
    }
}
