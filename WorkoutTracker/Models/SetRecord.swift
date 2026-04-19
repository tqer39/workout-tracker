import Foundation
import SwiftData

@Model
final class SetRecord {
    var id: UUID
    var exercise: Exercise?
    var session: WorkoutSession?
    var weightKg: Double
    var reps: Int
    var rpe: Double?
    var performedAt: Date
    var restSeconds: Int?

    init(
        id: UUID = UUID(),
        exercise: Exercise,
        session: WorkoutSession? = nil,
        weightKg: Double,
        reps: Int,
        rpe: Double? = nil,
        performedAt: Date = Date(),
        restSeconds: Int? = nil
    ) {
        self.id = id
        self.exercise = exercise
        self.session = session
        self.weightKg = weightKg
        self.reps = reps
        self.rpe = rpe
        self.performedAt = performedAt
        self.restSeconds = restSeconds
    }
}
