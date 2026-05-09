import XCTest
@testable import WorkoutTracker

@MainActor
final class AppRouterTests: XCTestCase {
    func test_initial_state_is_home_and_no_pending() {
        let router = AppRouter()
        XCTAssertEqual(router.selectedTab, .home)
        XCTAssertNil(router.pendingStart)
    }

    func test_requestStart_template_sets_pending_and_switches_tab() {
        let router = AppRouter()
        let id = UUID()
        router.requestStart(template: id)
        XCTAssertEqual(router.pendingStart, .template(id))
        XCTAssertEqual(router.selectedTab, .recording)
    }

    func test_requestStartEmpty_sets_pending_and_switches_tab() {
        let router = AppRouter()
        router.requestStartEmpty()
        XCTAssertEqual(router.pendingStart, .empty)
        XCTAssertEqual(router.selectedTab, .recording)
    }

    func test_consumePendingStart_returns_value_and_clears() {
        let router = AppRouter()
        let id = UUID()
        router.requestStart(template: id)

        let consumed = router.consumePendingStart()
        XCTAssertEqual(consumed, .template(id))
        XCTAssertNil(router.pendingStart)

        let consumedAgain = router.consumePendingStart()
        XCTAssertNil(consumedAgain)
    }
}
