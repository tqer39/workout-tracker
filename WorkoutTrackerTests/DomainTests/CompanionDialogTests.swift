import XCTest
@testable import WorkoutTracker

final class CompanionDialogTests: XCTestCase {
    private let progress = JourneyProgress(
        totalSteps: 100_000,
        totalKm: 100,
        progressRatio: 0.087,
        lastPassedCheckpoint: JourneyRoute.tokyoToHakata[1],
        nextCheckpoint: JourneyRoute.tokyoToHakata[2],
        metersToNext: 5_000,
        isCompleted: false
    )

    func test_returns_non_empty_for_each_time_of_day() {
        for tod in TimeOfDay.allCases {
            let line = CompanionDialog.line(
                progress: progress, todaySteps: 4000,
                dailyGoal: 8000, timeOfDay: tod, lastShown: nil
            )
            XCTAssertFalse(line.isEmpty, "\(tod) でセリフが空")
        }
    }

    func test_avoids_repeating_lastShown() {
        for _ in 0..<100 {
            let last = "前回のセリフ"
            let line = CompanionDialog.line(
                progress: progress, todaySteps: 4000,
                dailyGoal: 8000, timeOfDay: .day, lastShown: last
            )
            XCTAssertNotEqual(line, last)
        }
    }

    func test_completed_journey_has_celebration_message() {
        let done = JourneyProgress(
            totalSteps: 1_200_000, totalKm: 1150, progressRatio: 1.0,
            lastPassedCheckpoint: JourneyRoute.tokyoToHakata.last,
            nextCheckpoint: nil, metersToNext: 0, isCompleted: true
        )
        let line = CompanionDialog.line(
            progress: done, todaySteps: 9000,
            dailyGoal: 8000, timeOfDay: .day, lastShown: nil
        )
        XCTAssertFalse(line.isEmpty)
    }

    func test_goal_achieved_uses_celebration_pool() {
        var seen: Set<String> = []
        for _ in 0..<30 {
            let line = CompanionDialog.line(
                progress: progress, todaySteps: 9000,
                dailyGoal: 8000, timeOfDay: .day, lastShown: nil
            )
            seen.insert(line)
        }
        XCTAssertGreaterThan(seen.count, 1, "達成時セリフプールが複数件あること")
    }
}
