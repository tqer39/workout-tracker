import XCTest
@testable import WorkoutTracker

final class WorkoutMetricsTests: XCTestCase {
    func test_totalVolume() {
        let volume = WorkoutMetrics.totalVolume(sets: [
            .init(weightKg: 80, reps: 10),
            .init(weightKg: 80, reps: 8),
            .init(weightKg: 60, reps: 12),
        ])
        let expected: Double = 80 * 10 + 80 * 8 + 60 * 12
        XCTAssertEqual(volume, expected, accuracy: 0.001)
    }

    func test_epley_1rm_1rep_returns_weight() throws {
        let value = try XCTUnwrap(WorkoutMetrics.epley1RM(weightKg: 100, reps: 1))
        XCTAssertEqual(value, 100, accuracy: 0.001)
    }

    func test_epley_1rm_formula() throws {
        let value = try XCTUnwrap(WorkoutMetrics.epley1RM(weightKg: 80, reps: 10))
        XCTAssertEqual(value, 80 * (1 + 10.0 / 30.0), accuracy: 0.001)
    }

    func test_epley_rejects_zero_reps() {
        XCTAssertNil(WorkoutMetrics.epley1RM(weightKg: 80, reps: 0))
    }
}
