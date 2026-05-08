import XCTest
@testable import WorkoutTracker

final class StreakCalculatorTests: XCTestCase {
    private let cal = Calendar(identifier: .gregorian)
    private let goal = 8000

    private func day(_ offset: Int, from base: Date) -> Date {
        cal.date(byAdding: .day, value: offset, to: base)!
    }

    private func record(_ steps: Int, dayStart: Date) -> StepDailyRecord {
        StepDailyRecord(dayStart: dayStart, steps: steps, source: .seed, lastSyncedAt: dayStart)
    }

    func test_no_records_zero_streak() {
        let today = cal.startOfDay(for: Date())
        let s = StreakCalculator.currentStreak(records: [], dailyGoal: goal,
                                                today: today, calendar: cal)
        XCTAssertEqual(s, 0)
    }

    func test_today_only_met() {
        let today = cal.startOfDay(for: Date())
        let s = StreakCalculator.currentStreak(
            records: [record(9000, dayStart: today)],
            dailyGoal: goal, today: today, calendar: cal
        )
        XCTAssertEqual(s, 1)
    }

    func test_today_unmet_yesterday_met_streak_one() {
        let today = cal.startOfDay(for: Date())
        let records = [
            record(3000, dayStart: today),
            record(8500, dayStart: day(-1, from: today)),
        ]
        let s = StreakCalculator.currentStreak(
            records: records, dailyGoal: goal, today: today, calendar: cal
        )
        XCTAssertEqual(s, 1)
    }

    func test_three_consecutive_days_met() {
        let today = cal.startOfDay(for: Date())
        let records = [
            record(8200, dayStart: today),
            record(8500, dayStart: day(-1, from: today)),
            record(9000, dayStart: day(-2, from: today)),
            record(7900, dayStart: day(-3, from: today)),
        ]
        let s = StreakCalculator.currentStreak(
            records: records, dailyGoal: goal, today: today, calendar: cal
        )
        XCTAssertEqual(s, 3)
    }

    func test_gap_breaks_streak() {
        let today = cal.startOfDay(for: Date())
        let records = [
            record(9000, dayStart: today),
            record(8500, dayStart: day(-2, from: today)),
        ]
        let s = StreakCalculator.currentStreak(
            records: records, dailyGoal: goal, today: today, calendar: cal
        )
        XCTAssertEqual(s, 1)
    }

    func test_zero_today_zero_yesterday() {
        let today = cal.startOfDay(for: Date())
        let records = [
            record(0, dayStart: today),
            record(0, dayStart: day(-1, from: today)),
        ]
        let s = StreakCalculator.currentStreak(
            records: records, dailyGoal: goal, today: today, calendar: cal
        )
        XCTAssertEqual(s, 0)
    }
}
