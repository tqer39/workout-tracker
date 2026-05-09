import XCTest
@testable import WorkoutTracker

#if DEBUG
final class DateHelpersTests: XCTestCase {
    func test_daysAgo_returnsDateInPast() {
        let now = Date(timeIntervalSince1970: 1_730_000_000)
        let yesterday = DateHelpers.daysAgo(1, from: now)
        let diff = now.timeIntervalSince(yesterday)
        XCTAssertEqual(diff, 86_400, accuracy: 1.0)
    }

    func test_daysAgo_zero_returnsSameDay() {
        let now = Date()
        let same = DateHelpers.daysAgo(0, from: now)
        XCTAssertEqual(now.timeIntervalSince(same), 0, accuracy: 1.0)
    }

    func test_startOfDay_alignsToCalendarMidnight() {
        let date = Date(timeIntervalSince1970: 1_730_045_000)
        let start = DateHelpers.startOfDay(date)
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute, .second], from: start)
        XCTAssertEqual(comps.hour, 0)
        XCTAssertEqual(comps.minute, 0)
        XCTAssertEqual(comps.second, 0)
    }
}
#endif
