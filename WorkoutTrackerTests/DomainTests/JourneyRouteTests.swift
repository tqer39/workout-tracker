import XCTest
@testable import WorkoutTracker

final class JourneyRouteTests: XCTestCase {
    func test_has_thirteen_checkpoints() {
        XCTAssertEqual(JourneyRoute.tokyoToHakata.count, 13)
    }

    func test_first_is_tokyo_last_is_hakata() {
        let route = JourneyRoute.tokyoToHakata
        XCTAssertEqual(route.first?.id, "tokyo")
        XCTAssertEqual(route.first?.cumulativeKm, 0)
        XCTAssertEqual(route.last?.id, "hakata")
        XCTAssertEqual(route.last?.cumulativeKm, 1150)
    }

    func test_cumulative_km_strictly_increasing() {
        let route = JourneyRoute.tokyoToHakata
        for (a, b) in zip(route, route.dropFirst()) {
            XCTAssertLessThan(a.cumulativeKm, b.cumulativeKm,
                              "\(a.id) < \(b.id) でなければならない")
        }
    }

    func test_map_position_within_unit_box() {
        for cp in JourneyRoute.tokyoToHakata {
            XCTAssertGreaterThanOrEqual(cp.mapPosition.x, 0)
            XCTAssertLessThanOrEqual(cp.mapPosition.x, 1)
            XCTAssertGreaterThanOrEqual(cp.mapPosition.y, 0)
            XCTAssertLessThanOrEqual(cp.mapPosition.y, 1)
        }
    }

    func test_blurb_non_empty() {
        for cp in JourneyRoute.tokyoToHakata {
            XCTAssertFalse(cp.blurb.isEmpty, "\(cp.id) の紹介文が空")
        }
    }
}
