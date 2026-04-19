import Foundation
import SwiftData

@Model
final class TemplateExercise {
    var id: UUID
    var order: Int
    var exercise: Exercise?
    var template: WorkoutTemplate?
    var targetSets: Int
    var targetReps: Int
    var targetWeightKg: Double?

    init(
        id: UUID = UUID(),
        order: Int = 0,
        exercise: Exercise,
        targetSets: Int,
        targetReps: Int,
        targetWeightKg: Double? = nil
    ) {
        self.id = id
        self.order = order
        self.exercise = exercise
        self.targetSets = targetSets
        self.targetReps = targetReps
        self.targetWeightKg = targetWeightKg
    }
}
