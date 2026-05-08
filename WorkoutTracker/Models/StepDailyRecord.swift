import Foundation
import SwiftData

@Model
final class StepDailyRecord {
    var id: UUID
    @Attribute(.unique) var dayStart: Date
    var steps: Int
    var source: StepSource
    var lastSyncedAt: Date

    init(
        id: UUID = UUID(),
        dayStart: Date,
        steps: Int,
        source: StepSource,
        lastSyncedAt: Date
    ) {
        self.id = id
        self.dayStart = dayStart
        self.steps = steps
        self.source = source
        self.lastSyncedAt = lastSyncedAt
    }
}
