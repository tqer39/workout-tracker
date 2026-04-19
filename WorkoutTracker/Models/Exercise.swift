import Foundation
import SwiftData

@Model
final class Exercise {
    var id: UUID
    var name: String
    var category: ExerciseCategory
    var defaultWeightKg: Double?
    var defaultRestSeconds: Int
    var notes: String?
    var isHidden: Bool

    @Relationship(deleteRule: .nullify, inverse: \SetRecord.exercise)
    var setRecords: [SetRecord] = []

    @Relationship(deleteRule: .nullify, inverse: \TemplateExercise.exercise)
    var templateExercises: [TemplateExercise] = []

    init(
        id: UUID = UUID(),
        name: String,
        category: ExerciseCategory,
        defaultWeightKg: Double? = nil,
        defaultRestSeconds: Int = 90,
        notes: String? = nil,
        isHidden: Bool = false
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.defaultWeightKg = defaultWeightKg
        self.defaultRestSeconds = defaultRestSeconds
        self.notes = notes
        self.isHidden = isHidden
    }
}
