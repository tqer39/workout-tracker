import XCTest
@testable import WorkoutTracker

final class SleepAggregatorTests: XCTestCase {
    private let cal = Calendar(identifier: .gregorian)

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d; c.hour = h; c.minute = min
        return cal.date(from: c)!
    }

    func test_empty_samples_returns_empty() {
        XCTAssertTrue(SleepAggregator.aggregate(samples: []).isEmpty)
    }

    func test_single_night_simple_sum() {
        let samples = [
            SleepSample(
                startDate: date(2026, 5, 7, 23, 0),
                endDate:   date(2026, 5, 8, 6, 0),
                isAsleep:  true
            )
        ]
        let result = SleepAggregator.aggregate(samples: samples, calendar: cal)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].totalMinutes, 7 * 60)
        XCTAssertEqual(
            result[0].dayStart,
            cal.startOfDay(for: date(2026, 5, 8, 6, 0))
        )
    }

    func test_multiple_samples_same_morning_are_summed() {
        let samples = [
            SleepSample(
                startDate: date(2026, 5, 7, 22, 30),
                endDate:   date(2026, 5, 8, 1, 0),
                isAsleep:  true
            ),
            SleepSample(
                startDate: date(2026, 5, 8, 1, 30),
                endDate:   date(2026, 5, 8, 6, 0),
                isAsleep:  true
            ),
        ]
        let result = SleepAggregator.aggregate(samples: samples)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].totalMinutes, 150 + 270)
    }

    func test_inBed_samples_are_skipped() {
        let samples = [
            SleepSample(
                startDate: date(2026, 5, 7, 22, 0),
                endDate:   date(2026, 5, 7, 23, 0),
                isAsleep:  false
            ),
            SleepSample(
                startDate: date(2026, 5, 7, 23, 0),
                endDate:   date(2026, 5, 8, 6, 0),
                isAsleep:  true
            ),
        ]
        let result = SleepAggregator.aggregate(samples: samples)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].totalMinutes, 7 * 60)
    }

    func test_overnight_attributes_to_morning() {
        let samples = [
            SleepSample(
                startDate: date(2026, 5, 7, 22, 0),
                endDate:   date(2026, 5, 8, 6, 0),
                isAsleep:  true
            )
        ]
        let result = SleepAggregator.aggregate(samples: samples, calendar: cal)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(
            result[0].dayStart,
            cal.startOfDay(for: date(2026, 5, 8, 6, 0))
        )
    }

    func test_two_separate_nights_yield_two_dtos() {
        let samples = [
            SleepSample(
                startDate: date(2026, 5, 6, 23, 0),
                endDate:   date(2026, 5, 7, 6, 0),
                isAsleep:  true
            ),
            SleepSample(
                startDate: date(2026, 5, 7, 23, 0),
                endDate:   date(2026, 5, 8, 6, 0),
                isAsleep:  true
            ),
        ]
        let result = SleepAggregator.aggregate(samples: samples)
            .sorted(by: { $0.dayStart < $1.dayStart })
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].totalMinutes, 7 * 60)
        XCTAssertEqual(result[1].totalMinutes, 7 * 60)
    }
}
