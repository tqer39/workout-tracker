import Foundation
import SwiftData

@Model
final class SleepDailyRecord {
    var id: UUID
    @Attribute(.unique) var dayStart: Date
    var totalMinutes: Int
    var source: SleepSource
    var lastSyncedAt: Date

    init(
        id: UUID = UUID(),
        dayStart: Date,
        totalMinutes: Int,
        source: SleepSource,
        lastSyncedAt: Date
    ) {
        self.id = id
        self.dayStart = dayStart
        self.totalMinutes = totalMinutes
        self.source = source
        self.lastSyncedAt = lastSyncedAt
    }
}
