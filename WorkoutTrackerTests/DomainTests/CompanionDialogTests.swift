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

    // 各テストで使う最小限のラインセット（bundledLines に依存しない）
    private let testLines: [CompanionLine] = [
        CompanionLine(text: "未達成・朝", progress: [.unmet], timeOfDay: [.morning], streak: nil, distance: nil),
        CompanionLine(text: "未達成・昼", progress: [.unmet], timeOfDay: [.day], streak: nil, distance: nil),
        CompanionLine(text: "未達成・夕", progress: [.unmet], timeOfDay: [.evening], streak: nil, distance: nil),
        CompanionLine(text: "未達成・夜", progress: [.unmet], timeOfDay: [.night], streak: nil, distance: nil),
        CompanionLine(text: "達成・汎用", progress: [.achieved], timeOfDay: nil, streak: nil, distance: nil),
        CompanionLine(text: "達成・昼", progress: [.achieved], timeOfDay: [.day], streak: nil, distance: nil),
        CompanionLine(text: "完走・祝福", progress: [.completed], timeOfDay: nil, streak: nil, distance: nil),
    ]

    func test_returns_non_empty_for_each_time_of_day() {
        for tod in TimeOfDay.allCases {
            let line = CompanionDialog.line(
                progress: progress, todaySteps: 4000,
                dailyGoal: 8000, timeOfDay: tod, streakDays: 0, lastShown: nil,
                lines: testLines
            )
            XCTAssertFalse(line.isEmpty, "\(tod) でセリフが空")
        }
    }

    func test_avoids_repeating_lastShown() {
        for _ in 0..<100 {
            let last = "達成・汎用"
            let line = CompanionDialog.line(
                progress: progress, todaySteps: 9000,
                dailyGoal: 8000, timeOfDay: .day, streakDays: 0, lastShown: last,
                lines: testLines
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
            dailyGoal: 8000, timeOfDay: .day, streakDays: 0, lastShown: nil,
            lines: testLines
        )
        XCTAssertFalse(line.isEmpty)
    }

    func test_goal_achieved_uses_celebration_pool() {
        var seen: Set<String> = []
        for _ in 0..<30 {
            let line = CompanionDialog.line(
                progress: progress, todaySteps: 9000,
                dailyGoal: 8000, timeOfDay: .day, streakDays: 0, lastShown: nil,
                lines: testLines
            )
            seen.insert(line)
        }
        XCTAssertGreaterThan(seen.count, 1, "達成時セリフプールが複数件あること")
    }

    // 追加テスト: progressBand によるフィルタリング
    func test_filter_lines_match_progress_band() {
        let done = JourneyProgress(
            totalSteps: 1_200_000, totalKm: 1150, progressRatio: 1.0,
            lastPassedCheckpoint: JourneyRoute.tokyoToHakata.last,
            nextCheckpoint: nil, metersToNext: 0, isCompleted: true
        )
        let lines: [CompanionLine] = [
            CompanionLine(text: "完走専用", progress: [.completed], timeOfDay: nil, streak: nil, distance: nil),
            CompanionLine(text: "未達成専用", progress: [.unmet], timeOfDay: nil, streak: nil, distance: nil),
        ]
        for _ in 0..<20 {
            let line = CompanionDialog.line(
                progress: done, todaySteps: 9000,
                dailyGoal: 8000, timeOfDay: .day, streakDays: 0, lastShown: nil,
                lines: lines
            )
            XCTAssertEqual(line, "完走専用", "completed プログレスでは completed ラインのみ選ばれること")
        }
    }

    // 追加テスト: streakBand による絞り込み（oneMonthPlus のみラインで完全一致確認）
    func test_filter_uses_streak_band() {
        // streak: oneMonthPlus かつ progress/timeOfDay 指定なし（ワイルドカード）
        // 他のラインは streak が指定されていないのでマッチしない
        let lines: [CompanionLine] = [
            CompanionLine(text: "1ヶ月以上継続", progress: nil, timeOfDay: nil, streak: [.oneMonthPlus], distance: nil),
            CompanionLine(text: "3日継続専用", progress: nil, timeOfDay: nil, streak: [.threeDay], distance: nil),
        ]
        // streakDays: 35 → StreakBand.oneMonthPlus
        var seen: Set<String> = []
        for _ in 0..<20 {
            let line = CompanionDialog.line(
                progress: progress, todaySteps: 4000,
                dailyGoal: 8000, timeOfDay: .day, streakDays: 35, lastShown: nil,
                lines: lines
            )
            seen.insert(line)
        }
        // oneMonthPlus のみがマッチするので、フォールバック前はそれしか選ばれない
        XCTAssertTrue(seen.contains("1ヶ月以上継続"), "oneMonthPlus ラインが候補に含まれること")
        XCTAssertFalse(seen.contains("3日継続専用"), "threeDay ラインは oneMonthPlus では選ばれない")
    }

    // 追加テスト: 一切マッチしなくてもフォールバックで何かを返す
    func test_falls_back_when_no_match() {
        // progress: achieved に固定したラインしかない状態で unmet を渡す
        let lines: [CompanionLine] = [
            CompanionLine(text: "達成のみ", progress: [.achieved], timeOfDay: [.morning], streak: nil, distance: nil),
        ]
        let line = CompanionDialog.line(
            progress: progress, todaySteps: 4000,
            dailyGoal: 8000, timeOfDay: .night, streakDays: 0, lastShown: nil,
            lines: lines
        )
        XCTAssertFalse(line.isEmpty, "フォールバックで空にならないこと")
    }
}
