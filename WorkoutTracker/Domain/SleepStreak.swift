import Foundation

enum SleepStreak {
    static func currentStreak(
        records: [SleepDailyRecord],
        targetMinutes: Int,
        today: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        let todayStart = calendar.startOfDay(for: today)
        let byDay = Dictionary(
            records.map { (calendar.startOfDay(for: $0.dayStart), $0.totalMinutes) },
            uniquingKeysWith: { a, b in max(a, b) }
        )

        var cursor = todayStart
        if (byDay[cursor] ?? 0) < targetMinutes {
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }

        var streak = 0
        while let minutes = byDay[cursor], minutes >= targetMinutes {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }
}
