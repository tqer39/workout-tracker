import Foundation
import SwiftData

@Model
final class WorkoutSession {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var templateRef: WorkoutTemplate?
    var notes: String?

    @Relationship(deleteRule: .cascade, inverse: \SetRecord.session)
    var sets: [SetRecord] = []

    init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        templateRef: WorkoutTemplate? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.templateRef = templateRef
        self.notes = notes
    }
}
