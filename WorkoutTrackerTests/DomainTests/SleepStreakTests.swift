import XCTest
@testable import WorkoutTracker

@MainActor
final class SleepStreakTests: XCTestCase {
    private let cal = Calendar(identifier: .gregorian)

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d
        return cal.date(from: c)!
    }

    private func record(_ d: Date, _ minutes: Int) -> SleepDailyRecord {
        SleepDailyRecord(
            dayStart: d, totalMinutes: minutes, source: .seed, lastSyncedAt: Date()
        )
    }

    func test_three_consecutive_met_days() {
        let today = day(2026, 5, 8)
        let records = [
            record(day(2026, 5, 6), 480),
            record(day(2026, 5, 7), 460),
            record(today, 470),
        ]
        let streak = SleepStreak.currentStreak(
            records: records, targetMinutes: 420, today: today, calendar: cal
        )
        XCTAssertEqual(streak, 3)
    }

    func test_today_unmet_falls_back_to_yesterday() {
        let today = day(2026, 5, 8)
        let records = [
            record(day(2026, 5, 6), 480),
            record(day(2026, 5, 7), 460),
            record(today, 300),  // 未達
        ]
        let streak = SleepStreak.currentStreak(
            records: records, targetMinutes: 420, today: today, calendar: cal
        )
        XCTAssertEqual(streak, 2)
    }

    func test_gap_breaks_streak() {
        let today = day(2026, 5, 8)
        let records = [
            record(day(2026, 5, 5), 480),
            record(day(2026, 5, 7), 460),
            record(today, 470),
        ]
        let streak = SleepStreak.currentStreak(
            records: records, targetMinutes: 420, today: today, calendar: cal
        )
        XCTAssertEqual(streak, 2)
    }
}
