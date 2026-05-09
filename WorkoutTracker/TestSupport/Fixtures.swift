import Foundation
import SwiftData

#if DEBUG
@MainActor
enum Fixtures {
    enum Steps {
        static let representative = 1234
        static let goalAchieved   = 8500
        static let lazy           = 320
        static let highEffort     = 12_345
    }

    static let varietyWeek: [Int]   = [1234, 5432, 8500, 320, 9100, 6700, 4200]
    static let streak4Days: [Int]   = [8500, 8600, 8400, 8700]

    static func stepRecord(_ count: Int, daysAgo: Int = 0) -> StepDailyRecord {
        StepDailyRecord(
            dayStart: DateHelpers.startOfDay(DateHelpers.daysAgo(daysAgo)),
            steps: count,
            source: .seed,
            lastSyncedAt: Date()
        )
    }

    static func achievement(_ checkpointId: String, daysAgo: Int = 0) -> CheckpointAchievement {
        CheckpointAchievement(
            checkpointId: checkpointId,
            achievedAt: DateHelpers.daysAgo(daysAgo),
            totalStepsAtAchievement: 0,
            celebrated: false
        )
    }

    static func bodyMetric(weightKg: Double = 72.4,
                           bodyFatPercent: Double? = 22.0,
                           daysAgo: Int = 0) -> BodyMetric {
        BodyMetric(
            recordedAt: DateHelpers.daysAgo(daysAgo),
            weightKg: weightKg,
            bodyFatPercent: bodyFatPercent,
            source: .manual
        )
    }

    static func session(startedDaysAgo: Int = 0) -> WorkoutSession {
        WorkoutSession(startedAt: DateHelpers.daysAgo(startedDaysAgo))
    }

    static func midJourneyAchievements() -> [CheckpointAchievement] {
        ["tokyo", "yokohama", "atami", "shizuoka"]
            .enumerated()
            .map { i, id in achievement(id, daysAgo: 30 - i * 5) }
    }

    static func firstDayUser() -> [StepDailyRecord] {
        [stepRecord(Steps.representative, daysAgo: 0)]
    }
}
#endif
