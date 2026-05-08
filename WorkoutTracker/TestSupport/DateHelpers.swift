import Foundation

#if DEBUG
enum DateHelpers {
    static func daysAgo(_ days: Int, from base: Date = Date()) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: base) ?? base
    }

    static func startOfDay(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }
}
#endif
