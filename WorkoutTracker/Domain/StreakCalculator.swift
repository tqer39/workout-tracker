import Foundation

enum StreakCalculator {
    static func currentStreak(
        records: [StepDailyRecord],
        dailyGoal: Int,
        today: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        let todayStart = calendar.startOfDay(for: today)
        let byDay = Dictionary(uniqueKeysWithValues:
            records.map { (calendar.startOfDay(for: $0.dayStart), $0.steps) }
        )

        var cursor = todayStart
        if (byDay[cursor] ?? 0) < dailyGoal {
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }

        var streak = 0
        while let steps = byDay[cursor], steps >= dailyGoal {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }
}
