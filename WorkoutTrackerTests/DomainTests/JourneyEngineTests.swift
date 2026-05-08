import XCTest
@testable import WorkoutTracker

final class JourneyEngineTests: XCTestCase {
    private let route = JourneyRoute.tokyoToHakata

    func test_zero_steps_at_origin() {
        let p = JourneyEngine.computeProgress(totalSteps: 0, route: route)
        XCTAssertEqual(p.totalKm, 0, accuracy: 0.001)
        XCTAssertEqual(p.progressRatio, 0, accuracy: 0.001)
        XCTAssertEqual(p.lastPassedCheckpoint?.id, "tokyo")
        XCTAssertEqual(p.nextCheckpoint?.id, "yokohama")
        XCTAssertEqual(p.metersToNext, 30_000, accuracy: 0.001)
        XCTAssertFalse(p.isCompleted)
    }

    func test_just_before_checkpoint() {
        let steps = 29_999
        let p = JourneyEngine.computeProgress(totalSteps: steps, route: route)
        XCTAssertEqual(p.lastPassedCheckpoint?.id, "tokyo")
        XCTAssertEqual(p.nextCheckpoint?.id, "yokohama")
    }

    func test_at_checkpoint_boundary() {
        let p = JourneyEngine.computeProgress(totalSteps: 30_000, route: route)
        XCTAssertEqual(p.lastPassedCheckpoint?.id, "yokohama")
        XCTAssertEqual(p.nextCheckpoint?.id, "atami")
    }

    func test_mid_journey() {
        let p = JourneyEngine.computeProgress(totalSteps: 575_000, route: route)
        XCTAssertEqual(p.lastPassedCheckpoint?.id, "osaka")
        XCTAssertEqual(p.nextCheckpoint?.id, "kobe")
        XCTAssertEqual(p.totalKm, 575, accuracy: 0.001)
        XCTAssertEqual(p.progressRatio, 575.0 / 1150.0, accuracy: 0.001)
    }

    func test_completed_at_finish() {
        let p = JourneyEngine.computeProgress(totalSteps: 1_150_000, route: route)
        XCTAssertTrue(p.isCompleted)
        XCTAssertEqual(p.lastPassedCheckpoint?.id, "hakata")
        XCTAssertNil(p.nextCheckpoint)
        XCTAssertEqual(p.progressRatio, 1.0, accuracy: 0.001)
    }

    func test_overshoot_clamps_to_completed() {
        let p = JourneyEngine.computeProgress(totalSteps: 9_999_999, route: route)
        XCTAssertTrue(p.isCompleted)
        XCTAssertEqual(p.progressRatio, 1.0, accuracy: 0.001)
        XCTAssertEqual(p.lastPassedCheckpoint?.id, "hakata")
    }

    func test_meters_per_step_two() {
        let p = JourneyEngine.computeProgress(totalSteps: 15_000, route: route, metersPerStep: 2.0)
        XCTAssertEqual(p.totalKm, 30, accuracy: 0.001)
        XCTAssertEqual(p.lastPassedCheckpoint?.id, "yokohama")
    }

    func test_passed_set_initial() {
        let ids = JourneyEngine.passedCheckpointIds(totalSteps: 0, route: route)
        XCTAssertEqual(ids, ["tokyo"])
    }

    func test_passed_set_three_cities() {
        let ids = JourneyEngine.passedCheckpointIds(totalSteps: 180_000, route: route)
        XCTAssertEqual(ids, ["tokyo", "yokohama", "atami", "shizuoka"])
    }

    func test_passed_set_completed() {
        let ids = JourneyEngine.passedCheckpointIds(totalSteps: 1_200_000, route: route)
        XCTAssertEqual(ids.count, 13)
    }
}
