import Foundation

struct SleepSample: Equatable, Sendable {
    let startDate: Date
    let endDate: Date
    let isAsleep: Bool
}

struct SleepDailyDTO: Equatable, Sendable {
    let dayStart: Date
    let totalMinutes: Int
    let source: SleepSource
}

enum SleepAggregator {
    static func aggregate(
        samples: [SleepSample],
        calendar: Calendar = .current
    ) -> [SleepDailyDTO] {
        var byDay: [Date: TimeInterval] = [:]
        for s in samples where s.isAsleep {
            let key = calendar.startOfDay(for: s.endDate)
            byDay[key, default: 0] += s.endDate.timeIntervalSince(s.startDate)
        }
        return byDay
            .map { (day, seconds) in
                SleepDailyDTO(
                    dayStart: day,
                    totalMinutes: max(0, Int((seconds / 60.0).rounded())),
                    source: .healthKit
                )
            }
            .sorted { $0.dayStart < $1.dayStart }
    }
}
