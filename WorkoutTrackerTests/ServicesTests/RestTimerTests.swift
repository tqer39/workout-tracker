import XCTest
@testable import WorkoutTracker

final class RestTimerTests: XCTestCase {
    func test_remaining_when_running() {
        let now = Date(timeIntervalSince1970: 1000)
        let timer = RestTimer(now: { now })
        timer.start(duration: 90)
        XCTAssertEqual(timer.remainingSeconds(at: now), 90)
        XCTAssertEqual(timer.remainingSeconds(at: now.addingTimeInterval(30)), 60)
        XCTAssertEqual(timer.remainingSeconds(at: now.addingTimeInterval(100)), 0)
    }

    func test_not_running_when_idle() {
        let timer = RestTimer()
        XCTAssertFalse(timer.isRunning)
    }

    func test_cancel() {
        let timer = RestTimer()
        timer.start(duration: 90)
        XCTAssertTrue(timer.isRunning)
        timer.cancel()
        XCTAssertFalse(timer.isRunning)
    }

    func test_completed_when_elapsed() {
        let now = Date(timeIntervalSince1970: 1000)
        let timer = RestTimer(now: { now })
        timer.start(duration: 60)
        XCTAssertTrue(timer.hasCompleted(at: now.addingTimeInterval(60)))
        XCTAssertFalse(timer.hasCompleted(at: now.addingTimeInterval(59)))
    }
}
